extends GutTest
## Career rules record the right events at the moment things happen.

const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")
const CareerFixture := preload("res://tests/helpers/career_fixture.gd")

var _balance: Balance
var _world: ClubWorld
var _rules: CareerRules


func before_all() -> void:
	_balance = BalanceFixture.shipped()
	_world = CareerFixture.world()
	_rules = CareerFixture.rules(_world)


func _types(career: CareerState) -> Array[String]:
	var types: Array[String] = []
	for event: CareerEvent in career.events:
		types.append(event.type)
	return types


func _play(career: CareerState, rating: float, intensity: String = TrainingPlan.NORMAL) -> void:
	var errors: Array[String] = []
	var plan := TrainingPlan.create("shooting", "pace", intensity)
	var expected := SeasonContext.expected_performance(career, _world, _balance, _rules)
	var performance := SeasonPerformance.create(expected.matches_played, rating)
	CareerSeason.play(career, plan, performance, _world, _balance, _rules, errors)


func _pro(club_id: String, age: int, rating: float) -> CareerState:
	var career := CareerFixture.career_at("FWD", age, rating, club_id, _balance)
	career.contract = CareerFixture.contract(club_id, 3, 500)
	career.trial_used = true
	return career


func test_every_season_is_news() -> void:
	var career := _pro("tidewell", 24, 55.0)
	_play(career, 7.0)
	var event := career.events[0]
	assert_eq(event.type, CareerEvent.SEASON_PLAYED)
	assert_eq(event.season_number, 1)
	assert_eq(event.age, 24)
	assert_eq(event.values["club"], "tidewell")
	assert_eq(event.values["rating"], 7.0)


func test_crossing_a_milestone_is_news_once() -> void:
	var career := _pro("tidewell", 20, 57.0)
	_play(career, 9.5)
	assert_true(_types(career).has(CareerEvent.MILESTONE))
	var count := _types(career).count(CareerEvent.MILESTONE)
	_play(career, 9.5)
	assert_eq(_types(career).count(CareerEvent.MILESTONE), count, "60 is not reported again")


func test_injury_is_news() -> void:
	var career := _pro("tidewell", 24, 55.0)
	career.fatigue = 70.0
	_play(career, 6.0, TrainingPlan.INTENSE)
	assert_true(_types(career).has(CareerEvent.INJURY))


func test_top_tier_debut_is_reported_once() -> void:
	var career := _pro("brackenford", 24, 80.0)
	_play(career, 7.0)
	_play(career, 7.0)
	assert_eq(_types(career).count(CareerEvent.TOP_TIER_DEBUT), 1)


func test_trials_are_news() -> void:
	var passed := CareerFixture.career_at("MID", 16, 40.0, _rules.academy_club, _balance)
	Trials.take(passed, _world.club("fernwick"), _world, _balance, _rules)
	assert_eq(_types(passed), [CareerEvent.TRIAL_PASSED] as Array[String])
	var failed := CareerFixture.career_at("MID", 16, 10.0, _rules.academy_club, _balance)
	Trials.take(failed, _world.club("brackenford"), _world, _balance, _rules)
	assert_eq(_types(failed), [CareerEvent.TRIAL_FAILED] as Array[String])
	assert_eq(failed.events[0].values["academy"], _rules.academy_club)


func test_transfer_and_renewal_are_news() -> void:
	var career := _pro("tidewell", 24, 75.0)
	OfferEngine.accept(
		career, OfferEngine.build_offer(career, _world.club("brackenford"), 70, _balance, _rules)
	)
	var transfer := career.events[-1]
	assert_eq(transfer.type, CareerEvent.TRANSFER)
	assert_eq(transfer.values["from_club"], "tidewell")
	assert_eq(transfer.values["fee"], 500.0)
	career.contract.years_left = 0
	var renewal := OfferEngine.build_offer(career, _world.club("brackenford"), 70, _balance, _rules)
	renewal.is_renewal = true
	OfferEngine.accept(career, renewal)
	assert_eq(career.events[-1].type, CareerEvent.RENEWAL)


func test_retirement_is_news_with_the_verdict() -> void:
	var career := _pro("tidewell", 34, 60.0)
	CareerSeason.retire(career, _world, _rules)
	var event := career.events[-1]
	assert_eq(event.type, CareerEvent.RETIREMENT)
	assert_false(event.values["inducted"])


func test_event_log_survives_json_and_rejects_bad_entries() -> void:
	var career := _pro("tidewell", 24, 55.0)
	_play(career, 8.3)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(career.to_dict()))
	assert_eq(CareerState.validate_dict(parsed, _balance, _world), [] as Array[String])
	assert_eq(
		JSON.stringify(CareerState.from_dict(parsed).to_dict()), JSON.stringify(career.to_dict())
	)
	var bad: Dictionary = parsed["events"][0]
	bad["type"] = "alien_invasion"
	assert_string_contains(
		"\n".join(CareerState.validate_dict(parsed, _balance, _world)), "alien_invasion"
	)


func test_missing_event_field_is_rejected() -> void:
	var data := CareerEvent.create(CareerEvent.MILESTONE, 1, 20, {"club": "tidewell"}).to_dict()
	assert_string_contains(CareerEvent.validate_dict(data)[0], "milestone")


func test_v2_save_gains_season_news_on_migration() -> void:
	var career := _pro("tidewell", 24, 55.0)
	_play(career, 7.0)
	_play(career, 7.0)
	var data := career.to_dict()
	data["version"] = 2
	data.erase("events")
	var migrated := CareerMigration.migrate(data, _rules.academy_club)
	assert_eq(CareerState.validate_dict(migrated, _balance, _world), [] as Array[String])
	var restored := CareerState.from_dict(migrated)
	assert_eq(restored.events.size(), 2)
	assert_eq(restored.events[1].values["overall_after"], float(career.history[1].overall_after))
