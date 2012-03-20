use strict;
use warnings;
package IPC::Pipeline::Composable::Command;
# ABSTRACT: A command in a pipeline
use English qw( -no_match_vars);
use Data::Dumper;
use autodie;

sub new {
  my ($class,%opt) = @_;
  return bless my $self = { %opt }, $class;
}

sub cmd { shift->{cmd} }
sub args { my ($self) = @_; wantarray ? @{ $self->{args} || [] } : ($self->{args} || []) }

sub spec {
  my ($self) = @_;
  $self->{cmd_str}  ? [split ' ', $self->{cmd_str}] :
  $self->{cmd_code} ? $self->{cmd_code} :
  [$self->{cmd}, @{ $self->{args} || [] } ];
}

1 && q{this expression is true};
__END__
