#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Slurp qw( read_file );
use Data::Dumper;
use autodie;

use_ok 'IPC::Pipeline::Composable', qw( ipc_pipeline ipc_proc ipc_sub );

my ($readfh, $writefh);
pipe $readfh, $writefh;
my $cmd      = ipc_proc(qw(head -n 5), $0);
my $sub      = ipc_sub('<', $cmd);
my $pl       = ipc_pipeline(ipc_proc('sort', $sub));
my @pidinfo  = $pl->run( sink_fh => $writefh )->pids;
my @statuses = map { waitpid($_, 0); $_ => ($? >> 8); } @pidinfo;
close $writefh;
my $got; while (sysread $readfh, my $buf, 512) { $got .= $buf }
my $expected = join( '', sort +(read_file $0)[0 .. 4] );
is $got, $expected, 'process substitution works!';
done_testing;
