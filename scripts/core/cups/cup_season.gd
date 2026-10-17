class_name CupSeason
extends RefCounted
## Which cups are held in a season, who plays in them, how much the player
## adds to their team, and the results. Everything is recomputable from a
## SeasonRecord, so brackets need not be stored.


## The player's effect on their team's match strength:
##   (overall - team strength) * overall_influence
##   + (season rating - baseline) * rating_influence
## scaled by how much of the season they played, clamped.
static func contribution(
	overall: int, rating: float, match_share: float, team_strength: float, cups: CupWorld
) -> float:
	var from_level := (overall - team_strength) * cups.match_value("overall_influence")
	var from_form := (
		(rating - cups.match_value("rating_baseline")) * cups.match_value("rating_influence")
	)
	return clampf(
		(from_level + from_form) * match_share,
		cups.match_value("min_contribution"),
		cups.match_value("max_contribution")
	)


## The Continental Cup field: the strongest top-tier home clubs plus foreign clubs.
static func continental_entrants(
	cup: CupDefinition, world: ClubWorld, cups: CupWorld
) -> Dictionary[String, float]:
	var home: Array[Club] = world.clubs_in_league(world.leagues[0].id)
	home.sort_custom(func(a: Club, b: Club) -> bool: return a.strength > b.strength)
	var field: Dictionary[String, float] = {}
	for club: Club in home.slice(0, cup.home_qualifiers):
		field[club.id] = club.strength
	for club: Club in cups.foreign_clubs:
		field[club.id] = club.strength
	return field


static func nation_entrants(cups: CupWorld) -> Dictionary[String, float]:
	var field: Dictionary[String, float] = {}
	for nation: Nation in cups.nations:
		field[nation.id] = nation.strength
	return field


## The team the player plays for in `cup` this season, or "".
static func player_team(
	cup: CupDefinition,
	record: SeasonRecord,
	field: Dictionary[String, float],
	rules: CareerRules,
	cups: CupWorld
) -> String:
	if record.age < rules.senior_age:
		return ""
	if cup.is_for_nations():
		return cups.home_nation if record.overall_after >= cup.call_up_min else ""
	return record.club_id if field.has(record.club_id) else ""


## Results of every cup held in the season of `record`.
static func results_for(
	record: SeasonRecord, world: ClubWorld, rules: CareerRules, cups: CupWorld
) -> Array[CupSim.Result]:
	var results: Array[CupSim.Result] = []
	for cup: CupDefinition in cups.cups:
		if not cup.is_held(record.season_number):
			continue
		var field := (
			nation_entrants(cups)
			if cup.is_for_nations()
			else continental_entrants(cup, world, cups)
		)
		var team := player_team(cup, record, field, rules, cups)
		var added := 0.0
		if not team.is_empty():
			added = contribution(
				record.overall_after,
				record.average_rating,
				_share(record, world, rules),
				field[team],
				cups
			)
		results.append(CupSim.play(cup.id, record.season_number, field, team, added, cups))
	return results


## Plays the season's cups for the career: stores the player's cup runs and
## records news events. Returns the number of trophies won this season.
static func apply(
	career: CareerState, record: SeasonRecord, world: ClubWorld, rules: CareerRules, cups: CupWorld
) -> int:
	var trophies := 0
	for result: CupSim.Result in results_for(record, world, rules, cups):
		if result.player_team.is_empty():
			continue
		if result.cup_id == CupDefinition.NATIONS and not _has_played_for_nation(career):
			CareerEvents.record_at_season(
				career, CareerEvent.NATIONAL_CALL_UP, record, {"nation": result.player_team}
			)
		var run := CupRun.create(record.season_number, result)
		career.cup_runs.append(run)
		if run.won:
			trophies += 1
		var values := {
			"cup": result.cup_id,
			"team": result.player_team,
			"wins": result.player_wins,
			"won": run.won
		}
		CareerEvents.record_at_season(career, CareerEvent.CUP_RESULT, record, values)
	return trophies


static func _has_played_for_nation(career: CareerState) -> bool:
	for run: CupRun in career.cup_runs:
		if run.cup_id == CupDefinition.NATIONS:
			return true
	return false


## Share of the season the player was on the pitch (role and injury).
static func _share(record: SeasonRecord, world: ClubWorld, rules: CareerRules) -> float:
	var share := rules.match_share(
		SeasonContext.role_at(record.overall_after, world.club(record.club_id), rules)
	)
	if record.injured:
		share *= 1.0 - rules.value("fatigue", "missed_match_share")
	return share
