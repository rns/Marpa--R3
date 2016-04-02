#!/usr/bin/perl
# Copyright 2016 Jeffrey Kegler
# This file is part of Marpa::R3.  Marpa::R3 is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::R3 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::R3.  If not, see
# http://www.gnu.org/licenses/.

# Tutorial 2 synopsis

use 5.010001;
use strict;
use warnings;

use Test::More tests => 1;

use lib 'inc';
use Marpa::R3::Test;

## no critic (ErrorHandling::RequireCarping);

# Marpa::R3::Display
# name: Tutorial 2 synopsis

use Marpa::R3;

my $dsl = <<'END_OF_DSL';
:default ::= action => [name,values]
lexeme default = latm => 1

Calculator ::= Expression action => ::first

Factor ::= Number action => ::first
Term ::=
    Term '*' Factor action => do_multiply
    | Factor action => ::first
Expression ::=
    Expression '+' Term action => do_add
    | Term action => ::first
Number ~ digits
digits ~ [\d]+
:discard ~ whitespace
whitespace ~ [\s]+
END_OF_DSL

my $grammar = Marpa::R3::Scanless::G->new( { source => \$dsl } );
my $recce = Marpa::R3::Scanless::R->new(
    { grammar => $grammar, semantics_package => 'My_Actions' } );
my $input = '42 * 1 + 7';
my $length_read = $recce->read( \$input );

die "Read ended after $length_read of ", length $input, " characters"
    if $length_read != length $input;

if ( my $ambiguous_status = $recce->ambiguous() ) {
    chomp $ambiguous_status;
    die "Parse is ambiguous\n", $ambiguous_status;
}

my $value_ref = $recce->value;
my $value = ${$value_ref};

sub My_Actions::do_add {
    my ( undef, $t1, undef, $t2 ) = @_;
    return $t1 + $t2;
}

sub My_Actions::do_multiply {
    my ( undef, $t1, undef, $t2 ) = @_;
    return $t1 * $t2;
}

# Marpa::R3::Display::End

Test::More::is( $value, 49, 'Tutorial 2 synopsis value' );

1;    # In case used as "do" file

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
