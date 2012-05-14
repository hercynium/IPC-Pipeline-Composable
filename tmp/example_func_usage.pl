#!/usr/bin/env perl
use strict;
use warnings;
use File::Slurp qw(read_file);
use IPC::Pipeline::Composable::Functions qw(:all);

# in shell this might be something like this:
#   export proc1='gunzip -c \$(eval echo $place1)'
#   export proc2='gzip -c \$(eval echo $place2)'
#   export sub2="<($proc2)"
#   export place1=$sub2
#   export place2=$0
#   eval $proc1
# except this doesn't work...

my $proc1 = ipc_proc('gunzip', '-c', ipc_place('gunzip_input'));
my $proc2 = ipc_proc('gzip',   '-c', ipc_place('gzip_input'));
my $sub2  = ipc_sub('<', $proc2 );
my @pids = $proc1->run(
  stdout       => \(my $output), # store output in this scalar
  placeholders => {
    gunzip_input => $sub2,
    gzip_input   => $0,
  },
);
wait for @pids;


my $expected = read_file $0;


print ($output eq $expected ? 'PASS' : 'FAIL'), "\n";


# or...
# my @pids = ipc_run(
#   ipc_proc('gunzip', '-c', ipc_place('gunzip_input')),
#   stdout       => \(my $output), # store output in this scalar
#   placeholders => {
#     gunzip_input => ipc_sub('<', ipc_proc('gzip',   '-c', $0)),
#   },
# );

