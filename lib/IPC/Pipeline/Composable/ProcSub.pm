use strict;
use warnings;
package IPC::Composable::Pipeline::ProcSub;
use Carp;

# ABSTRACT: An object for performing Process Substitution

# a substitution process is just a specialized pipeline
use parent qw(IPC::Composable::Pipeline);

sub new {
  my ($class, %opt) = @_;
  croak "Pipeline param is required" unless $opt{pipeline};
  croak "Mode param is required"     unless $opt{mode};
  return bless my $self = { %opt }, $class;
}

=attribute mode

The mode of this process substitution. Must be one of:

=for :list
* '<' read the output of this process as input
* '>' read the input of this process as output

=cut
sub mode { shift->{mode} };

1 && q{this expression is true};
__END__

=head1 DESCRIPTION

Give this object a command or pipeline object and it will 'wrap it',
so that it can be used for process substitution, in the same way you
can wrap bash shell commands or pipelines with the <( ... ) construct.

=cut
