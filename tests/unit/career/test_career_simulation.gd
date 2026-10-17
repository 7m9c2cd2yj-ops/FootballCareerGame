extends GutTest
## Whole careers through the career layer (trials, offers, contracts, fatigue,
## retirement). Guards against dead ends and checks the design intent in
## docs/CAREER.md. If a data change breaks one, fix the data or update the
## target on purpose.

const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")
const CareerFixture := preload("res://tests/helpers/career_fixture.gd")
const Flow := preload("res://tests/helpers/career_flow_sim.gd")

var _balance: Balance
var _world: ClubWorld
var _rules: CareerRules
var _cups: CupWorld


func before_all() -> void:
	_balance = BalanceFixture.shipped()
	_world = CareerFixture.world()
	_rules = CareerFixture.rules(_world)
	_cups = CareerFixture.cups()


func _run(position: String, rating: float, intensity: String) -> Flow.Outcome:
	return Flow.run(position, rating, intensity, _world, _balance, _rules, _cups)


func test_no_career_ever_gets_stuck() -> void:
	for position: String in _balance.positions():
		for rating: float in [9.7, 7.5, 5.0]:
			var outcome := _run(position, rating, TrainingPlan.NORMAL)
			assert_eq(outcome.stuck_reason, "", "%s %s" % [position, rating])
			assert_true(outcome.career.retired, "%s %s retired at the end" % [position, rating])


func test_elite_careers_reach_the_top_and_the_hall_of_fame() -> void:
	for position: String in _balance.positions():
		var outcome := _run(position, 9.7, TrainingPlan.NORMAL)
		var summary := HallOfFame.summarize(outcome.career, _world, _rules)
		assert_eq(outcome.final_tier, 1, position)
		assert_true(summary.inducted, "%s score %s" % [position, summary.score])


func test_good_careers_fall_short_of_the_hall_of_fame() -> void:
	for position: String in _balance.positions():
		var summary := HallOfFame.summarize(
			_run(position, 7.5, TrainingPlan.NORMAL).career, _world, _rules
		)
		assert_false(summary.inducted, "%s score %s" % [position, summary.score])


func test_weak_careers_stay_below_the_top_tier() -> void:
	for position: String in _balance.positions():
		assert_gt(_run(position, 5.0, TrainingPlan.NORMAL).final_tier, 1, position)


func test_always_training_intensely_backfires() -> void:
	for position: String in _balance.positions():
		var normal := _run(position, 7.5, TrainingPlan.NORMAL).peak_overall
		var intense := _run(position, 7.5, TrainingPlan.INTENSE).peak_overall
		assert_lt(intense, normal, position)


func test_careers_are_deterministic() -> void:
	var first := _run("MID", 8.1, TrainingPlan.NORMAL).career.to_dict()
	assert_eq(
		JSON.stringify(_run("MID", 8.1, TrainingPlan.NORMAL).career.to_dict()),
		JSON.stringify(first)
	)


func test_elite_careers_win_trophies_and_golden_balls() -> void:
	for position: String in _balance.positions():
		var summary := HallOfFame.summarize(
			_run(position, 9.7, TrainingPlan.NORMAL).career, _world, _rules
		)
		assert_gt(summary.trophies, 0, position)
		assert_gt(summary.golden_balls, 0, position)


func test_good_careers_never_win_the_golden_ball() -> void:
	for position: String in _balance.positions():
		var summary := HallOfFame.summarize(
			_run(position, 7.5, TrainingPlan.NORMAL).career, _world, _rules
		)
		assert_eq(summary.golden_balls, 0, position)
