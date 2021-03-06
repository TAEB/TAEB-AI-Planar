#!/usr/bin/env perl
package TAEB::AI::Planar::Plan::Equip;
use TAEB::OO;
use TAEB::Util qw/delta2vi refaddr/;
use Moose;
extends 'TAEB::AI::Planar::Plan::Strategic';

# We take an item in our inventory as argument.
has (item => (
    isa     => 'Maybe[NetHack::Item]',
    is      => 'rw',
    default => undef,
));
sub set_arg {
    my $self = shift;
    $self->item(shift);
}

has (taking_off => (
    isa     => 'Maybe[NetHack::Item]',
    is      => 'rw',
    default => undef,
));
has (unwielding => (
    isa     => 'Bool',
    is      => 'rw',
    default => 0,
));

sub aim_tile {
    my $self = shift;
    my $item = $self->item;
    return undef unless defined $item;
    return undef if !defined $item->is_cursed || $item->is_cursed;
    return TAEB->current_tile;
}

sub has_reach_action { 1 }
sub reach_action {
    my $self = shift;
    my $item = $self->item;
    return undef unless defined $item;
    if($item->isa('NetHack::Item::Weapon')) {
        return undef if $item->is_wielded;
        my $blocker = TAEB->inventory->equipment->blockers('weapon');
        if ($blocker) {
            TAEB->log->ai("I intend to take off $blocker to put on $item");
        }
        if ($blocker && $blocker->type eq 'weapon') {
            $self->unwielding(1);
            return TAEB::Action->new_action('wield', weapon => 'nothing');
        }
        $self->unwielding(0);
        $self->taking_off($blocker);
        return TAEB::Action->new_action('remove',  item => $blocker)
            if $blocker;
        return TAEB::Action->new_action('wield', weapon => $item);
    } else {
        # We need to take things off in order to put things on.
        # TODO: Ordering of multiple items
        return undef if $item->can('is_worn') && $item->is_worn;
        my $slot = $item->subtype;
        my $blocker = TAEB->inventory->equipment->blockers($slot);
        if ($blocker) {
            TAEB->log->ai("I intend to take off $blocker to put on $item");
            if (refaddr $blocker == refaddr $item) {
                $blocker = undef;
                TAEB->log->ai("It seems we aren't wearing $item after all, ".
                              "even though framework thought we were...",
                              level => 'error');
            }
        }
        if ($blocker && $blocker->type eq 'weapon') {
            $self->unwielding(1);
            return TAEB::Action->new_action('wield', weapon => 'nothing');
        }
        $self->unwielding(0);
        $self->taking_off($blocker);
        return TAEB::Action->new_action('remove',  item => $blocker)
            if $blocker;
        return TAEB::Action->new_action('wear',    item => $item);
    }
}

# The desire of equipping an item
sub gain_resource_conversion_desire {
    my $self = shift;
    my $ai   = TAEB->ai;
    my $item = $self->item;
    # Bump our own desirability.
    return unless $item->type eq 'weapon'
               || $item->type eq 'armor';
    return if $item->is_wielded;
    return if $item->can('is_worn') && $item->is_worn;
    my $benefit = $ai->use_benefit($item);
    $ai->add_capped_desire($self, $benefit);
}

sub calculate_extra_risk {
    my $self = shift;
    # TODO: More than this if we have to swap stuff out
    return $self->aim_tile_turns(1);
}

sub reach_action_succeeded {
    my $self = shift;
    my $item = $self->item;
    my $blocker = $self->taking_off;
    if ($self->unwielding) {
        return 0 if TAEB->inventory->equipment->weapon;
        return;
    }
    if ($blocker) {
        return 0 if $blocker->is_worn;
        return;
    }
    return 1 if $item->is_wielded || ($item->can('is_worn') && $item->is_worn);    
}

sub spread_desirability {
    my $self = shift;
    my $item = $self->item;
    $self->depends(1,'BCU',$item);
}

# This plan needs a continuous stream of validity from our inventory,
# or it ceases to exist.
sub invalidate {shift->validity(0);}

use constant description => 'Equipping a new item';
use constant references => ['BCU'];
# We don't want Equip plans to interrupt each other, as intermediate states
# can have their values out of line.  This is probably more correct than
# fudging the values of the intermediate states.
use constant uninterruptible_by => ['Equip'];

__PACKAGE__->meta->make_immutable;
no Moose;

1;
