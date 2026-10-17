class_name CupWorld
extends RefCounted
## Nations, cups, foreign clubs and Golden Ball rivals from data/nations.json
## and data/cups.json, validated.

const NATIONS_PATH := "res://data/nations.json"
const CUPS_PATH := "res://data/cups.json"
const BRACKET_SIZE := 16
const MATCH_KEYS: Array[String] = [
	"form_range",
	"overall_influence",
	"rating_influence",
	"rating_baseline",
	"min_contribution",
	"max_contribution",
	"goal_step",
	"max_goals",
]
const BALL_KEYS: Array[String] = [
	"rating_weight", "rating_baseline", "points_per_trophy", "form_range"
]


class Rival:
	extends RefCounted
	var name: String = ""
	var club: String = ""
	var level: float = 0.0


var home_nation: String = ""
var nations: Array[Nation] = []
var foreign_clubs: Array[Club] = []
var cups: Array[CupDefinition] = []
var rivals: Array[Rival] = []
var _match: Dictionary[String, float] = {}
var _ball: Dictionary[String, float] = {}
var _nations_by_id: Dictionary[String, Nation] = {}
var _foreign_by_id: Dictionary[String, Club] = {}


static func load_files(nations_path: String, cups_path: String, errors: Array[String]) -> CupWorld:
	var nations_data := JsonLoader.load_dictionary(nations_path)
	var cups_data := JsonLoader.load_dictionary(cups_path)
	for loaded: JsonLoader.LoadResult in [nations_data, cups_data]:
		if not loaded.is_ok():
			errors.append(loaded.error)
	if not errors.is_empty():
		return null
	var problems := validate(nations_data.data, cups_data.data)
	if not problems.is_empty():
		errors.append_array(problems)
		return null
	return from_dictionaries(nations_data.data, cups_data.data)


