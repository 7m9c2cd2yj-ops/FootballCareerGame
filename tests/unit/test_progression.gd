extends GutTest
## The growth formula: deterministic, bounded, and shaped by age, focus and form.

const Fixture := preload("res://tests/helpers/balance_fixture.gd")

var _balance: Balance


func before_each() -> void:
	_balance = Fixture.shipped()


func _player(position: String, age: int, value: float) -> PlayerModel:
	var player := PlayerModel.create("Test", position, _balance)
	player.age = age
	for attribute: String in PlayerModel.ATTRIBUTES:
		player.attributes[attribute] = value
	return player


func _season(rating: float, age: int) -> SeasonPerformance:
	return SeasonPerformance.create(_balance.matches_for_age(age), rating)


func test_headroom_is_full_at_minimum_and_floor_at_maximum() -> void:
	assert_almost_eq(Progression.headroom(_balance.attribute_min, _balance), 1.0, 0.0001)
	assert_eq(Progression.headroom(_balance.attribute_max, _balance), _balance.headroom_floor)


func test_headroom_shrinks_as_value_rises() -> void:
	var previous := 2.0
	for value: float in [1.0, 20.0, 40.0, 60.0, 80.0, 95.0]:
		var room := Progression.headroom(value, _balance)
		assert_lt(room, previous, "headroom at %s" % value)
		previous = room


func test_no_performance_bonus_at_or_below_baseline() -> void:
	var at_baseline := _season(_balance.performance_baseline, 20)
	assert_eq(Progression.performance_bonus(at_baseline, 34, _balance), 0.0)
	assert_eq(Progression.performance_bonus(_season(2.0, 20), 34, _balance), 0.0)


func test_performance_bonus_scales_with_rating_and_appearances() -> void:
	var full := Progression.performance_bonus(SeasonPerformance.create(34, 8.0), 34, _balance)
	var half := Progression.performance_bonus(SeasonPerformance.create(17, 8.0), 34, _balance)
	assert_almost_eq(full, 2.0 * _balance.performance_gain_per_point, 0.0001)
	assert_almost_eq(half, full / 2.0, 0.0001)


func test_same_inputs_give_same_changes() -> void:
	var player := _player("MID", 17, 40.0)
	var plan := TrainingPlan.create("passing", "dribbling")
	var first := Progression.season_changes(player, plan, _season(7.3, 17), _balance)
	for i: int in 5:
		assert_eq(Progression.season_changes(player, plan, _season(7.3, 17), _balance), first)


func test_primary_beats_secondary_beats_other() -> void:
	var player := _player("FWD", 14, 30.0)
	var plan := TrainingPlan.create("shooting", "pace")
	var changes := Progression.season_changes(player, plan, _season(6.0, 14), _balance)
	assert_gt(changes["shooting"], changes["pace"])
	assert_gt(changes["pace"], changes["dribbling"])
	assert_gt(changes["dribbling"], 0.0)


func test_good_form_only_develops_attributes_the_position_uses() -> void:
	var player := _player("FWD", 20, 50.0)
	var plan := TrainingPlan.create("passing", "physical")
	var calm := Progression.season_changes(player, plan, _season(6.0, 20), _balance)
	var great := Progression.season_changes(player, plan, _season(9.0, 20), _balance)
	assert_gt(great["shooting"], calm["shooting"])
	# FWD weights defending at 0, so form does not change it.
	assert_eq(great["defending"], calm["defending"])


func test_veterans_decline_fastest_in_pace() -> void:
	var player := _player("MID", 35, 80.0)
	var plan := TrainingPlan.create("passing", "shooting")
	var changes := Progression.season_changes(player, plan, _season(6.0, 35), _balance)
	assert_lt(changes["pace"], 0.0)
	assert_lt(changes["pace"], changes["dribbling"])


func test_training_softens_decline() -> void:
	var player := _player("MID", 35, 80.0)
	var focused := TrainingPlan.create("pace", "physical")
	var unfocused := TrainingPlan.create("passing", "shooting")
	var with_focus := Progression.season_changes(player, focused, _season(6.0, 35), _balance)
	var without := Progression.season_changes(player, unfocused, _season(6.0, 35), _balance)
	assert_gt(with_focus["pace"], without["pace"])


func test_round_value_survives_json_exactly() -> void:
	# snappedf(1.65, 0.01) is 1.6500000000000001, which JSON cannot reproduce.
	for raw: float in [1.65, 1.6500000000000001, 2.675, 98.125, 0.1 + 0.2, 6.0 + 8 * 0.05]:
		var stored := Progression.round_value(raw)
		var back: Array = JSON.parse_string(JSON.stringify([stored]))
		assert_eq(float(back[0]), stored, "value %s" % raw)


func test_apply_changes_clamps_and_rounds() -> void:
	var player := _player("FWD", 25, 98.0)
	player.attributes["defending"] = 1.5
	var changes: Dictionary[String, float] = {"shooting": 5.0, "defending": -3.0, "pace": 0.123456}
	Progression.apply_changes(player, changes, _balance)
	assert_eq(player.attributes["shooting"], _balance.attribute_max)
	assert_eq(player.attributes["defending"], _balance.attribute_min)
	assert_eq(player.attributes["pace"], 98.12)


func test_intense_training_grows_faster_than_light() -> void:
	var player := _player("MID", 16, 40.0)
	var light := TrainingPlan.create("passing", "dribbling", TrainingPlan.LIGHT)
	var intense := TrainingPlan.create("passing", "dribbling", TrainingPlan.INTENSE)
	var slow := Progression.season_changes(player, light, _season(6.0, 16), _balance)
	var fast := Progression.season_changes(player, intense, _season(6.0, 16), _balance)
	assert_gt(fast["passing"], slow["passing"])


func test_injury_cuts_training_growth() -> void:
	var player := _player("MID", 16, 40.0)
	var plan := TrainingPlan.create("passing", "dribbling")
	var fit := _season(6.0, 16)
	var injured := _season(6.0, 16)
	injured.training_share = 0.5
	var full := Progression.season_changes(player, plan, fit, _balance)
	var half := Progression.season_changes(player, plan, injured, _balance)
	assert_almost_eq(half["passing"], full["passing"] / 2.0, 1e-6)
