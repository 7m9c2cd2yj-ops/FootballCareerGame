extends GutTest
## Text sizes, palettes and haptics load from data, and the colour-blind
## palette keeps the colours that matter on the pitch apart.

## Smallest RGB distance (0..sqrt(3)) between colours that must be told apart.
const MIN_DISTANCE := 0.35
const OKABE_ITO: Array[String] = [
	"#e69f00", "#56b4e9", "#009e73", "#f0e442", "#0072b2", "#d55e00", "#cc79a7", "#000000"
]


func _shipped() -> Accessibility:
	var errors: Array[String] = []
	var loaded := Accessibility.load_file(Accessibility.DEFAULT_PATH, errors)
	assert_not_null(loaded, "\n".join(errors))
	return loaded


static func distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_shipped_file_has_defaults_first() -> void:
	var options := _shipped()
	assert_eq(options.text_size_ids[0], "normal")
	assert_eq(options.text_scale("normal"), 1.0)
	assert_eq(options.palette_ids, ["standard", "colorblind"] as Array[String])


func test_unknown_ids_fall_back_to_the_defaults() -> void:
	var options := _shipped()
	assert_eq(options.text_scale("huge"), 1.0)
	assert_eq(options.color("nope", "badge"), options.color("standard", "badge"))


func test_larger_text_sizes_scale_up() -> void:
	var options := _shipped()
	var previous := 0.0
	for id: String in options.text_size_ids:
		assert_gt(options.text_scale(id), previous, id)
		previous = options.text_scale(id)


func test_colorblind_palette_uses_only_okabe_ito_colours() -> void:
	var options := _shipped()
	for role: String in Accessibility.COLOR_ROLES:
		var html := "#" + options.color("colorblind", role).to_html(false)
		assert_has(OKABE_ITO, html, role)


func test_pitch_colours_are_distinct_in_every_palette() -> void:
	var options := _shipped()
	var roles: Array[String] = ["player_kit", "opponent_kit", "keeper_kit"]
	for id: String in options.palette_ids:
		for i: int in roles.size():
			for j: int in range(i + 1, roles.size()):
				var gap := distance(options.color(id, roles[i]), options.color(id, roles[j]))
				assert_gt(gap, MIN_DISTANCE, "%s: %s vs %s" % [id, roles[i], roles[j]])
		var outcome_gap := distance(options.color(id, "success"), options.color(id, "failure"))
		assert_gt(outcome_gap, MIN_DISTANCE, "%s: success vs failure" % id)


func test_bad_colour_is_reported() -> void:
	var data: Dictionary = JsonLoader.load_dictionary(Accessibility.DEFAULT_PATH).data
	var palettes: Array = data["palettes"]
	var first: Dictionary = palettes[0]
	var colors: Dictionary = first["colors"]
	colors["aim"] = "yellowish"
	colors.erase("badge")
	var problems := "\n".join(Accessibility.validate(data))
	assert_string_contains(problems, "aim must be a colour")
	assert_string_contains(problems, "badge must be a colour")


func test_out_of_range_values_are_reported() -> void:
	var data: Dictionary = JsonLoader.load_dictionary(Accessibility.DEFAULT_PATH).data
	var sizes: Array = data["text_sizes"]
	var first: Dictionary = sizes[0]
	first["scale"] = 5
	var haptics: Dictionary = data["haptics"]
	haptics["success_ms"] = 2000
	var problems := "\n".join(Accessibility.validate(data))
	assert_string_contains(problems, "scale must be from 0.5 to 2")
	assert_string_contains(problems, "haptics.success_ms")
