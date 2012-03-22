#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Slurp qw( read_file );
use Data::Dumper;
use autodie;

use_ok 'IPC::Pipeline::Composable', qw( ipc_pipeline ipc_cmd ipc_sub );

my ($readfh, $writefh);
pipe $readfh, $writefh;
my $cmd      = ipc_cmd(qw(head -n 5), $0);
my $pl       = ipc_pipeline(ipc_cmd('sort', ipc_sub('<', $cmd)));
my @pidinfo  = $pl->run( sink_fh => $writefh )->pids;
my @statuses = map { waitpid($_, 0); $_ => ($? >> 8); } @pidinfo;
sysread($readfh, my $got, 512);
my $expected = join( '', sort +(read_file $0)[0 .. 4] );
is $got, $expected, 'process substitution works!';
done_testing;
