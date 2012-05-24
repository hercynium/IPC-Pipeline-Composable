use strict;
use warnings;
package IPC::Pipeline::Composable::ProcSubst;
# ABSTRACT: An object indicating I:P:C should perform "Process Substitution"
use English qw(-no_match_vars);
use Carp;
use File::Slurp qw(read_file write_file);
use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use Scalar::Util qw(blessed reftype openhandle);

use parent qw(Exporter);
our @EXPORT_OK = qw(ipc_ps ipc_newps);

sub ipc_ps {
  my ($mode) = shift;
  my @cmd_specs;
  # eventually, accept objects of various types as well
  while (_ARRAYLIKE($_[0])) {
    push @cmd_specs, shift @_;
  }
  my %opt = @_;

}


1 && q{this statement is true};
__END__
