use strict;
use warnings;
package IPC::Pipeline::Composable;
use English qw( -no_match_vars);
use Data::Dumper;
use autodie;
use Scalar::Util qw(reftype blessed);
use Fcntl;

#  IPC::Pipeline::Continuous is based off IPC::Pipeline, but works
#  in a slightly different manner. (final FH is not linked to a pipe)
use IPC::Pipeline::Continuous qw(pipeline_c pipeline);

BEGIN {
  use parent qw(Exporter);
  use vars qw( @EXPORT_OK %EXPORT_TAGS );
  our @EXPORT_OK = qw( ipc_pipeline ipc_command ipc_placeholder pipeline_c pipeline);
  our %EXPORT_TAGS = ( all => \@EXPORT_OK );
}

use IPC::Pipeline::Composable::Command qw();
use IPC::Pipeline::Composable::Placeholder qw();


=method new
Standard constructor.
TODO: describe options
=cut
sub new {
  my ($class, %args) = @_;
  my %self = (
    pids      => [],
    cmds      => [ @{ $args{cmds} || [] } ],
    (exists $args{source_fh} ? (source_fh => $args{source_fh}) : ()),
    (exists $args{sink_fh}   ? (sink_fh   => $args{sink_fh})   : ()),
    (exists $args{err_fh}    ? (serr_fh   => $args{err_fh})    : ()),
  );
  return bless \%self, $class;
}

=function ipc_pipeline
Construct a pipeline from a series of commands, placeholders or other pipelines
=cut
sub ipc_pipeline {
  my ($class, @cmds) =
    !eval { $_[0]->isa(__PACKAGE__) } ? (__PACKAGE__, @_) :
    blessed($_[0])                    ? (__PACKAGE__, @_) :
    @_;

  return $class->new(
    cmds => [ map {
      eval { $_->isa("${class}::Command") } ? $_ :
      eval { $_->isa($class) }              ? $_->cmds :
      ! ref($_)              ? ${ \"${class}::Command" }->new(cmd_str => $_) :
      reftype($_) eq 'ARRAY' ? ${ \"${class}::Command" }->new(cmd => shift(@$_), args => $_) :
      reftype($_) eq 'CODE'  ? ${ \"${class}::Command" }->new(cmd_code => $_) :
      die "unhandled type passed to ipc_pipeline!\n";
      # TODO: handle placeholders as commands
    } @cmds ]);
}

=function ipc_command
Construct a command from a series of arguments or placeholders
=cut
sub ipc_command {
  my ($class, $cmd, @args) =
    !eval { $_[0]->isa(__PACKAGE__) } ? (__PACKAGE__, @_) :
    blessed($_[0])                    ? (__PACKAGE__, @_) :
    @_;

  return ${ \"${class}::Command" }->new(cmd => $cmd, args => \@args);
}

=function ipc_placeholder
Construct a placeholder with a name and arguments
TODO: describe arguments
SEE ALSO: the new() method in L<IPC::Pipeline::Composable::Placeholder>
=cut
sub ipc_placeholder {
  my ($class, $name, %args) =
    !eval { $_[0]->isa(__PACKAGE__) } ? (__PACKAGE__, @_) : @_;

  return ${ \"${class}::Placeholder" }->new(name => $name, %args);
}

=method cmds
Get the list of commands that make up this pipeline
=cut
sub cmds { my ($self) = @_; wantarray ? @{$self->{cmds}} : $self->{cmds} }


=method pids
When the pipeline is running, get the list of process IDS of the commands.
Please note - they may not all be running. Checking them is your (or another
module's) job.
=cut
sub pids { my ($self) = @_; wantarray ? @{$self->{pids}} : $self->{pids} }


=method run
construct and run the pipeline from the cmd objects we've composed.
TODO: describe options and other stuff
=cut
sub run {
  my ($self, %args) = @_;
  %args = (%$self, %args);
  my $src  = exists $args{source_fh} ? $args{source_fh} : $args{source_file} ? __popenw($args{source_file}) : undef;
  my $sink = exists $args{sink_fh}   ? $args{sink_fh} : $args{sink_file} ? __popenr($args{sink_file}) : undef;
  my $err  = exists $args{err_fh}    ? $args{err_fh} : undef;
  my @cmds = map { scalar $_->spec(%args) } @{$self->{cmds}};
  #print Dumper $src, $sink, $err, \@cmds;
  @{$self->{pids}} = pipeline_c( $src, $sink, $err, @cmds );
  return $self;
}

=comment

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
      $pl->run(src => $src_fh, sink => $sink_fh, file => $0);

  To get really silly, perhaps this should work:
      $pl->run(src_fh => $src_fh, sink_fh => $sink_fh, file => sub{ open my $f, '<', $0; print lc while <$f>; 1 });
    Description:
      - put a perl process that reads the current script as lowercase in the file placeholder
      - connect the stdout of that perl process to a fifo
      - pass the name of the fifo as an argument to gzip -c
      - connect the stdout of gzip to a fifo
      - pass the name of that fifo as an argument to gunzip -c
      - connect the stdout of gunzip to the sink_fh so it will write to it
      * the result should be the script, in lowercase.
=cut


use POSIX qw(mkfifo O_NONBLOCK O_RDONLY O_WRONLY); # :sys_wait_h
sub __popenw { my $fh1 = __popenr(@_); sysopen my $fh, $_[0], O_NONBLOCK | O_WRONLY; $fh }
sub __popenr { sysopen my $fh, $_[0], O_NONBLOCK | O_RDONLY; $fh }

# This is so non-portable... I can't find a CPAN dist for this???
sub _proc_path_from_fh {
  return
    $OSNAME =~ /Linux/i        ? "/proc/self/fd/".fileno(shift) :
    $OSNAME =~ /MacOS|darwin/i ? "/dev/fd/".fileno(shift) :
    return;
}

1 && q{this expression is true};


