class_name SeasonRecord
extends RefCounted
## What happened in one completed season; the career history is a list of these.

var season_number: int = 0
var age: int = 0
var position: String = ""
var primary_focus: String = ""
var secondary_focus: String = ""
var matches_played: int = 0
var average_rating: float = 0.0
var key_moments_played: int = 0
var key_moments_won: int = 0
var overall_before: int = 0
var overall_after: int = 0
## Attribute -> change applied this season (after clamping).
var attribute_changes: Dictionary[String, float] = {}


func to_dict() -> Dictionary:
	return {
		"season_number": season_number,
		"age": age,
		"position": position,
		"primary_focus": primary_focus,
		"secondary_focus": secondary_focus,
		"matches_played": matches_played,
		"average_rating": average_rating,
		"key_moments_played": key_moments_played,
		"key_moments_won": key_moments_won,
		"overall_before": overall_before,
		"overall_after": overall_after,
		"attribute_changes": attribute_changes.duplicate(),
	}


## Checks untrusted data (e.g. a save file) before `from_dict`.
static func validate_dict(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var number_keys: Array[String] = [
		"season_number",
		"age",
		"matches_played",
		"average_rating",
		"key_moments_played",
		"key_moments_won",
		"overall_before",
		"overall_after"
	]
	for key: String in number_keys:
		if typeof(data.get(key)) != TYPE_FLOAT and typeof(data.get(key)) != TYPE_INT:
			problems.append("season.%s must be a number" % key)
	for key: String in ["position", "primary_focus", "secondary_focus"]:
		if typeof(data.get(key)) != TYPE_STRING:
			problems.append("season.%s must be a string" % key)
	if typeof(data.get("attribute_changes")) != TYPE_DICTIONARY:
		problems.append("season.attribute_changes must be an object")
	return problems


## Builds a record from data that passed `validate_dict`. Unknown attributes are dropped.
static func from_dict(data: Dictionary) -> SeasonRecord:
	var record := SeasonRecord.new()
	record.season_number = int(data["season_number"])
	record.age = int(data["age"])
	record.position = data["position"]
	record.primary_focus = data["primary_focus"]
	record.secondary_focus = data["secondary_focus"]
	record.matches_played = int(data["matches_played"])
	record.average_rating = float(data["average_rating"])
	record.key_moments_played = int(data["key_moments_played"])
	record.key_moments_won = int(data["key_moments_won"])
	record.overall_before = int(data["overall_before"])
	record.overall_after = int(data["overall_after"])
	var changes: Dictionary = data["attribute_changes"]
	for attribute: String in PlayerModel.ATTRIBUTES:
		record.attribute_changes[attribute] = float(changes.get(attribute, 0.0))
	return record
