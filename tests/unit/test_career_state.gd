extends GutTest
## Career save data: round trips and rejection of corrupted or foreign data.

const CareerFixture := preload("res://tests/helpers/career_fixture.gd")
const Fixture := preload("res://tests/helpers/balance_fixture.gd")

var _balance: Balance
var _world: ClubWorld


func before_each() -> void:
	_balance = Fixture.shipped()
	_world = CareerFixture.world()


func _career_with_seasons(count: int) -> CareerState:
	var career := CareerState.start("Test", "DEF", _balance, "copperlake")
	var errors: Array[String] = []
	for i: int in count:
		var plan := TrainingAdvisor.recommended_plan(career.player, _balance)
		var performance := SeasonPerformance.expected_for(career.player, _balance)
		SeasonLoop.play_season(career, plan, performance, _balance, errors)
	return career


func _through_json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


func test_round_trip_through_json_keeps_everything() -> void:
	var career := _career_with_seasons(3)
	var parsed := _through_json(career.to_dict())
	assert_eq(CareerState.validate_dict(parsed, _balance, _world).size(), 0)
	var restored := CareerState.from_dict(parsed)
	assert_eq(_through_json(restored.to_dict()), parsed)
	assert_eq(restored.history.size(), 3)


func test_restored_career_continues_identically() -> void:
	var original := _career_with_seasons(4)
	var restored := CareerState.from_dict(_through_json(original.to_dict()))
	var errors: Array[String] = []
	for career: CareerState in [original, restored]:
		var plan := TrainingPlan.create("defending", "physical")
		var performance := SeasonPerformance.create(30, 7.0)
		SeasonLoop.play_season(career, plan, performance, _balance, errors)
	assert_eq(restored.to_dict(), original.to_dict())


func test_rejects_unknown_version() -> void:
	var data := _career_with_seasons(1).to_dict()
	data["version"] = 99
	assert_string_contains(CareerState.validate_dict(data, _balance, _world)[0], "version")


func test_rejects_missing_player() -> void:
	var data := _career_with_seasons(1).to_dict()
	data.erase("player")
	assert_string_contains(CareerState.validate_dict(data, _balance, _world)[0], "player")


func test_rejects_corrupt_history_entry() -> void:
	var data := _career_with_seasons(2).to_dict()
	data["history"][1]["overall_after"] = "ninety"
	assert_string_contains(
		"\n".join(CareerState.validate_dict(data, _balance, _world)), "overall_after"
	)


func test_rejects_non_object_history_entry() -> void:
	var data := _through_json(_career_with_seasons(1).to_dict())
	var history: Array = data["history"]
	history.append(42)
	assert_string_contains("\n".join(CareerState.validate_dict(data, _balance, _world)), "history")
