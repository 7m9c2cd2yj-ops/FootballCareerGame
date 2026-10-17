extends RefCounted
## Plays a whole career with one fixed strategy and returns the overall rating
## at every age. Shared by the tuning tests and tools/balance_report.gd.

## Pass as `match_rating` to use the deterministic expected rating each season.
const EXPECTED_RATING := -1.0


## `fixed_plan` null means "follow TrainingAdvisor every season".
static func overall_by_age(
	position: String, match_rating: float, fixed_plan: TrainingPlan, balance: Balance
) -> Dictionary[int, int]:
	var career := CareerState.start("Sim", position, balance)
	var overall: Dictionary[int, int] = {career.player.age: career.player.overall_rating(balance)}
	var errors: Array[String] = []
	while not career.is_finished(balance):
		var plan := fixed_plan
		if plan == null:
			plan = TrainingAdvisor.recommended_plan(career.player, balance)
		var performance := SeasonPerformance.expected_for(career.player, balance)
		if match_rating != EXPECTED_RATING:
			var matches := balance.matches_for_age(career.player.age)
			performance = SeasonPerformance.create(matches, match_rating)
		if SeasonLoop.play_season(career, plan, performance, balance, errors) == null:
			push_error("Simulated season failed: %s" % "; ".join(errors))
			break
		overall[career.player.age] = career.player.overall_rating(balance)
	return overall


## Highest overall in `overall_by_age` output, and the first age it was reached.
static func peak(overall: Dictionary[int, int]) -> Vector2i:
	var best := Vector2i(0, 0)
	for age: int in overall:
		if overall[age] > best.y:
			best = Vector2i(age, overall[age])
	return best
