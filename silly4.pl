#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use lib 'lib';
#use IPC::Pipeline::Composable::Functions qw(:all);
use IPC::Pipeline::Composable::Process qw(ipc_newcmd ipc_cmd);
use IPC::Run qw(harness);
use File::Temp qw(tmpnam);
use POSIX qw(mkfifo);
use File::Slurp qw(read_file);
use List::MoreUtils qw(pairwise);
use Data::Dumper;
use Capture::Tiny qw(capture);
use Test::More;

open my $fd3_fh, '>', 'fd3_out.txt';

my $cmd = ipc_cmd(
  './foo',
  {
    stdout => \*STDERR, # foo1
    stderr => \*STDOUT, # foo2
    fds => {
      3 => ['>', $fd3_fh] # foo3
    }
  }
);
print Dumper $cmd;

$cmd->run;


