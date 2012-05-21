#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use IPC::Pipeline::Composable::Functions qw(:all);

my $input1_file = shift || die "need to specify first file for input";
my $input2_file = shift || die "need to specify second file for input";

open my $err_fh,    '>', 'join_errors.txt';
open my $input2_fh, '<', $input2_file;

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
