extends GutTest
## At the largest text size every portrait screen must still fit a phone's
## width (nothing may need more room than the screen, or it is cut off).

const SCENES: Array[String] = [
	"res://scenes/main/main_menu.tscn",
	"res://scenes/main/onboarding.tscn",
	"res://scenes/main/careers_screen.tscn",
	"res://scenes/main/settings_screen.tscn",
	"res://scenes/main/store_screen.tscn",
	"res://scenes/main/locker_screen.tscn",
	"res://scenes/main/arena_screen.tscn",
	"res://scenes/career/career_setup.tscn",
	"res://scenes/career/season_screen.tscn",
	"res://scenes/career/clubs_app.tscn",
	"res://scenes/career/career_summary.tscn",
	"res://scenes/phone/phone.tscn",
]


func before_all() -> void:
	Session.start_career("FWD", 1)
	Preferences.set_text_size(Preferences.accessibility.text_size_ids[-1])


func after_all() -> void:
	DirAccess.remove_absolute(Preferences.path)
	Preferences.reload()
	Session.saves.delete(1)
	Session.career = null


func test_every_screen_fits_the_width_at_the_largest_text_size() -> void:
	var scale := get_tree().root.content_scale_factor
	assert_almost_eq(scale, 1.3, 0.001)
	# Portrait phones always get the base width; taller screens only add height.
	var width := ScreenFit.PORTRAIT_BASE.x / scale
	for path: String in SCENES:
		var screen: Node = add_child_autofree((load(path) as PackedScene).instantiate())
		await wait_process_frames(2)
		for node: Node in screen.find_children("*", "Control", true, false):
			if not node.is_in_group(ScreenFit.SAFE_AREA_GROUP):
				continue
			var needed := (node as Control).get_combined_minimum_size().x
			assert_lte(needed, width, "%s needs %d of %d px" % [path, needed, width])
		screen.queue_free()
		await wait_process_frames(1)
