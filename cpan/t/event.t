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

# Test of scannerless parsing -- predicted, nulled and completed events with 
# deactivation and reactivation

use 5.010001;
use strict;
use warnings;

use Test::More tests => 44;
use English qw( -no_match_vars );
use lib 'inc';
use Marpa::R3::Test;
use Marpa::R3;

my $rules = <<'END_OF_GRAMMAR';
:start ::= sequence
sequence ::= A B C D E F G  H I J K L
    action => OK
A ::= 'a'
B ::= 'b'
C ::= 'c'
D ::= 'd'
E ::=
F ::= 'f'
G ::=
H ::= 'h'
I ::= 'i'
J ::= 'j'
K ::=
L ::= 'l'

event '^a' = predicted A
event '^b' = predicted B
event '^c' = predicted C
event '^d' = predicted D
event '^e' = predicted E
event '^f' = predicted F
event '^g' = predicted G
event '^h' = predicted H
event '^i' = predicted I
event '^j' = predicted J
event '^k' = predicted K
event '^l' = predicted L
event 'a' = completed A
event 'b' = completed B
event 'c' = completed C
event 'd' = completed D
event 'e' = completed E
event 'f' = completed F
event 'g' = completed G
event 'h' = completed H
event 'i' = completed I
event 'j' = completed J
event 'k' = completed K
event 'l' = completed L
event 'a[]' = nulled A
event 'b[]' = nulled B
event 'c[]' = nulled C
event 'd[]' = nulled D
event 'e[]' = nulled E
event 'f[]' = nulled F
event 'g[]' = nulled G
event 'h[]' = nulled H
event 'i[]' = nulled I
event 'j[]' = nulled J
event 'k[]' = nulled K
event 'l[]' = nulled L
END_OF_GRAMMAR

# This test the order of events
# No more than one of each event type per line
# so that order is non-arbitrary
my $all_events_expected = <<'END_OF_EVENTS';
0 ^a
1 a ^b
2 b ^c
3 c ^d
4 d e[] ^f
5 f g[] ^h
6 h ^i
7 i ^j
8 j k[] ^l
9 l
END_OF_EVENTS

my %pos_by_event = ();
my @events;
for my $pos_events  (split /\n/xms, $all_events_expected)
{
    my ($pos, @pos_events) = split " ", $pos_events;
    $pos_by_event{$_} = $pos for @pos_events;
    push @events, @pos_events;
}

my $grammar = Marpa::R3::Scanless::G->new( { source => \$rules } );

my $location_0_event = qq{0 ^a\n} ;

# Test of all events
do_test( "all events", $grammar, q{abcdfhijl}, $all_events_expected );

# Now deactivate all events
do_test( "all events deactivated", $grammar, q{abcdfhijl}, $location_0_event, [] );

# Now deactivate all events, and turn them back on, one at a time
EVENT: for my $event (@events) {
    next EVENT if $event eq '^a'; # Location 0 events cannot be deactivated
    my $expected_events = $location_0_event . $pos_by_event{$event} . " $event\n";
    do_test( qq{event "$event" reactivated}, $grammar, q{abcdfhijl}, $expected_events, [$event] );
}

sub show_last_subtext {
    my ($recce) = @_;
    my ( $start, $length ) = $recce->last_completed('subtext');
    return 'No expression was successfully parsed' if not defined $start;
    return $recce->g1_literal( $start, $length );
}

sub do_test {
    my ( $test, $slg, $string, $expected_events, $reactivate_events ) = @_;
    my $actual_events = q{};
    my $recce = Marpa::R3::Scanless::R->new(
        { grammar => $grammar, semantics_package => 'My_Actions' } );
    if (defined $reactivate_events) {

# Marpa::R3::Display
# name: SLIF activate() method synopsis

        $recce->activate($_, 0) for @events;

# Marpa::R3::Display::End

        $recce->activate($_) for @{$reactivate_events};

    }

# Marpa::R3::Display
# name: SLIF events() method synopsis

    my $length = length $string;
    my $pos    = $recce->read( \$string );
    READ: while (1) {

        my @actual_events = ();

        EVENT:
        for my $event ( @{ $recce->events() } ) {
            my ($name) = @{$event};
            push @actual_events, $name;
        }

        if (@actual_events) {
            $actual_events .= join q{ }, $pos, @actual_events;
            $actual_events .= "\n";
        }
        last READ if $pos >= $length;
        $pos = $recce->resume($pos);
    } ## end READ: while (1)

# Marpa::R3::Display::End

    my $value_ref = $recce->value();
    if ( not defined $value_ref ) {
        die "No parse\n";
    }
    my $actual_value = ${$value_ref};
    Test::More::is( $actual_value, q{1792}, qq{Value for $test} );
    Marpa::R3::Test::is( $actual_events, $expected_events,
        qq{Events for $test} );
} ## end sub do_test

sub My_Actions::OK { return 1792 };

# vim: expandtab shiftwidth=4:
