class_name OneOnOneResolver
extends RefCounted
## Judges a one-on-one. The attacker runs at goal while the keeper rushes out;
## the player picks an action and *when* to do it (seconds since the run began).
##   SHOOT: aim at the goal. The closer the keeper, the more goal they cover.
##   CHIP:  works once the keeper is far enough off their line.
##   ROUND: works only inside a timing window; dribbling widens it.
## Doing nothing until the gap closes means the keeper smothers the ball.

const SHOOT := "shoot"
const CHIP := "chip"
const ROUND := "round"
const NONE := "none"


## Metres between attacker and goal line after `time` seconds.
static func attacker_distance(spec: MomentSpec, time: float, tuning: MomentTuning) -> float:
	var speed := tuning.by_skill("one_on_one", "min_run_speed", "max_run_speed", spec.skill("pace"))
	return tuning.value("one_on_one", "start_distance") - speed * maxf(time, 0.0)


## Metres the keeper has come off their line after `time` seconds.
static func keeper_out(time: float, tuning: MomentTuning) -> float:
	var out := tuning.value("one_on_one", "keeper_speed") * maxf(time, 0.0)
	return minf(out, tuning.value("one_on_one", "keeper_max_out"))


static func gap(spec: MomentSpec, time: float, tuning: MomentTuning) -> float:
	return attacker_distance(spec, time, tuning) - keeper_out(time, tuning)


## The last moment an action still counts (gap down to smother_gap), in seconds
## since the run began. The keeper stops advancing at keeper_max_out.
static func time_limit(spec: MomentSpec, tuning: MomentTuning) -> float:
	var run := tuning.by_skill("one_on_one", "min_run_speed", "max_run_speed", spec.skill("pace"))
	var keeper_speed := tuning.value("one_on_one", "keeper_speed")
	var max_out := tuning.value("one_on_one", "keeper_max_out")
	var closing := (
		tuning.value("one_on_one", "start_distance") - tuning.value("one_on_one", "smother_gap")
	)
	var while_rushing := closing / (run + keeper_speed)
	if while_rushing <= max_out / keeper_speed:
		return while_rushing
	return (closing - max_out) / run


static func resolve(
	spec: MomentSpec, action: String, time: float, aim: Vector2, tuning: MomentTuning
) -> MomentResult:
	var keeper_point := Vector2(0.0, tuning.value("one_on_one", "keeper_center_height"))
	var current_gap := gap(spec, time, tuning)
	if action == NONE or current_gap <= tuning.value("one_on_one", "smother_gap"):
		return MomentResult.create(spec, MomentResult.SAVED, 0.0, keeper_point, keeper_point)
	match action:
		SHOOT:
			return _shoot(spec, time, aim, tuning)
		CHIP:
			return _chip(spec, time, tuning)
		ROUND:
			return _round(spec, current_gap, tuning)
	return MomentResult.create(spec, MomentResult.SAVED, 0.0, keeper_point, keeper_point)


## Goal-plane radius the keeper covers when the shot is taken at `time`.
static func keeper_coverage(spec: MomentSpec, time: float, tuning: MomentTuning) -> float:
	var distance := attacker_distance(spec, time, tuning)
	# The keeper's body hides more of the goal the closer they are to the shooter.
	var projection := distance / maxf(gap(spec, time, tuning), 0.01)
	var finesse := 1.0 - spec.skill("shooting") * tuning.value("one_on_one", "finesse_reduction")
	var body := tuning.value("one_on_one", "keeper_projected_size") * projection * finesse
	var flight_time := distance / tuning.value("one_on_one", "shot_speed")
	var reaction := tuning.value("keeper", "reaction_delay")
	var dive := ShotModel.keeper_reach(flight_time, reaction, spec.opponent_skill, tuning)
	return body + dive - tuning.value("keeper", "body_radius")


static func _shoot(
	spec: MomentSpec, time: float, aim: Vector2, tuning: MomentTuning
) -> MomentResult:
	var keeper_point := Vector2(0.0, tuning.value("one_on_one", "keeper_center_height"))
	var target := ShotModel.apply_aim_assist(aim, spec.skill("shooting"), tuning)
	target = ShotModel.keep_above_ground(target, tuning)
	if not ShotModel.in_goal(target, tuning):
		return MomentResult.create(spec, MomentResult.MISSED, 0.0, target, keeper_point)
	var coverage := keeper_coverage(spec, time, tuning)
	var distance := keeper_point.distance_to(target)
	if distance <= coverage:
		return MomentResult.create(spec, MomentResult.SAVED, 0.0, target, target)
	var quality := ShotModel.clearance_quality(distance, coverage, tuning)
	var keeper_end := keeper_point + (target - keeper_point).limit_length(coverage)
	return MomentResult.create(spec, MomentResult.GOAL, quality, target, keeper_end)


static func _chip(spec: MomentSpec, time: float, tuning: MomentTuning) -> MomentResult:
	var out := keeper_out(time, tuning)
	var needed := (
		tuning.value("one_on_one", "chip_min_keeper_out")
		- spec.skill("shooting") * tuning.value("one_on_one", "chip_skill_bonus")
	)
	var target := Vector2(0.0, tuning.value("goal", "height") * 0.6)
	var keeper_point := Vector2(0.0, tuning.value("one_on_one", "keeper_center_height"))
	var enough_gap := gap(spec, time, tuning) >= tuning.value("one_on_one", "chip_min_gap")
	if out < needed or not enough_gap:
		return MomentResult.create(spec, MomentResult.SAVED, 0.0, keeper_point, keeper_point)
	var quality := clampf((out - needed) / tuning.value("quality", "span"), 0.0, 1.0)
	return MomentResult.create(spec, MomentResult.GOAL, quality, target, keeper_point)


static func _round(spec: MomentSpec, current_gap: float, tuning: MomentTuning) -> MomentResult:
	var window_start := tuning.value("one_on_one", "round_min_gap")
	var window := (
		tuning.value("one_on_one", "round_window")
		+ spec.skill("dribbling") * tuning.value("one_on_one", "round_skill_bonus")
	)
	var keeper_point := Vector2(0.0, tuning.value("one_on_one", "keeper_center_height"))
	if current_gap < window_start or current_gap > window_start + window:
		return MomentResult.create(spec, MomentResult.SAVED, 0.0, keeper_point, keeper_point)
	# Best right in the middle of the window.
	var centre := window_start + window / 2.0
	var quality := 1.0 - absf(current_gap - centre) / (window / 2.0)
	var empty_net := Vector2(0.0, tuning.value("goal", "ball_radius"))
	return MomentResult.create(spec, MomentResult.GOAL, quality, empty_net, keeper_point)
