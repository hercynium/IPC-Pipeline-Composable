#!/usr/bin/env perl
use strict;
use warnings;
use File::Slurp qw(read_file);
use IPC::Composable::Pipeline;


my $place1 = IPC::Composable::Pipeline::Placeholder->new( name => 'gunzip_input' );
my $proc1  = IPC::Composable::Pipeline::Process->new(
  cmd  => 'gunzip',
  args => [ '-c', $place_1 ],
);


my $place2 = IPC::Composable::Pipeline::Placeholder->new( name => 'gzip_input' );
my $proc2  = IPC::Composable::Pipeline::Process->new(
  cmd  => 'gzip',
  args => [ '-c', $place2 ],
);
my $sub2 = IPC::Composable::Pipeline::ProcSub->new(
  pipeline => $proc2,  # a process is just a pipeline with a single item
  mode     => '<',     # sub as a named pipe for reading
);


my @pids = $proc1->run(
  stdout       => \(my $output), # store output in this scalar
  placeholders => {
    gunzip_input => $sub2,
    gzip_input   => $0,
  },
);
wait for @pids;


my $expected = read_file $0;


print ($output eq $expected ? 'PASS' : 'FAIL'), "\n";


