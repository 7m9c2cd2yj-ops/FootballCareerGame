extends GutTest
## First launch flow and the accessibility settings.

const ONBOARDING_SCENE := preload("res://scenes/main/onboarding.tscn")
const SETTINGS_SCENE := preload("res://scenes/main/settings_screen.tscn")


func after_each() -> void:
	DirAccess.remove_absolute(Preferences.path)
	Preferences.reload()
	Session.career = null
	Session.practice_moment = null
	Session.practice_return_scene = ""


func _button_texts(screen: Node) -> Array[String]:
	var texts: Array[String] = []
	for button: Button in screen.find_children("*", "Button", true, false):
		texts.append(button.text)
	return texts


func test_new_settings_need_onboarding() -> void:
	assert_false(Preferences.settings.onboarding_done)


func test_name_choice_is_used_for_careers_and_online() -> void:
	var screen: Control = add_child_autofree(ONBOARDING_SCENE.instantiate())
	var names: OptionButton = screen.find_children("*", "OptionButton", true, false)[0]
	assert_eq(names.item_count, Preferences.preset_names.size(), "preset names only")
	names.select(3)
	screen.call("choose_name")
	var chosen := Preferences.preset_names[3]
	assert_eq(Preferences.settings.player_name, chosen)
	assert_eq(Backend.display_name, chosen)
	assert_has(_button_texts(screen), "Try a practice penalty")
	Session.start_career("MID")
	assert_eq(Session.career.player.display_name, chosen)


func test_practice_comes_back_to_how_it_works() -> void:
	Session.start_practice(MomentSpec.PENALTY, "res://scenes/main/onboarding.tscn")
	assert_eq(Session.practice_moment.moment_type, MomentSpec.PENALTY)
	assert_eq(Session.practice_moment.distance, Session.moment_tuning.value("penalty", "distance"))
	var screen: Control = add_child_autofree(ONBOARDING_SCENE.instantiate())
	assert_has(_button_texts(screen), "Start my career")


func test_text_size_scales_the_ui() -> void:
	var screen: Control = add_child_autofree(SETTINGS_SCENE.instantiate())
	screen.call("choose_text_size", 2)
	assert_eq(Preferences.settings.text_size, "largest")
	assert_almost_eq(get_tree().root.content_scale_factor, 1.3, 0.001)
	screen.call("choose_text_size", 0)
	assert_almost_eq(get_tree().root.content_scale_factor, 1.0, 0.001)


func test_palette_and_haptics_choices_are_saved() -> void:
	var screen: Control = add_child_autofree(SETTINGS_SCENE.instantiate())
	screen.call("choose_palette", 1)
	(screen.get_node("%HapticsCheck") as CheckButton).button_pressed = false
	Preferences.reload()
	assert_eq(Preferences.settings.palette, "colorblind")
	assert_false(Preferences.settings.haptics)
	assert_eq(Preferences.color("opponent_kit"), Color.html("#d55e00"))


func test_replay_tutorial_resets_onboarding_and_tips() -> void:
	Preferences.finish_onboarding()
	Preferences.mark_tip_seen(MomentSpec.SAVE)
	var screen: Control = add_child_autofree(SETTINGS_SCENE.instantiate())
	screen.call("replay_tutorial")
	assert_false(Preferences.settings.onboarding_done)
	assert_true(Preferences.needs_tip(MomentSpec.SAVE))


func test_privacy_link_waits_for_the_parental_gate() -> void:
	var screen: Control = add_child_autofree(SETTINGS_SCENE.instantiate())
	screen.call("open_privacy_policy")
	var dialogs := screen.find_children("*", "ParentalGateDialog", true, false)
	assert_eq(dialogs.size(), 1)
	var dialog: ParentalGateDialog = dialogs[0]
	dialog.answered.emit(false)
	await wait_process_frames(2)
	assert_eq(screen.find_children("*", "ParentalGateDialog", true, false).size(), 0)
