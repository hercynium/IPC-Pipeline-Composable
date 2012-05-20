use strict;
use warnings;
package IPC::Pipeline::Composable::ProcSubst;
# ABSTRACT: An object indicating I:P:C should perform "Process Substitution"
use English qw(-no_match_vars);
use Carp;
use File::Slurp qw(read_file write_file);
use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use Scalar::Util qw(blessed reftype openhandle);




1 && q{this statement is true};
__END__
