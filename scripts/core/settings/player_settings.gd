class_name PlayerSettings
extends RefCounted
## Device settings: accessibility choices, onboarding progress, the chosen
## preset name and equipped cosmetics. Stored as JSON in user://; a missing
## or damaged file just means defaults, and unknown values fall back to them.

var text_size: String = ""
var palette: String = ""
var haptics: bool = true
var onboarding_done: bool = false
## A preset name (data/preset_names.json); "" until onboarding picks one.
var player_name: String = ""
## Moment types whose how-to-play tip has been shown.
var tips_seen: Array[String] = []
## Cosmetic kind (StoreCatalog.KINDS) -> chosen item id. Checked against
## Entitlements whenever it is used.
var equipped: Dictionary[String, String] = {}


static func defaults(accessibility: Accessibility) -> PlayerSettings:
	var settings := PlayerSettings.new()
	settings.text_size = accessibility.text_size_ids[0]
	settings.palette = accessibility.palette_ids[0]
	return settings


func to_dict() -> Dictionary:
	return {
		"text_size": text_size,
		"palette": palette,
		"haptics": haptics,
		"onboarding_done": onboarding_done,
		"player_name": player_name,
		"tips_seen": tips_seen.duplicate(),
		"equipped": equipped.duplicate(),
	}


## Builds settings from stored data, keeping only values that are still valid.
static func from_dict(
	data: Dictionary, accessibility: Accessibility, preset_names: Array[String]
) -> PlayerSettings:
	var settings := defaults(accessibility)
	if accessibility.has_text_size(str(data.get("text_size"))):
		settings.text_size = str(data["text_size"])
	if accessibility.has_palette(str(data.get("palette"))):
		settings.palette = str(data["palette"])
	if typeof(data.get("haptics")) == TYPE_BOOL:
		settings.haptics = data["haptics"]
	if typeof(data.get("onboarding_done")) == TYPE_BOOL:
		settings.onboarding_done = data["onboarding_done"]
	if preset_names.has(data.get("player_name")):
		settings.player_name = str(data["player_name"])
	if typeof(data.get("tips_seen")) == TYPE_ARRAY:
		for moment_type: Variant in data["tips_seen"]:
			if MomentSpec.TYPES.has(moment_type) and not settings.tips_seen.has(moment_type):
				settings.tips_seen.append(str(moment_type))
	if typeof(data.get("equipped")) == TYPE_DICTIONARY:
		var stored: Dictionary = data["equipped"]
		for kind: String in StoreCatalog.KINDS:
			if typeof(stored.get(kind)) == TYPE_STRING:
				settings.equipped[kind] = str(stored[kind])
	return settings


static func load_file(
	path: String, accessibility: Accessibility, preset_names: Array[String]
) -> PlayerSettings:
	var loaded := JsonLoader.load_dictionary(path)
	if not loaded.is_ok():
		return defaults(accessibility)
	return from_dict(loaded.data, accessibility, preset_names)


## Writes the settings to `path`; returns "" or what went wrong.
func save_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not write %s (%s)" % [path, error_string(FileAccess.get_open_error())]
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return ""
