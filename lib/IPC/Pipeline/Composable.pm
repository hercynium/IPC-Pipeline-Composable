use strict;
use warnings;
package IPC::Pipeline::Composable;
use English qw( -no_match_vars);
use Data::Dumper;
use autodie;
use Fcntl;

# This package is embedded at the bottom of this module.
#  It is based off IPC::Pipeline, but works in a slightly
#  different manner. (final FH is not linked to a pipe)
IPC::Pipeline::Continuous->import('pipeline_c');

sub new {
  my ($class, %args) = @_;
  my %self = (
    pids      => [],
    cmds      => [],
    (exists $args{source_fh} ? (source_fh => $args{source_fh}) : ()),
    (exists $args{sink_fh}   ? (sink_fh   => $args{sink_fh})   : ()),
    (exists $args{err_fh}    ? (serr_fh   => $args{err_fh})    : ()),
  );
  return bless \%self, $class;
}

sub push_cmd {
  my ($self, @args) = @_;
  push @{$self->{cmds}}, \@args;
  return $self;
}

sub unshift_cmd {
  my ($self, @args) = @_;
  unshift @{$self->{cmds}}, \@args;
  return $self;
}

sub pids {
  my ($self) = @_;
  return wantarray ? @{$self->{pids}} : $self->{pids};
}

# This is so non-portable... I can't find a CPAN dist for this???
sub _proc_path_from_fh {
  return
    $OSNAME =~ /Linux/i        ? "/proc/self/fd/".fileno(shift) :
    $OSNAME =~ /MacOS|darwin/i ? "/dev/fd/".fileno(shift) :
    return;
}

# a writable fh for the pipeline's source, if available
sub source_fh {
  return shift->{source_fh};
}

# a writable path for the source, if available. (not all handles
# have paths, and some OSes don't have paths for all types of
# handles, for example, pipes on Windows, AFAIK)
sub source_fn {
  return _proc_path_from_fh(shift->source_fh);
}

# a readable fh for the pipeline's sink, if available
sub sink_fh {
  return shift->{sink_fh};
}

# a readable path for the sink, if available
sub sink_fn {
  return _proc_path_from_fh(shift->sink_fh);
}

# a readable fh for the pipeline's err output, if available
sub err_fh {
  return shift->{err_fh};
}

# a readable path for the err output, if available
sub err_fn {
  return _proc_path_from_fh(shift->err_fh);
}



# construct and run the pipeline from the cmd objects we've composed.
# the idea is this: an object of this class can double as a file-handle,
# so it can act as either a source or a sink!
sub run {
  my ($self,%args) = @_;
  my $src  = exists $self->{source_fh} ? $self->{source_fh} : undef; # shift @{$self->{cmds}};
  my $sink = exists $self->{sink_fh}   ? $self->{sink_fh}   : undef; #pop   @{$self->{cmds}};
  my $err  = exists $self->{err_fh}    ? $self->{err_fh}    : undef; #\*STDERR;
  @{$self->{pids}} = pipeline_c(
    $src, $sink, $err,
    @{ $self->{cmds} },
    #map { scalar $_->_spec() } @{$self->{cmds}},
  );
  #close $in;
  return $self;
}

1 && q{this expression is true};








# Hide this from PAUSE/CPAN
package
  IPC::Pipeline::Continuous;

use POSIX ();

BEGIN {
    use Exporter    ();
    use vars        qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    $VERSION        = 'based-on_IPC-Pipeline-0.4-2011070701';
    @ISA            = qw(Exporter);
    @EXPORT         = qw(pipeline pipeline_c);
    @EXPORT_OK      = qw();
    %EXPORT_TAGS    = qw();
}

sub exec_filter {
    my ($filter) = @_;

    if (ref($filter) eq 'CODE') {
        exit $filter->();
    } elsif (ref($filter) eq 'ARRAY') {
        exec(@$filter) or die("Cannot exec(): $!");
    }

    die('Invalid filter');
}

