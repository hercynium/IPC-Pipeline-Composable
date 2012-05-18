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

my $ph1 = IPC::Pipeline::Composable::Placeholder->new(name => 'foo');
my $ph2 = IPC::Pipeline::Composable::Placeholder->new(name => 'bar');
my $cmd1 = IPC::Pipeline::Composable::CmdProc->new(cmd => 'head', args => ['-n1', $ph1]);
my $cmd2 = IPC::Pipeline::Composable::CmdProc->new(cmd => 'echo', args => ['-n', $ph2]);

my $expected = (read_file $0)[0];

my ($stdout1, $stderr1, @pids1) = capture {
    pipe my($read, $write);
    my @pids = $cmd1->run(foo=>$0, stdout => $write);
    wait for @pids;
    close $write;
    while (sysread($read, my $buf, 512)) { print $buf }
    close $read;
    return @pids;
};

is $stdout1, $expected, "running simple command";

my ($stdout2, $stderr2, @pids2) = capture {
    pipe my($read, $write);
    my @pids = $cmd2->run(foo=>$0, bar=>$cmd1, stdout => $write);
    wait for @pids;
    close $write;
    while (sysread($read, my $buf, 512)) { print $buf }
    close $read;
    return @pids;
};

is $stdout2, $expected, "running command with command substitution and placeholder";

done_testing;
__END__
