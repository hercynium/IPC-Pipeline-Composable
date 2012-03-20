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

my $pl1 = ipc_pipeline( $cmd1, sub { print lc $_ while <>; 1 } ); # convert rot13 txt to lowercase

my @pl1_cmds = $pl1->cmds;
is scalar @pl1_cmds, 2, "first pipeline has expected number of commands";
isa_ok $_, 'IPC::Pipeline::Composable::Command' for @pl1_cmds;

my @pl1_cmd1_args = $pl1_cmds[0]->args;
is scalar @pl1_cmd1_args, 2, "first command in first pipeline has expected number of args";



# compose $pl1 into new pipeline
my $pl2 = ipc_pipeline(
  $pl1,
  ipc_command('sed', 's/.*//'), # delete all text, leave blank lines
);

my @pl2_cmds = $pl2->cmds;
is scalar @pl2_cmds, 3, "second pipeline has expected number of commands";

my @pl2_cmd1_args = $pl2_cmds[0]->args;
is scalar @pl2_cmd1_args, 2, "first command in second pipeline has expected number of args";

is_deeply \@pl2_cmd1_args, \@pl1_cmd1_args, "first command args from first and second pipeline match";

is scalar @{$pl2->cmds->[2]->args}, 1, "third command in second pipeline has expected number of args";


# run what we have right now...
pipe my($myend, $sinkend);
open my $src, '<', $0;
my @pidinfo  = $pl2->run( source_fh => $src, sink_fh => $sinkend )->pids;
my @statuses = map { waitpid($_, 0); $_ => ($? >> 8); } @pidinfo;
close $sinkend;
my $got = ''; while (sysread($myend, my $buf, 512)) { $got .= $buf; };
my $expected = join '', map {s/.*//; $_} read_file $0;

is $got, $expected, "it fucking WORKED!";

done_testing;
__END__
# compose with yet another pipeline, one with a command that uses a placeholder for an argument
my $pl3 = ipc_pipeline(
  $pl2,
  ipc_command('cat', ipc_placeholder( 'catfile' ), '-'),
  q{sed '/^$/d'}, # delete all blank lines
);

my @pl3_cmds = $pl3->cmds;
is scalar @pl3_cmds, 5, "second pipeline has expected number of commands";

my @pl3_cmd3_args = $pl3_cmds[3]->args;
is scalar @{$pl3_cmds[3]->args}, 2, "fourth command in third pipeline has expected number of args";


done_testing;
__END__

# run the pipeline, supplying the placeholder. colect the output and check it.
pipe my($myend, $sinkend);
my %pidinfo = $pl3->run( source => $0, sink => $sinkend, catfile => $0)->pids;
my %statuses =
  map { waitpid($_, 0); $_ => ($? >> 8); }
  keys %pidinfo;
close $sinkend;
my $got = ''; while (sysread($myend, my $buf, 512)) { $got .= $buf; };
my $expected = grep { ! /^$/ } read_file $0;

is $got, $expected, "it fucking WORKED!";

done_testing;
