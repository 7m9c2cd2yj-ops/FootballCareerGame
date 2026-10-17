class_name SaveResolver
extends RefCounted
## Judges a save. The opponent's shot (spec.shot_target, spec.shot_speed) is
## known in advance only to the game; the player sees the ball fly and swipes
## to dive. `reaction_time` is seconds from the shot until the swipe.
## Goalkeeping skill gives a faster dive and a bigger catch radius.


## Seconds until the ball reaches the goal line.
static func flight_time(spec: MomentSpec) -> float:
	return spec.distance / spec.shot_speed


## `has_dive` false means the player never reacted: the keeper stays put.
static func resolve(
	spec: MomentSpec,
	has_dive: bool,
	dive_target: Vector2,
	reaction_time: float,
	tuning: MomentTuning
) -> MomentResult:
	var skill := spec.skill("goalkeeping")
	var start := Vector2(0.0, tuning.value("keeper", "start_height"))
	var keeper_end := start
	if has_dive:
		var dive_speed := tuning.by_skill("save", "min_dive_speed", "max_dive_speed", skill)
		var travel := maxf(0.0, flight_time(spec) - maxf(reaction_time, 0.0)) * dive_speed
		keeper_end = start + (dive_target - start).limit_length(travel)
	var catch_radius := tuning.by_skill("save", "catch_radius_min", "catch_radius_max", skill)
	var miss_by := keeper_end.distance_to(spec.shot_target)
	if miss_by <= catch_radius:
		var quality := 1.0 - miss_by / catch_radius
		return MomentResult.create(spec, MomentResult.SAVED, quality, spec.shot_target, keeper_end)
	return MomentResult.create(spec, MomentResult.CONCEDED, 0.0, spec.shot_target, keeper_end)
