extends GutHookScript
## Runs before all tests: point the Session's saves at a throwaway folder so
## tests never touch real player saves, and start it empty.

const TEST_SAVE_ROOT := "user://test_saves"


func run() -> void:
	clear(TEST_SAVE_ROOT)
	var tree: SceneTree = Engine.get_main_loop()
	var session: Node = tree.root.get_node("Session")
	session.set("saves", SaveSlots.new(TEST_SAVE_ROOT))


static func clear(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
