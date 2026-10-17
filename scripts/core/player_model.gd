class_name PlayerModel
extends RefCounted
## The player's current state: identity, age, position and attributes.
## Attributes are floats so small yearly gains accumulate; UI shows them rounded.

const ATTRIBUTES: Array[String] = [
	"pace",
	"shooting",
	"passing",
	"dribbling",
	"defending",
	"physical",
	"goalkeeping",
]

var display_name: String = ""
var position: String = ""
var age: int = 0
var attributes: Dictionary[String, float] = {}


## A new academy player at the balance file's start age.
static func create(name: String, start_position: String, balance: Balance) -> PlayerModel:
	var player := PlayerModel.new()
	player.display_name = name
	player.position = start_position
	player.age = balance.start_age
	for attribute: String in ATTRIBUTES:
		player.attributes[attribute] = balance.start_attribute(start_position, attribute)
	return player


## Position-weighted average of attributes, rounded and clamped to the attribute range.
func overall_rating(balance: Balance) -> int:
	var weighted := 0.0
	var total_weight := 0.0
	for attribute: String in ATTRIBUTES:
		var weight := balance.weight(position, attribute)
		weighted += attributes[attribute] * weight
		total_weight += weight
	var overall := roundi(weighted / total_weight)
	return clampi(overall, int(balance.attribute_min), int(balance.attribute_max))


func copy() -> PlayerModel:
	var clone := PlayerModel.new()
	clone.display_name = display_name
	clone.position = position
	clone.age = age
	clone.attributes = attributes.duplicate()
	return clone


func to_dict() -> Dictionary:
	return {
		"display_name": display_name,
		"position": position,
		"age": age,
		"attributes": attributes.duplicate(),
	}


## Checks untrusted data (e.g. a save file) before `from_dict`.
static func validate_dict(data: Dictionary, balance: Balance) -> Array[String]:
	var problems: Array[String] = []
	if typeof(data.get("display_name")) != TYPE_STRING:
		problems.append("player.display_name must be a string")
	if typeof(data.get("position")) != TYPE_STRING or not balance.has_position(data["position"]):
		problems.append("player.position is not a known position")
	if not _is_whole_number(data.get("age")):
		problems.append("player.age must be a whole number")
	elif int(data["age"]) < balance.start_age or int(data["age"]) > balance.max_age:
		problems.append("player.age is out of range")
	if typeof(data.get("attributes")) != TYPE_DICTIONARY:
		problems.append("player.attributes must be an object")
		return problems
	var values: Dictionary = data["attributes"]
	for attribute: String in ATTRIBUTES:
		var value: Variant = values.get(attribute)
		var is_number := typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT
		if not is_number or float(value) < balance.attribute_min:
			problems.append("player.attributes.%s is missing or too low" % attribute)
		elif float(value) > balance.attribute_max:
			problems.append("player.attributes.%s is too high" % attribute)
	return problems


## Builds a player from data that passed `validate_dict`.
static func from_dict(data: Dictionary) -> PlayerModel:
	var player := PlayerModel.new()
	player.display_name = data["display_name"]
	player.position = data["position"]
	player.age = int(data["age"])
	for attribute: String in ATTRIBUTES:
		player.attributes[attribute] = float(data["attributes"][attribute])
	return player


## JSON numbers arrive as floats, so 12.0 counts as whole but 12.5 does not.
static func _is_whole_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), roundf(float(value)))
