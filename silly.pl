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
my $input3_file = $0; #shift || die "need to specify third file for input";

open my $err_fh,    '>', 'join_errors.txt';

# using IPC::Run, which is what the objects might invoke
# underneath-the-hood...
# note that this isn't entirely semantically equivalent with the above examples
# (no placeholders, for example)
sub test3 {

  my $sort_pipe = tmpnam(); # race condition? probably.
  mkfifo $sort_pipe, 0700;
  my $sort_cmd = harness
    ['sort', $input1_file],
    '0<' => \undef,
    '1>' => $pipe,
    '2>' => \*STDERR;

  my $tr_pipe = tmpnam(); # race condition? probably.
  mkfifo $tr_pipe, 0700;
  my $tr_cmd = harness
    ['tr', 'a-zA-Z', 'n-za-mN-ZA-M', $input2_file],
    '0<' => \undef,
    '1>' => $pipe,
    '2>' => \*STDERR;

  my $paste_cmd = harness
    [ 'paste', '-', $sort_pipe, $tr_pipe ],
    '0<' => $input3_fh,
    '1>' => \*STDERR,
    '2>' => $err_fh;

  $paste_cmd->start();
  my @paste_pids = map { $_->{PID} } $paste_cmd->_running_kids;

  $sort_cmd->start();
  my @sort_pids = map { $_->{PID} } $sort_cmd->_running_kids;

  $tr_cmd->start();
  my @tr_pids = map { $_->{PID} } $tr_cmd->_running_kids;

  wait for (@paste_pids, @sort_pids, @tr_pids);

  $_->finish() for $paste_cmd, $sort_cmd, $tr_cmd;

  unlink $sort_pipe, $tr_pipe;

}

my ($stdout, $stderr) = capture { test3() };

no warnings 'once';
my @lines1 = sort { $a cmp $b } read_file $0;
my @lines2 = read_file $0;
my $expected = join "", pairwise { chomp $a; "$a\t$b" } @lines1, @lines2;

is $stdout, $expected, "output matches expected";



# using simplified function-like syntax (still objects underneath)
# without using placeholders
sub test4 {

  # paste stdin plus two other input files
  my $join_cmd = ipc_cmd(
    [
      'paste',
      '-',
      ipc_ps('<', 'sort', $input1_file),
      ipc_ps('<', 'tr', 'a-zA-Z', 'n-za-mN-ZA-M', $input2_file)
    ],
    stdin  => $input3_fh,
    stdout => \*STDERR,
    stderr => $err_fh,
  );

  my $cmd_info = $join_cmd->run;

  wait for $cmd_info->all_pids();

  print "DONE\n";
}




done_testing;
