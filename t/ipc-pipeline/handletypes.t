#! /usr/bin/perl

# Copyright (c) 2012, cPanel, Inc.
# All rights reserved.
# http://cpanel.net/
#
# This is free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.  See the LICENSE file for further details.

use Test::More ( tests => 8 );

use strict;
use warnings;

#use IPC::Pipeline::Continuous qw(pipeline);
use IPC::Pipeline;

ok( !defined pipeline( undef, undef, undef ), 'Calling pipeline() without commands returns undef' );

{
    my $pid = pipeline( my ( $in, $out, $error ), [qw/echo hi/], [qw/cat/] );

    close($in);
    close($out);

    waitpid( $pid, 1 );

    ok( $pid > 0, "Calling pipeline() in scalar context returns single nonzero pid ($pid)" );
}

{
    open( TEST_IN,    '>', '/dev/null' );
    open( TEST_OUT,   '<', '/dev/null' );
    open( TEST_ERROR, '<', '/dev/null' );

    my $expected = 2;

    my @pids = pipeline(
        \*TEST_IN, \*TEST_OUT, \*TEST_ERROR,
        [ qw/perl -e/, 'print readline(STDIN) ."\n"; die' ],
        [qw/cat/]
    );

    ok( scalar @pids == $expected, "Calling pipeline() with typeglobs succeeds in creating $expected processes" );

    {
        my $expected = 'Test line';
        print( TEST_IN "$expected\n" );
        close(TEST_IN);

        my $line = readline(TEST_OUT);
        chomp($line);
        ok( $line eq $expected, 'Reading and writing to typeglob handles passed to pipeline() succeeds' );
    }

    {
        my $expected = qr/^Died at/;
        my $line     = readline(TEST_ERROR);
        chomp($line);

        ok( $line =~ $expected, 'Reading from error typeglob handle passed to pipeline() succeeds' );
    }

    close(TEST_OUT);
    close(TEST_ERROR);

    foreach (@pids) {
        waitpid( $_, 1 );
    }
}

{
    open( my $fh_in,    '>', '/dev/null' );
    open( my $fh_out,   '<', '/dev/null' );
    open( my $fh_error, '<', '/dev/null' );

    my $expected = 2;

    my @pids = pipeline(
        fileno($fh_in), fileno($fh_out), fileno($fh_error),
        [ qw/perl -e/, 'print readline(STDIN) ."\n"; die' ],
        [qw/cat/]
    );

    ok( scalar @pids == $expected, "Calling pipeline() with file descriptors succeeds in creating $expected processes" );

    {
        my $expected = 'Test line';
        print( $fh_in "$expected\n" );
        close($fh_in);

        my $line = readline($fh_out);
        chomp($line);
        ok( $line eq $expected, 'Reading and writing to file descriptors passed to pipeline() succeeds' );
    }

    {
        my $expected = qr/^Died at/;
        my $line     = readline($fh_error);
        chomp($line);

        ok( $line =~ $expected, 'Reading from error file descriptors passed to pipeline() succeeds' );
    }

    close($fh_out);
    close($fh_error);

    foreach (@pids) {
        waitpid( $_, 1 );
    }
}
