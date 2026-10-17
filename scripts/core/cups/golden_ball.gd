class_name GoldenBall
extends RefCounted
## The season's best-player award (senior players). No randomness:
##   player score = overall + (season rating - baseline) * rating_weight
##                  + trophies this season * points_per_trophy
##   rival score  = rival level + fixed form from Variety
## Rank 1 wins. Rivals are fictional players in data/cups.json.

const SALT_RIVALS := 51


class Standing:
	extends RefCounted
	var season_number: int = 0
	## 1 = winner.
	var rank: int = 0
	## Name of the winner (the player's own name if they won).
	var winner: String = ""

	func to_dict() -> Dictionary:
		return {"season_number": season_number, "rank": rank, "winner": winner}

	static func validate_dict(data: Dictionary) -> Array[String]:
		var problems: Array[String] = []
		for key: String in ["season_number", "rank"]:
			if not DataChecks.is_number(data.get(key)):
				problems.append("golden_ball.%s must be a number" % key)
		if typeof(data.get("winner")) != TYPE_STRING:
			problems.append("golden_ball.winner must be a string")
		return problems

	static func from_dict(data: Dictionary) -> Standing:
		var loaded := Standing.new()
		loaded.season_number = int(data["season_number"])
		loaded.rank = int(data["rank"])
		loaded.winner = data["winner"]
		return loaded


static func player_score(record: SeasonRecord, trophies: int, cups: CupWorld) -> float:
	var form := (
		(record.average_rating - cups.ball_value("rating_baseline"))
		* cups.ball_value("rating_weight")
	)
	return record.overall_after + form + trophies * cups.ball_value("points_per_trophy")


static func rival_score(rival_index: int, season_number: int, cups: CupWorld) -> float:
	var form := Variety.unit(season_number, rival_index, SALT_RIVALS) - 0.5
	return cups.rivals[rival_index].level + form * cups.ball_value("form_range")


static func standing(
	record: SeasonRecord, trophies: int, player_name: String, cups: CupWorld
) -> Standing:
	var result := Standing.new()
	result.season_number = record.season_number
	var mine := player_score(record, trophies, cups)
	var best_rival := -1
	var rank := 1
	for index: int in cups.rivals.size():
		var score := rival_score(index, record.season_number, cups)
		if score > mine:
			rank += 1
		if best_rival < 0 or score > rival_score(best_rival, record.season_number, cups):
			best_rival = index
	result.rank = rank
	result.winner = player_name if rank == 1 else cups.rivals[best_rival].name
	return result


## Awards the season's Golden Ball; stores the player's rank and records news
## for a top-3 finish. Seniors only.
static func apply(
	career: CareerState, record: SeasonRecord, trophies: int, rules: CareerRules, cups: CupWorld
) -> void:
	if record.age < rules.senior_age:
		return
	var result := standing(record, trophies, career.player.display_name, cups)
	career.golden_balls.append(result)
	if result.rank <= 3:
		var values := {"rank": result.rank, "winner": result.winner}
		CareerEvents.record_at_season(career, CareerEvent.GOLDEN_BALL, record, values)
