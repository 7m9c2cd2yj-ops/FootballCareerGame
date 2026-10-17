extends GutTest
## Device settings survive a round trip and never break on damaged data.

const PATH := "user://test_player_settings.json"

var _options: Accessibility = null
var _names: Array[String] = ["SwiftFalcon", "BraveBadger"]


func before_each() -> void:
	var errors: Array[String] = []
	_options = Accessibility.load_file(Accessibility.DEFAULT_PATH, errors)
	DirAccess.remove_absolute(PATH)


func after_all() -> void:
	DirAccess.remove_absolute(PATH)


func test_defaults() -> void:
	var settings := PlayerSettings.defaults(_options)
	assert_eq(settings.text_size, "normal")
	assert_eq(settings.palette, "standard")
	assert_true(settings.haptics)
	assert_false(settings.onboarding_done)
	assert_eq(settings.player_name, "")


func test_round_trip_through_a_file() -> void:
	var settings := PlayerSettings.defaults(_options)
	settings.text_size = "largest"
	settings.palette = "colorblind"
	settings.haptics = false
	settings.onboarding_done = true
	settings.player_name = "BraveBadger"
	settings.tips_seen.append(MomentSpec.PENALTY)
	settings.equipped[StoreCatalog.BOOTS] = "boots_neon"
	assert_eq(settings.save_file(PATH), "")
	var loaded := PlayerSettings.load_file(PATH, _options, _names)
	assert_eq(loaded.to_dict(), settings.to_dict())


func test_missing_file_gives_defaults() -> void:
	var loaded := PlayerSettings.load_file(PATH, _options, _names)
	assert_eq(loaded.to_dict(), PlayerSettings.defaults(_options).to_dict())


func test_damaged_values_fall_back_one_by_one() -> void:
	var data := {
		"text_size": "gigantic",
		"palette": 7,
		"haptics": "yes",
		"onboarding_done": true,
		"player_name": "Free Text Name",
		"tips_seen": ["penalty", "dance", "penalty"],
		"equipped": {"boots": "boots_neon", "hat": "cap", "kits": 3},
	}
	var settings := PlayerSettings.from_dict(data, _options, _names)
	assert_eq(settings.text_size, "normal")
	assert_eq(settings.palette, "standard")
	assert_true(settings.haptics)
	assert_true(settings.onboarding_done, "valid values are kept")
	assert_eq(settings.player_name, "", "only preset names are accepted")
	assert_eq(settings.tips_seen, [MomentSpec.PENALTY] as Array[String])
	assert_eq(settings.equipped, {"boots": "boots_neon"} as Dictionary[String, String])


func test_corrupt_file_gives_defaults() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	var loaded := PlayerSettings.load_file(PATH, _options, _names)
	assert_eq(loaded.to_dict(), PlayerSettings.defaults(_options).to_dict())
