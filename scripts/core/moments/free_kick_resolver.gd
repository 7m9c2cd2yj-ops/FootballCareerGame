class_name FreeKickResolver
extends RefCounted
## Judges a free kick from aim, curl (-1..1) and power (0..1).
## The ball must get past the wall (over it with a soft, lofted shot, or round
## it with curl) and then beat the keeper, who reacts late behind the wall.
## Curl reach grows with the passing skill; accuracy comes from shooting.


static func resolve(
	spec: MomentSpec, aim: Vector2, curl: float, power: float, tuning: MomentTuning
) -> MomentResult:
	var target := PenaltyResolver.aimed_target(aim, power, spec.skill("shooting"), tuning)
	var keeper_start := Vector2(spec.keeper_x, tuning.value("keeper", "start_height"))
	if not ShotModel.in_goal(target, tuning):
		return MomentResult.create(spec, MomentResult.MISSED, 0.0, target, keeper_start)
	var at_wall := point_at_wall(spec, target, curl, power, tuning)
	if is_blocked(spec, at_wall, tuning):
		return MomentResult.create(spec, MomentResult.BLOCKED, 0.0, at_wall, keeper_start)
	var flight_time := spec.distance / ShotModel.speed(power, tuning)
	var reaction := tuning.value("free_kick", "reaction_delay")
	var reach := ShotModel.keeper_reach(flight_time, reaction, spec.opponent_skill, tuning)
	return PenaltyResolver.judge_against_keeper(spec, target, keeper_start, reach, tuning)


## Where the ball passes the wall: part of the way to the target, bent by curl
## and lifted by loft (softer shots loop higher).
static func point_at_wall(
	spec: MomentSpec, target: Vector2, curl: float, power: float, tuning: MomentTuning
) -> Vector2:
	var fraction := tuning.value("free_kick", "wall_distance") / spec.distance
	var bend := tuning.value("free_kick", "curl_bend") * (0.5 + 0.5 * spec.skill("passing"))
	var loft := (1.0 - power) * tuning.value("free_kick", "loft_per_softness")
	return Vector2(target.x * fraction + clampf(curl, -1.0, 1.0) * bend, target.y * fraction + loft)


static func is_blocked(spec: MomentSpec, at_wall: Vector2, tuning: MomentTuning) -> bool:
	var half_width := tuning.value("free_kick", "wall_width") / 2.0
	var beside_wall := absf(at_wall.x - spec.wall_center_x) > half_width
	return not beside_wall and at_wall.y < tuning.value("free_kick", "wall_height")
