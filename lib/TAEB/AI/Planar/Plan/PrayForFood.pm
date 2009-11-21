#!/usr/bin/env perl
package TAEB::AI::Planar::Plan::PrayForFood;
use TAEB::OO;
use TAEB::Util qw/delta2vi/;
extends 'TAEB::AI::Planar::Plan::Strategic';

# As long as prayer is safe, this isn't risky at all. Not even tile risk,
# because you're invulnerable whilst praying.
sub calculate_extra_risk {
    # Put the cost of the prayer here?
    return 0;
}

# We get set to 900 nutrition if we do this.
sub gain_resource_conversion_desire {
    my $self = shift;
    my $gain = 900 - TAEB->nutrition;
    my $ai   = TAEB->ai;
    $ai->add_capped_desire($self, $ai->resources->{'Nutrition'}->value * $gain);
}

# This is only set if we can pray for food right now.
sub aim_tile {
    my $self = shift;
    return undef unless TAEB::Action::Pray->is_advisable;
    return undef unless TAEB->nutrition <= 49;
    return TAEB->current_tile;
}

sub has_reach_action { 1 }
sub reach_action {
    my $self = shift;
    return TAEB::Action->new_action('pray');
}

use constant description => 'Praying for food';

__PACKAGE__->meta->make_immutable;
no Moose;

1;
