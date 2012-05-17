#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use IPC::Pipeline::Composable::CmdProc;
use IPC::Pipeline::Composable::Placeholder;
use Data::Dumper;

my $ph1 = IPC::Pipeline::Composable::Placeholder->new(name => 'foo');
my $ph2 = IPC::Pipeline::Composable::Placeholder->new(name => 'bar');
my $cmd1 = IPC::Pipeline::Composable::CmdProc->new(cmd => 'head', args => ['-n1', $ph1]);
my $cmd2 = IPC::Pipeline::Composable::CmdProc->new(cmd => 'echo', args => [$ph2]);

print Dumper($cmd1->run(foo=>$0, stdout => \*STDERR));
print Dumper($cmd2->run(foo=>$0, bar=>$cmd1, stdout => \*STDOUT));

print "OK\n";
