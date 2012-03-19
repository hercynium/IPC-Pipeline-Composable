#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use IPC::Pipeline::Composable;
use autodie;

### new functionality!

# stream thru pipe to parent's STDERR
waitpid($_, 1) for pipeline(
  undef, \*STDERR, undef,
  ['sort' => $0],
  [qw(tr a-z A-Z)],
  [qw(grep -Pv ^\s*$)],
);

# same for STDOUT
waitpid($_, 1) for pipeline(
  undef, \*STDOUT, undef,
  ['sort' => $0],
  [qw(tr a-z A-Z)],
  sub { /^\s*$/ or print $_ while <>; 1 },
);

# really, same for *any* file-handle!
open my $foo, '>', "$0.out";
waitpid($_, 1) for pipeline(
  undef, $foo, undef,
  [cat => $0],
  ['sort'],
  sub { print scalar reverse while <>; 1},
  [qw(tr a-z A-Z)]
);
close $foo;

### documented functionality

my @pids = pipeline(
  my ($in, $out), undef,
  ['sort'],
  [qw(tr a-z A-Z)],
  ['gtac'],
);
print $in "$_\n" for qw(wibble wobble weeble woo-hoo);
close $in;
while (my $len = sysread($out, my $buf, 512)) {
  syswrite(STDOUT, $buf, $len);
}
close $out;
foreach my $pid (@pids) {
  waitpid($pid, 1);
}


__DATA__
foo
bar
baz
wibble wobble
weeble

