#! /usr/bin/perl

# Copyright (c) 2012, cPanel, Inc.
# All rights reserved.
# http://cpanel.net/
#
# This is free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.  See the LICENSE file for further details.

use Test::More ( 'tests' => 1 );
use Test::Exception;

use strict;
use warnings;

#use IPC::Pipeline::Continuous qw(pipeline);
use IPC::Pipeline;

throws_ok {
    pipeline( my ( $in, $out, $err ), 'foo' );
}
qr/^Filter passed is not a/, 'pipeline() fails when filter is not CODE or ARRAY';
