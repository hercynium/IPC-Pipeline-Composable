use strict;
use warnings;
package IPC::Pipeline::Composable::Process;
# ABSTRACT: Object representing a process in an I:P:C pipeline
use English qw(-no_match_vars);
use Carp;
#use File::Slurp qw(read_file write_file);
#use List::Util qw(first max maxstr min minstr reduce shuffle sum);
#use Scalar::Util qw(blessed reftype openhandle);
use Params::Util qw(_ARRAYLIKE _NUMBER _HANDLE);

sub new {
  my ($class, %opt) = @_;

  # make sure args is an array, if supplied:
  croak "the args parameter must be an arrayref or undef!\n"
    if defined $opt{args} and ! _ARRAYLIKE($opt{args});

  my %fds = $class->_fds_from_opts(%opt);

  return bless {
    fds => \%fds,
    %opt,
  }, $class;
}

sub _fds_from_opts {
  my ($self, %opt) = @_;

  # get the STD* handles if specified and
  # get a copy of the fds hash to avoid, um... issues...
  my %fds;
  @fds{0,1,2} = delete @opt{qw(stdin stdout stderr)};
  %fds        = (%fds, %{ delete $opt{fds} || {} });

  # make sure all fd names are numbers
  # make sure all fd values are handles or undef
  while ( my ($k, $v) = each %fds ) {
    croak "error in fds hash: key [$k] is not a number!\n"
      unless defined _NUMBER($k);
    croak "error in fds hash at fd [$k]: value [$v] is not undef or a handle!\n"
      if defined $v and ! _HANDLE($v);
  }
  return %fds;
}

sub cmd    { die "This cmd method should be overridden by a derived class!\n" }
sub args   { my $x = shift->{args} || []; wantarray ? @$x : $x }
sub handle { shift->{fds}{shift} }
sub stdin  { shift->{fds}{0} }
sub stdout { shift->{fds}{1} }
sub stderr { shift->{fds}{2} }

# run the command, linking its fds to the specified handles
sub run {
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
