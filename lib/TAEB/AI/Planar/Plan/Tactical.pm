#!/usr/bin/env perl
package TAEB::AI::Planar::Plan::Tactical;
use TAEB::OO;
use TAEB::AI::Planar::TacticsMapEntry;
use TAEB::Util qw/delta2vi/;
extends 'TAEB::AI::Planar::Plan';

# Tactical plans. These are similar to strategic plans, but plan
# movement from one tile to the next, rather than the much broader
# scope of strategic plans. Generally speaking, most of the time we
# have a strategic plan (where to go and what to do), and a tactical
# plan (how to get there); the action from the tactical plan is used
# if there is one (unless it's the no-op plan Nop). Instead of being
# based on desirability, tactical plans create tactics map entries;
# most of them will need a tactics map entry to do calculations (apart
# from Nop), which is the tactics needed to reach the square they're
# on. This differs from an argument (which some plans have as well);
# for instance, Walk needs the tile it's pathing to as well as the
# TME. The arguments are sent in the form [level, x, y] (with possibly
# others); the idea is that the arguments should be the same if the
# plan is the same in essence. (This is why the location of the TME is
# sent, not the TME itself; the TMEs will change every step, but that
# doesn't change the essence of what the plan is.) However; the TME
# location is only used to see if two plans are the same; the TME
# itself isn't stored on the plan for efficiency reasons, but instead
# passed round from procedure to procedure as an argument.

# Nearly all tactical plans want this. The one that doesn't can
# override it to an error. A typical argument list for a tactical plan
# looks like [level, x, y], or often [level, x, y, tileto] for plans
# like Walk which are coming from somewhere and going to somewhere.
# The level, x, and y are stored as a TME, but not passed that way.
sub set_arg {
    my $self = shift;
    my @args = @{(shift)};
    splice @args, 0, 3;
    $self->set_additional_args(@args);
}
# However, many tactical plans don't need this one; the ones that
# do can override it.
sub set_additional_args {
    die "Unexpected additional argument" unless @_ == 1; # 1 for ourself
}

# Get the tile corresponding to the passed-in TME.
sub tme_tile {
    my $self = shift;
    my $tme  = shift;
    return $tme->{'tile_level'}->at($tme->{'tile_x'},$tme->{'tile_y'});
}

# Things that should never be called on a tactical plan.
sub spread_desirability { die "Tactical plans cannot spread desirability"; }
sub gain_resource_conversion_desire { die "Tactical plans cannot gain desire"; }
sub planspawn { die "Tactical plan is trying to spawn strategic plans"; }

# Impossibility for tactical plans is based on the tactical success count.
sub appropriate_success_count {
    return TAEB->personality->tactical_success_count;
}

# The main entry point for tactical planning. This causes the plan to
# either call add_possible_move to add a possible move from where it
# is at the moment, or to call check_possibility on other plans if
# this is a metaplan (as opposed to spawning via planspawn).
sub check_possibility {
    my $self = shift;
    return if $self->difficulty > 0;
    # Do the plan-specific possibility checks.
    $self->check_possibility_inner(shift);
}
sub check_possibility_inner {
    die "All tactical plans must override check_possibility_inner";
}
# A helper function for check_possibility; call check_possibility on
# another plan, with the same TME (which must be passed in as an
# argument).
sub generate_plan {
    my $self = shift;
    my $tme = shift;
    my $planname = shift;
    my @args = @_;
    my $ai = TAEB->personality;
    $ai->get_tactical_plan($planname, [$tme->{'tile_level'},
				       $tme->{'tile_x'},
				       $tme->{'tile_y'},
				       @args])->check_possibility($tme);
}

# add_possible_move on the plan fills in a tactical map entry, then
# calls add_possible_move on the AI. Nearly all TMEs get created via
# this function; however, as it requires an existing TME to get
# started, at least one is created a different way. This calls
# calculate_risk to get a spending plan, and uses that for risk
# calculations.
sub add_possible_move {
    my $self = shift;
    my $oldtme = shift;
    my $newx = shift;
    my $newy = shift;
    my $oldlevel = $oldtme->{'tile_level'};
    my $newlevel = shift || $oldlevel;
    my $ai = TAEB->personality;
    # We can save a lot of time by not bothering if there's already a
    # current TME for this square.
    my $currenttme = $ai->tactics_map->{$newlevel}->[$newx]->[$newy];
    return if defined $currenttme and $currenttme->{'step'} == $ai->aistep;
    $self->next_plan_calculation;
    $self->spending_plan({});
    $self->calculate_risk($oldtme);
    # Make a deep copy of the spending plan, and add the spending plan
    # so far to it.
    my %risk = %{$self->spending_plan};
    $risk{$_} += $oldtme->{'risk'}->{$_} for keys %{$oldtme->{'risk'}};

    # Note: 1-level calculations are done lazily, so aren't calculated
    # here. (They're only needed when changing level.)

    # Work out the added risk from threats, and the plans which will
    # eliminate or reduce it.
    my %msp = %{$oldtme->{'make_safer_plans'}};
    my $msp = \%msp;
    my $timetohere = $risk{"Time"} || 0;
    my $thme = $ai->threat_map->{$oldlevel}->[$newx]->[$newy];
    for my $p (keys %$thme) {
	# Not all possible values of $p are threats.
	defined($thme->{$p}) or next;
	# If the threat never gets here in time, ignore it.
	my ($turns, $reductionplan) = split / /, $p;
	$turns > $timetohere and next;
	# Add risk from the threat.
	my %threatrisk = %{$thme->{$p}};
	$risk{$_} += $threatrisk{$_} for keys %threatrisk;
	# Add the threat reduction plan.
	$msp->{$reductionplan} += $ai->resources->{$_}->cost($threatrisk{$_})
	    for keys %threatrisk;
    }

    # Create the new TME.
    my $tme = {
	prevtile_level   => $oldlevel,
	prevtile_x       => $oldtme->{'tile_x'},
	prevtile_y       => $oldtme->{'tile_y'},
	risk             => \%risk,
	tactic           => $self,
	physicalpath     => ($oldtme->{'physicalpath'} .
			     $self->_extvidelta($newx, $newy, $newlevel,
			 		       $oldtme->{'tile_x'},
			 		       $oldtme->{'tile_y'},
			 		       $oldtme->{'tile_level'})),
	tile_x           => $newx,
	tile_y           => $newy,
	tile_level       => $newlevel,
	step             => $ai->aistep,
        make_safer_plans => $msp,
    };
    bless $tme, "TAEB::AI::Planar::TacticsMapEntry";
    $ai->add_possible_move($tme);
}

sub _extvidelta {
    my $self  = shift;
    my $xto   = shift;
    my $yto   = shift;
    my $lto   = shift;
    my $xfrom = shift;
    my $yfrom = shift;
    my $lfrom = shift;
    if ($lfrom != $lto) {
	return '>'; # generic level-change, the direction doesn't matter
    }
    my $delta = delta2vi($xto-$xfrom,$yto-$yfrom);
    return $delta || '?';
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;