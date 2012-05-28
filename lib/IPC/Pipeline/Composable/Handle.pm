use strict;
use warnings;
package IPC::Pipeline::Composable::Handle;

# ABSTRACT: An IO handle for doing IPC with I.P.C.

sub new {
  my ($class, %opt) = @_;
  bless {%opt}, $class;
}

sub mode { shift->{mode} }
sub handle { shift->{handle} }
sub fileno { fileno shift->handle }
sub fd { shift->fileno }

1 && q{this statement is true};
