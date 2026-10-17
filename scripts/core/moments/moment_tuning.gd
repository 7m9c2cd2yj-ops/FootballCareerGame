class_name MomentTuning
extends RefCounted
## Typed, validated view of data/moment_tuning.json. Numbers are read with
## `value(section, key)`; SCHEMA lists every key that must exist.

const DEFAULT_PATH := "res://data/moment_tuning.json"
const SCHEMA: Dictionary = {
	"goal": ["half_width", "height", "ball_radius"],
	"power": ["sweet_min", "sweet_max", "min_speed", "max_speed"],
	"power_bar": ["period_at_min_skill", "period_at_max_skill"],
	"overhit": ["lift_per_power", "wide_per_power", "skill_reduction"],
	"aim_assist": ["max_distance"],
	"keeper": ["body_radius", "start_height", "reaction_delay", "min_dive_speed", "max_dive_speed"],
	"quality": ["span"],
	"penalty": ["distance"],
	"free_kick":
	[
		"min_distance",
		"max_distance",
		"wall_distance",
		"wall_height",
		"wall_width",
		"wall_max_offset",
		"keeper_shift",
		"loft_per_softness",
		"curl_bend",
		"reaction_delay",
	],
	"one_on_one":
	[
		"start_distance",
		"min_run_speed",
		"max_run_speed",
		"keeper_speed",
		"keeper_max_out",
		"smother_gap",
		"keeper_projected_size",
		"keeper_center_height",
		"finesse_reduction",
		"shot_speed",
		"chip_min_keeper_out",
		"chip_skill_bonus",
		"chip_min_gap",
		"round_min_gap",
		"round_window",
		"round_skill_bonus",
	],
	"save":
	[
		"open_play_min_distance",
		"open_play_max_distance",
		"open_play_speed",
		"penalty_speed",
		"target_edge_margin",
		"min_dive_speed",
		"max_dive_speed",
		"catch_radius_min",
		"catch_radius_max",
	],
	"rating": ["success_min", "success_max", "failure", "weight"],
	"schedule": ["academy_until_age", "academy_moments", "senior_moments"],
}

var _values: Dictionary[String, Dictionary] = {}
## Position -> ordered list of moment types, cycled through season by season.
var _schedule: Dictionary[String, Array] = {}


## Loads and validates `path`. Returns null and appends to `errors` on failure.
static func load_file(path: String, errors: Array[String]) -> MomentTuning:
	var loaded := JsonLoader.load_dictionary(path)
	if not loaded.is_ok():
		errors.append(loaded.error)
		return null
	var problems := validate(loaded.data)
	if not problems.is_empty():
		for problem: String in problems:
			errors.append("%s: %s" % [path, problem])
		return null
	return from_dictionary(loaded.data)


static func validate(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	DataChecks.require_number_sections(data, SCHEMA, problems)
	if not problems.is_empty():
		return problems
	if float(data["power"]["sweet_min"]) >= float(data["power"]["sweet_max"]):
		problems.append("power.sweet_min must be lower than power.sweet_max")
	if float(data["power_bar"]["period_at_min_skill"]) <= 0.0:
		problems.append("power_bar periods must be positive")
	if float(data["free_kick"]["min_distance"]) <= float(data["free_kick"]["wall_distance"]):
		problems.append("free_kick.min_distance must be beyond the wall")
	_validate_schedule(data["schedule"], problems)
	return problems


static func from_dictionary(data: Dictionary) -> MomentTuning:
	var tuning := MomentTuning.new()
	for section: String in SCHEMA:
		var values: Dictionary[String, float] = {}
		for key: String in SCHEMA[section]:
			values[key] = float(data[section][key])
		tuning._values[section] = values
	var by_position: Dictionary = data["schedule"]["by_position"]
	for position: String in by_position:
		var types: Array[String] = []
		types.assign(by_position[position])
		tuning._schedule[position] = types
	return tuning


func value(section: String, key: String) -> float:
	return _values[section][key]


## `low + (high - low) * skill`, reading `low_key`/`high_key` from `section`.
func by_skill(section: String, low_key: String, high_key: String, skill: float) -> float:
	return lerpf(value(section, low_key), value(section, high_key), clampf(skill, 0.0, 1.0))


func has_schedule(position: String) -> bool:
	return _schedule.has(position)


func schedule_for(position: String) -> Array[String]:
	var types: Array[String] = []
	types.assign(_schedule[position])
	return types


static func _validate_schedule(schedule: Dictionary, problems: Array[String]) -> void:
	if typeof(schedule.get("by_position")) != TYPE_DICTIONARY:
		problems.append("schedule.by_position must be an object")
		return
	var by_position: Dictionary = schedule["by_position"]
	for position: String in by_position:
		if typeof(by_position[position]) != TYPE_ARRAY:
			problems.append("schedule.by_position.%s must be an array" % position)
			continue
		var types: Array = by_position[position]
		if types.is_empty():
			problems.append("schedule.by_position.%s must not be empty" % position)
		for moment_type: Variant in types:
			if not MomentSpec.TYPES.has(moment_type):
				problems.append(
					"schedule.by_position.%s has unknown type %s" % [position, moment_type]
				)
