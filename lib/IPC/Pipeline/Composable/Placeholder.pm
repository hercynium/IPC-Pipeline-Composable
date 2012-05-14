use strict;
use warnings;
package IPC::Pipeline::Composable::Placeholder;
use Carp;

# ABSTRACT: A placeholder in a command or pipeline

sub new {
  my ($class, %opt) = @_;
  croak "name parameter is required" unless $opt{name};
  return bless my $self = { %opt }, $class;
}

=attribute name

The name of this placeholder

=cut
sub name { shift->{name} };

1 && q{this expression is true};
__END__
