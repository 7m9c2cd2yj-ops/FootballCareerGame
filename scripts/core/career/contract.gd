class_name Contract
extends RefCounted
## The player's current deal with a club. Wages and fees are in thousands of
## fictional credits per season.

var club_id: String = ""
var wage: int = 0
var years_left: int = 0
## Fee another club must be able to pay to sign the player before it ends.
var release_clause: int = 0
var is_youth: bool = false


func has_expired() -> bool:
	return years_left <= 0


func to_dict() -> Dictionary:
	return {
		"club_id": club_id,
		"wage": wage,
		"years_left": years_left,
		"release_clause": release_clause,
		"is_youth": is_youth,
	}


static func validate_dict(data: Dictionary, world: ClubWorld) -> Array[String]:
	var problems: Array[String] = []
	if typeof(data.get("club_id")) != TYPE_STRING or not world.has_club(str(data.get("club_id"))):
		problems.append("contract.club_id is not a known club")
	for key: String in ["wage", "years_left", "release_clause"]:
		if not DataChecks.is_number(data.get(key)) or float(data[key]) < 0.0:
			problems.append("contract.%s must be a non-negative number" % key)
	if typeof(data.get("is_youth")) != TYPE_BOOL:
		problems.append("contract.is_youth must be true or false")
	return problems


static func from_dict(data: Dictionary) -> Contract:
	var contract := Contract.new()
	contract.club_id = data["club_id"]
	contract.wage = int(data["wage"])
	contract.years_left = int(data["years_left"])
	contract.release_clause = int(data["release_clause"])
	contract.is_youth = data["is_youth"]
	return contract
