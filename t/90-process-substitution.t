#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Slurp qw( read_file );
use Data::Dumper;


use_ok 'IPC::Pipeline::Composable', qw( ipc_pipeline ipc_cmd ipc_sub );


my $cmd = ipc_cmd(qw(head -n 5), $0);
my $pl = ipc_pipeline(ipc_cmd('sort', ipc_sub('<', $cmd)));
my @pidinfo  = $pl->run( sink_fh => \*STDOUT )->pids;
my @statuses = map { waitpid($_, 0); $_ => ($? >> 8); } @pidinfo;

done_testing;
