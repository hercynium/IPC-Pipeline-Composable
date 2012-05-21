use strict;
use warnings;
package IPC::Pipeline::Composable::Process::Code;
# ABSTRACT: Perl code to be run in a separate process
use English qw(-no_match_vars);
use Carp;
use File::Slurp qw(read_file write_file);
use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use Scalar::Util qw(blessed reftype openhandle);
use Params::Util qw(_STRING);

use parent qw(IPC::Pipeline::Composable::Process);

sub new {
  my ($class, %opt) = @_;

  my $self = $class->SUPER::new(%opt);

  croak "the code parameter is required!\n" unless $opt{code};
  croak "the code parameter must be a coderef!\n" unless defined _CODELIKE($opt{code});

  return bless $self, $class;
}

sub code { shift->{code} }

#sub run {
#  my ($self, %opt) = @_;
#  # I'd better read up:
#  # http://search.cpan.org/dist/IPC-Run/lib/IPC/Run.pm#Redirection_Operators
#
#}




1 && q{this statement is true};
__END__
