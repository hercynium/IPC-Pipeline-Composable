#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::Slurp qw(read_file);

my $CLASS;
BEGIN { $CLASS = "IPC::Pipeline::Composable"; use_ok($CLASS); }

$|++;

# pipe this file through tac
pipe my($readme,$writeme);
my $obj = new_ok( $CLASS => [sink_fh => $writeme] );
$obj->push_cmd( 'cat' => $0 );
$obj->push_cmd( 'gtac' );

my %statuses =
  map { waitpid($_, 0); $_ => ($? >> 8); }
  $obj->run()->pids();
close $writeme;

is $statuses{$_}, 0, "process $_ existed sucessfully" for keys %statuses;


my $got=''; while (sysread($readme, my $buf, 512)) { $got .= $buf; }
my $expected = join '', reverse read_file($0);

is $got, $expected, "got the data we expected";

done_testing;

__DATA__
foo
bar
baz
wibble wobble
weeble

