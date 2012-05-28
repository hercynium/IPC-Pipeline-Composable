use strict;
use warnings;
package IPC::Pipeline::Composable::Process;

# ABSTRACT: Code or a system command to be run in a separate process

use English qw(-no_match_vars);
use Carp;
use Data::Dumper;
use Scalar::Util qw(reftype);
use Params::Util qw(_STRING _ARRAYLIKE _HASHLIKE _NUMBER _HANDLE);
use List::Util qw(reduce);
use File::Temp qw(tmpnam);
use POSIX qw(:signal_h :errno_h :sys_wait_h mkfifo);

#use IPC::Pipeline::Composable qw(ipc_pl);
#use IPC::Pipeline::Composable::CmdSubst qw(ipc_cs);
#use IPC::Pipeline::Composable::ProcSubst qw(ipc_ps);
#use IPC::Pipeline::Composable::PlaceHolder qw(ipc_ph);

use parent qw(Exporter);
our @EXPORT_OK = qw(ipc_newcmd ipc_cmd);


### CONSTRUCTOR ###

sub new {
  my ($class, %opt) = @_;

  croak "the cmd parameter is required!\n" unless $opt{cmd};
  croak "the cmd parameter must be a string or subref!\n"
    unless defined _STRING($opt{cmd}) or _CODELIKE($opt{cmd});

  croak "the args parameter must be an arrayref or undef!\n"
    if defined $opt{args} and ! _ARRAYLIKE($opt{args});
  $opt{args} ||= [];

  my $self = bless { %opt }, $class;

  $self->{fds} = {$self->_init_fds(%opt)};

  # _init_fds takes care of these, so they're junk now.
  delete @{$self}{qw(stdout stdin stderr)};

  return $self;
}

### COMMAND EXECUTION ###


sub run {
  my ($self, %opt) = @_;

  # figure out what args will *really* be used with the command,
  # make sure to keep track of process-subst. stuff
  my ($real_args, $ps_fifos) = __process_args(scalar $self->args, \%opt);

  my $cmd_pid = $self->_fork_cmd([$self->cmd, @$real_args], \%opt);

#my $old_reaper = $SIG{CHLD};
  my $new_reaper;
  $SIG{CHLD} = $new_reaper = sub {
    my $pid = waitpid(-1, WNOHANG);
    if ( $pid == $cmd_pid ) {
      if ( WIFEXITED($?) ) {
        # clean up PS fifos... WHY U NO WORK RIGHT?
        print "Process $pid exited.\n";
        unlink keys %$ps_fifos;
      }
    }
    #$old_reaper->() if $old_reaper;
    $SIG{CHLD} = $new_reaper;
  };

  my @ps_pids = $self->_fork_ps_cmds($ps_fifos, \%opt);

  waitpid $cmd_pid,0; exit;
}

sub _fork_ps_cmds {
  my ($self, $ps_fifos, $opt) = @_;
  my @ps_pids;
  while (my ($fifo, $ps_cmd_spec) = each %$ps_fifos) {
    my ($mode, $cmd_spec) = @$ps_cmd_spec;
    my $fmode = $mode eq '<' ? '>' : $mode eq '>' ? '<' : die "unknown PS mode $mode\n";
    print "Running " . Dumper $cmd_spec;
    open my $fifo_fh, "$fmode", $fifo;
    my %ps_opt = (
      %$opt,
      stdin => ($mode eq '>' ? $fifo_fh : undef),
      stdout => ($mode eq '<' ? $fifo_fh : undef),
    );
    push @ps_pids, $self->_fork_cmd($cmd_spec, \%ps_opt);
  }
  return @ps_pids;
}

