class_name CupRun
extends RefCounted
## One cup the player took part in: how far their team got.

var season_number: int = 0
var cup_id: String = ""
var team: String = ""
## Matches won: 0 = out in the round of 16 ... 4 = champions.
var wins: int = 0
var won: bool = false


static func create(season: int, result: CupSim.Result) -> CupRun:
	var run := CupRun.new()
	run.season_number = season
	run.cup_id = result.cup_id
	run.team = result.player_team
	run.wins = result.player_wins
	run.won = result.champion == result.player_team
	return run


func to_dict() -> Dictionary:
	return {
		"season_number": season_number, "cup_id": cup_id, "team": team, "wins": wins, "won": won
	}


static func validate_dict(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if not CupDefinition.IDS.has(data.get("cup_id")):
		problems.append("cup_run.cup_id is unknown")
	for key: String in ["season_number", "wins"]:
		if not DataChecks.is_number(data.get(key)):
			problems.append("cup_run.%s must be a number" % key)
	if typeof(data.get("team")) != TYPE_STRING or typeof(data.get("won")) != TYPE_BOOL:
		problems.append("cup_run needs a team string and won true/false")
	return problems


static func from_dict(data: Dictionary) -> CupRun:
	var run := CupRun.new()
	run.season_number = int(data["season_number"])
	run.cup_id = data["cup_id"]
	run.team = data["team"]
	run.wins = int(data["wins"])
	run.won = data["won"]
	return run
