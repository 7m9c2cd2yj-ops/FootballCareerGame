extends SceneTree
## Compiles every GDScript under the given res:// folders and exits 1 if any
## fails. Unlike `--check-only`, this runs with autoloads registered, so
## scripts that use the Session autoload compile correctly.
## Usage: godot --headless -s tools/compile_all.gd -- res://scripts res://tests

var _failures: Array[String] = []


func _initialize() -> void:
	for folder: String in OS.get_cmdline_user_args():
		_compile_folder(folder)
	for failure: String in _failures:
		printerr("compile_all: failed to compile %s" % failure)
	print("compile_all: %d failure(s)" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


func _compile_folder(folder: String) -> void:
	for file_name: String in DirAccess.get_files_at(folder):
		var path := folder.path_join(file_name)
		var own_script: Script = get_script()
		# Reloading this running script would crash the engine, so skip it.
		if file_name.ends_with(".gd") and path != own_script.resource_path:
			var script := load(path) as GDScript
			if script == null or not script.can_instantiate():
				_failures.append(path)
	for sub_folder: String in DirAccess.get_directories_at(folder):
		_compile_folder(folder.path_join(sub_folder))
