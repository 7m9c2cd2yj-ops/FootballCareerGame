class_name ClubWorld
extends RefCounted
## All leagues and clubs from data/clubs.json, validated, in file order.

const DEFAULT_PATH := "res://data/clubs.json"

var nation: String = ""
var leagues: Array[League] = []
var clubs: Array[Club] = []
var _clubs_by_id: Dictionary[String, Club] = {}
var _leagues_by_id: Dictionary[String, League] = {}


## `positions` are the valid position codes (from Balance).
static func load_file(path: String, positions: Array[String], errors: Array[String]) -> ClubWorld:
	var loaded := JsonLoader.load_dictionary(path)
	if not loaded.is_ok():
		errors.append(loaded.error)
		return null
	var problems := validate(loaded.data, positions)
	if not problems.is_empty():
		for problem: String in problems:
			errors.append("%s: %s" % [path, problem])
		return null
	return from_dictionary(loaded.data)


static func validate(data: Dictionary, positions: Array[String]) -> Array[String]:
	var problems: Array[String] = []
	if typeof(data.get("nation")) != TYPE_STRING:
		problems.append("nation must be a string")
	if typeof(data.get("leagues")) != TYPE_ARRAY or typeof(data.get("clubs")) != TYPE_ARRAY:
		problems.append("leagues and clubs must be arrays")
		return problems
	var league_ids := _validate_leagues(data["leagues"], problems)
	var club_ids: Dictionary[String, bool] = {}
	for entry: Variant in data["clubs"]:
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("clubs entries must be objects")
			continue
		var fields: Dictionary = entry
		var label := "club %s" % str(fields.get("id", "?"))
		_validate_club(fields, label, league_ids, positions, problems)
		if club_ids.has(str(fields.get("id"))):
			problems.append("%s: duplicate id" % label)
		club_ids[str(fields.get("id"))] = true
	return problems


static func from_dictionary(data: Dictionary) -> ClubWorld:
	var world := ClubWorld.new()
	world.nation = data["nation"]
	for entry: Dictionary in data["leagues"]:
		var league := League.from_dict(entry)
		world.leagues.append(league)
		world._leagues_by_id[league.id] = league
	for entry: Dictionary in data["clubs"]:
		var loaded_club := Club.from_dict(entry)
		world.clubs.append(loaded_club)
		world._clubs_by_id[loaded_club.id] = loaded_club
	return world


func has_club(club_id: String) -> bool:
	return _clubs_by_id.has(club_id)


func club(club_id: String) -> Club:
	return _clubs_by_id[club_id]


## The club's position in the file, used as a stable key for Variety.
func club_index(club_id: String) -> int:
	return clubs.find(_clubs_by_id[club_id])


func league_of(club_id: String) -> League:
	return _leagues_by_id[club(club_id).league_id]


func clubs_in_league(league_id: String) -> Array[Club]:
	var found: Array[Club] = []
	for candidate: Club in clubs:
		if candidate.league_id == league_id:
			found.append(candidate)
	return found


static func _validate_leagues(entries: Array, problems: Array[String]) -> Dictionary[String, bool]:
	var ids: Dictionary[String, bool] = {}
	for entry: Variant in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("leagues entries must be objects")
			continue
		var league: Dictionary = entry
		if typeof(league.get("id")) != TYPE_STRING or typeof(league.get("name")) != TYPE_STRING:
			problems.append("each league needs a string id and name")
			continue
		DataChecks.require_number(league, "tier", "league %s: " % league["id"], problems)
		DataChecks.require_number(league, "strength", "league %s: " % league["id"], problems)
		ids[league["id"]] = true
	return ids


static func _validate_club(
	fields: Dictionary,
	label: String,
	league_ids: Dictionary[String, bool],
	positions: Array[String],
	problems: Array[String]
) -> void:
	for key: String in ["id", "name", "league", "budget"]:
		if typeof(fields.get(key)) != TYPE_STRING:
			problems.append("%s: %s must be a string" % [label, key])
			return
	if not league_ids.has(fields["league"]):
		problems.append("%s: unknown league %s" % [label, fields["league"]])
	for key: String in ["strength", "youth_intake_min"]:
		if DataChecks.require_number(fields, key, label + ": ", problems):
			if float(fields[key]) < 1.0 or float(fields[key]) > 99.0:
				problems.append("%s: %s must be between 1 and 99" % [label, key])
	_validate_crest(fields.get("crest"), label, problems)
	_validate_needs(fields.get("needs"), label, positions, problems)


static func _validate_crest(crest: Variant, label: String, problems: Array[String]) -> void:
	if typeof(crest) != TYPE_DICTIONARY:
		problems.append("%s: crest must be an object" % label)
		return
	var crest_fields: Dictionary = crest
	if not Club.SHAPES.has(crest_fields.get("shape")):
		problems.append("%s: crest.shape must be one of %s" % [label, Club.SHAPES])
	if not Club.PATTERNS.has(crest_fields.get("pattern")):
		problems.append("%s: crest.pattern must be one of %s" % [label, Club.PATTERNS])
	for key: String in ["primary", "secondary"]:
		var value: Variant = crest_fields.get(key)
		if typeof(value) != TYPE_STRING or not Color.html_is_valid(str(value)):
			problems.append("%s: crest.%s must be a colour like #1E4D8C" % [label, key])


static func _validate_needs(
	needs: Variant, label: String, positions: Array[String], problems: Array[String]
) -> void:
	if typeof(needs) != TYPE_ARRAY:
		problems.append("%s: needs must be an array" % label)
		return
	var entries: Array = needs
	if entries.is_empty():
		problems.append("%s: needs must not be empty" % label)
	for entry: Variant in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("%s: needs entries must be objects" % label)
			continue
		var need: Dictionary = entry
		if not positions.has(need.get("position")):
			problems.append("%s: need has unknown position %s" % [label, need.get("position")])
		DataChecks.require_number(need, "min_rating", label + ": need.", problems)
		if need.has("max_age"):
			DataChecks.require_number(need, "max_age", label + ": need.", problems)
