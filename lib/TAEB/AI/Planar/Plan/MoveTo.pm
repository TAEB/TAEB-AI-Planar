#!/usr/bin/env perl
package TAEB::AI::Planar::Plan::MoveTo;
use TAEB::OO;
use TAEB::AI::Planar::TacticsMapEntry;
extends 'TAEB::AI::Planar::Plan::Tactical';

# A metaplan. This one encompasses all methods of moving from a
# particular TME to a particular tile; it works by looking at the tile
# that's being moved to, then spawning an appropriate plan (or
# appropriate plans) to move there (such as OpenDoor+KickDownDoor, or
# Walk). This only allows for movement from adjacent tiles; it
# shouldn't be generated with a TME that isn't adjacent to the target
# tile.

has tile => (
    isa => 'Maybe[TAEB::World::Tile]',
    default => undef,
);
sub set_additional_args {
    my $self = shift;
    $self->tile(shift);
}

sub check_possibility_inner {
    my $self = shift;
    my $tme  = shift;
    my $tile = $self->tile;
    my $x    = $tile->x;
    my $y    = $tile->y;
    my $l    = $tile->level;
    my $tmex = $tme->{'tile_x'};
    my $tmey = $tme->{'tile_y'};
    my $tmel = $tme->{'tile_level'};
    my $ai   = TAEB->personality;
    my $aistep = $ai->aistep;
    # Bail as fast as we can if a faster way to move to this tile has
    # already been locked into the tactical map, to save needless
    # computation.
    my $currenttme = $ai->tactics_map->{$l}->[$x]->[$y];
    return if defined $currenttme && $currenttme->{'step'} == $aistep;
    my $type = $tile->type;

    # Things which might care about which direction we approach the tile from.

    if($type eq 'closeddoor') {
	# Open the door, or kick it down.
	$self->generate_plan($tme,"OpenDoor",$tile);
	$self->generate_plan($tme,"KickDownDoor",$tile);
    }

    if($type eq 'opendoor' && ($tmex == $x || $tmey == $y)) {
	# This is just a Walk, but the direction it comes from matters.
	$self->generate_plan($tme,"Walk",$tile);
    }

    # Boulders can sometimes be pushed. It depends on what's beyond them.
    # We try to push them if it's unexplored beyond them.
    # TODO: Also push boulders along corridors until they reach a junction
    # (where we can walk round them).
    if($tile->has_boulder && (!defined $l->branch || $l->branch ne 'sokoban')) {
	my $beyond = $l->at($x*2-$tmex,$y*2-$tmey);
	if($beyond->type eq 'unexplored') {
	    $self->generate_plan($tme,"PushBoulder",$tile);
	}
    }

    # For things that don't care about which direction we approach the tile
    # from, there's an optimisation trick; the first MoveTo aiming at that
    # tile in any given pathfind will necessarily be the one that returns
    # the most optimal value, so we may as well use it.
    # Note that this breaks if tiles have different costs to move /off/,
    # but that would break the AI anyway; instead, the cost of moving onto
    # a "sticky" tile should also include the cost to move back off it
    # again, which is slightly counterintuitive but helps centralise the
    # cost rather than spreading it all over the AI, requiring a lot of
    # special-casing.
    # The cache is placed on the AI, in the plan_caches hash. The plan
    # name is hardcoded here deliberately; if this is subclassed for
    # some reason, we still want MoveTo's cache itself if this
    # procedure is still being used.
    my $cache = $ai->plan_caches->{'MoveTo'};
    if(!defined $cache) {
	$cache = {};
	$ai->plan_caches->{'MoveTo'} = $cache;
    }
    my $levelcache = $cache->{$l};
    if(!defined $levelcache) {
	$levelcache = [];
	$levelcache->[$_] = [] for 0..79;
	$cache->{$l} = $levelcache;
    }
    return if ($levelcache->[$x]->[$y] // -1) == $aistep;
    $levelcache->[$x]->[$y] = $aistep;

    # We can just walk to passable tiles. There could be something blocking
    # them, but if so Walk should notice, and if it doesn't impossibility
    # tracking will. Obscured is on this list because it's worth a try, and
    # impossibility tracking will work out when it's impossible to route
    # there.
    if($type =~ /^(?:fountain|stairsup|stairsdown|ice|drawbridge|altar|
                     corridor|floor|grave|sink|throne|obscured)$/xo) {
	$self->generate_plan($tme,"Walk",$tile);
    }
    # Unexplored tiles can be searched to explore them, if moving next
    # to them doesn't explore them (e.g. when blind). We shouldn't do
    # this unless we've stepped onto the tile to search them from,
    # though, as it would be semantically wrong; generally speaking
    # tiles become explored when we walk next to them, and if tiles
    # are more than distance 1 away we don't yet know if they're
    # unexplored.
    if($type eq 'unexplored' && $tmel->at($tmex,$tmey)->stepped_on) {
	$self->generate_plan($tme,"LightTheWay",$tile);
    }

    # TODO: Need much more here
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;