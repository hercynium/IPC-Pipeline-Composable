use strict;
use warnings;
package IPC::Pipeline::Composable::Process;

# ABSTRACT: A process in a pipeline

sub new {
  my ($class, %opt) = @_;
  return bless my $self = { %opt }, $class;
}

sub cmd { shift->{cmd} }

sub args {
  my ($self) = @_;
  return wantarray ? @{ $self->{args} || [] } : ($self->{args} || []);
}

1 && q{this expression is true};
__END__
