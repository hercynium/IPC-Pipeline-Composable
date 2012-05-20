#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use File::Slurp qw(read_file);
use Capture::Tiny qw(capture);
use Test::More;

use lib 'lib';
use IPC::Pipeline::Composable::CmdProc;
use IPC::Pipeline::Composable::Placeholder;
use IPC::Pipeline::Composable::ProcSub;

my $ph1 = IPC::Pipeline::Composable::Placeholder->new(name => 'foo'); # ipc_ph('foo')
my $ph2 = IPC::Pipeline::Composable::Placeholder->new(name => 'bar'); # ipc_ph('bar')
my $cmd1 = IPC::Pipeline::Composable::CmdProc->new(cmd => 'head', args => ['-n1', $ph1]); # ipc_cmd(...)
my $cmd2 = IPC::Pipeline::Composable::CmdProc->new(cmd => 'echo', args => ['-n', $ph2]);  # ipc_cmd(...)
my $ps1  = IPC::Pipeline::Composable::ProcSub->new(mode => '<', pipeline => $cmd2);        # ipc_ps(...)

my $expected = (read_file $0)[0];

my ($stdout1, $stderr1, @pids1) = capture {
    map { wait } $cmd1->run(foo => $0, stdout => \*STDOUT);
};

is $stdout1, $expected, "running simple command";

my ($stdout2, $stderr2, @pids2) = capture {
    map { wait } $cmd2->run(foo => $0, bar => $cmd1, stdout => \*STDOUT);
};

is $stdout2, $expected, "running command with command substitution and placeholder";

my ($stdout3, $stderr3, @pids3) = capture {
    map { wait } $cmd1->run(foo => $ps1, bar=> $0, stdout => \*STDOUT);
};

is $stdout3, $expected, "running command with command substitution and placeholder";

done_testing;
__END__
