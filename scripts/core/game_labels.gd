class_name GameLabels
extends RefCounted
## Display names for attributes and positions, loaded from data/labels.json.
## Kept out of code so text can be changed (or localized) without touching logic.

const DEFAULT_PATH := "res://data/labels.json"
const SECTIONS: Array[String] = [
	"attributes", "positions", "moments", "outcomes", "roles", "intensities", "tips"
]

var _attributes: Dictionary[String, String] = {}
var _positions: Dictionary[String, String] = {}
var _moments: Dictionary[String, String] = {}
var _outcomes: Dictionary[String, String] = {}
var _roles: Dictionary[String, String] = {}
var _intensities: Dictionary[String, String] = {}
var _tips: Dictionary[String, String] = {}


## Loads and validates `path`. Returns null and appends to `errors` on failure.
static func load_file(path: String, errors: Array[String]) -> GameLabels:
	var loaded := JsonLoader.load_dictionary(path)
	if not loaded.is_ok():
		errors.append(loaded.error)
		return null
	var problems := validate(loaded.data)
	if not problems.is_empty():
		for problem: String in problems:
			errors.append("%s: %s" % [path, problem])
		return null
	var labels := GameLabels.new()
	labels._attributes.assign(loaded.data["attributes"])
	labels._positions.assign(loaded.data["positions"])
	labels._moments.assign(loaded.data["moments"])
	labels._outcomes.assign(loaded.data["outcomes"])
	labels._roles.assign(loaded.data["roles"])
	labels._intensities.assign(loaded.data["intensities"])
	labels._tips.assign(loaded.data["tips"])
	return labels


## Every attribute needs a name; positions must be an object of strings.
static func validate(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for section: String in SECTIONS:
		if typeof(data.get(section)) != TYPE_DICTIONARY:
			problems.append("%s must be an object" % section)
			continue
		var names: Dictionary = data[section]
		for key: String in names:
			if typeof(names[key]) != TYPE_STRING:
				problems.append("%s.%s must be a string" % [section, key])
	if problems.is_empty():
		var attribute_names: Dictionary = data["attributes"]
		for attribute: String in PlayerModel.ATTRIBUTES:
			if not attribute_names.has(attribute):
				problems.append("attributes is missing '%s'" % attribute)
		var tips: Dictionary = data["tips"]
		for moment_type: String in MomentSpec.TYPES:
			if not tips.has(moment_type):
				problems.append("tips is missing '%s'" % moment_type)
	return problems


## Falls back to the code itself so a missing label never breaks the UI.
func attribute_name(attribute: String) -> String:
	return _attributes.get(attribute, attribute)


func position_name(position: String) -> String:
	return _positions.get(position, position)


func moment_name(moment_type: String) -> String:
	return _moments.get(moment_type, moment_type)


func outcome_name(outcome: String) -> String:
	return _outcomes.get(outcome, outcome)


func role_name(role: String) -> String:
	return _roles.get(role, role)


func intensity_name(intensity: String) -> String:
	return _intensities.get(intensity, intensity)


## How to play a moment type, shown before the player's first one.
func tip(moment_type: String) -> String:
	return _tips.get(moment_type, "")


func has_moment(moment_type: String) -> bool:
	return _moments.has(moment_type)


func has_position(position: String) -> bool:
	return _positions.has(position)
