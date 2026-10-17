class_name GameLabels
extends RefCounted
## Display names for attributes and positions, loaded from data/labels.json.
## Kept out of code so text can be changed (or localized) without touching logic.

const DEFAULT_PATH := "res://data/labels.json"

var _attributes: Dictionary[String, String] = {}
var _positions: Dictionary[String, String] = {}


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
	return labels


## Every attribute needs a name; positions must be an object of strings.
static func validate(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for section: String in ["attributes", "positions"]:
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
	return problems


## Falls back to the code itself so a missing label never breaks the UI.
func attribute_name(attribute: String) -> String:
	return _attributes.get(attribute, attribute)


func position_name(position: String) -> String:
	return _positions.get(position, position)


func has_position(position: String) -> bool:
	return _positions.has(position)
