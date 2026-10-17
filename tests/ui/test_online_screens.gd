extends GutTest
## Online screens without a backend config (tests run offline): they explain
## that online features are unavailable and never block the game.

const SETTINGS_SCENE := preload("res://scenes/main/settings_screen.tscn")
const ARENA_SCENE := preload("res://scenes/main/arena_screen.tscn")


func test_settings_offer_only_preset_names_and_explain_offline() -> void:
	var screen: Control = add_child_autofree(SETTINGS_SCENE.instantiate())
	var names: OptionButton = screen.get_node("%NameOption")
	assert_eq(names.item_count, Backend.preset_names.size())
	assert_string_contains((screen.get_node("%StatusLabel") as Label).text, "offline")


func test_account_deletion_needs_two_taps() -> void:
	var screen: Control = add_child_autofree(SETTINGS_SCENE.instantiate())
	screen.call("press_delete")
	assert_string_contains((screen.get_node("%DeleteButton") as Button).text, "Tap again")
	await screen.call("press_delete")
	assert_string_contains((screen.get_node("%MessageLabel") as Label).text, Backend.NOT_CONFIGURED)


func test_arena_explains_it_needs_online_setup() -> void:
	var screen: Control = add_child_autofree(ARENA_SCENE.instantiate())
	assert_eq((screen.get_node("%StatusLabel") as Label).text, Backend.NOT_CONFIGURED)
