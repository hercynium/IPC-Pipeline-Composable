#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Slurp qw( read_file );
use IPC::Pipeline::Compasable qw( ipc_pipeline ipc_cmd ipc_arg );



my $cmd1 = ipc_cmd(qw( tr a-mn-zA-MN-Z n-za-mN-ZA-M )); # rot13
is $cmd1->cmd, 'tr', "command has expected command name";
is scalar @{$cmd1->args}, 2, "command has expected number of args";

my $pl1 = ipc_pipeline( $cmd1, sub { lc } ); # convert rot13 txt to lowercase
my @pl1_cmds = $pl1->cmds;
is scalar @pl1_cmds, 2, "first pipeline has expected number of commands";
isa_ok $_, 'IPC::Pipeline::Composable::Command' for @pl1_cmds;



my @pl1_cmd1_args = $pl1_cmds[0]->args;
is scalar @pl1_cmd1_args, 2, "first command in first pipeline has expected number of args"



my $pl2 = ipc_pipeline(
  ipc_cmd(sub { uc }),
  ipc_cmd(qw( tr A-Z # )), ### test this one
);



# compose $pl2 into new pipeline
my $pl3 = ipc_pipeline(
  $pl2,
  ipc_cmd(qw( cat - ), ipc_arg( 'catfile' )),
  ipc_cmd(qw( sed /^[	 A-Z]*$/ )),
);

my @pl3_cmds = $pl3->cmds;
is scalar @pl3_cmds, 4, "third pipeline has expected number of commands";

my @pl3_cmd2_args = $pl3_cmds[1]->args;
is scalar @pl3_cmd2_args, 2, "second command in third pipeline has expected number of args";

is_deeply @pl3_cmd2_args, @pl1_cmd2_args, "second command args from first and third pipeline match";



# run the pipeline, colect the output and check
pipe my($myend, $sinkend);
my %pidinfo = ipc_pipeline( $pl1, $pl3 )
  ->run( source => $0, sink => $sinkend, catfile => $0)
  ->pids;
my %statuses =
  map { waitpid($_, 0); $_ => ($? >> 8); }
  keys %pidinfo;
close $sinkend;
my $got = ''; while (sysread($myend, my $buf, 512)) { $got .= $buf; };
my $expected = grep { ! /^$/ } read_file $0;

is $got, $expected, "it fucking WORKED!";

done_testing;
