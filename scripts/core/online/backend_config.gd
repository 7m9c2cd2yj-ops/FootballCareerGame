class_name BackendConfig
extends RefCounted
## Where the online backend is. Read from a git-ignored file generated at
## build time from environment variables (tools/write_backend_config.sh), so
## keys are never committed. Without it the game simply plays offline.

const DEFAULT_PATH := "res://config/backend.local.json"
## Tests and local tools may point the game at another config file.
const PATH_OVERRIDE_ENV := "KL_BACKEND_CONFIG"

var url: String = ""
## The public anon key (protected by row-level security), never the service key.
var anon_key: String = ""


static func path() -> String:
	var override := OS.get_environment(PATH_OVERRIDE_ENV)
	return override if not override.is_empty() else DEFAULT_PATH


## Returns a config, or null if the file is missing or incomplete (offline).
static func load_file(file_path: String) -> BackendConfig:
	if not FileAccess.file_exists(file_path):
		return null
	var loaded := JsonLoader.load_dictionary(file_path)
	if not loaded.is_ok():
		return null
	return from_dictionary(loaded.data)


static func from_dictionary(data: Dictionary) -> BackendConfig:
	var url_value := str(data.get("url", "")).strip_edges().trim_suffix("/")
	var key_value := str(data.get("anon_key", "")).strip_edges()
	if url_value.is_empty() or key_value.is_empty() or not url_value.begins_with("http"):
		return null
	var config := BackendConfig.new()
	config.url = url_value
	config.anon_key = key_value
	return config
