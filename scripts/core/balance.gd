class_name Balance
extends RefCounted
## Typed, validated view of data/balance.json: every tunable progression number.
## Build it with `load_file` or `from_dictionary` after `validate`.

const DEFAULT_PATH := "res://data/balance.json"
const TRAINING_KEYS: Array[String] = [
	"primary_multiplier",
	"secondary_multiplier",
	"other_multiplier",
	"primary_decline_protection",
	"secondary_decline_protection",
]

var start_age: int = 0
var max_age: int = 0
var attribute_min: float = 0.0
var attribute_max: float = 0.0
## Position -> (attribute -> starting value).
var start_attributes: Dictionary[String, Dictionary] = {}
## Position -> (attribute -> weight in the overall rating).
var position_weights: Dictionary[String, Dictionary] = {}
## How strongly each attribute falls when the age curve is negative.
var decline_weights: Dictionary[String, float] = {}
## Keys listed in TRAINING_KEYS.
var training: Dictionary[String, float] = {}
var headroom_exponent: float = 1.0
var headroom_floor: float = 0.0
var performance_baseline: float = 0.0
var performance_gain_per_point: float = 0.0
var expected_neutral: float = 0.0
var expected_per_overall_point: float = 0.0
var expected_min: float = 0.0
var expected_max: float = 0.0

var _age_curve: Array[AgeBracket] = []
var _competition_strength: Array[AgeBracket] = []
var _matches_per_season: Array[AgeBracket] = []


## One row of an age table: applies to ages from_age..to_age inclusive.
class AgeBracket:
	extends RefCounted
	var from_age: int = 0
	var to_age: int = 0
	var value: float = 0.0


## Loads and validates `path`. Returns null and appends to `errors` on failure.
static func load_file(path: String, errors: Array[String]) -> Balance:
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


