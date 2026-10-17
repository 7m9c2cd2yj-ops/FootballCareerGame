class_name CareerEvent
extends RefCounted
## Something that happened in a career, recorded when it happened. Holds ids
## and numbers only; display text is generated later from data/text_templates.json.

const SEASON_PLAYED := "season_played"
const MILESTONE := "milestone"
const INJURY := "injury"
const TOP_TIER_DEBUT := "top_tier_debut"
const TRIAL_PASSED := "trial_passed"
const TRIAL_FAILED := "trial_failed"
const TRANSFER := "transfer"
const RENEWAL := "renewal"
const RETIREMENT := "retirement"

## Event type -> the value keys it carries. Templates may use exactly these
## (plus the common placeholders in EventText).
const FIELDS: Dictionary = {
	SEASON_PLAYED:
	["club", "overall_before", "overall_after", "rating", "moments_won", "moments_played"],
	MILESTONE: ["club", "milestone"],
	INJURY: ["club"],
	TOP_TIER_DEBUT: ["club"],
	TRIAL_PASSED: ["club"],
	TRIAL_FAILED: ["club", "academy"],
	TRANSFER: ["from_club", "to_club", "fee", "wage"],
	RENEWAL: ["club", "wage", "years"],
	RETIREMENT: ["club", "peak_overall", "score", "inducted"],
}
## Value keys that hold club ids (shown as club names).
const CLUB_FIELDS: Array[String] = ["club", "from_club", "to_club", "academy"]

var type: String = ""
var season_number: int = 0
var age: int = 0
## Keys from FIELDS[type]; values are strings, booleans or floats (numbers are
## stored as rounded floats so the log survives a JSON round trip exactly).
var values: Dictionary = {}


static func create(
	event_type: String, season: int, player_age: int, event_values: Dictionary
) -> CareerEvent:
	var event := CareerEvent.new()
	event.type = event_type
	event.season_number = season
	event.age = player_age
	for key: Variant in event_values:
		event.values[key] = _stable(event_values[key])
	return event


func to_dict() -> Dictionary:
	return {"type": type, "season_number": season_number, "age": age, "values": values.duplicate()}


static func validate_dict(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if not FIELDS.has(data.get("type")):
		problems.append("event.type %s is unknown" % str(data.get("type")))
		return problems
	for key: String in ["season_number", "age"]:
		if not DataChecks.is_number(data.get(key)):
			problems.append("event.%s must be a number" % key)
	if typeof(data.get("values")) != TYPE_DICTIONARY:
		problems.append("event.values must be an object")
		return problems
	var event_values: Dictionary = data["values"]
	for field: String in FIELDS[data["type"]]:
		if not event_values.has(field):
			problems.append("event %s is missing %s" % [data["type"], field])
	return problems


static func from_dict(data: Dictionary) -> CareerEvent:
	var stored: Dictionary = data["values"]
	return create(data["type"], int(data["season_number"]), int(data["age"]), stored)


static func _stable(value: Variant) -> Variant:
	if DataChecks.is_number(value):
		return Progression.round_value(float(value))
	return value
