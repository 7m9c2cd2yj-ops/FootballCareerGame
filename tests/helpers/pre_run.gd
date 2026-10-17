extends GutHookScript
## Runs before all tests: point the Session's saves, the device settings, the
## online profile and the store's purchase records at throwaway locations so
## tests never touch a player's real files, and start them empty.

const TEST_SAVE_ROOT := "user://test_saves"
const TEST_SETTINGS := "user://test_settings.json"
const TEST_STORE_DIR := "user://test_store"
const TEST_ONLINE_PROFILE := "user://test_online_profile.json"
const TEST_ONLINE_SESSION := "user://test_online_session.json"


func run() -> void:
	clear(TEST_SAVE_ROOT)
	clear(TEST_STORE_DIR)
	for path: String in [TEST_SETTINGS, TEST_ONLINE_PROFILE, TEST_ONLINE_SESSION]:
		DirAccess.remove_absolute(path)
	var tree: SceneTree = Engine.get_main_loop()
	tree.root.get_node("Session").set("saves", SaveSlots.new(TEST_SAVE_ROOT))
	var preferences: Node = tree.root.get_node("Preferences")
	preferences.set("path", TEST_SETTINGS)
	preferences.call("reload")
	var backend: Node = tree.root.get_node("Backend")
	backend.set("_profile_path", TEST_ONLINE_PROFILE)
	backend.set("_session_path", TEST_ONLINE_SESSION)
	var store: Node = tree.root.get_node("Store")
	store.set("state_dir", TEST_STORE_DIR)
	store.call("reload")


static func clear(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
