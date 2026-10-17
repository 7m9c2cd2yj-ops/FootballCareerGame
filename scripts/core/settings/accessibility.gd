class_name Accessibility
extends RefCounted
## Text sizes, colour palettes and haptic pulse lengths from data/accessibility.json.
## Every palette defines every colour role, so screens can ask for any role.

const DEFAULT_PATH := "res://data/accessibility.json"
const COLOR_ROLES: Array[String] = [
	"player_kit",
	"opponent_kit",
	"keeper_kit",
	"aim",
	"power",
	"success",
	"failure",
	"badge",
	"highlight",
]
const HAPTIC_KEYS: Array[String] = ["success_ms", "failure_ms"]

## Ids in file order; the first of each is the default.
var text_size_ids: Array[String] = []
var palette_ids: Array[String] = []
var _text_labels: Dictionary[String, String] = {}
var _text_scales: Dictionary[String, float] = {}
var _palette_labels: Dictionary[String, String] = {}
var _palettes: Dictionary[String, Dictionary] = {}
var _haptics: Dictionary[String, int] = {}


static func load_file(path: String, errors: Array[String]) -> Accessibility:
	var loaded := JsonLoader.load_dictionary(path)
	if not loaded.is_ok():
		errors.append(loaded.error)
		return null
	var problems := validate(loaded.data)
	if not problems.is_empty():
		for problem: String in problems:
			errors.append("%s: %s" % [path, problem])
		return null
	return from_dictionary(loaded.data)


static func validate(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	_validate_text_sizes(data.get("text_sizes"), problems)
	_validate_palettes(data.get("palettes"), problems)
	if typeof(data.get("haptics")) != TYPE_DICTIONARY:
		problems.append("haptics must be an object")
	else:
		var haptics: Dictionary = data["haptics"]
		for key: String in HAPTIC_KEYS:
			var value: Variant = haptics.get(key)
			if not DataChecks.is_number(value) or float(value) < 0 or float(value) > 500:
				problems.append("haptics.%s must be a number from 0 to 500" % key)
	return problems


static func from_dictionary(data: Dictionary) -> Accessibility:
	var built := Accessibility.new()
	for entry: Dictionary in data["text_sizes"]:
		var id := str(entry["id"])
		built.text_size_ids.append(id)
		built._text_labels[id] = str(entry["label"])
		built._text_scales[id] = float(entry["scale"])
	for entry: Dictionary in data["palettes"]:
		var id := str(entry["id"])
		built.palette_ids.append(id)
		built._palette_labels[id] = str(entry["label"])
		var colors: Dictionary[String, Color] = {}
		for role: String in COLOR_ROLES:
			colors[role] = Color.html(str(entry["colors"][role]))
		built._palettes[id] = colors
	for key: String in HAPTIC_KEYS:
		built._haptics[key] = int(data["haptics"][key])
	return built


func has_text_size(id: String) -> bool:
	return _text_scales.has(id)


func has_palette(id: String) -> bool:
	return _palettes.has(id)


func text_label(id: String) -> String:
	return _text_labels.get(id, id)


func palette_label(id: String) -> String:
	return _palette_labels.get(id, id)


## UI scale for a text size; unknown ids use the first (default) size.
func text_scale(id: String) -> float:
	return _text_scales.get(id, _text_scales[text_size_ids[0]])


## Colour for `role` in palette `id`; unknown ids use the first (default) palette.
func color(id: String, role: String) -> Color:
	var colors: Dictionary = _palettes.get(id, _palettes[palette_ids[0]])
	return colors[role]


func haptic_ms(key: String) -> int:
	return _haptics.get(key, 0)


static func _validate_text_sizes(sizes: Variant, problems: Array[String]) -> void:
	if not _is_filled_array(sizes):
		problems.append("text_sizes must be a non-empty array")
		return
	for entry: Variant in sizes:
		if not _has_id_and_label(entry):
			problems.append("text_sizes entries need a text id and label")
			return
		var size: Dictionary = entry
		var scale: Variant = size.get("scale")
		if not DataChecks.is_number(scale) or float(scale) < 0.5 or float(scale) > 2.0:
			problems.append("text size %s: scale must be from 0.5 to 2" % size["id"])


static func _validate_palettes(palettes: Variant, problems: Array[String]) -> void:
	if not _is_filled_array(palettes):
		problems.append("palettes must be a non-empty array")
		return
	for entry: Variant in palettes:
		if not _has_id_and_label(entry):
			problems.append("palettes entries need a text id and label")
			return
		var palette: Dictionary = entry
		if typeof(palette.get("colors")) != TYPE_DICTIONARY:
			problems.append("palette %s: colors must be an object" % palette["id"])
			continue
		var colors: Dictionary = palette["colors"]
		for role: String in COLOR_ROLES:
			var value: Variant = colors.get(role)
			if typeof(value) != TYPE_STRING or not Color.html_is_valid(str(value)):
				problems.append(
					"palette %s: %s must be a colour like #1a2b3c" % [palette["id"], role]
				)


static func _is_filled_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var entries: Array = value
	return not entries.is_empty()


static func _has_id_and_label(entry: Variant) -> bool:
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = entry
	return typeof(data.get("id")) == TYPE_STRING and typeof(data.get("label")) == TYPE_STRING