## Returns human-readable problems; empty means `data` is safe for from_dictionary.
static func validate(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key: String in ["start_age", "max_age", "attribute_min", "attribute_max"]:
		DataChecks.require_number(data, key, "", problems)
	if not problems.is_empty():
		return problems
	var first_age := int(data["start_age"])
	var last_age := int(data["max_age"])
	if first_age >= last_age:
		problems.append("start_age must be lower than max_age")
	if float(data["attribute_min"]) >= float(data["attribute_max"]):
		problems.append("attribute_min must be lower than attribute_max")
	_validate_positions(data, problems)
	_validate_attribute_table(data.get("decline_weights"), "decline_weights", problems)
	_validate_sections(data, problems)
	_validate_brackets(data, "age_curve", "base_gain", first_age, last_age, problems)
	_validate_brackets(data, "competition_strength", "value", first_age, last_age, problems)
	_validate_brackets(data, "matches_per_season", "value", first_age, last_age, problems)
	return problems


## Builds a Balance from data that passed `validate`.
static func from_dictionary(data: Dictionary) -> Balance:
	var balance := Balance.new()
	balance.start_age = int(data["start_age"])
	balance.max_age = int(data["max_age"])
	balance.attribute_min = float(data["attribute_min"])
	balance.attribute_max = float(data["attribute_max"])
	for position: String in data["position_weights"]:
		balance.position_weights[position] = _to_float_table(data["position_weights"][position])
		balance.start_attributes[position] = _to_float_table(data["start_attributes"][position])
	balance.decline_weights.assign(_to_float_table(data["decline_weights"]))
	balance.training.assign(_to_float_table(data["training"]))
	balance.headroom_exponent = float(data["headroom"]["exponent"])
	balance.headroom_floor = float(data["headroom"]["floor"])
	balance.performance_baseline = float(data["performance"]["baseline_rating"])
	balance.performance_gain_per_point = float(data["performance"]["gain_per_point"])
	balance.expected_neutral = float(data["expected_rating"]["neutral"])
	balance.expected_per_overall_point = float(data["expected_rating"]["per_overall_point"])
	balance.expected_min = float(data["expected_rating"]["min"])
	balance.expected_max = float(data["expected_rating"]["max"])
	balance._age_curve = _to_brackets(data["age_curve"], "base_gain")
	balance._competition_strength = _to_brackets(data["competition_strength"], "value")
	balance._matches_per_season = _to_brackets(data["matches_per_season"], "value")
	return balance


## Position codes (e.g. "FWD"), sorted for stable UI order.
func positions() -> Array[String]:
	var codes: Array[String] = []
	codes.assign(position_weights.keys())
	codes.sort()
	return codes


func has_position(position: String) -> bool:
	return position_weights.has(position)


func weight(position: String, attribute: String) -> float:
	return float(position_weights[position][attribute])


func start_attribute(position: String, attribute: String) -> float:
	return float(start_attributes[position][attribute])


## Base yearly change at `age` before training focus and headroom.
func base_gain_for_age(age: int) -> float:
	return _lookup(_age_curve, age)


## Strength of the default competition for `age` (academy brackets; clubs replace it in M4).
func competition_strength_for_age(age: int) -> float:
	return _lookup(_competition_strength, age)


func matches_for_age(age: int) -> int:
	return int(_lookup(_matches_per_season, age))


## Ages outside the table use the nearest bracket, so lookups never fail.
func _lookup(brackets: Array[AgeBracket], age: int) -> float:
	var clamped := clampi(age, start_age, max_age)
	for bracket: AgeBracket in brackets:
		if clamped >= bracket.from_age and clamped <= bracket.to_age:
			return bracket.value
	return brackets[-1].value


static func _to_float_table(source: Dictionary) -> Dictionary[String, float]:
	var table: Dictionary[String, float] = {}
	for key: String in source:
		table[key] = float(source[key])
	return table


static func _to_brackets(rows: Array, value_key: String) -> Array[AgeBracket]:
	var brackets: Array[AgeBracket] = []
	for row: Dictionary in rows:
		var bracket := AgeBracket.new()
		bracket.from_age = int(row["from_age"])
		bracket.to_age = int(row["to_age"])
		bracket.value = float(row[value_key])
		brackets.append(bracket)
	return brackets


## `table` must be an object with a non-negative number for every attribute.
static func _validate_attribute_table(
	table: Variant, label: String, problems: Array[String]
) -> void:
	if typeof(table) != TYPE_DICTIONARY:
		problems.append("%s must be an object" % label)
		return
	var values: Dictionary = table
	for attribute: String in PlayerModel.ATTRIBUTES:
		if not DataChecks.is_number(values.get(attribute)):
			problems.append("%s.%s must be a number" % [label, attribute])
		elif float(values[attribute]) < 0.0:
			problems.append("%s.%s must not be negative" % [label, attribute])


static func _validate_positions(data: Dictionary, problems: Array[String]) -> void:
	if typeof(data.get("position_weights")) != TYPE_DICTIONARY:
		problems.append("position_weights must be an object")
		return
	if typeof(data.get("start_attributes")) != TYPE_DICTIONARY:
		problems.append("start_attributes must be an object")
		return
	var weights: Dictionary = data["position_weights"]
	var starts: Dictionary = data["start_attributes"]
	if weights.is_empty():
		problems.append("position_weights must define at least one position")
	for position: String in weights:
		_validate_attribute_table(weights[position], "position_weights." + position, problems)
		if not starts.has(position):
			problems.append("start_attributes is missing position %s" % position)
			continue
		_validate_attribute_table(starts[position], "start_attributes." + position, problems)
	if problems.is_empty():
		_validate_position_values(data, problems)


## Runs after the shape checks: weights must sum above zero, starts must be in range.
static func _validate_position_values(data: Dictionary, problems: Array[String]) -> void:
	var low := float(data["attribute_min"])
	var high := float(data["attribute_max"])
	var weights: Dictionary = data["position_weights"]
	for position: String in weights:
		var total := 0.0
		for attribute: String in PlayerModel.ATTRIBUTES:
			total += float(weights[position][attribute])
			var start := float(data["start_attributes"][position][attribute])
			if start < low or start > high:
				problems.append("start_attributes.%s.%s is out of range" % [position, attribute])
		if total <= 0.0:
			problems.append("position_weights.%s must have a positive total" % position)


static func _validate_sections(data: Dictionary, problems: Array[String]) -> void:
	var sections: Dictionary = {
		"training": TRAINING_KEYS,
		"headroom": ["exponent", "floor"],
		"performance": ["baseline_rating", "gain_per_point"],
		"expected_rating": ["neutral", "per_overall_point", "min", "max"],
	}
	DataChecks.require_number_sections(data, sections, problems)
	if not problems.is_empty():
		return
	if float(data["headroom"]["exponent"]) <= 0.0:
		problems.append("headroom.exponent must be positive")
	if float(data["headroom"]["floor"]) < 0.0 or float(data["headroom"]["floor"]) > 1.0:
		problems.append("headroom.floor must be between 0 and 1")
	if float(data["expected_rating"]["min"]) > float(data["expected_rating"]["max"]):
		problems.append("expected_rating.min must not exceed expected_rating.max")


## Rows must be sorted, contiguous and cover first_age..last_age exactly.
static func _validate_brackets(
	data: Dictionary,
	key: String,
	value_key: String,
	first_age: int,
	last_age: int,
	problems: Array[String]
) -> void:
	var raw_rows: Variant = data.get(key)
	if typeof(raw_rows) != TYPE_ARRAY:
		problems.append("%s must be an array" % key)
		return
	var rows: Array = raw_rows
	if rows.is_empty():
		problems.append("%s must not be empty" % key)
		return
	var next_age := first_age
	for row: Variant in rows:
		if typeof(row) != TYPE_DICTIONARY:
			problems.append("%s rows must be objects" % key)
			return
		var fields: Dictionary = row
		for field: String in ["from_age", "to_age", value_key]:
			if not DataChecks.require_number(fields, field, key + ".", problems):
				return
		if int(fields["from_age"]) != next_age or int(fields["to_age"]) < next_age:
			problems.append("%s has a gap or overlap at age %d" % [key, next_age])
			return
		next_age = int(fields["to_age"]) + 1
	if next_age != last_age + 1:
		problems.append("%s must end exactly at max_age %d" % [key, last_age])
