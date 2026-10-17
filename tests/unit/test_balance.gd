extends GutTest
## Balance validation catches broken tuning files; lookups cover every age.

const Fixture := preload("res://tests/helpers/balance_fixture.gd")


func _problems_after(change: Callable) -> Array[String]:
	var data := Fixture.shipped_data()
	change.call(data)
	return Balance.validate(data)


func _assert_problem(change: Callable, expected_text: String) -> void:
	var problems := _problems_after(change)
	assert_gt(problems.size(), 0, "expected a problem mentioning '%s'" % expected_text)
	if problems.size() > 0:
		assert_string_contains("\n".join(problems), expected_text)


func test_shipped_balance_is_valid() -> void:
	var errors: Array[String] = []
	assert_not_null(Balance.load_file(Balance.DEFAULT_PATH, errors), "\n".join(errors))


func test_missing_top_level_number() -> void:
	_assert_problem(func(d: Dictionary) -> void: d.erase("max_age"), "max_age")


func test_start_age_must_be_below_max_age() -> void:
	_assert_problem(func(d: Dictionary) -> void: d["start_age"] = 40, "start_age must be lower")


func test_age_curve_gap_is_rejected() -> void:
	_assert_problem(
		func(d: Dictionary) -> void: d["age_curve"][1]["from_age"] = 14, "age_curve has a gap"
	)


func test_age_curve_overlap_is_rejected() -> void:
	_assert_problem(
		func(d: Dictionary) -> void: d["age_curve"][1]["from_age"] = 12, "age_curve has a gap"
	)


func test_age_table_must_reach_max_age() -> void:
	_assert_problem(
		func(d: Dictionary) -> void: d["matches_per_season"][-1]["to_age"] = 35,
		"matches_per_season must end exactly"
	)


func test_missing_attribute_weight() -> void:
	var remove_pace := func(d: Dictionary) -> void:
		var forward_weights: Dictionary = d["position_weights"]["FWD"]
		forward_weights.erase("pace")
	_assert_problem(remove_pace, "position_weights.FWD.pace")


func test_negative_weight_is_rejected() -> void:
	_assert_problem(
		func(d: Dictionary) -> void: d["position_weights"]["MID"]["passing"] = -1, "negative"
	)


func test_all_zero_weights_are_rejected() -> void:
	var zero_weights := func(d: Dictionary) -> void:
		for attribute: String in PlayerModel.ATTRIBUTES:
			d["position_weights"]["GK"][attribute] = 0
	_assert_problem(zero_weights, "positive total")


func test_start_attribute_out_of_range() -> void:
	_assert_problem(
		func(d: Dictionary) -> void: d["start_attributes"]["DEF"]["pace"] = 150, "out of range"
	)


func test_position_without_start_attributes() -> void:
	var remove_goalkeeper := func(d: Dictionary) -> void:
		var starts: Dictionary = d["start_attributes"]
		starts.erase("GK")
	_assert_problem(remove_goalkeeper, "missing position GK")


func test_headroom_floor_above_one() -> void:
	_assert_problem(func(d: Dictionary) -> void: d["headroom"]["floor"] = 1.5, "headroom.floor")


func test_expected_rating_min_above_max() -> void:
	_assert_problem(
		func(d: Dictionary) -> void: d["expected_rating"]["min"] = 9.0, "expected_rating.min"
	)


func test_training_value_must_be_number() -> void:
	_assert_problem(
		func(d: Dictionary) -> void: d["training"]["primary_multiplier"] = "lots",
		"training.primary_multiplier"
	)


func test_age_lookups_use_inclusive_brackets() -> void:
	var balance := Fixture.shipped()
	var data := Fixture.shipped_data()
	for row: Dictionary in data["age_curve"]:
		assert_eq(balance.base_gain_for_age(int(row["from_age"])), float(row["base_gain"]))
		assert_eq(balance.base_gain_for_age(int(row["to_age"])), float(row["base_gain"]))


func test_age_lookups_clamp_outside_range() -> void:
	var balance := Fixture.shipped()
	assert_eq(balance.matches_for_age(3), balance.matches_for_age(balance.start_age))
	assert_eq(balance.matches_for_age(99), balance.matches_for_age(balance.max_age))


func test_positions_are_sorted() -> void:
	assert_eq(Fixture.shipped().positions(), ["DEF", "FWD", "GK", "MID"] as Array[String])
