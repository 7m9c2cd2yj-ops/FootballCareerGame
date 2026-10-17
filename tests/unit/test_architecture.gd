extends GutTest
## Guards the layering rule: scripts/core is pure logic that never touches
## nodes, the scene tree or input, so it stays testable headless.

const CORE_DIR := "res://scripts/core/"
const FORBIDDEN_PATTERNS: Array[String] = [
	"extends Node",
	"extends Control",
	"get_tree(",
	"get_node(",
	"Input.",
	"Engine.get_main_loop",
]


func _core_script_paths() -> Array[String]:
	var paths: Array[String] = []
	_collect_scripts(CORE_DIR, paths)
	return paths


func _collect_scripts(folder: String, paths: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.ends_with(".gd"):
			paths.append(folder.path_join(file_name))
	for sub_folder: String in DirAccess.get_directories_at(folder):
		_collect_scripts(folder.path_join(sub_folder), paths)


func test_core_subfolders_are_scanned() -> void:
	assert_true(_core_script_paths().has("res://scripts/core/moments/penalty_resolver.gd"))


func test_core_folder_has_scripts() -> void:
	assert_gt(_core_script_paths().size(), 0)


func test_core_scripts_are_engine_independent() -> void:
	for path: String in _core_script_paths():
		var source := FileAccess.get_file_as_string(path)
		for pattern: String in FORBIDDEN_PATTERNS:
			assert_false(source.contains(pattern), "%s uses '%s'" % [path, pattern])
