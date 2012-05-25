use strict;
use warnings;
package IPC::Pipeline::Composable::Process::Command;

# ABSTRACT: A system command to be run in a separate process

use English qw(-no_match_vars);
use Carp;
use Data::Dumper;
use Params::Util qw(_STRING _ARRAYLIKE _HASHLIKE);
use List::Util qw(reduce);
use File::Temp qw(tmpnam);
use POSIX qw(mkfifo);

#use IPC::Pipeline::Composable qw(ipc_pl);
#use IPC::Pipeline::Composable::CmdSubst qw(ipc_cs);
#use IPC::Pipeline::Composable::ProcSubst qw(ipc_ps);
#use IPC::Pipeline::Composable::PlaceHolder qw(ipc_ph);

use parent qw(IPC::Pipeline::Composable::Process Exporter);
our @EXPORT_OK = qw(ipc_newcmd ipc_cmd);

sub run {
  my ($self, %opt) = @_;

  # figure out what args will *really* be used with the command,
  # make sure to keep track of process-subst. stuff
  my ($real_args, $ps_fifos) = __process_args(scalar $self->args, \%opt);

  my $cmd_pid = $self->_run_cmd([$self->cmd, @$real_args], \%opt);
  print Dumper $cmd_pid; exit;
  my @ps_pids = __run_ps_cmds($ps_fifos, \%opt);
}

# just a stub for now...
sub _run_cmd {
  my ($self, $cmd_spec, $opt) = @_;
  return join ' ', @$cmd_spec;
}

### ARGUMENT PROCESSING ###

sub __process_args {
  my ($args, $opt) = @_;

  # store process subst fifo => process specs in ps_fifos
  my %ps_fifos = %{ $opt->{ps_fifos} || {} };

  my @real_args;
  for my $arg ( @$args ) {

    # process substitution
    if ( __is_ps_spec($arg) ) {
      # make the fifo, record the association to its command, and push
      # it onto the command's real args
      my $fifo_name = tmpnam(); # race condition? probably.
      mkfifo $fifo_name, 0700;
      $ps_fifos{$fifo_name} = $arg;
      push @real_args, $fifo_name;
      next;
    }

    # command substitution
    if ( __is_cs_spec($arg) ) {

      die "Command Substitution not yet implemented!";

      # run the pipeline of commands, collect stdout into buffer,
      # push buffer contents onto real args
      my $buf;
      ipc_pl(@$arg)->run(stdout => \$buf, ps_fifos => \%ps_fifos)->finish;
      push @real_args, $buf;
      next;
    }

    # placeholder
    if ( __is_ph_spec($arg) ) {

      die "Placeholders not yet implemented!";

      my $ph_name = $arg->[0];

      if ( ! exists $opt->{places}{$ph_name} ) {
        carp "Missing value for placeholder [$ph_name]. using an empty string instead.";
        push @real_args, "";
        next;
      }

      my $ph_val = $opt->{places}{$ph_name};

    }

    # normal argument
    if ( _STRING($arg) ) {
      push @real_args, $arg;
      next;
    }

    # allow this so we have a mechanism to *skip* arguments
    next if !defined $arg;

    croak "Unknown type of command argument: [$arg]";
  }

  return (\@real_args, \%ps_fifos);
}

### ARG/SPEC DETECTION ###

# we know it's a process-substitution spec if it's an array where the first
# element is a string indicating the PS mode, and the remaining elements
# are all arrays or hashes. (the arrays are commands and the hashes are
# options)
sub __is_ps_spec {
  my ($spec) = @_;
  return unless _ARRAYLIKE($spec);
  return unless $spec->[0] =~ /^[><]$/;
  # we want the inverse - if any elements match the grep, the spec isn't correct.
  return ! grep { ! _ARRAYLIKE($_) and ! _HASHLIKE($_) } @$spec[ 1 .. $#$spec ];
}

# we know it's a command-substitution spec if it's an array where the first
# element is a string indicating CS-mode ($), and the remaining elements
# are all arrays or hashes. (the arrays are commands and the hashes are
# options)
sub __is_cs_spec {
  my ($spec) = @_;
  return unless _ARRAYLIKE($spec);
  return unless $spec->[0] =~ /^[\$]$/;
  return ! grep { ! _ARRAYLIKE($_) and ! _HASHLIKE($_) } @$spec[ 1 .. $#$spec ];
}

# we know it's a placeholder spec if it's an array with a single element
# that is a string.
sub __is_ph_spec {
  my ($spec) = @_;
  return unless _ARRAYLIKE($spec);
  return unless @$spec == 1;
  return defined _STRING($spec->[0]);
}

### CONSTRUCTOR ###

sub new {
  my ($class, %opt) = @_;

  croak "the cmd parameter is required!\n" unless $opt{cmd};
  croak "the cmd parameter must be a string!\n" unless defined _STRING($opt{cmd});

  my $self = $class->SUPER::new(%opt);

  return bless $self, $class;
}

### EXPORTED SUBS ###

sub ipc_newcmd { return __PACKAGE__->new(@_) }

sub ipc_cmd {
  my $cmd = shift;
  my @args = grep { _ARRAYLIKE($_) } @_;
  my $opt = reduce { %$a = (%$a, %$b); $a } grep { _HASHLIKE($_) } {},{}, @_;
  return __PACKAGE__->new(%$opt, cmd => $cmd, args => [@args]);
}


1 && q{this statement is true};
__END__
