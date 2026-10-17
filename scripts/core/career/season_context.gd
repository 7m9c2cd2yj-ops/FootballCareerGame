class_name SeasonContext
extends RefCounted
## Where and how much the player plays next season: competition strength,
## role at the club and the number of matches (after any injury).
## Before senior_age the academy/youth tables in balance.json apply; from
## senior_age the club's league strength and the player's role decide.


static func competition_strength(
	career: CareerState, world: ClubWorld, balance: Balance, rules: CareerRules
) -> float:
	if career.player.age < rules.senior_age:
		return balance.competition_strength_for_age(career.player.age)
	return world.league_of(career.club_id).strength


## Starter, rotation or bench, from overall versus the club's strength.
static func role(
	career: CareerState, world: ClubWorld, balance: Balance, rules: CareerRules
) -> String:
	var club := world.club(career.club_id)
	return role_at(career.player.overall_rating(balance), club, rules)


static func role_at(overall: int, club: Club, rules: CareerRules) -> String:
	var gap := overall - club.strength
	if gap >= -rules.value("roles", "starter_margin"):
		return CareerRules.STARTER
	if gap >= -rules.value("roles", "rotation_margin"):
		return CareerRules.ROTATION
	return CareerRules.BENCH


## Share of the season's matches the player plays (youth players play them all).
static func match_share(
	career: CareerState, world: ClubWorld, balance: Balance, rules: CareerRules
) -> float:
	var share := 1.0
	if career.player.age >= rules.senior_age:
		share = rules.match_share(role(career, world, balance, rules))
	if career.injured_next_season:
		share *= 1.0 - rules.value("fatigue", "missed_match_share")
	return share


## The deterministic baseline performance for the coming season.
static func expected_performance(
	career: CareerState, world: ClubWorld, balance: Balance, rules: CareerRules
) -> SeasonPerformance:
	var player := career.player
	var strength := competition_strength(career, world, balance, rules)
	var rating := SeasonPerformance.expected_rating(
		player.overall_rating(balance), strength, balance
	)
	var share := match_share(career, world, balance, rules)
	var expected := SeasonPerformance.create(
		roundi(balance.matches_for_age(player.age) * share), rating
	)
	if career.injured_next_season:
		expected.training_share = 1.0 - rules.value("fatigue", "missed_match_share")
	return expected
