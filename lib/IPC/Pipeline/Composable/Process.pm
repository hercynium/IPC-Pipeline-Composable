use strict;
use warnings;
package IPC::Pipeline::Composable::Process;
# ABSTRACT: Object representing a process in an I:P:C pipeline
use English qw(-no_match_vars);
use Carp;
#use File::Slurp qw(read_file write_file);
#use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use Scalar::Util qw(blessed reftype openhandle);
use Params::Util qw(_ARRAYLIKE _NUMBER _HANDLE);
use Data::Dumper;
use IPC::Run;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(ipc_newcmd);

sub new {
  my ($class, %opt) = @_;

  # make sure args is an array, if supplied:
  croak "the args parameter must be an arrayref or undef!\n"
    if defined $opt{args} and ! _ARRAYLIKE($opt{args});

  my $self = bless {%opt}, $class;

  $self->{fds} = {$self->_init_fds(%opt)};

  return $self;
}

sub ipc_newcmd { return __PACKAGE__->new(@_) }

# the user will likely specify that certain fds get mapped to file
# handles (or *not* mapped). this sub validates the user's options
# and sets up the mappings for use later on. it's kind of icky code,
# but, meh.
sub _init_fds {
  my ($self, %opt) = @_;

  # collect the FD=>[mode,handle] mappings in this:
  my %fds;

  # get the STD* handle shortcuts, if specified
  $fds{0} = ['>', ($opt{stdin}  || \undef) ] if exists $opt{stdin};
  $fds{1} = ['<', ($opt{stdout} || \undef) ] if exists $opt{stdout};
  $fds{2} = ['<', ($opt{stderr} || \undef) ] if exists $opt{stderr};
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
    $m = "" unless defined $m;
    croak "invalid mode for fd [$k]: [$m]" unless "$m" =~ /^[><]$/;

    next if ref($h) and reftype($h) eq 'SCALAR' and !defined $$h;
    if (!defined $h) { $h = \undef; next; }
    # make sure the fd spec contains a valid handle
    croak "invalid handle for fd [$k]: [$h]\n" if ! _HANDLE($h);
  }

  return %fds;
}

sub args   { my $x = shift->{args} || []; wantarray ? @$x : $x }
sub handle { shift->{fds}{shift}[1] }
sub stdin  { shift->{fds}{0}[1] }
sub stdout { shift->{fds}{1}[1] }
sub stderr { shift->{fds}{2}[1] }

# run the command, linking its fds to the specified handles
sub run {
  my ($self, %opt) = @_;
  #croak "The run method should be overridden by a derived class!\n";
  my @ipc_run_fds = $self->_gen_ipc_run_fds(%opt);
  print Dumper \@ipc_run_fds;

}


sub _gen_ipc_run_fds {
  my ($self, %opt) = @_;
  my @ipc_run_fds;
  my %fds = $self->_init_fds(fds => $self->{fds}, %opt);
  while ( my ($fd, $spec) = sort each %fds ) {
    push @ipc_run_fds, "$fd$spec->[0]", (defined $spec->[1] ? $spec->[1] : \undef );
  }
  return @ipc_run_fds;
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
