extends GutTest
## Display names exist for everything the UI shows.

const Fixture := preload("res://tests/helpers/balance_fixture.gd")


func _shipped() -> GameLabels:
	var errors: Array[String] = []
	var labels := GameLabels.load_file(GameLabels.DEFAULT_PATH, errors)
	assert_not_null(labels, "\n".join(errors))
	return labels


func test_every_balance_position_has_a_label() -> void:
	var labels := _shipped()
	for position: String in Fixture.shipped().positions():
		assert_true(labels.has_position(position), position)


func test_missing_attribute_label_is_reported() -> void:
	var problems := GameLabels.validate({"attributes": {"pace": "Pace"}, "positions": {}})
	assert_string_contains("\n".join(problems), "shooting")


func test_unknown_code_falls_back_to_the_code() -> void:
	assert_eq(_shipped().attribute_name("flair"), "flair")
