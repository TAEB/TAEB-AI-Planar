#!/usr/bin/env perl
package TAEB::AI::Planar::Plan::Stairs;
use TAEB::OO;
use TAEB::Util qw/delta2vi/;
use Moose;
extends 'TAEB::AI::Planar::Plan::ComplexTactic';

sub calculate_risk {
    my $self = shift;
    my $tme  = shift;
    $self->cost("Time",1);
    $self->level_step_danger($self->tile->level);
    if ($self->tile_from->level == TAEB->current_level) {
        # Add two turns of attacks from all monsters in LOS.
        # We're going to have to deal with them eventually, and now
        # is better than later.
        # If there are at least two such monsters capable of attacking,
        # don't use the stairs at all until we've cleared them a bit
        # (this is a bit hackish, but needed until we get a better AI
        # for fighting mobs).
        my $mcount = 0;
        for my $monster (TAEB->current_level->monsters) {
            next unless $monster->tile->in_los;
            my $spoiler = $monster->spoiler;
            if ($spoiler) {
                my $maxd = $monster->maximum_melee_damage;
                $self->cost("Hitpoints",$maxd*2);
                $mcount++ if $maxd;
            } else {
                # default for undeterminable monsters
                $self->cost("Hitpoints",5*2);
            }
        }
        $self->cost("Impossibility",1) if $mcount >= 2;
    }
}

sub is_possible {
    my $self = shift;
    my $tme  = shift;
    my $tile = $self->tile_from;
    return $tile->can("other_side") && defined $tile->other_side;
}

sub action {
    my $self = shift;
    my $tile = $self->tile_from;
    return TAEB::Action->new_action('ascend') if $tile->type eq 'stairsup';
    return TAEB::Action->new_action('descend') if $tile->type eq 'stairsdown';
    return undef;
}

sub succeeded {
    my $self = shift;
    return TAEB->current_tile == $self->tile;
}

use constant description => 'Using stairs';

__PACKAGE__->meta->make_immutable;
no Moose;

1;
