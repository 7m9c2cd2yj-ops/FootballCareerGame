extends GutTest
## Session autosaves the active career and loads it back.


func after_each() -> void:
	Session.career = null
	Session.saves.delete(2)


func test_new_career_is_saved_and_loads_back() -> void:
	Session.start_career("GK", 2)
	var errors: Array[String] = []
	Session.sim_season(TrainingPlan.create("goalkeeping", "physical"), errors)
	var saved := JSON.stringify(Session.career.to_dict())
	Session.career = null
	assert_eq(Session.load_career(2), "")
	assert_eq(JSON.stringify(Session.career.to_dict()), saved)
	assert_eq(Session.saves.summary(2)["seasons"], 1)


func test_loading_an_empty_slot_explains_why() -> void:
	assert_string_contains(Session.load_career(3), "No valid save")


func test_careers_screen_lists_slots_and_deletes_after_confirming() -> void:
	Session.saves.delete(1)
	Session.start_career("MID", 2)
	var screen: Control = add_child_autofree(
		preload("res://scenes/main/careers_screen.tscn").instantiate()
	)
	var text := ""
	for label: Node in screen.find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	assert_string_contains(text, "Slot 1 · empty")
	assert_string_contains(text, "Slot 2 · Rookie")
	screen.call("press_delete", 2)
	assert_true(Session.saves.has_save(2), "first tap only asks")
	screen.call("press_delete", 2)
	assert_false(Session.saves.has_save(2))