static func validate(nations_data: Dictionary, cups_data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var nation_ids := _validate_nations(nations_data, problems)
	DataChecks.require_number_sections(
		cups_data, {"match": MATCH_KEYS, "golden_ball": BALL_KEYS}, problems
	)
	for cup_id: String in CupDefinition.IDS:
		DataChecks.require_number_sections(
			cups_data, {cup_id: ["every_seasons", "season_offset"]}, problems
		)
	_validate_foreign_clubs(cups_data.get("foreign_clubs"), nation_ids, problems)
	_validate_rivals(cups_data, problems)
	return problems


static func from_dictionaries(nations_data: Dictionary, cups_data: Dictionary) -> CupWorld:
	var world := CupWorld.new()
	world.home_nation = nations_data["home"]
	for entry: Dictionary in nations_data["nations"]:
		var loaded_nation := Nation.from_dict(entry)
		world.nations.append(loaded_nation)
		world._nations_by_id[loaded_nation.id] = loaded_nation
	for entry: Dictionary in cups_data["foreign_clubs"]:
		var club := _foreign_club(entry)
		world.foreign_clubs.append(club)
		world._foreign_by_id[club.id] = club
	for cup_id: String in CupDefinition.IDS:
		world.cups.append(CupDefinition.from_dict(cup_id, cups_data[cup_id]))
	for key: String in MATCH_KEYS:
		world._match[key] = float(cups_data["match"][key])
	for key: String in BALL_KEYS:
		world._ball[key] = float(cups_data["golden_ball"][key])
	for entry: Dictionary in cups_data["golden_ball"]["rivals"]:
		var rival := Rival.new()
		rival.name = entry["name"]
		rival.club = entry["club"]
		rival.level = float(entry["level"])
		world.rivals.append(rival)
	return world


func match_value(key: String) -> float:
	return _match[key]


func ball_value(key: String) -> float:
	return _ball[key]


func cup(cup_id: String) -> CupDefinition:
	for definition: CupDefinition in cups:
		if definition.id == cup_id:
			return definition
	return null


func nation(nation_id: String) -> Nation:
	return _nations_by_id[nation_id]


func has_foreign_club(club_id: String) -> bool:
	return _foreign_by_id.has(club_id)


func foreign_club(club_id: String) -> Club:
	return _foreign_by_id[club_id]


## Display name of a team in `cup_id` (club ids may be Valdorian or foreign).
func team_name(cup_id: String, team_id: String, clubs: ClubWorld) -> String:
	if cup_id == CupDefinition.NATIONS:
		return nation(team_id).name if _nations_by_id.has(team_id) else team_id
	if has_foreign_club(team_id):
		return foreign_club(team_id).name
	return clubs.club(team_id).name if clubs.has_club(team_id) else team_id


static func _foreign_club(entry: Dictionary) -> Club:
	var club := Club.new()
	club.id = entry["id"]
	club.name = entry["name"]
	club.strength = float(entry["strength"])
	var crest: Dictionary = entry["crest"]
	club.crest_shape = crest["shape"]
	club.crest_pattern = crest["pattern"]
	club.crest_primary = Color.html(crest["primary"])
	club.crest_secondary = Color.html(crest["secondary"])
	return club


static func _validate_nations(
	data: Dictionary, problems: Array[String]
) -> Dictionary[String, bool]:
	var ids: Dictionary[String, bool] = {}
	if typeof(data.get("nations")) != TYPE_ARRAY:
		problems.append("nations must be an array")
		return ids
	for entry: Variant in data["nations"]:
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("nations entries must be objects")
			continue
		var fields: Dictionary = entry
		var label := "nation %s" % str(fields.get("id", "?"))
		if typeof(fields.get("name")) != TYPE_STRING:
			problems.append("%s: name must be a string" % label)
		else:
			_check_name(fields["name"], label, problems)
		DataChecks.require_number(fields, "strength", label + ": ", problems)
		_validate_flag(fields.get("flag"), label, problems)
		ids[str(fields.get("id"))] = true
	if ids.size() != BRACKET_SIZE:
		problems.append("there must be exactly %d nations" % BRACKET_SIZE)
	if not ids.has(str(data.get("home"))):
		problems.append("home must be one of the nations")
	return ids


static func _validate_flag(flag: Variant, label: String, problems: Array[String]) -> void:
	if typeof(flag) != TYPE_DICTIONARY:
		problems.append("%s: flag must be an object" % label)
		return
	var fields: Dictionary = flag
	if not Nation.PATTERNS.has(fields.get("pattern")):
		problems.append("%s: flag.pattern must be one of %s" % [label, Nation.PATTERNS])
	if typeof(fields.get("colors")) != TYPE_ARRAY:
		problems.append("%s: flag.colors must be an array" % label)
		return
	var colors: Array = fields["colors"]
	if colors.size() < 2:
		problems.append("%s: flag needs at least 2 colours" % label)
	for color: Variant in colors:
		if typeof(color) != TYPE_STRING or not Color.html_is_valid(str(color)):
			problems.append("%s: flag colour %s is not valid" % [label, str(color)])


static func _validate_foreign_clubs(
	clubs: Variant, nation_ids: Dictionary[String, bool], problems: Array[String]
) -> void:
	if typeof(clubs) != TYPE_ARRAY:
		problems.append("foreign_clubs must be an array")
		return
	var entries: Array = clubs
	for entry: Variant in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("foreign_clubs entries must be objects")
			continue
		var fields: Dictionary = entry
		var label := "foreign club %s" % str(fields.get("id", "?"))
		_check_name(str(fields.get("name", "")), label, problems)
		if not nation_ids.has(str(fields.get("nation"))):
			problems.append("%s: unknown nation" % label)
		DataChecks.require_number(fields, "strength", label + ": ", problems)
		if typeof(fields.get("crest")) != TYPE_DICTIONARY:
			problems.append("%s: crest must be an object" % label)


static func _validate_rivals(cups_data: Dictionary, problems: Array[String]) -> void:
	if typeof(cups_data.get("golden_ball")) != TYPE_DICTIONARY:
		return
	var ball: Dictionary = cups_data["golden_ball"]
	if typeof(ball.get("rivals")) != TYPE_ARRAY:
		problems.append("golden_ball.rivals must be an array")
		return
	var rivals_data: Array = ball["rivals"]
	for entry: Variant in rivals_data:
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("golden_ball.rivals entries must be objects")
			continue
		var fields: Dictionary = entry
		_check_name(str(fields.get("name", "")), "rival", problems)
		DataChecks.require_number(fields, "level", "rival %s: " % fields.get("name"), problems)


static func _check_name(text: String, label: String, problems: Array[String]) -> void:
	var problem := ContentRules.problem_in(text)
	if not problem.is_empty():
		problems.append("%s: name %s" % [label, problem])
