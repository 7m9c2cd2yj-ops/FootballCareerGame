extends GutTest
## PlayerModel creation, overall rating and save-data round trips.

const Fixture := preload("res://tests/helpers/balance_fixture.gd")

var _balance: Balance


func before_each() -> void:
	_balance = Fixture.shipped()


func _player_with_all(value: float, position: String) -> PlayerModel:
	var player := PlayerModel.create("Test", position, _balance)
	for attribute: String in PlayerModel.ATTRIBUTES:
		player.attributes[attribute] = value
	return player


func test_create_uses_start_age_and_position_start_values() -> void:
	var player := PlayerModel.create("Test", "FWD", _balance)
	assert_eq(player.age, _balance.start_age)
	assert_eq(player.position, "FWD")
	assert_eq(player.attributes["shooting"], _balance.start_attribute("FWD", "shooting"))


func test_overall_of_uniform_attributes_is_that_value() -> void:
	for position: String in _balance.positions():
		assert_eq(_player_with_all(50.0, position).overall_rating(_balance), 50)


func test_overall_is_weighted_by_position() -> void:
	var player := _player_with_all(10.0, "FWD")
	player.attributes["shooting"] = 90.0
	# FWD shooting weight 0.4 of total 1.0: 0.4 * 90 + 0.6 * 10 = 42.
	assert_eq(player.overall_rating(_balance), 42)
	player.position = "DEF"
	# DEF does not weight shooting at all.
	assert_eq(player.overall_rating(_balance), 10)


func test_overall_never_exceeds_attribute_max() -> void:
	assert_eq(_player_with_all(99.0, "MID").overall_rating(_balance), 99)


func test_copy_is_independent() -> void:
	var player := PlayerModel.create("Test", "MID", _balance)
	var clone := player.copy()
	clone.attributes["passing"] = 80.0
	clone.age = 30
	assert_ne(player.attributes["passing"], 80.0)
	assert_eq(player.age, _balance.start_age)


func test_dict_round_trip_through_json() -> void:
	var player := PlayerModel.create("Test", "GK", _balance)
	player.attributes["goalkeeping"] = 47.25
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	assert_eq(PlayerModel.validate_dict(parsed, _balance).size(), 0)
	assert_eq(PlayerModel.from_dict(parsed).to_dict(), player.to_dict())


func test_validate_rejects_unknown_position() -> void:
	var data := PlayerModel.create("Test", "GK", _balance).to_dict()
	data["position"] = "STRIKER"
	assert_string_contains("\n".join(PlayerModel.validate_dict(data, _balance)), "position")


func test_validate_rejects_fractional_age() -> void:
	var data := PlayerModel.create("Test", "GK", _balance).to_dict()
	data["age"] = 12.5
	assert_string_contains("\n".join(PlayerModel.validate_dict(data, _balance)), "age")


func test_validate_rejects_missing_and_out_of_range_attributes() -> void:
	var data := PlayerModel.create("Test", "GK", _balance).to_dict()
	var attributes: Dictionary = data["attributes"]
	attributes.erase("pace")
	attributes["shooting"] = 120
	var problems := "\n".join(PlayerModel.validate_dict(data, _balance))
	assert_string_contains(problems, "pace is missing")
	assert_string_contains(problems, "shooting is too high")
