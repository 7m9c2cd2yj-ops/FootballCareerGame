extends GutTest
## Tests for JsonLoader: valid objects load, everything else reports an error.


func test_parses_object() -> void:
	var result := JsonLoader.parse_dictionary('{"a": 1, "b": "x"}', "inline")
	assert_true(result.is_ok(), result.error)
	assert_eq(result.data.get("b"), "x")


func test_rejects_invalid_json_with_line_number() -> void:
	var result := JsonLoader.parse_dictionary('{\n"a": }', "broken.json")
	assert_false(result.is_ok())
	assert_string_contains(result.error, "broken.json: line 2")
	assert_eq(result.data.size(), 0)


func test_rejects_non_object_top_level() -> void:
	var result := JsonLoader.parse_dictionary("[1, 2, 3]", "list.json")
	assert_false(result.is_ok())
	assert_string_contains(result.error, "must be an object")


func test_missing_file_reports_path() -> void:
	var result := JsonLoader.load_dictionary("res://does/not/exist.json")
	assert_false(result.is_ok())
	assert_string_contains(result.error, "res://does/not/exist.json")


func test_loads_real_data_file() -> void:
	var result := JsonLoader.load_dictionary(GameConfig.DEFAULT_PATH)
	assert_true(result.is_ok(), result.error)
