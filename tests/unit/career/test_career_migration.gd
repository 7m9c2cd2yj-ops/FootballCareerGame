extends GutTest
## Save format v2 round trips and the v1 -> v2 migration.

const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")
const CareerFixture := preload("res://tests/helpers/career_fixture.gd")

var _balance: Balance
var _world: ClubWorld
var _rules: CareerRules


func before_all() -> void:
	_balance = BalanceFixture.shipped()
	_world = CareerFixture.world()
	_rules = CareerFixture.rules(_world)


func _v1_save() -> Dictionary:
	var player := PlayerModel.create("Old", "MID", _balance)
	var season := {
		"season_number": 1,
		"age": 8,
		"position": "MID",
		"primary_focus": "passing",
		"secondary_focus": "dribbling",
		"matches_played": 20,
		"average_rating": 6.0,
		"overall_before": 12,
		"overall_after": 15,
		"attribute_changes": {"passing": 3.0},
	}
	player.age = 9
	return {"version": 1, "player": player.to_dict(), "history": [season]}


func test_v1_save_migrates_to_a_valid_v2_career() -> void:
	var original := _v1_save()
	var migrated := CareerMigration.migrate(original, _rules.academy_club)
	assert_eq(int(migrated["version"]), CareerState.FORMAT_VERSION)
	assert_eq(CareerState.validate_dict(migrated, _balance, _world), [] as Array[String])
	var career := CareerState.from_dict(migrated)
	assert_eq(career.club_id, _rules.academy_club)
	assert_eq(career.history[0].intensity, TrainingPlan.NORMAL)
	assert_eq(career.history[0].overall_after, 15)
	assert_eq(int(original["version"]), 1, "the input is not modified")


func test_current_saves_are_left_alone() -> void:
	var career := CareerState.start("Now", "GK", _balance, _rules.academy_club)
	var data := career.to_dict()
	assert_eq(CareerMigration.migrate(data, _rules.academy_club), data)


func test_future_versions_are_rejected() -> void:
	var data := CareerState.start("Now", "GK", _balance, _rules.academy_club).to_dict()
	data["version"] = 99
	var migrated := CareerMigration.migrate(data, _rules.academy_club)
	var problems := CareerState.validate_dict(migrated, _balance, _world)
	assert_string_contains(problems[0], "version")


func test_full_career_round_trips_through_json() -> void:
	var career := CareerFixture.career_at("FWD", 24, 75.0, "tidewell", _balance)
	career.contract = CareerFixture.contract("tidewell", 2, 700)
	career.fatigue = 33.5
	career.trial_used = true
	var offer := OfferEngine.build_offer(career, _world.club("brackenford"), 70.0, _balance, _rules)
	OfferEngine.accept(career, offer)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(career.to_dict()))
	assert_eq(CareerState.validate_dict(parsed, _balance, _world), [] as Array[String])
	var restored := CareerState.from_dict(parsed)
	assert_eq(JSON.stringify(restored.to_dict()), JSON.stringify(career.to_dict()))


func test_unknown_club_in_save_is_rejected() -> void:
	var data := CareerState.start("Now", "GK", _balance, _rules.academy_club).to_dict()
	data["club_id"] = "real_club_fc"
	assert_string_contains("\n".join(CareerState.validate_dict(data, _balance, _world)), "club_id")
