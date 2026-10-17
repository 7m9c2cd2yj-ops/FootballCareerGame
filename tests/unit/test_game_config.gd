extends GutTest
## Tests for GameConfig validation and the shipped data/game_config.json.


func _valid_data() -> Dictionary:
	return {
		"title": "Test Title",
		"version": "1.2.3",
		"disclaimer": "Unofficial fan game.",
		"privacy_policy_url": "https://example.com/privacy",
		"default_player_name": "Rookie",
	}


func test_valid_data_has_no_problems() -> void:
	assert_eq(GameConfig.validate(_valid_data()).size(), 0)


func test_missing_key_is_reported() -> void:
	var data := _valid_data()
	data.erase("disclaimer")
	var problems := GameConfig.validate(data)
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "disclaimer")


func test_wrong_type_is_reported() -> void:
	var data := _valid_data()
	data["title"] = 42
	assert_string_contains(GameConfig.validate(data)[0], "must be a string")


func test_blank_value_is_reported() -> void:
	var data := _valid_data()
	data["title"] = "   "
	assert_string_contains(GameConfig.validate(data)[0], "must not be empty")


func test_from_dictionary_copies_fields() -> void:
	var config := GameConfig.from_dictionary(_valid_data())
	assert_eq(config.title, "Test Title")
	assert_eq(config.version, "1.2.3")
	assert_eq(config.privacy_policy_url, "https://example.com/privacy")


func test_load_file_reports_missing_file() -> void:
	var errors: Array[String] = []
	assert_null(GameConfig.load_file("res://nope.json", errors))
	assert_eq(errors.size(), 1)


func test_shipped_config_is_valid() -> void:
	var errors: Array[String] = []
	var config := GameConfig.load_file(GameConfig.DEFAULT_PATH, errors)
	assert_not_null(config, "\n".join(errors))


func test_shipped_disclaimer_states_unofficial_and_unaffiliated() -> void:
	var errors: Array[String] = []
	var text := GameConfig.load_file(GameConfig.DEFAULT_PATH, errors).disclaimer.to_lower()
	assert_string_contains(text, "unofficial")
	assert_string_contains(text, "not affiliated")


## The launcher name comes from project.godot and cannot read JSON, so this
## guards against the two drifting apart when the working title changes.
func test_project_name_matches_config_title() -> void:
	var errors: Array[String] = []
	var config := GameConfig.load_file(GameConfig.DEFAULT_PATH, errors)
	assert_eq(ProjectSettings.get_setting("application/config/name"), config.title)
