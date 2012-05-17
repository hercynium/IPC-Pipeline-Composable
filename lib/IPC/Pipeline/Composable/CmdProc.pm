use strict;
use warnings;
package IPC::Pipeline::Composable::CmdProc;
# ABSTRACT: A command process in a pipeline
use Carp;
use English qw( -no_match_vars );
use autodie;
use Scalar::Util qw( reftype blessed );
use File::Temp qw( tmpnam );
use POSIX qw( mkfifo );
use IPC::Pipeline::Continuous qw( pipeline_c pipeline );
use Data::Dumper;

=method new

Create a new command process object

Takes the following options:

=for :list
* cmd - the path to the command to run. (required)
* args - an arrayref of strings that will be arguments to the command. (optional)

=cut
sub new {
  my ($class, %opt) = @_;
  return bless {
    cmdsub_class      => __PACKAGE__,
    procsub_class     => 'IPC::Pipeline::Composable::ProcSub',
    placeholder_class => 'IPC::Pipeline::Composable::Placeholder',
    %opt,
  }, $class;
}

=attribute cmd

The command that will be exec'd

=cut
sub cmd { shift->{cmd} }

=attribute args

The arguments to pass to the command when it is exec'd

=cut
sub args {
  my ($self) = @_;
  return wantarray ? @{ $self->{args} || [] } : ($self->{args} || []);
}

=attribute spec

The "spec" that is passed to L<IPC::Pipeline::Continuous>

=cut
sub spec {
  my ($self) = @_;
  return [ $self->cmd, $self->args ];
}

=attribute cmdsub_class

The class this object recognizes for command substitution

=cut
sub cmdsub_class { shift->{cmdsub_class} }

=attribute procsub_class

The class this object recognizes for process substitution

=cut
sub procsub_class { shift->{procsub_class} }

=attribute placeholder_class

The class this object recognizes as a placeholder

=cut
sub placeholder_class { shift->{placeholder_class} }


=method run

Run the command in a forked process, with STDIN, STDOUT and STDERR connected
to the specified handles

Takes the following options: (all optional)

=for :list
* stdin - the file handle used to feed input to the command's STDIN
* stdout - the file handle used to read output from the command's STDOUT
* stderr - the file handle used to read output from the command's STDERR

=cut
sub run {
  my ($self, %opt) = @_;

  my %procsub_pipes; # hold named pipe paths for process substitution

  my @args = map { $self->_process_arg($_, \%procsub_pipes, \%opt) } $self->args;
  my @handles      = @opt{qw(stdin stdout stderr)};
  my $cmd_spec     = [$self->cmd, @args];
  #print Dumper(\@handles);
  #print Dumper($cmd_spec);
  my @cmd_pids     = $self->_run_pipeline( @handles, $cmd_spec );
  my @procsub_pids = __do_procsubs( \%procsub_pipes, $opt{stderr} );
  my @pids         = ( @cmd_pids, @procsub_pids );
  return wantarray ? @pids : \@pids;
}

sub _run_pipeline {
  my ($self, $stdin, $stdout, $stderr, @cmds) = @_;

  #print Dumper [$stdin, $stdout, $stderr, @cmds];

  # TODO: when this is working for stdout, do it for all three handles.
  if ( ref($stdout) and reftype($stdout) eq 'SCALAR' ) {
    pipe(my($mine), my($theirs)); # TODO: file a bug on autodie for this.
    my @pids = pipeline_c( $stdin, $theirs, $stderr, @cmds );
    wait for @pids;
    close $theirs;
    while (sysread($mine, my $buf, 512)) { $$stdout .= $buf; };
    close $mine;
    return @pids;
  }
  return pipeline_c( $stdin, $stdout, $stderr, @cmds );
}

sub _process_arg {
  my ($self, $arg, $procsub_pipes, $opt) = @_;

  return $arg unless blessed $arg;

  if ( $arg->isa( $self->procsub_class ) ) {
    my $pipe = tmpnam; # race condition? probably.
    mkfifo $pipe, 0700;
    $procsub_pipes->{$pipe} = $arg;
    return $pipe;
  }

  if ( $arg->isa( $self->placeholder_class ) ) {
    my $name = $arg->name;
    my $actual =
      exists $opt->{$name}             ? $opt->{$name} :
      exists $self->{placevars}{$name} ? $self->{placevars}{$name} :
      return ();
    return $self->_process_arg($actual, $procsub_pipes, $opt);
  }

  if ( $arg->isa( $self->cmdsub_class ) ) {
    my $buf;
    my %cs_opt = %$opt;
    delete @cs_opt{qw(stdin stdout stderr)};
    my @pids = $arg->run(%cs_opt, stdout => \$buf);
    return $buf;
  }
}

sub __do_procsubs {
  my ($procsub_pipes, $err) = @_;

  my @procsub_pids;
  while ( my($pipe, $procsub) = each %$procsub_pipes ) {

    my $fmode =
      $procsub->mode eq '>' ? '<' :
      $procsub->mode eq '<' ? '>' : undef;

    open my($fh), $fmode, $pipe;
    push @procsub_pids, $procsub->run(
      stdin  => ($procsub->mode eq '>' ? $fh : undef),
      stdout => ($procsub->mode eq '<' ? $fh : undef),
      stderr => $err,
    );

    unlink $pipe;
  }

  return @procsub_pids;
}

1 && q{this expression is true};
__END__
