#!/usr/bin/env perl
package TAEB::AI::Planar::Resource::Hitpoints;
use TAEB::OO;
use Moose;
extends 'TAEB::AI::Planar::Resource';

has (_value => (
    isa => 'Num',
    is  => 'rw',
    default => 10, # hitpoints are one of the most valuable resources
));

sub amount {
    return TAEB->hp-1;
}

# Scarcity of hitpoints depends on how close to max hp we are; they
# aren't scarce if we have more than half, and get scarcer and scarcer
# as we get more and more injured.
sub scarcity {
    my $self = shift;
    my $quantity = shift;
    my $n=1;
    my $maxhp = TAEB->maxhp;
    $quantity <= 0 and return 1024;
    $quantity * 5 >= $maxhp * 4 and return 0.02;
    while (1) {
	$quantity > $maxhp/($n+1) and return $n*$n;
	$n++;
	$n >= 32 and return 1024;
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
