use strict;
use warnings;
package IPC::Pipeline::Composable::Placeholder;
# ABSTRACT: A placeholder in a command or pipeline
use English qw( -no_match_vars);
use Data::Dumper;
use autodie;

sub new {
  my ($class,%opt) = @_;
  return bless my $self = { %opt }, $class;
}


1 && q{this expression is true};
__END__
