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

# CENSUS: ASIS
# Note: SLIF TEST

# Test of scannerless parsing -- diagnostics

use 5.010001;
use strict;
use warnings;

use Test::More tests => 9;
use English qw( -no_match_vars );
use lib 'inc';
use Marpa::R3::Test;
use Marpa::R3;

my $dsl = <<'END_OF_RULES';
:default ::= action => My_Actions::do_arg0
:start ::= Script
Script ::= Calculation* action => do_list
Calculation ::= Expression | ('say') Expression
Expression ::=
     Number
   | ('+') Expression Expression action => do_add
Number ~ [\d] +
:discard ~ whitespace
whitespace ~ [\s]+
# allow comments
:discard ~ <hash comment>
<hash comment> ~ <terminated hash comment> | <unterminated
   final hash comment>
<terminated hash comment> ~ '#' <hash comment body> <vertical space char>
<unterminated final hash comment> ~ '#' <hash comment body>
<hash comment body> ~ <hash comment char>*
<vertical space char> ~ [\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
<hash comment char> ~ [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
END_OF_RULES

my $grammar = Marpa::R3::Scanless::G->new( { source => \$dsl, });

package My_Actions;
# The SELF object is a very awkward way of specifying the per-parse
# argument directly, one which was necessary before the $recce->value()
# method took an argument.
# This way of doing things is discourage and preserved here for testing purposes.
our $SELF;
sub new { return $SELF }

sub do_list {
    my ( $self, $v ) = @_;
    my @results = @{$v};
    return +( scalar @results ) . ' results: ' . join q{ }, @results;
}

sub do_add  { return $_[1]->[0] + $_[1]->[1] }
sub do_arg0 { return $_[1]->[0] }

sub show_last_expression {
    my ($self) = @_;
    my $recce = $self->{recce};
    my ( $start, $length ) = $recce->last_completed('Expression');
    return if not defined $start;
    my $last_expression = $recce->length( $start, $length );
    return $last_expression;
} ## end sub show_last_expression

package main;

sub my_parser {
    my ( $grammar, $string ) = @_;

    my $self = bless { grammar => $grammar }, 'My_Actions';
    local $My_Actions::SELF = $self;

    my $trace_output = q{};
    open my $trace_fh, q{>}, \$trace_output;
    my $recce = Marpa::R3::Scanless::R->new(
        {   grammar               => $grammar,
            semantics_package => 'My_Actions',
            trace_terminals       => 2,
            trace_file_handle     => $trace_fh,
            too_many_earley_items => 100,         # test this
        }
    );
    $self->{recce} = $recce;
    my ( $parse_value, $parse_status, $last_expression );

    my $eval_ok = eval { $recce->read( \$string ); 1 };
    close $trace_fh;

    if ( not defined $eval_ok ) {
        my $abbreviated_error = $EVAL_ERROR;
        chomp $abbreviated_error;
        $abbreviated_error =~ s/\n.*//xms;
        die $self->show_last_expression(), $EVAL_ERROR;
    } ## end if ( not defined $eval_ok )
    my $value_ref = $recce->value;
    if ( not defined $value_ref ) {
        die join q{ },
            'Input read to end but no parse',
            $self->show_last_expression();
    }
    return $recce, ${$value_ref}, $trace_output;
} ## end sub my_parser

my @tests_data = (
    [ '+++ 1 2 3 + + 1 2 4', '1 results: 13', 'Parse OK', 'entire input' ],
);

TEST:
for my $test_data (@tests_data) {
    my ($test_string,     $expected_value,
        $expected_result, $expected_last_expression
    ) = @{$test_data};
    my ( $recce, $actual_value, $trace_output ) =
        my_parser( $grammar, $test_string );

# Marpa::R3::Display
# name: Scanless terminals_expected() synopsis

    my @terminals_expected = @{$recce->terminals_expected()};

# Marpa::R3::Display::End

    Marpa::R3::Test::is(
        ( join q{ }, sort @terminals_expected ),
        'Number [Lex-0] [Lex-1]',
        qq{SLIF terminals_expected()}
    );

# Marpa::R3::Display
# name: Scanless show_progress() synopsis

    my $show_progress_output = $recce->show_progress();

# Marpa::R3::Display::End

    Marpa::R3::Test::is( $show_progress_output,
        <<'END_OF_EXPECTED_OUTPUT', qq{Scanless show_progess()} );
P0 @0-11 L1c1-19 Script -> . Calculation *
F0 @0-11 L1c1-19 Script -> Calculation * .
P1 @11-11 L1c19 Calculation -> . Expression
F1 @0-11 L1c1-19 Calculation -> Expression .
P2 @11-11 L1c19 Calculation -> . 'say' Expression
P3 @11-11 L1c19 Expression -> . Number
F3 @10-11 L1c17-19 Expression -> Number .
P4 @11-11 L1c19 Expression -> . '+' Expression Expression
F4 x2 @0,6-11 L1c1-19 Expression -> '+' Expression Expression .
F5 @0-11 L1c1-19 [:start] -> Script .
END_OF_EXPECTED_OUTPUT

    Marpa::R3::Test::is( $actual_value, $expected_value,
        qq{Value of "$test_string"} );
    Marpa::R3::Test::is( $trace_output,
        <<'END_OF_OUTPUT', qq{Trace output for "$test_string"} );
Setting trace_terminals option
Expecting "Number" at earleme 0
Expecting "[Lex-0]" at earleme 0
Expecting "[Lex-1]" at earleme 0
Registering character U+002b '+' as symbol 5: [\+]
Registering character U+002b '+' as symbol 9: [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
Accepted lexeme L1c1 e1: '+'; value="+"
Accepted lexeme L1c2 e2: '+'; value="+"
Accepted lexeme L1c3 e3: '+'; value="+"
Registering character U+0020 as symbol 7: [\s]
Registering character U+0020 as symbol 9: [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
Registering character U+0031 '1' as symbol 6: [\d]
Registering character U+0031 '1' as symbol 9: [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
Discarded lexeme L1c4: whitespace
Accepted lexeme L1c5 e4: Number; value="1"
Registering character U+0032 '2' as symbol 6: [\d]
Registering character U+0032 '2' as symbol 9: [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
Discarded lexeme L1c6: whitespace
Accepted lexeme L1c7 e5: Number; value="2"
Registering character U+0033 '3' as symbol 6: [\d]
Registering character U+0033 '3' as symbol 9: [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
Discarded lexeme L1c8: whitespace
Accepted lexeme L1c9 e6: Number; value="3"
Discarded lexeme L1c10: whitespace
Accepted lexeme L1c11 e7: '+'; value="+"
Discarded lexeme L1c12: whitespace
Accepted lexeme L1c13 e8: '+'; value="+"
Discarded lexeme L1c14: whitespace
Accepted lexeme L1c15 e9: Number; value="1"
Discarded lexeme L1c16: whitespace
Accepted lexeme L1c17 e10: Number; value="2"
Registering character U+0034 '4' as symbol 6: [\d]
Registering character U+0034 '4' as symbol 9: [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
Discarded lexeme L1c18: whitespace
Accepted lexeme L1c19 e11: Number; value="4"
END_OF_OUTPUT

    my $expected_progress_output = [
        [ 0, -1, 0 ],
        [ 1, -1, 0 ],
        [ 3, -1, 10 ],
        [ 4, -1, 0 ],
        [ 4, -1, 6 ],
        [ 5, -1, 0 ],
        [ 0, 0,  0 ],
        [ 1, 0,  11 ],
        [ 2, 0,  11 ],
        [ 3, 0,  11 ],
        [ 4, 0,  11 ],
    ];

# Marpa::R3::Display
# name: Scanless progress() synopsis

    my $progress_output = $recce->progress();

# Marpa::R3::Display::End

    Marpa::R3::Test::is(
        Data::Dumper::Dumper($progress_output),
        Data::Dumper::Dumper($expected_progress_output),
        qq{Scanless progress()}
    );

# Marpa::R3::Display
# name: Scanless g1_pos() synopsis

    my $g1_pos = $recce->g1_pos();

# Marpa::R3::Display::End

    Test::More::is( $g1_pos, 11, qq{Scanless g1_pos()} );

# Marpa::R3::Display
# name: SLIF pos() example

    my $pos = $recce->pos();

# Marpa::R3::Display::End

    Test::More::is( $pos, 19, qq{Scanless pos()} );

# Marpa::R3::Display
# name: SLIF input_length() example

    my $input_length = $recce->input_length();

# Marpa::R3::Display::End

    Test::More::is( $input_length, 19, qq{Scanless input_length()} );

    # Test translation from G1 location to input stream spans
    my %location_seen = ();
    my @spans         = ();
    for my $g1_location (
        sort { $a <=> $b }
        grep { !$location_seen{$_}++; } map { $_->[-1] } @{$progress_output}
        )
    {

# Marpa::R3::Display
# name: Scanless g1_location_to_span() synopsis

        my ( $span_start, $span_length ) =
            $recce->g1_location_to_span($g1_location);

# Marpa::R3::Display::End

        push @spans, [ $g1_location, $span_start, $span_length ];
    } ## end for my $g1_location ( sort { $a <=> $b } grep { !$location_seen...})

    # One result for each unique G1 location in progress report
    # Format of each result is [g1_location, span_start, span_length]
    my $expected_spans =
        [ [ 0, 0, 0 ], [ 6, 8, 1 ], [ 10, 16, 1 ], [ 11, 18, 1 ] ];
    Test::More::is_deeply( \@spans, $expected_spans,
        qq{Scanless g1_location_to_span()} );

} ## end TEST: for my $test_data (@tests_data)

# vim: expandtab shiftwidth=4:
