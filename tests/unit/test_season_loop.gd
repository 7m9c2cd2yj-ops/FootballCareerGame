extends GutTest
## Playing seasons: ageing, history records and refusal of invalid seasons.

const Fixture := preload("res://tests/helpers/balance_fixture.gd")

var _balance: Balance
var _career: CareerState
var _errors: Array[String]


func before_each() -> void:
	_balance = Fixture.shipped()
	_career = CareerState.start("Test", "FWD", _balance)
	_errors = []


func _play(plan: TrainingPlan) -> SeasonRecord:
	var performance := SeasonPerformance.expected_for(_career.player, _balance)
	return SeasonLoop.play_season(_career, plan, performance, _balance, _errors)


func test_season_ages_player_and_records_history() -> void:
	var record := _play(TrainingPlan.create("shooting", "pace"))
	assert_not_null(record)
	assert_eq(_career.player.age, _balance.start_age + 1)
	assert_eq(_career.history.size(), 1)
	assert_eq(record.season_number, 1)
	assert_eq(record.age, _balance.start_age)
	assert_eq(record.primary_focus, "shooting")
	assert_gt(record.overall_after, record.overall_before)


func test_record_changes_match_player_attributes() -> void:
	var before := _career.player.copy()
	var record := _play(TrainingPlan.create("shooting", "pace"))
	for attribute: String in PlayerModel.ATTRIBUTES:
		var expected := before.attributes[attribute] + record.attribute_changes[attribute]
		assert_almost_eq(_career.player.attributes[attribute], expected, 0.011)


func test_season_numbers_increase() -> void:
	for i: int in 3:
		_play(TrainingPlan.create("shooting", "pace"))
	assert_eq(_career.history[2].season_number, 3)
	assert_eq(_career.next_season_number(), 4)


func test_invalid_plan_changes_nothing() -> void:
	var before := _career.to_dict()
	assert_null(_play(TrainingPlan.create("pace", "pace")))
	assert_gt(_errors.size(), 0)
	assert_eq(_career.to_dict(), before)


func test_no_seasons_after_max_age() -> void:
	_career.player.age = _balance.max_age
	assert_true(_career.is_finished(_balance))
	assert_null(_play(TrainingPlan.create("shooting", "pace")))
	assert_string_contains(_errors[0], "career has ended")
