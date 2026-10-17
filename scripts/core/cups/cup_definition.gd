class_name CupDefinition
extends RefCounted
## One competition: who plays (clubs or nations) and how often it is held.

const CONTINENTAL := "continental_cup"
const NATIONS := "world_nations_cup"
const IDS: Array[String] = [CONTINENTAL, NATIONS]

var id: String = ""
var name: String = ""
## Held in seasons where (season_number + season_offset) % every_seasons == 0.
var every_seasons: int = 1
var season_offset: int = 0
## Continental Cup: how many top Valdorian clubs qualify.
var home_qualifiers: int = 0
## World Nations Cup: overall needed for a national call-up.
var call_up_min: float = 0.0


func is_for_nations() -> bool:
	return id == NATIONS


func is_held(season_number: int) -> bool:
	return (season_number + season_offset) % every_seasons == 0


static func from_dict(cup_id: String, data: Dictionary) -> CupDefinition:
	var cup := CupDefinition.new()
	cup.id = cup_id
	cup.name = data["name"]
	cup.every_seasons = int(data["every_seasons"])
	cup.season_offset = int(data["season_offset"])
	cup.home_qualifiers = int(data.get("home_qualifiers", 0))
	cup.call_up_min = float(data.get("call_up_min", 0.0))
	return cup
