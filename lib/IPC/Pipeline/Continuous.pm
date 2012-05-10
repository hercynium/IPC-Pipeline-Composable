use strict;
use warnings;
package IPC::Pipeline::Continuous;

# ABSTRACT: a pipeline where the ends don't have to be 'pumped'

###
### THIS CODE BASED HEAVILY ON IPC::Pipeline v0.4
### BY Erin Schönhals <wrath@cpan.org>.
### HOWEVER, THE BUGS ARE ALL MINE :)
###

use POSIX ();
use Data::Dumper;
use autodie;
use Scalar::Util qw(reftype);

BEGIN {
  use Exporter ();
  use vars     qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

  @ISA         = ('Exporter');
  @EXPORT      = qw(pipeline pipeline_c);
  @EXPORT_OK   = ();
  %EXPORT_TAGS = ();
}

sub pipeline {

  my ($child_out, $in);
  pipe $child_out, $in;
  if (!defined $_[0]) {
    $_[0] = $in;
  }
  elsif (reftype $_[0] eq 'GLOB') {
    open($_[0], '>&=', $in);
  }
  else {
    POSIX::dup2(fileno($in), $_[0]);
  }

  my ($out, $child_in);
  pipe $out, $child_in;
  if (!defined $_[1]) {
    $_[1] = $out;
  }
  elsif (reftype $_[1] eq 'GLOB') {
    open($_[1], '<&=', $out);
  }
  else {
    POSIX::dup2(fileno($out), $_[1]);
  }

  my ($error_out, $error_in);
  pipe $error_out, $error_in;
  if (!defined $_[2]) {
    $_[2] = $error_out;
  }
  elsif (reftype $_[2] eq 'GLOB') {
    open($_[2], '<&=', $error_out);
  }
  else {
    POSIX::dup2(fileno($error_out), $_[2]);
  }

  return pipeline_c($child_out, $child_in, $error_in, @_[3 .. $#_]);
}

sub pipeline_c {
  my @filters = @_[3..$#_];

  return undef unless @filters;

  foreach my $filter (@filters) {
    next if reftype($filter) =~ /^CODE|ARRAY$/;
    die('Filter passed is not a CODE reference or ARRAY containing command and arguments');
  }

  my $child_out = my $in = $_[0];

  # assign whatever for the child to use for stderr
  my $error_in = $_[2];

  #print STDERR "$$ parent output fileno: ", fileno($_[1]), "\n";

  my @pids;
  foreach my $i (0 .. $#filters) {
    my $filter = $filters[$i];

    my ($out, $child_in);
    if ($i == $#filters and ref($_[1]) and reftype($_[1]) eq 'GLOB') {
      $out = $child_in = $_[1];
      #print STDERR "$$ last child output fileno: ", fileno($child_in), "\n";
    }
    else {
      pipe $out, $child_in or die('Cannot create a file handle pair for standard output piping');
      #print STDERR "$$ pipe ends for next child: ", fileno($child_in), " -> ", fileno($out), "\n";
    }

    my $pid = fork_filter($child_out, $child_in, $error_in, $filter);

    $child_out = $out;

    push @pids, $pid;
  }

  return wantarray ? @pids : $pids[0];
}

sub fork_filter {
  my ($src, $sink, $err, $filter) = @_;

  my $pid = fork();
  return $pid if $pid;

  #print STDERR "$$ child filter: " . Dumper $filter;
  #print STDERR "$$ child in -> out: ", fileno($src), " -> ", fileno($sink), "\n" if defined $src and defined $sink;

  #print STDERR "$$ child input fileno: ", fileno($src), "\n" if defined $src and !defined $sink;
  if (defined $src and fileno($src) != fileno(STDIN)) {
    open(STDIN, '<&', $src) or die("Cannot dup2() to child $$ stdin");
  }

  #print STDERR "$$ child output fileno: ", fileno($sink), "\n" if defined $sink and !defined $src;
  if (defined $sink and fileno($sink) != fileno(STDOUT)) {
    open(STDOUT, '>&', $sink) or die("Cannot dup2() to child $$ stdout");
  }

  if (defined $err and fileno($err) != fileno(STDERR)) {
    open(STDERR, '>&', $err) or die("Cannot dup2() to child $$ stderr");
  }

  exec_filter($filter);
  die "pid $$ should never have gotten here.";
}

sub exec_filter {
  my ($filter) = @_;

  if (reftype($filter) eq 'CODE') {
    exit $filter->();
  }
  elsif (reftype($filter) eq 'ARRAY') {
    exec(@$filter) or die("Cannot exec(): $!");
  }

  die('Invalid filter');
}

1;

__END__

=head1 SYNOPSIS

    use IPC::Pipeline::Continuous;

    my @pids = pipeline(\*FIRST_CHLD_IN, \*LAST_CHLD_OUT, \*CHILDREN_ERR,
        [qw(filter1 args)],
        sub { filter2(); return 0 },
        [qw(filter3 args)],
        ...
        [qw(commandN args)]
    );

    ... do stuff ...

    my %statuses = map {
        waitpid($_, 0);
        $_ => ($? >> 8);
    } @pids;

=head1 ATTRIBUTION

The code in this module is based B<heavily> on L<IPC::Pipeline> v0.4 by
Erin Schönhals (<wrath@cpan.org>). Heavily as in, I copied almost all of it
directly. While I made a number of modifications, L<IPC::Pipeline::Continuous>
I<should> work as a drop-in-replacement, and so I've kept her documentation.
It does pass all of IPC::Pipeline's tests. The new functionality I added
is highly experimental and is currently only suitable for use by folks who
are willing to read the code, hence it not being documented at this time.

=head1 DESCRIPTION

Similar in calling convention to IPC::Open3, pipeline() spawns N children,
connecting the first child to the FIRST_CHLD_IN handle, the final child to
LAST_CHLD_OUT, and each child to a shared standard error handle, CHILDREN_ERR.
Each subsequent filter specified causes a new process to be fork()ed.  Each
process is linked to the last with a file descriptor pair created by pipe(),
using dup2() to chain each process' standard input to the last standard output.

=head2 FEATURES

IPC::Pipeline::Continuous accepts external commands to be executed in the form of ARRAY
references containing the command name and each argument, as well as CODE
references that are executed within their own processes as well, each as
independent parts of a pipeline.

=head3 ARRAY REFS

When a filter is passed in the form of an ARRAY containing an external system
command, each such item is executed in its own subprocess in the following
manner.

    exec(@$filter) or die("Cannot exec(): $!");

=head3 CODE REFS

When a filter is passed in the form of a CODE ref, each such item is executed in
its own subprocess in the following way.

    exit $filter->();

=head2 BEHAVIOR

If fileglobs or numeric file descriptors are passed in any of the three
positional parameters, then they will be duplicated onto the file handles 
allocated as a result of the process pipelining.  Otherwise, simple scalar
assignment will be performed.

Like IPC::Open3, pipeline() returns immediately after spawning the process
chain, though differing slightly in that the IDs of each process is returned
in order of specification in a list when called in array context.  When called
in scalar context, only the ID of the first child process spawned is returned.

Also like IPC::Open3, one may use select() to multiplex reading and writing to
each of the handles returned by pipeline(), preferably with non-buffered
sysread() and syswrite() calls.  Using this to handle reading standard output
and error from the children is ideal, as blocking and buffering considerations
are alleviated.

=head2 CAVEATS

If any child process dies prematurely, or any of the piped file handles are
closed for any reason, the calling process inherits the kernel behavior of
receiving a SIGPIPE, which requires the installation of a signal handler for
appropriate recovery.

Please be advised that any usage of numeric file descriptors will result in an
implicit import of POSIX::dup2() at runtime.

=head1 EXAMPLE ONE - OUTPUT ONLY

The following example implements a quick and dirty, but relatively sane tar and
gzip solution.  For proper error handling from any of the children, use select()
to multiplex the output and error streams.

    use IPC::Pipeline;

    my @paths = qw(/some /random /locations);

    my @pids = pipeline(my ($in, $out), undef,
        [qw(tar pcf -), @paths],
        ['gzip']
    );

    open(my $fh, '>', 'file.tar.gz');
    close $in;

    while (my $len = sysread($out, my $buf, 512)) {
        syswrite($fh, $buf, $len);
    }

    close $fh;
    close $out;

    #
    # We may need to wait for the children to die in some extraordinary
    # circumstances.
    #
    foreach my $pid (@pids) {
        waitpid($pid, 1);
    }

=head1 EXAMPLE TWO - INPUT AND OUTPUT

The following solution implements a true I/O stream filter as provided by any
Unix-style shell.

    use IPC::Pipeline;

    my @pids = pipeline(my ($in, $out), undef,
        [qw(tr A-Ma-mN-Zn-z N-Zn-zA-Ma-m)],
        [qw(cut -d), ':', qw(-f 2)]
    );

    my @records = qw(
        foo:bar:baz
        eins:zwei:drei
        cats:dogs:rabbits
    );

    foreach my $record (@records) {
        print $in $record ."\n";
    }

    close $in;

    while (my $len = sysread($out, my $buf, 512)) {
        syswrite(STDOUT, $buf, $len);
    }

    close $out;

    foreach my $pid (@pids) {
        waitpid($pid, 1);
    }

=head1 EXAMPLE THREE - MIXING COMMANDS AND CODEREFS

The following solution demonstrates the ability of IPC::Pipeline to execute CODE
references in the midst of a pipeline.

    use IPC::Pipeline;

    my @pids = pipeline(my ($in, $out), undef,
        sub { print 'cats'; return 0 },
        [qw(tr acst lbhe)]
    );

    close $in;

    while (my $line = readline($out)) {
        chomp $line;
        print "Got '$line'\n";
    }

    close $out;

=head1 SEE ALSO

=over

=item * IPC::Open3

=item * IPC::Run, for a Swiss Army knife of Unix I/O gizmos

It should be mentioned that mst's IO::Pipeline has very little in common with IPC::Pipeline.

=back

=head1 COPYRIGHT

Copyright 2011, Erin Schönhals <wrath@cpan.org>.  Released under the terms of
the MIT license.
