extends GutTest
## Moment tuning validation, deterministic planning and the season rating.

const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")
const Fixture := preload("res://tests/helpers/moment_fixture.gd")

var _tuning: MomentTuning
var _balance: Balance


func before_all() -> void:
	_tuning = Fixture.tuning()
	_balance = BalanceFixture.shipped()


func _data() -> Dictionary:
	return JsonLoader.load_dictionary(MomentTuning.DEFAULT_PATH).data


func test_unknown_moment_type_in_schedule_is_rejected() -> void:
	var data := _data()
	data["schedule"]["by_position"]["FWD"] = ["penalty", "bicycle_kick"]
	assert_string_contains("\n".join(MomentTuning.validate(data)), "bicycle_kick")


func test_missing_number_is_rejected() -> void:
	var data := _data()
	var penalty: Dictionary = data["penalty"]
	penalty.erase("distance")
	assert_string_contains("\n".join(MomentTuning.validate(data)), "penalty.distance")


func test_sweet_spot_must_be_ordered() -> void:
	var data := _data()
	data["power"]["sweet_min"] = 0.9
	assert_string_contains("\n".join(MomentTuning.validate(data)), "sweet_min")


func test_every_position_has_a_schedule() -> void:
	for position: String in _balance.positions():
		assert_true(_tuning.has_schedule(position), position)


func test_variety_is_deterministic_and_spread() -> void:
	var seen: Dictionary[float, bool] = {}
	for season: int in 50:
		var value := Variety.unit(season, 2, 7)
		assert_eq(Variety.unit(season, 2, 7), value)
		assert_true(value >= 0.0 and value < 1.0)
		seen[value] = true
	assert_gt(seen.size(), 45)


func test_academy_seasons_have_fewer_moments() -> void:
	var player := PlayerModel.create("Test", "FWD", _balance)
	var academy := MomentPlanner.moment_count(player, _tuning)
	player.age = 25
	assert_gt(MomentPlanner.moment_count(player, _tuning), academy)


func test_moment_types_rotate_by_season() -> void:
	var player := PlayerModel.create("Test", "FWD", _balance)
	var schedule := _tuning.schedule_for("FWD")
	var season_one := MomentPlanner.plan_season(player, 1, 30.0, _balance, _tuning)
	var season_two := MomentPlanner.plan_season(player, 2, 30.0, _balance, _tuning)
	assert_eq(season_one[0].moment_type, schedule[0])
	assert_eq(season_two[0].moment_type, schedule[1])


func test_planning_is_deterministic() -> void:
	var player := PlayerModel.create("Test", "GK", _balance)
	var first := MomentPlanner.plan_season(player, 7, 40.0, _balance, _tuning)
	var again := MomentPlanner.plan_season(player, 7, 40.0, _balance, _tuning)
	for i: int in first.size():
		assert_eq(again[i].shot_target, first[i].shot_target)
		assert_eq(again[i].distance, first[i].distance)


func test_specs_carry_player_skills_and_opposition() -> void:
	var player := PlayerModel.create("Test", "MID", _balance)
	var spec := MomentPlanner.plan_season(player, 1, 49.5, _balance, _tuning)[0]
	assert_almost_eq(spec.skill("passing"), player.attributes["passing"] / 99.0, 1e-6)
	assert_almost_eq(spec.opponent_skill, 0.5, 1e-6)


func test_opponent_shots_are_always_on_target() -> void:
	var player := PlayerModel.create("Test", "GK", _balance)
	for season: int in range(1, 40):
		for spec: MomentSpec in MomentPlanner.plan_season(player, season, 50.0, _balance, _tuning):
			if spec.is_save():
				assert_true(ShotModel.in_goal(spec.shot_target, _tuning), str(spec.shot_target))


func test_free_kick_walls_stay_within_bounds() -> void:
	var player := PlayerModel.create("Test", "MID", _balance)
	var limit := _tuning.value("free_kick", "wall_max_offset")
	for season: int in range(1, 40):
		for spec: MomentSpec in MomentPlanner.plan_season(player, season, 50.0, _balance, _tuning):
			if spec.moment_type == MomentSpec.FREE_KICK:
				assert_between(spec.wall_center_x, -limit, limit)
				assert_between(spec.distance, 18.0, 28.0)


func _result(moment_type: String, outcome: String, quality: float) -> MomentResult:
	var spec := Fixture.spec(moment_type, 0.5, 0.5)
	return MomentResult.create(spec, outcome, quality, Vector2.ZERO, Vector2.ZERO)


func test_success_depends_on_the_players_role() -> void:
	assert_true(_result(MomentSpec.PENALTY, MomentResult.GOAL, 1.0).success)
	assert_false(_result(MomentSpec.PENALTY, MomentResult.SAVED, 1.0).success)
	assert_true(_result(MomentSpec.SAVE, MomentResult.SAVED, 1.0).success)
	assert_false(_result(MomentSpec.SAVE, MomentResult.CONCEDED, 1.0).success)


func test_season_rating_rises_with_good_moments() -> void:
	var expected := SeasonPerformance.create(34, 6.0)
	var none: Array[MomentResult] = []
	assert_eq(SeasonMoments.performance(expected, none, _tuning), expected)
	var perfect: Array[MomentResult] = [
		_result(MomentSpec.PENALTY, MomentResult.GOAL, 1.0),
		_result(MomentSpec.FREE_KICK, MomentResult.GOAL, 1.0),
	]
	var bad: Array[MomentResult] = [
		_result(MomentSpec.PENALTY, MomentResult.MISSED, 0.0),
		_result(MomentSpec.FREE_KICK, MomentResult.BLOCKED, 0.0),
	]
	assert_eq(SeasonMoments.performance(expected, perfect, _tuning).average_rating, 10.0)
	assert_almost_eq(SeasonMoments.performance(expected, bad, _tuning).average_rating, 4.8, 1e-6)
	assert_eq(SeasonMoments.successes(perfect), 2)


func test_season_in_progress_walks_through_moments() -> void:
	var career := CareerState.start("Test", "FWD", _balance)
	var plan := TrainingPlan.create("shooting", "pace")
	var expected := SeasonPerformance.expected_for(career.player, _balance)
	var season := SeasonInProgress.start(career, plan, expected, 30.0, _balance, _tuning)
	assert_eq(season.moments.size(), MomentPlanner.moment_count(career.player, _tuning))
	while not season.is_complete():
		var spec := season.current_moment()
		season.record(MomentResult.create(spec, MomentResult.GOAL, 1.0, Vector2.ZERO, Vector2.ZERO))
	assert_null(season.current_moment())
	assert_gt(season.performance(_tuning).average_rating, expected.average_rating)
