class_name SeasonLoop
extends RefCounted
## Plays one season: applies the progression formula, ages the player one year
## and appends a SeasonRecord to the career history.


## Returns null and appends to `errors` if the season cannot be played.
static func play_season(
	career: CareerState,
	plan: TrainingPlan,
	performance: SeasonPerformance,
	balance: Balance,
	errors: Array[String]
) -> SeasonRecord:
	if career.is_finished(balance):
		errors.append("The career has ended; no more seasons can be played")
		return null
	var plan_problems := plan.validate()
	if not plan_problems.is_empty():
		errors.append_array(plan_problems)
		return null

	var player := career.player
	var before := player.copy()
	var changes := Progression.season_changes(player, plan, performance, balance)
	Progression.apply_changes(player, changes, balance)

	var record := SeasonRecord.new()
	record.season_number = career.next_season_number()
	record.age = before.age
	record.position = player.position
	record.primary_focus = plan.primary
	record.secondary_focus = plan.secondary
	record.intensity = plan.intensity
	record.matches_played = performance.matches_played
	record.average_rating = Progression.round_value(performance.average_rating)
	record.key_moments_played = performance.key_moments_played
	record.key_moments_won = performance.key_moments_won
	record.overall_before = before.overall_rating(balance)
	record.overall_after = player.overall_rating(balance)
	for attribute: String in PlayerModel.ATTRIBUTES:
		var applied := player.attributes[attribute] - before.attributes[attribute]
		record.attribute_changes[attribute] = Progression.round_value(applied)

	player.age += 1
	career.history.append(record)
	return record
