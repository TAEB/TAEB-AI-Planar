#!/usr/bin/env perl
package TAEB::AI::Planar::Plan::Excalibur;
use TAEB::OO;
use TAEB::Spoilers::Combat;
use Moose;
extends 'TAEB::AI::Planar::Plan::Strategic';

# We take a tile as argument.
has (tile => (
    isa     => 'Maybe[TAEB::World::Tile]',
    is  => 'rw',
    default => undef,
));
sub set_arg {
    my $self = shift;
    $self->tile(shift);
}


sub invalidate { shift->validity(0); }

sub aim_tile {
    my $self = shift;
    $self->validity(0), return if $self->tile->type ne 'fountain';
    return if TAEB->get_artifact("Excalibur");
    return if TAEB->level < 5;
    return if TAEB->align ne 'Law';
    return if $self->tile->level->is_minetown;
    return unless TAEB->has_item('long sword');
    return $self->tile;
}

sub gain_resource_conversion_desire {
    my $self = shift;
    return if TAEB->get_artifact("Excalibur");
    return if TAEB->level < 5;
    return if TAEB->align ne 'Law';
    return unless TAEB->has_item('long sword');
    # Excalibur does an extra 5.5 damage on average.
    TAEB->ai->add_capped_desire($self,
        TAEB->ai->resources->{'DamagePotential'}->anticost(5.5));
}

sub has_reach_action { 1 }
# TODO: Which longsword should we dip if we have more than one?
sub reach_action {
    my $self = shift;
    return TAEB::Action->new_action('dip',
                                    item => TAEB->has_item('long sword'),
                                    into => 'fountain');
}
sub reach_action_succeeded {
    my $self = shift;
    return 1 if TAEB->get_artifact("Excalibur");
    return 0 if $self->tile->type ne 'fountain';
    return undef; # TODO: figure out when this won't work
}
sub calculate_extra_risk {
    my $self = shift;
    my $risk = 0;
    my $count = 0;
    $risk += $self->cost('Time', 1);
    $risk += $self->cost('Hitpoints',5);
    # Don't be too anxious to get Excalibur at low levels, it's
    # usually too dangerous for a character newly reaching level 5
    $risk += $self->cost('Hitpoints',10) if TAEB->level < 8;
    $risk += $self->cost('Hitpoints',20) if TAEB->level < 7;
    $risk += $self->cost('Hitpoints',40) if TAEB->level < 6;
    # If we don't know of a lot of fountains, we might just wind up
    # with a rusty heap.
    $risk += $self->cost('DamagePotential',3)
        unless TAEB->dungeon->special_level->{'oracle'}
            || TAEB->nearest_level(sub { $count += shift->tiles_of('fountain');
                                         $count >= 3; });
    return $risk;
}

use constant description => "Dipping for Excalibur";

__PACKAGE__->meta->make_immutable;
no Moose;

1;
