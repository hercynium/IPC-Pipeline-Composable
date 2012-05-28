use strict;
use warnings;
package IPC::Pipeline::Composable::ProcHandle;

# ABSTRACT: A handle for a running I.P.C Process

use English qw(-no_match_vars);
use Carp;
use Data::Dumper;
use Scalar::Util qw(reftype);
use Params::Util qw(_STRING _ARRAYLIKE _HASHLIKE _NUMBER _HANDLE);
use List::Util qw(reduce);
use File::Temp qw(tmpnam);
use POSIX qw(mkfifo);

#use IPC::Pipeline::Composable qw(ipc_pl);
#use IPC::Pipeline::Composable::CmdSubst qw(ipc_cs);
#use IPC::Pipeline::Composable::ProcSubst qw(ipc_ps);
#use IPC::Pipeline::Composable::PlaceHolder qw(ipc_ph);

use parent qw(Exporter);

# the pid of the main process this object represents.
sub pid {}

# pids of any substituted processes. These processes
# may or may not finish before the main process, but
# when the main process is finished, these should all
# be terminated and reaped.
sub ps_pids {}

# pids of any command-substitution processes
# (note that these pids will be *finished* before
# the main process is executed)
sub cs_pids {}

# pid of the main process and any co/sub processes
# (like substituted processes or commands)
sub all_pids {}

# wait for this process to finish
sub finish {}

# terminate this process, forcibly if need be
sub abort {}

# returns the I.P.C Process object belonging to this Handle
sub process {}


