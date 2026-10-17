class_name PenaltyResolver
extends RefCounted
## Judges a penalty from the player's aim (goal-plane point) and power (0..1).
## The keeper reaches a radius that grows with the ball's flight time, so
## corners beat them and soft or central shots are saved.


static func resolve(
	spec: MomentSpec, aim: Vector2, power: float, tuning: MomentTuning
) -> MomentResult:
	var target := aimed_target(aim, power, spec.skill("shooting"), tuning)
	var keeper_start := Vector2(0.0, tuning.value("keeper", "start_height"))
	if not ShotModel.in_goal(target, tuning):
		return MomentResult.create(spec, MomentResult.MISSED, 0.0, target, keeper_start)
	var flight_time := spec.distance / ShotModel.speed(power, tuning)
	var reaction := tuning.value("keeper", "reaction_delay")
	var reach := ShotModel.keeper_reach(flight_time, reaction, spec.opponent_skill, tuning)
	return judge_against_keeper(spec, target, keeper_start, reach, tuning)


## Where the ball actually goes after overhit and aim assist.
static func aimed_target(aim: Vector2, power: float, skill: float, tuning: MomentTuning) -> Vector2:
	var target := ShotModel.apply_overhit(aim, power, skill, tuning)
	target = ShotModel.apply_aim_assist(target, skill, tuning)
	return ShotModel.keep_above_ground(target, tuning)


## Saved if the target is within the keeper's reach, otherwise a goal.
static func judge_against_keeper(
	spec: MomentSpec, target: Vector2, keeper_start: Vector2, reach: float, tuning: MomentTuning
) -> MomentResult:
	var distance := keeper_start.distance_to(target)
	if distance <= reach:
		return MomentResult.create(spec, MomentResult.SAVED, 0.0, target, target)
	var keeper_end := ShotModel.keeper_stretch(keeper_start, target, reach, tuning)
	var quality := ShotModel.clearance_quality(distance, reach, tuning)
	return MomentResult.create(spec, MomentResult.GOAL, quality, target, keeper_end)