sub _fork_cmd {
  my ($self, $cmd_spec, $opt) = @_;

  my $pid = fork();
  return $pid if $pid;

  my %fds = $self->_init_fds(%$opt);

  # setup file descriptors in child
  while ( my ($fd, $spec) = each %{ $self->{fds} } ) {
    my ($mode, $hnd) = @$spec;
    if (!defined $hnd) {
      next;
    }
    my $h_fd = fileno($hnd);
    defined POSIX::close($fd) or die "Couldn't close descriptor [$fd] in pid [$PID]: $!\n";
    defined POSIX::dup2($h_fd, $fd) or die "Couldn't dup2 [$h_fd],[$fd] in pid [$PID]: $!\n";
  }

  __exec_cmd($cmd_spec);
  die "pid $PID should never have gotten here.";

}

sub __exec_cmd {
  my ($cmd) = @_;

  if (_STRING($cmd)) {
    exec $cmd or die "Cannot exec [$cmd]: $!\n";
  }

  if (ref($cmd->[0]) and reftype($cmd->[0]) eq 'CODE') {
    my $code = shift @$cmd;
    exit $code->(@$cmd);
  }

  #print "about to exec $cmd->[0]\n";
  exec(@$cmd) or die "Cannot exec [$cmd->[0]]: $!\n";
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

### HANDLE USER-SUPPLIED FDS ###

# the user will likely specify that certain fds get mapped to file
# handles (or *not* mapped). this sub validates the user's options
# and sets up the mappings for use later on. it's kind of icky code,
# but, meh.
## TODO: forget about compat with IPC::Run. Trying to be compatible with it
##       just seems too expensive in terms of code complexity right now.
sub _init_fds {
  my ($self, %opt) = @_;

  # collect the FD=>[mode,handle] mappings in this:
  my %fds;

  # get the STD* handle shortcuts, if specified
  $fds{0} = [ '<', (exists $opt{stdin}  ? $opt{stdin}  : undef) ];
  $fds{1} = [ '>', (exists $opt{stdout} ? $opt{stdout} : undef) ];
  $fds{2} = [ '>', (exists $opt{stderr} ? $opt{stderr} : undef) ];
  %fds = (%{$self->{fds} || {} }, %fds, %{ delete $opt{fds} || {} });

  # make sure all fd specs contain valid handles
  while ( my ($k, $v) = each %fds ) {

    # make sure the fd name is a number
    croak "error in fds hash: key [$k] is not a number\n"
      unless defined _NUMBER($k);

    # make sure the fd spec is an array or undef
    croak "invalid handle spec for fd: [$k]: not an array ref\n"
      unless defined $v and _ARRAYLIKE($v);
    next unless defined $v;

    my ($m, $h) = @$v;

    # make sure the fd spec contains a valid mode
    # note: IPC::Run takes richer modes - should we support those? how???
    $m = "" unless defined $m;
    croak "invalid mode for fd [$k]: [$m]" unless "$m" =~ /^[><]$/;

    # make sure the fd spec contains a valid handle
    next if !defined $h;
    next if ref($h) and reftype($h) eq 'SCALAR' and !defined $$h;
    croak "invalid handle for fd [$k]: [$h]\n" if ! _HANDLE($h);
  }

  return %fds;
}


### ACCESSORS ###

sub cmd    { shift->{cmd} }
sub args   { my $x = shift->{args} || []; wantarray ? @$x : $x }
sub handle { shift->{fds}{shift}[1] }
sub stdin  { shift->{fds}{0}[1] }
sub stdout { shift->{fds}{1}[1] }
sub stderr { shift->{fds}{2}[1] }


### EXPORTED SUBS ###

sub ipc_newcmd { return __PACKAGE__->new(@_) }

sub ipc_cmd {
  my $cmd = shift;
  my @args = grep { ! _HASHLIKE($_) } @_;
  my $opt = reduce { %$a = (%$a, %$b); $a } grep { _HASHLIKE($_) } {},{}, @_;
  return ipc_newcmd(%$opt, cmd => $cmd, args => [@args]);
}


=for comment

maybe these methods would be useful:
  last_pid - pid from the last time this command was run
  last_status - exit status from the last time this command was run

However, care should be taken to make them "atomic" with respect to
each other and the state of the process - when ->run() is called,
make sure to set last_status to undef to indicate that the process
is still running!

=cut


1 && q{this statement is true};
__END__

