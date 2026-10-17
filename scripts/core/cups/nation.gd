class_name Nation
extends RefCounted
## A fictional national team with a flag drawn from simple shapes.

const PATTERNS: Array[String] = ["horizontal", "vertical", "cross", "diagonal", "circle"]

var id: String = ""
var name: String = ""
var strength: float = 0.0
var flag_pattern: String = "horizontal"
var flag_colors: Array[Color] = []


static func from_dict(data: Dictionary) -> Nation:
	var nation := Nation.new()
	nation.id = data["id"]
	nation.name = data["name"]
	nation.strength = float(data["strength"])
	var flag: Dictionary = data["flag"]
	nation.flag_pattern = flag["pattern"]
	for color: String in flag["colors"]:
		nation.flag_colors.append(Color.html(color))
	return nation
