#!/usr/bin/env perl
package TAEB::AI::Planar::Plan::Projectile;
use TAEB::OO;
use TAEB::Util qw/delta2vi/;
use TAEB::AI::Planar::Resource::Ammo;
use POSIX qw/ceil/;
extends 'TAEB::AI::Planar::Plan::Strategic';

# We take a monster as argument.
has monster => (
    isa     => 'Maybe[TAEB::World::Monster]',
    is  => 'rw',
    default => undef,
);
sub set_arg {
    my $self = shift;
    $self->monster(shift);
}

sub get_projectile {
    my $projectile = (TAEB::AI::Planar::Resource::Ammo::projectilelist 0)[0];
    $projectile and return $projectile;
    return;
}

# To throw projectiles, we're aiming for a tile orthogonal or diagonal
# to the monster.
sub aim_tile {
    my $self = shift;
    return $self->monster->tile if $self->get_projectile;
    return undef;
}
sub stop_early {
    my $projectile = get_projectile;
    return $projectile->throw_range if $projectile;
    return 0; # irrelevant anyway at this point
}
sub stop_early_blocked_by {
    my $self = shift;
    my $tile = shift;
    my $monster = $self->monster;
    return 1 if $tile->type eq 'rock' && !$tile->has_boulder;
    return 1 if $tile->type eq 'wall';
    return 1 if $tile->has_monster;
    return 1 if $tile->type eq 'sink';
    return 1 if $tile->type eq 'unexplored'
             && $monster->glyph eq 'I' || TAEB->is_blind;
    return 0;
}
sub mobile_target { 1 }
sub has_reach_action { 1 }
sub reach_action {
    my $self = shift;
    my $aim = $self->aim_tile;
    my $dir = delta2vi($aim->x-TAEB->x <=> 0, $aim->y-TAEB->y <=> 0);
    my $action = 'throw';
    return undef unless $dir =~ /[yuhjklbn]/;
    return TAEB::Action->new_action($action,
                                    projectile => $self->get_projectile,
                                    target_tile => $aim,
                                    direction => $dir);
}

sub calculate_extra_risk {
    my $self = shift;
    my $risk = $self->cost("Ammo",
	$self->get_projectile->identity =~ /dagger/ ? 1 : 0.1);
    my $monster = $self->monster;
    if (abs($monster->x - TAEB->x) <= 1 &&
        abs($monster->y - TAEB->y) <= 1) {
        $risk += $self->aim_tile_turns(
            ceil($monster->average_actions_to_kill // 10));
    } else {
        $risk += $self->aim_tile_turns(1);
    }
    # Chasing unicorns is fruitless
    $risk += $self->cost("Impossibility", 1) if $monster->is_unicorn &&
	$self->aim_tile_cache != $self->aim_tile;
    $risk += $self->attack_monster_risk($monster) // 0;
    return $risk;
}

# Invalidate ourselves if the monster stops existing.
sub invalidate { shift->validity(0); }

use constant description => 'Throwing projectiles at a monster';

__PACKAGE__->meta->make_immutable;
no Moose;

1;
