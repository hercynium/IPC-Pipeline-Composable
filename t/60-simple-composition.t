#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::Slurp qw(read_file);

my $CLASS;
BEGIN { $CLASS = "IPC::Pipeline::Composable"; use_ok $CLASS; }

$|++;

# create an IPC object, specifying the sink as one end of a pipe
pipe my($readme,$writeme);
my $obj = new_ok $CLASS => [sink_fh => $writeme];

# first, run cat with this filename as its argument
$obj->push_cmd( 'cat' => $0 );

# and connect the stdout of cat with the stdin of gtac
$obj->push_cmd( 'gtac' );

# if we run the pipeline now, the output will go to the sink
# we specified earlier. wait for the process exit statuses.
my %statuses =
  map { waitpid($_, 0); $_ => ($? >> 8); }
  $obj->run()->pids();
close $writeme;

# make sure all the processes ran and exited OK
is scalar keys %statuses, 2, "expected number of processes spawned";
is $statuses{$_}, 0, "process $_ exited sucessfully" for keys %statuses;

# read the pipe and make sure the output was this file backwards...
my $got=''; while (sysread($readme, my $buf, 512)) { $got .= $buf; }
my $expected = join '', reverse read_file($0);
is $got, $expected, "got the data we expected";


# add another 'tac' to the end of this pipeline and see if
# it still works as expected...
close $readme;
pipe $readme, $writeme;
$obj->push_cmd( 'gtac' );
%statuses = map { waitpid($_, 0); $_ => ($? >> 8); } $obj->run()->pids();
close $writeme;
is scalar keys %statuses, 3, "expected number of processes spawned";
is $statuses{$_}, 0, "process $_ exited sucessfully" for keys %statuses;
$got=''; while (sysread($readme, my $buf, 512)) { $got .= $buf; }
$expected = read_file($0);
is $got, $expected, "got the data we expected";


done_testing;

__DATA__
foo
bar
baz
wibble wobble
weeble

