class_name GameConfig
extends RefCounted
## Global game settings loaded from data/game_config.json (title, version,
## legal disclaimer). Change the working title there, not in code.

const DEFAULT_PATH := "res://data/game_config.json"
const REQUIRED_TEXT_KEYS: Array[String] = [
	"title", "version", "disclaimer", "privacy_policy_url", "default_player_name"
]

var title: String = ""
var version: String = ""
var disclaimer: String = ""
var privacy_policy_url: String = ""
## Used until onboarding (M8) lets the player pick a preset name.
var default_player_name: String = ""


## Returns a list of human-readable problems; empty means `data` is valid.
static func validate(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key: String in REQUIRED_TEXT_KEYS:
		if not data.has(key):
			problems.append("Missing key '%s'" % key)
		elif typeof(data[key]) != TYPE_STRING:
			problems.append("Key '%s' must be a string" % key)
		elif str(data[key]).strip_edges().is_empty():
			problems.append("Key '%s' must not be empty" % key)
	return problems


## Builds a config from already-validated data (see `validate`).
static func from_dictionary(data: Dictionary) -> GameConfig:
	var config := GameConfig.new()
	config.title = data["title"]
	config.version = data["version"]
	config.disclaimer = data["disclaimer"]
	config.privacy_policy_url = data["privacy_policy_url"]
	config.default_player_name = data["default_player_name"]
	return config


## Loads and validates `path`. Returns null and appends to `errors` on failure.
static func load_file(path: String, errors: Array[String]) -> GameConfig:
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
