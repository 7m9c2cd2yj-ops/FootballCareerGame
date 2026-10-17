class_name CareerSeason
extends RefCounted
## Plays a season inside a career: checks the player may play, runs SeasonLoop,
## then the end-of-season steps (contract year, fatigue and injury, forced
## retirement at max age). Also handles voluntary retirement.


## Empty string if the next season can be played, otherwise why not.
static func blocker(career: CareerState, balance: Balance, rules: CareerRules) -> String:
	if career.is_finished(balance):
		return "Your career is over"
	if Trials.is_due(career, rules):
		return "Trials are open: pick a club in the Clubs app on your phone"
	if career.contract != null and career.contract.has_expired():
		return "Your contract has ended: choose a club in the Clubs app on your phone"
	return ""


static func play(
	career: CareerState,
	plan: TrainingPlan,
	performance: SeasonPerformance,
	world: ClubWorld,
	balance: Balance,
	rules: CareerRules,
	cups: CupWorld,
	errors: Array[String]
) -> SeasonRecord:
	var reason := blocker(career, balance, rules)
	if not reason.is_empty():
		errors.append(reason)
		return null
	var share := SeasonContext.match_share(career, world, balance, rules)
	var played_injured := career.injured_next_season
	var age := career.player.age
	var record := SeasonLoop.play_season(career, plan, performance, balance, errors)
	if record == null:
		return null
	record.club_id = career.club_id
	record.injured = played_injured
	_end_of_season(career, plan, share, age, rules)
	record.fatigue_after = career.fatigue
	CareerEvents.record_season(career, record, world, rules)
	var trophies := CupSeason.apply(career, record, world, rules, cups)
	GoldenBall.apply(career, record, trophies, rules, cups)
	if career.player.age >= balance.max_age:
		career.retired = true
		CareerEvents.record_retirement(career, world, rules)
	return record


static func can_retire(career: CareerState, rules: CareerRules) -> bool:
	return not career.retired and career.player.age >= int(rules.value("retirement", "min_age"))


static func retire(career: CareerState, world: ClubWorld, rules: CareerRules) -> bool:
	if not can_retire(career, rules):
		return false
	career.retired = true
	CareerEvents.record_retirement(career, world, rules)
	return true


## `age` is the player's age during the season just played.
static func _end_of_season(
	career: CareerState, plan: TrainingPlan, match_share: float, age: int, rules: CareerRules
) -> void:
	if career.contract != null:
		career.contract.years_left -= 1
	var load_share := match_share
	if age < rules.senior_age:
		load_share = 1.0
	Fatigue.apply_season(career, age, plan.intensity, load_share, rules)
