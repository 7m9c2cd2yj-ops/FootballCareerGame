extends Node
## Autoload "Preferences": the device settings (PlayerSettings) plus the
## accessibility data they refer to. Screens read colours and the text size
## here; `changed` fires after every change so open screens can update.

signal changed

const DEFAULT_PATH := "user://settings.json"

var accessibility: Accessibility = null
var settings: PlayerSettings = null
var preset_names: Array[String] = []
## Where settings are stored; tests point this at a throwaway file.
var path: String = DEFAULT_PATH


func _ready() -> void:
	var errors: Array[String] = []
	accessibility = Accessibility.load_file(Accessibility.DEFAULT_PATH, errors)
	preset_names.assign(JsonLoader.load_dictionary("res://data/preset_names.json").data["names"])
	for error: String in errors:
		push_error(error)
	reload()


## Re-reads the settings file (missing or damaged means defaults).
func reload() -> void:
	settings = PlayerSettings.load_file(path, accessibility, preset_names)
	changed.emit()


func save() -> void:
	var error := settings.save_file(path)
	if not error.is_empty():
		push_warning("Settings not saved: %s" % error)
	changed.emit()


func color(role: String) -> Color:
	return accessibility.color(settings.palette, role)


func text_scale() -> float:
	return accessibility.text_scale(settings.text_size)


func set_text_size(id: String) -> void:
	if accessibility.has_text_size(id):
		settings.text_size = id
		save()


func set_palette(id: String) -> void:
	if accessibility.has_palette(id):
		settings.palette = id
		save()


func set_haptics(enabled: bool) -> void:
	settings.haptics = enabled
	save()


## The name new careers start with: the onboarding choice, else the default.
func player_name(fallback: String) -> String:
	return settings.player_name if not settings.player_name.is_empty() else fallback


func choose_name(name_choice: String) -> void:
	if preset_names.has(name_choice):
		settings.player_name = name_choice
		save()


func finish_onboarding() -> void:
	settings.onboarding_done = true
	save()


## Shows onboarding and every moment tip again.
func replay_tutorial() -> void:
	settings.onboarding_done = false
	settings.tips_seen.clear()
	save()


func needs_tip(moment_type: String) -> bool:
	return not settings.tips_seen.has(moment_type)


func mark_tip_seen(moment_type: String) -> void:
	if needs_tip(moment_type):
		settings.tips_seen.append(moment_type)
		save()


## A short vibration for a moment result, if haptics are on (phones only).
func pulse(success: bool) -> void:
	if not settings.haptics or not OS.has_feature("mobile"):
		return
	var key := "success_ms" if success else "failure_ms"
	Input.vibrate_handheld(accessibility.haptic_ms(key))
