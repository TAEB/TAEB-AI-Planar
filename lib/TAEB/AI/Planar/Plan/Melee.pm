#!/usr/bin/env perl
package TAEB::AI::Planar::Plan::Melee;
use TAEB::OO;
use TAEB::Util qw/delta2vi/;
extends 'TAEB::AI::Planar::Plan::PathBased';

# We take a monster as argument.
has monster => (
    isa     => 'Maybe[TAEB::World::Monster]',
    default => undef,
);
sub set_arg {
    my $self = shift;
    $self->monster(shift);
}

# When meleeing, we run up next to the monster before attacking.
sub aim_tile {
    shift->monster->tile;
}
sub stop_early { 1 }
sub mobile_target { 1 }
# Whack it!
sub has_reach_action { 1 }
sub reach_action {
    my $self = shift;
    my $aim = $self->aim_tile;
    my $dir = delta2vi($aim->x-TAEB->x,$aim->y-TAEB->y);
    my $action = 'melee';
    return undef unless $dir =~ /[yuhjklbn]/;
    if ($self->monster->is_ghost && TAEB->level < 10) {
	$action = 'kick';
    }
    return TAEB::Action->new_action($action, direction => $dir);
}

sub calculate_extra_risk {
    my $self = shift;
    # It's risky to attack something that isn't meleeable.
    my $risk = 20*!($self->monster->is_meleeable);
    $risk += $self->aim_tile_turns(1);
    return $risk;
}

# Invalidate ourselves if the monster stops existing.
sub invalidate { shift->validity(0); }

use constant description => 'Meleeing a monster';

__PACKAGE__->meta->make_immutable;
no Moose;

1;