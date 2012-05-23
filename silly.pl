#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
#use IPC::Pipeline::Composable::Functions qw(:all);
use IPC::Pipeline::Composable::Process::Command qw(ipc_newcmd);
use IPC::Run qw(harness);
use File::Temp qw(tmpnam);
use POSIX qw(mkfifo);
use File::Slurp qw(read_file);
use List::MoreUtils qw(pairwise);
use Data::Dumper;
use Capture::Tiny qw(capture);
use Test::More;

pipe my ($read), my ($write);
my $foo = ipc_newcmd( cmd => 'sort', args => [ $0 ], stdin => undef, stderr => \*STDERR );
my @pids = $foo->run( stdout => $write, fds => { 3 => [ '<', \undef ] } );
wait for @pids;
close $write;
while (sysread($read, my $buf, 512)) { print $buf };
exit;

my $input1_file = $0; #shift || die "need to specify first file for input";
my $input2_file = $0; #shift || die "need to specify second file for input";

open my $err_fh,    '>', 'join_errors.txt';
open my $input2_fh, '<', $input2_file;

# using full objects
sub test1 {

  my $join_cmd = ipc_newcmd(
    cmd => 'paste',
    args => [
      ipc_newph(name => 'input1'),
      ipc_newph(name => 'input2'),
    ],
    stderr => $err_fh,
  );

  my $cmd_info = $join_cmd->run(
    input1 => ipc_newps(
      mode => '1<',
      ipc_newcmd(
        cmd  => 'sort',
        args => [$input1_file],
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
    ['paste', ipc_ph('input1'), ipc_ph('input2')],
    stderr => $err_fh,
  );

  my $cmd_info = $join_cmd->run(
    input1 => ipc_ps(
      '1<', ['sort', $input1_file],
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
# note that this isn't entirely semantically equivalent with the above examples
# (no placeholders, for example)
sub test3 {

  my $pipe = tmpnam(); # race condition? probably.
  mkfifo $pipe, 0700;

  my $sort_cmd = harness
    ['sort', $input1_file],
    '0<' => \undef,
    '1>' => $pipe,
    '2>' => \*STDERR;

  my $join_cmd = harness
    [ 'paste', $pipe, '-' ],
    '0<' => $input2_fh,
    '1>' => \*STDOUT,
    '2>' => $err_fh;

  $join_cmd->start();
  my @join_pids = map { $_->{PID} } $join_cmd->_running_kids;

  $sort_cmd->start();
  my @sort_pids = map { $_->{PID} } $sort_cmd->_running_kids;

  wait for (@join_pids, @sort_pids);
  unlink $pipe;

}

my ($stdout, $stderr) = capture { test3() };

no warnings 'once';
my @lines1 = sort { $a cmp $b } read_file $0;
my @lines2 = read_file $0;
my $expected = join "", pairwise { chomp $a; "$a\t$b" } @lines1, @lines2;

is $stdout, $expected, "output matches expected";

done_testing;
