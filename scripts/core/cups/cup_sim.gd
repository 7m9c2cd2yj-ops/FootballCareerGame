class_name CupSim
extends RefCounted
## Plays a 16-team knockout. No randomness:
##   match strength = base strength + (player contribution if it is the
##   player's team, otherwise a fixed form from Variety)
## The stronger side wins; ties go to the higher base strength, then the
## higher seed. Scorelines follow the strength gap (the losing side's goals
## are flavour from Variety). The draw is seeded by base strength.

## Standard seeding: seed numbers (1 = strongest) in bracket order.
const SEED_ORDER: Array[int] = [1, 16, 8, 9, 4, 13, 5, 12, 2, 15, 7, 10, 3, 14, 6, 11]
const ROUNDS := 4
const SALT_FORM := 41
const SALT_GOALS := 42


class Match:
	extends RefCounted
	## 0 = round of 16, 1 = quarter-final, 2 = semi-final, 3 = final.
	var round_index: int = 0
	var home: String = ""
	var away: String = ""
	var home_goals: int = 0
	var away_goals: int = 0
	var winner: String = ""


class Result:
	extends RefCounted
	var cup_id: String = ""
	var season_number: int = 0
	var matches: Array[Match] = []
	var champion: String = ""
	## "" if the player did not take part.
	var player_team: String = ""
	## Matches the player's team won (4 = champions).
	var player_wins: int = 0


## `strengths` maps team id -> base strength (16 teams).
static func play(
	cup_id: String,
	season_number: int,
	strengths: Dictionary[String, float],
	player_team: String,
	contribution: float,
	cups: CupWorld
) -> Result:
	var result := Result.new()
	result.cup_id = cup_id
	result.season_number = season_number
	result.player_team = player_team
	var alive := seeded_bracket(strengths)
	var salt := SALT_FORM + CupDefinition.IDS.find(cup_id) * 10
	for round_index: int in ROUNDS:
		var next: Array[String] = []
		for slot: int in range(0, alive.size(), 2):
			var key := round_index * 16 + slot
			var context := [season_number, key, salt]
			var played := _play_match(
				alive[slot], alive[slot + 1], strengths, result, contribution, context, cups
			)
			played.round_index = round_index
			result.matches.append(played)
			next.append(played.winner)
			if played.winner == player_team:
				result.player_wins += 1
		alive = next
	result.champion = alive[0]
	return result


## Team ids in bracket order, strongest seeded apart.
static func seeded_bracket(strengths: Dictionary[String, float]) -> Array[String]:
	var by_strength: Array[String] = []
	by_strength.assign(strengths.keys())
	by_strength.sort_custom(
		func(a: String, b: String) -> bool:
			return strengths[a] > strengths[b] or (strengths[a] == strengths[b] and a < b)
	)
	var bracket: Array[String] = []
	for seed_number: int in SEED_ORDER:
		bracket.append(by_strength[seed_number - 1])
	return bracket


## `context` is [season_number, match key, salt] for Variety.
static func _play_match(
	home: String,
	away: String,
	strengths: Dictionary[String, float],
	result: Result,
	contribution: float,
	context: Array,
	cups: CupWorld
) -> Match:
	var home_strength := _match_strength(
		home, strengths, result.player_team, contribution, context, 0, cups
	)
	var away_strength := _match_strength(
		away, strengths, result.player_team, contribution, context, 1, cups
	)
	var played := Match.new()
	played.home = home
	played.away = away
	var home_wins := home_strength > away_strength
	if is_equal_approx(home_strength, away_strength):
		home_wins = strengths[home] >= strengths[away]
	played.winner = home if home_wins else away
	var gap := absf(home_strength - away_strength)
	var winner_goals := clampi(
		1 + floori(gap / cups.match_value("goal_step")), 1, int(cups.match_value("max_goals"))
	)
	var flavour := Variety.unit(int(context[0]), int(context[1]), SALT_GOALS)
	var loser_goals := mini(winner_goals - 1, floori(flavour * 3.0))
	played.home_goals = winner_goals if home_wins else loser_goals
	played.away_goals = loser_goals if home_wins else winner_goals
	return played


static func _match_strength(
	team: String,
	strengths: Dictionary[String, float],
	player_team: String,
	contribution: float,
	context: Array,
	side: int,
	cups: CupWorld
) -> float:
	if team == player_team:
		return strengths[team] + contribution
	var form := Variety.unit(int(context[0]), int(context[1]) + side, int(context[2])) - 0.5
	return strengths[team] + form * cups.match_value("form_range")
