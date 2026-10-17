class_name CareerRules
extends RefCounted
## Typed, validated view of data/career_rules.json. Numbers are read with
## `value(section, key)`; sections and keys are listed in SCHEMA.

const DEFAULT_PATH := "res://data/career_rules.json"
const STARTER := "starter"
const ROTATION := "rotation"
const BENCH := "bench"
const ROLES: Array[String] = [STARTER, ROTATION, BENCH]
const BUDGET_KEYS: Array[String] = ["wage_base", "youth_wage", "transfer_budget"]
const SCHEMA: Dictionary = {
	"trial": ["bonus_per_key_moment_won"],
	"needs": ["open_share"],
	"roles": ["starter_margin", "rotation_margin"],
	"contract":
	["wage_per_point_above_need", "release_clause_multiplier", "youth_years", "renewal_margin"],
	"fatigue":
	[
		"carryover",
		"match_load_at_full_share",
		"age_load_from",
		"age_load_per_year",
		"injury_threshold",
		"after_injury",
		"missed_match_share",
	],
	"retirement": ["min_age"],
	"hall_of_fame":
	[
		"min_peak_overall",
		"induction_score",
		"points_per_peak_overall",
		"points_per_top_tier_season",
		"points_per_key_moment_won",
		"points_per_trophy",
		"points_per_golden_ball",
	],
}

var academy_club: String = ""
var fallback_club: String = ""
var trial_age: int = 0
var senior_age: int = 0
var _values: Dictionary[String, Dictionary] = {}
var _match_share: Dictionary[String, float] = {}
var _intensity_load: Dictionary[String, float] = {}
var _budgets: Dictionary[String, Dictionary] = {}
var _contract_years: AgeTable = null


## `world` is used to check that the academy and fallback clubs exist.
static func load_file(
	path: String, world: ClubWorld, max_age: int, errors: Array[String]
) -> CareerRules:
	var loaded := JsonLoader.load_dictionary(path)
	if not loaded.is_ok():
		errors.append(loaded.error)
		return null
	var problems := validate(loaded.data, world, max_age)
	if not problems.is_empty():
		for problem: String in problems:
			errors.append("%s: %s" % [path, problem])
		return null
	return from_dictionary(loaded.data)


static func validate(data: Dictionary, world: ClubWorld, max_age: int) -> Array[String]:
	var problems: Array[String] = []
	DataChecks.require_number_sections(data, SCHEMA, problems)
	for key: String in ["trial_age", "senior_age"]:
		DataChecks.require_number(data, key, "", problems)
	for key: String in ["academy_club", "fallback_club"]:
		if typeof(data.get(key)) != TYPE_STRING or not world.has_club(str(data.get(key))):
			problems.append("%s must name a club in clubs.json" % key)
	if not problems.is_empty():
		return problems
	var roles: Dictionary = data["roles"]
	var fatigue: Dictionary = data["fatigue"]
	_validate_named_numbers(roles.get("match_share"), "roles.match_share", ROLES, problems)
	var loads: Variant = fatigue.get("intensity_load")
	_validate_named_numbers(loads, "fatigue.intensity_load", TrainingPlan.INTENSITIES, problems)
	_validate_budgets(data.get("budgets"), world, problems)
	AgeTable.validate(data, "contract_years", "value", int(data["trial_age"]), max_age, problems)
	return problems


static func from_dictionary(data: Dictionary) -> CareerRules:
	var rules := CareerRules.new()
	rules.academy_club = data["academy_club"]
	rules.fallback_club = data["fallback_club"]
	rules.trial_age = int(data["trial_age"])
	rules.senior_age = int(data["senior_age"])
	for section: String in SCHEMA:
		var values: Dictionary[String, float] = {}
		for key: String in SCHEMA[section]:
			values[key] = float(data[section][key])
		rules._values[section] = values
	rules._match_share.assign(data["roles"]["match_share"])
	rules._intensity_load.assign(data["fatigue"]["intensity_load"])
	for budget: String in data["budgets"]:
		rules._budgets[budget] = data["budgets"][budget]
	rules._contract_years = AgeTable.from_rows(data["contract_years"], "value")
	return rules


func value(section: String, key: String) -> float:
	return _values[section][key]


func match_share(role: String) -> float:
	return _match_share[role]


func intensity_load(intensity: String) -> float:
	return _intensity_load[intensity]


func budget_value(budget: String, key: String) -> float:
	return float(_budgets[budget][key])


func contract_years(age: int) -> int:
	return int(_contract_years.value_at(age))


static func _validate_named_numbers(
	table: Variant, label: String, names: Array[String], problems: Array[String]
) -> void:
	if typeof(table) != TYPE_DICTIONARY:
		problems.append("%s must be an object" % label)
		return
	var values: Dictionary = table
	for key: String in names:
		DataChecks.require_number(values, key, label + ".", problems)


static func _validate_budgets(budgets: Variant, world: ClubWorld, problems: Array[String]) -> void:
	if typeof(budgets) != TYPE_DICTIONARY:
		problems.append("budgets must be an object")
		return
	var tiers: Dictionary = budgets
	for budget: String in tiers:
		_validate_named_numbers(tiers[budget], "budgets." + budget, BUDGET_KEYS, problems)
	for club: Club in world.clubs:
		if not tiers.has(club.budget):
			problems.append("club %s uses unknown budget '%s'" % [club.id, club.budget])
