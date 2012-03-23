use strict;
use warnings;
package IPC::Pipeline::Composable;

# ABSTRACT: compose commands and pipelines

use English qw( -no_match_vars );
use Data::Dumper;
use autodie;
use Scalar::Util qw( reftype blessed );
use File::Temp qw( tmpnam );
use POSIX qw( mkfifo );

#  IPC::Pipeline::Continuous is based off IPC::Pipeline, but works
#  in a slightly different manner. (final FH is not linked to a pipe)
use IPC::Pipeline::Continuous qw( pipeline_c pipeline );

BEGIN {
  use parent qw( Exporter );
  use vars qw( @EXPORT_OK %EXPORT_TAGS );
  our @EXPORT_OK = qw(
    ipc_pipeline
    ipc_cmd
    ipc_proc
    ipc_sub
    ipc_placeholder
    pipeline_c
    pipeline
  );
  our %EXPORT_TAGS = ( all => \@EXPORT_OK );
}

use IPC::Pipeline::Composable::Process qw();
use IPC::Pipeline::Composable::Placeholder qw();
use IPC::Pipeline::Composable::ProcessSub qw();
use IPC::Pipeline::Composable::CommandSub qw();


=method new

Standard constructor.

=for :list
* procs - an arrayref of processes you want in this pipeline.

=cut

sub new {
  my ($class, %args) = @_;
  my %self = (
    pids      => [],
    procs      => [ @{ $args{procs} || [] } ],
    (exists $args{source_fh} ? (source_fh => $args{source_fh}) : ()),
    (exists $args{sink_fh}   ? (sink_fh   => $args{sink_fh})   : ()),
    (exists $args{err_fh}    ? (serr_fh   => $args{err_fh})    : ()),
  );
  return bless \%self, $class;
}





=function ipc_pipeline

Construct a pipeline from a series of commands, placeholders or other pipelines

Arguments represent processes to run, and each can be any one of the following:

=for :list
* arrayref - ['sort', '-k2,2', '-g']
* subref   - sub { print map { join '', @$_ } sort { $a->[1] <=> $b->[1] } map { [split] } <> }
* Object of type IPC::Pipeline::Composable::Process or IPC::Pipeline::Composable

  my $pl = ipc_pipeline($obj, &some_sub, \@some_array, ...)

=cut

sub ipc_pipeline {
  my ($class, @procs) =
    !eval { $_[0]->isa(__PACKAGE__) } ? (__PACKAGE__, @_) :
    blessed($_[0])                    ? (__PACKAGE__, @_) :
    @_;

  return $class->new(
    procs => [ map {
      # IPC::Process object can be used as-is
      eval { $_->isa("${class}::Process") } ? $_ :
      # IPC object needs its processes extracted
      eval { $_->isa($class) }              ? ($_->procs) :
      # If it's a non-ref, try to stringify and use that as the process spec
      ! ref($_)              ? ${ \"${class}::Process" }->new(cmd_str => $_) :
      # Initialize a Process object from an arrayref
      reftype($_) eq 'ARRAY' ? ${ \"${class}::Process" }->new(cmd => shift(@$_), args => $_) :
      # Initialize a Process object from a subref
      reftype($_) eq 'CODE'  ? ${ \"${class}::Process" }->new(cmd => $_) :
      # unknown argument? DIE!
      die "unhandled type passed to ipc_pipeline!\n";
      # TODO: handle placeholders for processes
    } @procs ]);
}


# allow exported subs to be called as functions, or object/class methods.
sub __func_meth_args {
  return
    !eval { $_[0]->isa(__PACKAGE__) } ? (__PACKAGE__, @_) : # function call
    blessed($_[0])                    ? (__PACKAGE__, @_) : # object method call
    @_;                                                     # class method call
}

=function ipc_proc

Construct a process from a command and a series of arguments or placeholders

=cut

sub ipc_proc {
  my ($class, $cmd, @args) = __func_meth_args(@_);

  return ${ \"${class}::Process" }->new(cmd => $cmd, args => \@args);
}


=function ipc_sub

Turn a pipeline or process into a process substitution

=cut

sub ipc_sub {
  my ($class, $mode, @args) = __func_meth_args(@_);

  return ${ \"${class}::ProcessSub" }->new(
    mode => $mode,
    proc => ipc_pipeline(@args),
  );
}



=function ipc_placeholder

Construct a placeholder with a name and arguments

TODO: describe arguments

SEE ALSO: the new() method in L<IPC::Pipeline::Composable::Placeholder>

=cut

sub ipc_placeholder {
  my ($class, $name, %args) = __func_meth_args(@_);

  return ${ \"${class}::Placeholder" }->new(name => $name, %args);
}





=method procs

Get the list of processes that make up this pipeline

=cut

sub procs { my ($self) = @_; wantarray ? @{$self->{procs}} : $self->{procs} }



=method pids

