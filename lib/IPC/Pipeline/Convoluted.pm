use strict;
use warnings;
package IPC::Pipeline::Convoluted;

# ABSTRACT: run a command in a separate process

use English qw( -no_match_vars );
use Data::Dumper;
use autodie;
use Scalar::Util qw( reftype blessed );
use File::Temp qw( tmpnam );
use POSIX qw( mkfifo );


