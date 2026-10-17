class_name MomentPlanner
extends RefCounted
## Builds the list of key moments for a season. Fully deterministic: the moment
## types cycle through the position's schedule, and staging details (free-kick
## spot, where an opponent shoots) come from Variety, keyed on season and index.

const VARIETY_DISTANCE := 1
const VARIETY_WALL := 2
const VARIETY_TARGET_X := 3
const VARIETY_TARGET_Y := 4


static func moment_count(player: PlayerModel, tuning: MomentTuning) -> int:
	if player.age <= int(tuning.value("schedule", "academy_until_age")):
		return int(tuning.value("schedule", "academy_moments"))
	return int(tuning.value("schedule", "senior_moments"))


static func plan_season(
	player: PlayerModel,
	season_number: int,
	competition_strength: float,
	balance: Balance,
	tuning: MomentTuning
) -> Array[MomentSpec]:
	var schedule := tuning.schedule_for(player.position)
	var specs: Array[MomentSpec] = []
	for index: int in moment_count(player, tuning):
		var moment_type := schedule[(season_number - 1 + index) % schedule.size()]
		var spec := _spec_for(player, moment_type, index, competition_strength, balance)
		_stage(spec, season_number, tuning)
		specs.append(spec)
	return specs


## A single moment for the tutorial, staged like a first-season moment. The
## caller must not record its result.
static func practice(
	player: PlayerModel,
	moment_type: String,
	competition_strength: float,
	balance: Balance,
	tuning: MomentTuning
) -> MomentSpec:
	var spec := _spec_for(player, moment_type, 0, competition_strength, balance)
	_stage(spec, 1, tuning)
	return spec


static func _spec_for(
	player: PlayerModel, moment_type: String, index: int, strength: float, balance: Balance
) -> MomentSpec:
	var spec := MomentSpec.new()
	spec.moment_type = moment_type
	spec.index = index
	spec.opponent_skill = clampf(strength / balance.attribute_max, 0.0, 1.0)
	for attribute: String in PlayerModel.ATTRIBUTES:
		spec.skills[attribute] = player.attributes[attribute] / balance.attribute_max
	return spec


static func _stage(spec: MomentSpec, season: int, tuning: MomentTuning) -> void:
	match spec.moment_type:
		MomentSpec.PENALTY:
			spec.distance = tuning.value("penalty", "distance")
		MomentSpec.FREE_KICK:
			var spot := Variety.unit(season, spec.index, VARIETY_DISTANCE)
			spec.distance = tuning.by_skill("free_kick", "min_distance", "max_distance", spot)
			var side := Variety.unit(season, spec.index, VARIETY_WALL) * 2.0 - 1.0
			spec.wall_center_x = side * tuning.value("free_kick", "wall_max_offset")
			# The keeper covers the side the wall does not.
			spec.keeper_x = -spec.wall_center_x * tuning.value("free_kick", "keeper_shift")
		MomentSpec.ONE_ON_ONE:
			spec.distance = tuning.value("one_on_one", "start_distance")
		MomentSpec.SAVE:
			var spot := Variety.unit(season, spec.index, VARIETY_DISTANCE)
			spec.distance = tuning.by_skill(
				"save", "open_play_min_distance", "open_play_max_distance", spot
			)
			spec.shot_speed = tuning.value("save", "open_play_speed")
			spec.shot_target = _opponent_target(season, spec.index, tuning)
		MomentSpec.PENALTY_SAVE:
			spec.distance = tuning.value("penalty", "distance")
			spec.shot_speed = tuning.value("save", "penalty_speed")
			spec.shot_target = _opponent_target(season, spec.index, tuning)


## Somewhere inside the frame, kept `target_edge_margin` away from posts and bar.
static func _opponent_target(season: int, index: int, tuning: MomentTuning) -> Vector2:
	var margin := tuning.value("save", "target_edge_margin")
	var half_width := tuning.value("goal", "half_width") - margin
	var low := tuning.value("goal", "ball_radius")
	var high := tuning.value("goal", "height") - margin
	var x := lerpf(-half_width, half_width, Variety.unit(season, index, VARIETY_TARGET_X))
	var y := lerpf(low, high, Variety.unit(season, index, VARIETY_TARGET_Y))
	return Vector2(x, y)
