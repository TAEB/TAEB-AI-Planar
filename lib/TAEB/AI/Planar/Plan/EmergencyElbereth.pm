#!/usr/bin/env perl
package TAEB::AI::Planar::Plan::EmergencyElbereth;
use TAEB::OO;
use TAEB::Util qw/delta2vi/;
extends 'TAEB::AI::Planar::Plan::Strategic';

sub aim_tile {
    my $self = shift;
    return undef unless TAEB->can_engrave;
    return TAEB->current_tile;
}

sub has_reach_action { 1 }
sub reach_action {
    my $self = shift;
    return TAEB::Action->new_action('engrave', best => 1);
}

# No aim_tile_turns! This only happens in an emergency, so we want to
# completely ignore threats.
sub calculate_extra_risk {
    my $self = shift;
    return $self->cost("Time",1);
}

sub reach_action_succeeded {
    # Reinstate all plans. This is because they'll have been abandoned
    # in order to do the emergency Elberething.
    my $self = shift;
    my $ai = TAEB->ai;
    $ai->tactical_success_count($ai->tactical_success_count + 10000);
    $ai->strategic_success_count($ai->strategic_success_count + 10000);
    return 1; # if we're still alive, it worked
}

use constant description => "Elberething in the hope we don't die";

__PACKAGE__->meta->make_immutable;
no Moose;

1;