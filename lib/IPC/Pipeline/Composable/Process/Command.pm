use strict;
use warnings;
package IPC::Pipeline::Composable::Process::Command;
# ABSTRACT: A system command to be run in a separate process
use English qw(-no_match_vars);
use Carp;
#use File::Slurp qw(read_file write_file);
#use List::Util qw(first max maxstr min minstr reduce shuffle sum);
#use Scalar::Util qw(blessed reftype openhandle);
use Params::Util qw(_STRING);

use parent qw(IPC::Pipeline::Composable::Process);

sub new {
  my ($class, %opt) = @_;

  my $self = $class->SUPER::new(%opt);

  croak "the cmd parameter is required!\n" unless $self->{cmd};
  croak "the cmd parameter must be a string!\n" unless defined _STRING($_[0]);

  return bless $self, $class;
}

sub cmd { shift->{cmd} }

sub run {
  my ($self, %opt) = @_;
  # I'd better read up:
  # http://search.cpan.org/dist/IPC-Run/lib/IPC/Run.pm#Redirection_Operators

}


1 && q{this statement is true};
__END__
