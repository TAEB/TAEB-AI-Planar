#!/usr/bin/env perl
package TAEB::AI::Planar::Plan::Melee;
use TAEB::OO;
use TAEB::Util qw/delta2vi/;
use Moose;
use POSIX qw/ceil/;
extends 'TAEB::AI::Planar::Plan::Strategic';

# We take a monster as argument.
has (monster => (
    isa     => 'Maybe[TAEB::World::Monster]',
    is  => 'rw',
    default => undef,
));
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
    my $monster = $self->monster;
    my $ttk = ceil($self->monster->average_actions_to_kill // 3) || 1;
    # It's risky to attack something that isn't meleeable.
    my $risk = 0;
    $risk = $self->cost('Impossibility', 1)
        unless $self->monster->is_meleeable;
    $risk += $self->aim_tile_turns(1+$ttk/10); # arbitrary
    $risk += $self->attack_monster_risk($monster)
        // $self->cost('Hitpoints', 5); # stock value for hallu

    $risk += $self->cost('Pacifism', 1);
    return $risk;
}

sub spread_desirability {
    my $self = shift;
    # scare off enemies, make this cheaper
    $self->depends(1,"DefensiveElbereth") if
        TAEB->current_tile->any_adjacent(sub {
            $_->has_monster && $_->monster->respects_elbereth;
        });
}

# Writing Elbereth before melee tends to just scare monsters off.
# XXX monster tracking, ekiM
sub elbereth_helps { 0 }

# Invalidate ourselves if the monster stops existing.
sub invalidate { shift->validity(0); }

use constant description => 'Meleeing a monster';
use constant references => ['DefensiveElbereth'];

__PACKAGE__->meta->make_immutable;
no Moose;

1;
