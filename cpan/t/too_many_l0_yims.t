#!perl
# Marpa::R3 is Copyright (C) 2016, Jeffrey Kegler.
#
# This module is free software; you can redistribute it and/or modify it
# under the same terms as Perl 5.10.1. For more details, see the full text
# of the licenses in the directory LICENSES.
#
# This program is distributed in the hope that it will be
# useful, but it is provided “as is” and without any express
# or implied warranties. For details, see the full text of
# of the licenses in the directory LICENSES.

use 5.010001;

# This test is new with Marpa::R3
# A test of the warning for "too many Earley items"
# Uses a grammar which creates the Catalan numbers
# This version tests the L0 threshold

use strict;
use warnings;

use Test::More tests => 1;
use lib 'inc';
use Marpa::R3::Test;
use Marpa::R3;

my $grammar = Marpa::R3::Scanless::G->new(
    {
        source => \<<'END_OF_DSL',
top ::= lex_pair
lex_pair ~ pair
pair ~ a a
pair ~ pair a
pair ~ a pair
pair ~ pair pair
a ~ 'a'
END_OF_DSL
    }
);

my $n           = 20;
my $parse_count = 0;

my $recce = Marpa::R3::Scanless::R->new(
    { grammar => $grammar, too_many_earley_items => 10 } );

# An arbitrary maximum is put on the number of parses -- this is for
# debugging, and infinite loops happen.
$recce->set( { max_parses => 999, } );

my $trace_output;
open my $trace_fh, q{>}, \$trace_output;
$recce->set( { trace_file_handle => $trace_fh } );

$recce->read( \( 'a' x $n ) );

$recce->set( { trace_file_handle => \*STDOUT } );
close $trace_fh;

my $expected_trace_output = <<'END_OF_TRACE';
L0 exceeded earley item threshold at pos 19: 103 Earley items
END_OF_TRACE

Marpa::R3::Test::is( $trace_output, $expected_trace_output,
    '"Too many Earley items" Trace Output' );

1;    # In case used as "do" file

# vim: expandtab shiftwidth=4:
