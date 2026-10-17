extends GutTest
## Trials, season context, fatigue and injuries, retirement and Hall of Fame.

const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")
const CareerFixture := preload("res://tests/helpers/career_fixture.gd")

var _balance: Balance
var _world: ClubWorld
var _rules: CareerRules


func before_all() -> void:
	_balance = BalanceFixture.shipped()
	_world = CareerFixture.world()
	_rules = CareerFixture.rules(_world)


func _academy_player(age: int, rating: float) -> CareerState:
	return CareerFixture.career_at("MID", age, rating, _rules.academy_club, _balance)


func _record_with_moments(won: int) -> SeasonRecord:
	var record := SeasonRecord.new()
	record.key_moments_won = won
	record.club_id = _rules.academy_club
	return record


func test_trial_is_due_once_at_the_trial_age() -> void:
	assert_false(Trials.is_due(_academy_player(_rules.trial_age - 1, 30.0), _rules))
	var career := _academy_player(_rules.trial_age, 30.0)
	assert_true(Trials.is_due(career, _rules))
	Trials.take(career, _world.club("fernwick"), _world, _balance, _rules)
	assert_false(Trials.is_due(career, _rules))


func test_key_moments_raise_the_trial_score() -> void:
	var career := _academy_player(_rules.trial_age, 30.0)
	var base := Trials.trial_score(career, _balance, _rules)
	career.history.append(_record_with_moments(3))
	var bonus := _rules.value("trial", "bonus_per_key_moment_won")
	assert_eq(Trials.trial_score(career, _balance, _rules), base + 3 * bonus)


func test_passing_a_trial_signs_a_youth_contract_there() -> void:
	var career := _academy_player(_rules.trial_age, 40.0)
	var club := _world.club("brackenford")
	assert_true(Trials.take(career, club, _world, _balance, _rules))
	assert_eq(career.club_id, "brackenford")
	assert_true(career.contract.is_youth)
	assert_eq(career.contract.years_left, int(_rules.value("contract", "youth_years")))


func test_failing_a_trial_falls_back_to_the_academy_club() -> void:
	var career := _academy_player(_rules.trial_age, 20.0)
	assert_false(Trials.take(career, _world.club("brackenford"), _world, _balance, _rules))
	assert_eq(career.club_id, _rules.academy_club)
	assert_not_null(career.contract)


func test_blockers_explain_why_a_season_cannot_start() -> void:
	var career := _academy_player(_rules.trial_age, 30.0)
	assert_string_contains(CareerSeason.blocker(career, _balance, _rules), "Trials")
	career.contract = CareerFixture.contract(_rules.academy_club, 0, 10)
	assert_string_contains(CareerSeason.blocker(career, _balance, _rules), "contract has ended")
	career.contract.years_left = 1
	assert_eq(CareerSeason.blocker(career, _balance, _rules), "")


func test_seniors_face_their_league_and_youngsters_the_age_table() -> void:
	var youth := _academy_player(14, 30.0)
	var youth_strength := SeasonContext.competition_strength(youth, _world, _balance, _rules)
	assert_eq(youth_strength, _balance.competition_strength_for_age(14))
	var senior := CareerFixture.career_at("MID", 24, 70.0, "brackenford", _balance)
	var league := _world.league_of("brackenford").strength
	assert_eq(SeasonContext.competition_strength(senior, _world, _balance, _rules), league)


func test_bench_players_play_fewer_matches() -> void:
	var starter := CareerFixture.career_at("MID", 24, 90.0, "brackenford", _balance)
	var bench := CareerFixture.career_at("MID", 24, 50.0, "brackenford", _balance)
	var full := SeasonContext.expected_performance(starter, _world, _balance, _rules)
	var few := SeasonContext.expected_performance(bench, _world, _balance, _rules)
	assert_gt(full.matches_played, few.matches_played)


func test_season_ticks_the_contract_and_records_the_club() -> void:
	var career := CareerFixture.career_at("FWD", 24, 70.0, "tidewell", _balance)
	career.contract = CareerFixture.contract("tidewell", 2, 100)
	var errors: Array[String] = []
	var plan := TrainingPlan.create("shooting", "pace")
	var performance := SeasonContext.expected_performance(career, _world, _balance, _rules)
	var record := CareerSeason.play(career, plan, performance, _world, _balance, _rules, errors)
	assert_not_null(record, "\n".join(errors))
	assert_eq(record.club_id, "tidewell")
	assert_eq(career.contract.years_left, 1)
	assert_eq(career.player.age, 25)


func test_normal_training_is_sustainable_for_a_starter() -> void:
	var fatigue := 0.0
	for season: int in 10:
		fatigue = Fatigue.after_season(fatigue, 24, TrainingPlan.NORMAL, 1.0, _rules)
	assert_false(Fatigue.causes_injury(fatigue, _rules))


func test_back_to_back_intense_seasons_cause_an_injury() -> void:
	var first := Fatigue.after_season(0.0, 24, TrainingPlan.INTENSE, 1.0, _rules)
	assert_false(Fatigue.causes_injury(first, _rules))
	var second := Fatigue.after_season(first, 24, TrainingPlan.INTENSE, 1.0, _rules)
	assert_true(Fatigue.causes_injury(second, _rules))


func test_veterans_tire_faster() -> void:
	var young := Fatigue.season_load(24, TrainingPlan.NORMAL, 1.0, _rules)
	assert_gt(Fatigue.season_load(35, TrainingPlan.NORMAL, 1.0, _rules), young)


func test_injury_costs_half_a_season_then_fatigue_resets() -> void:
	var career := CareerFixture.career_at("FWD", 24, 70.0, "tidewell", _balance)
	career.fatigue = 70.0
	var healthy := SeasonContext.expected_performance(career, _world, _balance, _rules)
	assert_true(Fatigue.apply_season(career, 24, TrainingPlan.INTENSE, 1.0, _rules))
	assert_eq(career.fatigue, _rules.value("fatigue", "after_injury"))
	var injured := SeasonContext.expected_performance(career, _world, _balance, _rules)
	assert_eq(injured.matches_played, roundi(healthy.matches_played * 0.5))


func test_retirement_rules() -> void:
	var career := CareerFixture.career_at("FWD", 32, 70.0, "tidewell", _balance)
	assert_false(CareerSeason.retire(career, _world, _rules))
	career.player.age = int(_rules.value("retirement", "min_age"))
	assert_true(CareerSeason.retire(career, _world, _rules))
	assert_true(career.is_finished(_balance))
	assert_string_contains(CareerSeason.blocker(career, _balance, _rules), "over")


func test_reaching_max_age_retires_the_player() -> void:
	var career := CareerFixture.career_at("FWD", _balance.max_age - 1, 60.0, "tidewell", _balance)
	career.contract = CareerFixture.contract("tidewell", 1, 10)
	var errors: Array[String] = []
	var plan := TrainingPlan.create("shooting", "pace")
	var performance := SeasonContext.expected_performance(career, _world, _balance, _rules)
	CareerSeason.play(career, plan, performance, _world, _balance, _rules, errors)
	assert_true(career.retired)


func _season(club_id: String, age: int, overall: int, moments_won: int) -> SeasonRecord:
	var record := SeasonRecord.new()
	record.club_id = club_id
	record.age = age
	record.overall_after = overall
	record.key_moments_won = moments_won
	return record


func test_hall_of_fame_rewards_elite_careers() -> void:
	var legend := CareerFixture.career_at("FWD", 36, 90.0, "brackenford", _balance)
	for age: int in range(18, 36):
		legend.history.append(_season("brackenford", age, 95, 3))
	var summary := HallOfFame.summarize(legend, _world, _rules)
	assert_eq(summary.peak_overall, 95)
	assert_eq(summary.top_tier_seasons, 18)
	assert_true(summary.inducted, "score %s" % summary.score)


func test_hall_of_fame_needs_a_high_peak() -> void:
	var journeyman := CareerFixture.career_at("FWD", 36, 70.0, "brackenford", _balance)
	for age: int in range(18, 36):
		journeyman.history.append(_season("brackenford", age, 80, 4))
	assert_false(HallOfFame.summarize(journeyman, _world, _rules).inducted)
