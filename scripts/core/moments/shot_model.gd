class_name ShotModel
extends RefCounted
## Geometry shared by the shooting moments. All points are on the goal plane:
## x = metres from the goal centre, y = height in metres.


static func in_goal(point: Vector2, tuning: MomentTuning) -> bool:
	var radius := tuning.value("goal", "ball_radius")
	var half_width := tuning.value("goal", "half_width") - radius
	return absf(point.x) <= half_width and point.y <= tuning.value("goal", "height") - radius


## Ball speed for a power value 0..1.
static func speed(power: float, tuning: MomentTuning) -> float:
	return tuning.by_skill("power", "min_speed", "max_speed", power)


## How far the keeper can stretch from their start point before the ball arrives.
static func keeper_reach(
	flight_time: float, reaction_delay: float, opponent_skill: float, tuning: MomentTuning
) -> float:
	var dive_speed := tuning.by_skill("keeper", "min_dive_speed", "max_dive_speed", opponent_skill)
	var dive := maxf(0.0, flight_time - reaction_delay) * dive_speed
	return tuning.value("keeper", "body_radius") + dive


## Overhitting (power above the sweet spot) lifts the ball and pushes it away
## from the centre; better shooters lose less accuracy.
static func apply_overhit(
	aim: Vector2, power: float, skill: float, tuning: MomentTuning
) -> Vector2:
	var excess := maxf(0.0, power - tuning.value("power", "sweet_max"))
	var control := 1.0 - skill * tuning.value("overhit", "skill_reduction")
	var lift := excess * tuning.value("overhit", "lift_per_power") * control
	var wide := excess * tuning.value("overhit", "wide_per_power") * control
	return Vector2(aim.x + signf(aim.x) * wide, aim.y + lift)


## Rating-based aim assist: a shot just outside the frame is pulled back
## inside if it is within `skill * max_distance` of the goal.
static func apply_aim_assist(target: Vector2, skill: float, tuning: MomentTuning) -> Vector2:
	var radius := tuning.value("goal", "ball_radius")
	var limit := Vector2(
		tuning.value("goal", "half_width") - radius, tuning.value("goal", "height") - radius
	)
	var inside := Vector2(clampf(target.x, -limit.x, limit.x), clampf(target.y, radius, limit.y))
	var assist := skill * tuning.value("aim_assist", "max_distance")
	return inside if target.distance_to(inside) <= assist else target


## Shots aimed into the ground roll along it.
static func keep_above_ground(target: Vector2, tuning: MomentTuning) -> Vector2:
	return Vector2(target.x, maxf(target.y, tuning.value("goal", "ball_radius")))


## 0 when the ball is just beyond the keeper's reach, 1 when well clear.
static func clearance_quality(
	distance_from_keeper: float, reach: float, tuning: MomentTuning
) -> float:
	return clampf((distance_from_keeper - reach) / tuning.value("quality", "span"), 0.0, 1.0)


## Where a keeper who could not reach `target` ends up: stretched towards it.
static func keeper_stretch(
	start: Vector2, target: Vector2, reach: float, tuning: MomentTuning
) -> Vector2:
	var stretch := maxf(0.0, reach - tuning.value("keeper", "body_radius"))
	return start + (target - start).limit_length(stretch)
