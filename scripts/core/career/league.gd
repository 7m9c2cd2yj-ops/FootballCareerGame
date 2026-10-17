class_name League
extends RefCounted
## A fictional league. Tier 1 is the top; strength is the competition level a
## senior player faces there (comparable with overall ratings).

var id: String = ""
var name: String = ""
var tier: int = 0
var strength: float = 0.0


static func from_dict(data: Dictionary) -> League:
	var league := League.new()
	league.id = data["id"]
	league.name = data["name"]
	league.tier = int(data["tier"])
	league.strength = float(data["strength"])
	return league
