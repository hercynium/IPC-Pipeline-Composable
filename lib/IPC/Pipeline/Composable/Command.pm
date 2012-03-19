use strict;
use warnings;
package IPC::Pipeline::Composable::Command;
# ABSTRACT: Object representation of a command in an I:P:C.
use English qw( -no_match_vars);
use Data::Dumper;
use autodie;
use Fcntl;

sub new {
  my ($class,%opt) = @_;
  return bless my $self = { %opt }, $class;
}


1 && q{this expression is true};
__END__