When the pipeline is running, get the list of process IDs.
Please note - they may not all be running. Checking them is your (or another
module's) job.

=cut

sub pids {
  my ($self) = @_;
  return wantarray ? @{$self->{pids}} : [ @{$self->{pids}} ];
}

sub cmd_sub_pids  {
  my ($self) = @_;
  return wantarray ? @{$self->{cmd_sub_pids}} : [ @{$self->{cmd_sub_pids}} ];
}

sub proc_sub_pids {
  my ($self) = @_;
  return wantarray ? @{$self->{proc_sub_pids}} : [ @{$self->{proc_sub_pids}} ];
}

sub all_pids {
  my ($self) = @_;
  return (
    @{$self->{pids}},
    @{$self->{cmd_sub_pids}},
    @{$self->{proc_sub_pids}},
  );
}


sub _get_opt_fhs {
  my ($self, %opt) = @_;
  %opt = (%$self, %opt);
  # TODO: support opening files for the user
  my $src  = exists $opt{source_fh} ? $opt{source_fh} : undef;
  my $sink = exists $opt{sink_fh}   ? $opt{sink_fh} : undef;
  my $err  = exists $opt{err_fh}    ? $opt{err_fh} : undef;
  return ($src, $sink, $err);
}


=method run

Run the pipeline with the given inputs and outputs

TODO: describe the arguments

=cut

# this sub id a bit longer than I would like,
# but it all seems necessary...
sub run {
  my ($self, %opt) = @_;

  my ($src, $sink, $err) = $self->_get_opt_fhs(%opt);

  my @cmd_sub_pids;
  my @proc_specs;
  my %proc_sub_pipe;
  for my $proc ($self->procs) {
    if (ref($proc->cmd) and ref($proc->cmd) eq 'CODE') {
      push @proc_specs, $proc->cmd;
      next;
    }
    my @args;
    for my $arg ($proc->args) {

      # if it's an object, it might deserve some special treatment
      if (blessed($arg)) {
        if ($arg->isa(__PACKAGE__."::ProcessSub")) {
          my $pipe = tmpnam(); # race condition? probably.
          mkfifo $pipe, 0700;
          $proc_sub_pipe{$pipe} = $arg;
          push @args, $pipe;
          next;
        }
        if ($arg->isa(__PACKAGE__."::CommandSub")) {
          my $buf = '';
          push @cmd_sub_pids, $arg->run(output => \$buf)->all_pids;
          push @args, $buf;
          next;
        }
        if ($arg->isa(__PACKAGE__."::Placeholder")) {
          #print Dumper $arg, $arg->name, $opt{$arg->name}; exit;
          push @args, $opt{$arg->name} if $opt{$arg->name};
          # TODO: handle placeholder that isa ProcessSub, Process, or hmmmm...
          next;
        }
      }
      # didn't match anything above? stringify.
      push @args, "$arg";
    }

    push @proc_specs, [$proc->cmd, @args];
  }

  # finally run the procs in this pipeline
  my @pipeline_pids = pipeline_c($src, $sink, $err, @proc_specs);

  # if there were any proc subs, now's the time to start them.
  my @proc_sub_pids = __do_process_substitution(\%proc_sub_pipe, $err);

  $self->{pids}          = \@pipeline_pids;
  $self->{cmd_sub_pids}  = \@cmd_sub_pids;
  $self->{proc_sub_pids} = \@proc_sub_pids;

  return $self;
}


sub __do_process_substitution {
  my ($proc_sub_pipe, $err) = @_;

  my @proc_sub_pids;
  while ( my($pipe, $procsub) = each %$proc_sub_pipe ) {

    my $fmode =
      $procsub->mode eq '>' ? '<' :
      $procsub->mode eq '<' ? '>' : undef;

    open my($fh), $fmode, $pipe;
    @proc_sub_pids = $procsub->run(
      source_fh => ($procsub->mode eq '>' ? $fh : undef),
      sink_fh   => ($procsub->mode eq '<' ? $fh : undef),
      err_fh    => $err,
    );
    unlink $pipe;
  }

  return @proc_sub_pids;
}

# This is so non-portable... I can't find a CPAN dist for this???
sub __proc_path_from_fh {
  return
    $OSNAME =~ /Linux/i        ? "/proc/self/fd/".fileno(shift) :
    $OSNAME =~ /MacOS|darwin/i ? "/dev/fd/".fileno(shift) :
    return;
}

1 && q{this expression is true};
__END__

=begin notes

Notes to self:

  The desired feature is to have shell-like process-substitution.

  The way to do that in the API is to pass a pipeline or command as the argument for a command.

    examples:
      my $pl = ipc_pipeline(ipc_cmd('gunzip', '-c', ipc_sub('<', 'gzip -c', $0)));
      my $pl = ipc_pipeline(ipc_cmd('gunzip', '-c', ipc_sub('<', ipc_cmd('gzip -c', $0))));

  Technically, a command should just be a single-command pipeline.
      my $pl = ipc_cmd('gunzip', '-c', ipc_sub('<', 'gzip -c', $0));

  And of course, placeholders...
      my $pl = ipc_cmd('gunzip', '-c', ipc_sub('<', 'gzip -c', ipc_placeholder('file')));
      $pl->run(sink => $sink_fh, file => $0);

  To get really silly, perhaps this should work:
      $pl->run(sink_fh => $sink_fh, file => sub{ open my $f, '<', $0; print lc while <$f>; 1 });
    Description:
      - put a perl process that reads the current script as lowercase in the file placeholder
      - connect the stdout of that perl process to a fifo
      - pass the name of the fifo as an argument to gzip -c
      - connect the stdout of gzip to a fifo
      - pass the name of that fifo as an argument to gunzip -c
      - connect the stdout of gunzip to the sink_fh so it will write to it
      * the result should be the script, in lowercase.

    What should really happen:
      - see the ipc_sub when scanning the gunzip command's args
      - create a fifo/named pipe (store the path in a hash assocuated to the ipc_sub)
      - start the gunzip process with its output connected to $sink_fh, passing the fifo as an argument in place of the ipc_sub
      - start the gzip process with its output connected to the fifo for writing
=end notes

