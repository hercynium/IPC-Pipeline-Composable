#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Slurp qw( read_file );
use Data::Dumper;


use_ok 'IPC::Pipeline::Composable', qw( ipc_pipeline ipc_command ipc_placeholder );



my $cmd1 = ipc_command(qw( tr a-mn-zA-MN-Z n-za-mN-ZA-M )); # rot13
is $cmd1->cmd, 'tr', "command has expected command name";
is scalar @{$cmd1->args}, 2, "command has expected number of args";

my $pl1 = ipc_pipeline( $cmd1, sub { lc } ); # convert rot13 txt to lowercase

my @pl1_cmds = $pl1->cmds;
is scalar @pl1_cmds, 2, "first pipeline has expected number of commands";
isa_ok $_, 'IPC::Pipeline::Composable::Command' for @pl1_cmds;

my @pl1_cmd1_args = $pl1_cmds[0]->args;
is scalar @pl1_cmd1_args, 2, "first command in first pipeline has expected number of args";



# compose $pl1 into new pipeline
my $pl2 = ipc_pipeline(
  $pl1,
  ipc_command('cat', ipc_placeholder( 'catfile' ), '-'),
);

my @pl2_cmds = $pl2->cmds;
is scalar @pl2_cmds, 3, "second pipeline has expected number of commands";

my @pl2_cmd1_args = $pl2_cmds[0]->args;
is scalar @pl2_cmd1_args, 2, "first command in second pipeline has expected number of args";

is_deeply \@pl2_cmd1_args, \@pl1_cmd1_args, "first command args from first and second pipeline match";

is scalar @{$pl2->cmds->[2]->args}, 2, "third command in second pipeline has expected number of args";


my $pl3 = ipc_pipeline(
  ipc_command(sub { uc }),
  ipc_command('sed', 's/.*//'),
);



done_testing;
__END__

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
