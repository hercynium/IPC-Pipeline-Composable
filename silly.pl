#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
#use IPC::Pipeline::Composable::Functions qw(:all);
use IPC::Run qw(harness);
use File::Temp qw(tmpnam);
use POSIX qw(mkfifo);
use Data::Dumper;

my $input1_file = shift || die "need to specify first file for input";
my $input2_file = shift || die "need to specify second file for input";

open my $err_fh,    '>', 'join_errors.txt';
open my $input2_fh, '<', $input2_file;

# using full objects
sub test1 {
  my $join_cmd = ipc_newcmd(
    cmd => 'join',
    args => [
      ipc_newph(name => 'input1'),
      ipc_newph(name => 'input2'),
    ],
    stderr => $err_fh,
  );

  my $cmd_info = $join_cmd->run(
    input1 => ipc_newps(
      mode => '<',
      ipc_newcmd(
        cmd  => 'sort',
        args => ['-k1,1', $input1_file],
      )
    ),
    input2 => '-',
    stdin  => $input2_fh,
    stdout => \*STDERR,
  );

  wait for $cmd_info->all_pids();

  print "DONE\n";
}

# using simplified function-like syntax (still objects underneath)
sub test2 {
  my $join_cmd = ipc_cmd(
    ['join', ipc_ph('input1'), ipc_ph('input2')],
    stderr => $err_fh,
  );

  my $cmd_info = $join_cmd->run(
    input1 => ipc_ps(
      '<', ['sort', '-k1,1', $input1_file],
    ),
    input2 => '-',
    stdin  => $input2_fh,
    stdout => \*STDERR,
  );

  wait for $cmd_info->all_pids();

  print "DONE\n";
}

# using IPC::Run, which is what the objects might invoke
# underneath-the-hood...
sub test3 {
  my $pipe = tmpnam(); # race condition? probably.
  mkfifo $pipe, 0700;

  my $sort_cmd = harness
    ['sort', '-k1,1', $input1_file],
    '0<' => \undef,
    '1>' => $pipe,
    '2>' => \*STDERR;

  my $join_cmd = harness
    [ 'join', $pipe, '-' ],
    '0<' => $input2_fh,
    '1>' => \*STDOUT,
    '2>' => $err_fh;

  $join_cmd->start();
  my @join_pids = map { $_->{PID} } $join_cmd->_running_kids;

  $sort_cmd->start();
  my @sort_pids = map { $_->{PID} } $sort_cmd->_running_kids;

  #print Dumper \@join_pids, \@sort_pids;
  wait for (@join_pids, @sort_pids);

  print "DONE\n";
}

test3();

