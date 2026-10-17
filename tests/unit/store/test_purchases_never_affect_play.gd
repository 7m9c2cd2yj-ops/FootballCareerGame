extends GutTest
## Purchases and settings are kept out of every rule that decides a career or
## a moment: core logic outside store/ and settings/ never refers to them.

const CORE_DIR := "res://scripts/core/"
const ALLOWED_DIRS: Array[String] = ["res://scripts/core/store", "res://scripts/core/settings"]
const STORE_NAMES: Array[String] = [
	"Store", "Entitlements", "StoreCatalog", "Preferences", "PlayerSettings", "cosmetic"
]


func _scripts(folder: String, paths: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.ends_with(".gd"):
			paths.append(folder.path_join(file_name))
	for sub_folder: String in DirAccess.get_directories_at(folder):
		var path := folder.path_join(sub_folder)
		if not ALLOWED_DIRS.has(path):
			_scripts(path, paths)


func test_game_rules_never_mention_the_store() -> void:
	var paths: Array[String] = []
	_scripts(CORE_DIR.trim_suffix("/"), paths)
	assert_gt(paths.size(), 40)
	assert_false(paths.has("res://scripts/core/store/entitlements.gd"))
	var word := RegEx.create_from_string("\\b(%s)\\b" % "|".join(STORE_NAMES))
	for path: String in paths:
		var found := word.search(_code_only(FileAccess.get_file_as_string(path)))
		assert_null(found, "%s mentions %s" % [path, found.get_string() if found else ""])


## The source without comments (prose may say "store" in other senses).
static func _code_only(source: String) -> String:
	var lines: Array[String] = []
	for line: String in source.split("\n"):
		lines.append(line.get_slice("#", 0))
	return "\n".join(lines)


func test_moment_resolvers_take_no_cosmetics() -> void:
	# The resolvers' inputs are the spec, the player's touch input and tuning.
	var spec := MomentSpec.new()
	assert_false("boots" in spec)
	assert_false("kit" in spec)
	assert_false("celebration" in spec)
