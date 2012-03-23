use strict;
use warnings;
package IPC::Pipeline::Composable::Placeholder;

# ABSTRACT: A placeholder in a command or pipeline

sub new {
  my ($class, %opt) = @_;
  return bless my $self = { %opt }, $class;
}

sub name { shift->{name} };

1 && q{this expression is true};
__END__
