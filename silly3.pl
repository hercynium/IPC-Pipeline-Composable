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

my $input1_file = $0; #shift || die "need to specify first file for input";
my $input2_file = $0; #shift || die "need to specify second file for input";
my $input3_file = $0; #shift || die "need to specify third file for input";

open my $err_fh, '>', 'cmd_errors.txt';

#my $cmd = ipc_cmd(
#  'cat',
#  { stdin => \*STDIN },
#  ['<', ['echo', $0]],
#  { stdout => \*STDOUT, stdin => undef },
#);

#my $cmd = ipc_cmd('./bar', $0, { fds => { 3 => ['>', \*STDERR]}});
my $cmd = ipc_cmd('cat', ['<',['./foo']], $0);
print Dumper $cmd;
$cmd->run;