sub pipeline_c {
    my @filters = @_[3..$#_];

    return undef unless @filters;

    #
    # Validate the filters and die early.
    #
    foreach my $filter (@filters) {
        next if ref($filter) =~ /^CODE|ARRAY$/;

        die('Filter passed is not a CODE reference or ARRAY containing command and arguments');
    }

    #
    # Create the initial pipe for passing data into standard input to the first
    # filter passed.
    #
    pipe my ($child_out, $in) or die('Cannot create a file handle pair for standard input piping');

    #
    # Only create a standard error pipe if a standard error file handle glob
    # was passed in the 3rd argument position.
    #
    my ($error_out, $error_in);

    if (defined $_[2]) {
        pipe $error_out, $error_in or die('Cannot create a file handle pair for standard error piping');
    }

    my @pids;

    foreach my $f_idx (0..@filters-1) {
        my $filter = $filters[$f_idx];

        my ($out, $child_in);
        if (ref($_[1]) eq 'GLOB' and $f_idx >= @filters-1) {
            open($child_in, '>&=', $_[1])
        }
        else {
            pipe $out, $child_in
              or die('Cannot create a file handle pair for standard output piping');
        }

        my $pid = fork();

        if (!defined $pid) {
            die("Cannot fork(): $!");
        } elsif ($pid == 0) {
            open(STDIN, '<&', $child_out) or die('Cannot dup2() last output fd to current child stdin');
            open(STDOUT, '>&', $child_in) or die('Cannot dup2() last input fd to current child stdout');

            if (defined $_[2]) {
                open(STDERR, '>&', $error_in) or die('Cannot dup2() error pipe input to current child stderr');
            }

            exec_filter($filter);
        }

        #
        # This last child STDOUT file handle should be duplicated onto the next
        # process' standard input reader, or will be passed as the last child
        # output file descriptor if no other subsequent commands are left
        # to be run.
        #
        $child_out = $out;

        push @pids, $pid;
    }

    #
    # Substitute the first three arguments passed by the user with the file
    # handle on the parent's writing end of the initial pipe created for
    # writing to the first command, the last output file handle for the
    # last command, and the standard error handle.  If typeglobs or numeric
    # file descriptors for existing file handles are passed, an attempt will
    # be made to dup2() them as appropriate.
    #

    if (!defined $_[0]) {
        $_[0] = $in;
    } elsif (ref $_[0] eq 'GLOB') {
        open($_[0], '>&=', $in);
    } else {
        POSIX::dup2(fileno($in), $_[0]);
    }

    if (!defined $_[1]) {
        $_[1] = $child_out;
    } elsif (ref $_[1] eq 'GLOB') {
        open($_[1], '<&=', $child_out) if defined $child_out;
    } else {
        POSIX::dup2(fileno($child_out), $_[1]);
    }

    if (!defined $_[2]) {
        $_[2] = $error_out;
    } elsif (ref $_[2] eq 'GLOB') {
        open($_[2], '<&=', $error_out);
    } else {
        POSIX::dup2(fileno($error_out), $_[2]);
    }

    #
    # If called in array context, return each subprocess ID in the same order
    # as they are specified in the commands provided.  Otherwise, return the
    # pid of the first child.
    #
    return wantarray? @pids: $pids[0];
}

sub pipeline {
  if (ref($_[1]) ne 'GLOB') {
    goto pipeline_c;
  }
  pipe my($readme,$writeme);
  open($_[1], '<&=', $readme);
  return pipeline_c($_[0], $writeme, @_[2..$#_]);
}


1 && q{this expression is false};
__END__

=head1 NAME

IPC::Pipeline::Composable - Compose code and shell commands together into pipelines

=head1 SYNOPSIS

    use IPC::Pipeline::Composable qw( ipc_cmd ipc_pipeline ipc_placeholder );

    open my $f1, '>', "$0.sorted.gz";

    my $cmd1 = IPC::Pipeline::Composable->new( source => $0, cmd => 'sort' );
    my $cmd2 = ipc_cmd( source => $cmd1, cmd => 'gzip -c', sink => $f1 );

    # the two are composed into a pipeline and run as a set of connected
    # forked processes, much like shell redirection.
    $cmd2->run_async();

=head1 SYNOPSIS2

  my $ipc = IPC::Pipeline::Composable->new();
  $cat = $ipc->push_cmd( 'cat', $file_in );
  $tac = $ipc->push_cmd( 'tac' );

  my %statuses = map {
    waitpid($_, 0);
    $_ => ($? >> 8);
  } $ipc->run()->pids();

=head1 SYNOPSIS3

  use IPC::Pipeline::Composable qw(mk_cmd)

  $file_in = shift;

  $cat = mk_cmd( 'cat' args => [ $file_in ] );
  $tac = mk_cmd( 'tac' );

  $pipeline = $cat | $tac;

  $pipeline->run( sink => reverse $file_in );

  open my $out_fh, '>', (reverse $file_in)."alt";
  $pipeline = $pipeline | $out_fh

  $pipeline->run(); # output to alternate file

=head1 DESCRIPTION

This module takes the awesome L<IPC::Pipeline> and allows one to compose
pipelines together in a somewhat functional fashion, though with an
OO flavor.

So, every pipeline must have a sink, but a source is "optional"; The
command at the head of the pipeline could be a source, or you could
specify one when you call ->run(), *or* you could run with *no source*
and use ->pump() to pump data into the STDIN of the pipeline.

I've considered making it optional to have a sink as well, and adding
a ->drain() method, but that sounds problematic, both as a use-case
and for implementation. If you want, I plan on implementing the ability
to use a ref to a scalar as the sink.

=head2 FEATURES

=head2 CAVEATS

If any child process dies prematurely, or any of the piped file handles are
closed for any reason, the calling process inherits the kernel behavior of
receiving a SIGPIPE, which requires the installation of a signal handler for
appropriate recovery.


=head1 SEE ALSO

=over

=item * IPC::Pipeline, for the awesome module this is based on

=item * IPC::Open3, the standard in this area

=item * IPC::Run, for a Swiss Army knife of Unix I/O gizmos

=item * Forks::Super

=back

