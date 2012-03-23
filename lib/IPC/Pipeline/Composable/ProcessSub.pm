use strict;
use warnings;
package IPC::Pipeline::Composable::ProcessSub;

# ABSTRACT: An object for performing Process Substitution

use parent qw(IPC::Pipeline::Composable);

sub new {
  my ($class, %opt) = @_;
  $opt{procs} = [ $opt{proc}->procs ];
  return bless my $self = { %opt }, $class;
}

sub mode { shift->{mode} };

1 && q{this expression is true};
__END__
