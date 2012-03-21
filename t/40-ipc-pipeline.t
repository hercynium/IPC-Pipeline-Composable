#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use autodie;
use File::Slurp qw(read_file);
use File::Temp qw(:seekable);
use Test::More;
use Capture::Tiny qw(:all);

use_ok 'IPC::Pipeline::Composable' => qw(pipeline pipeline_c);

my $expected = join '', (
  grep { $_ !~ /^\s*$/ }
  map { uc }
  sort { $a cmp $b }
  read_file($0)
)[0..4];

my @filters = (
  ['sort' => $0],
  [qw(tr a-z A-Z)],
  sub { /^\s*$/ or print $_ while <>; 1 },
  [qw(head -n 5)],
);


sub stdout_to_stdout {
  waitpid($_, 0) for pipeline_c( undef, \*STDOUT, undef, @filters );
}

sub stdout_to_stderr {
  # stream thru pipe to parent's STDERR
  waitpid($_, 0) for pipeline_c( undef, \*STDERR, undef, @filters );
}

sub no_output {
  waitpid($_, 0) for pipeline_c( undef, undef, undef, @filters );
}

# really, same for *any* file-handle
sub fh_output {
  waitpid($_, 0) for pipeline_c( undef, shift(), undef, @filters );
}


my ($stdout, $stderr, @result);

($stdout, $stderr, @result) = capture \&stdout_to_stdout;
is $stdout, $expected, 'stdout streaming works';

($stdout, $stderr, @result) = capture \&stdout_to_stderr;
is $stderr, $expected, 'stderr streaming works';

($stdout, $stderr, @result) = capture \&no_output;
is $stdout, '', 'no stdout when no handle passed';

($stdout, $stderr, @result) = capture \&no_output;
is $stderr, '', 'no stderr when no handle passed';


my $tmpfh = File::Temp->new(UNLINK => 1);
fh_output($tmpfh);
seek( $tmpfh, 0, SEEK_SET );
#diag "Filename: " . $tmpfh->filename;
is scalar read_file($tmpfh), $expected, 'streaming to filehandle works';


done_testing;
