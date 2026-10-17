extends Control
## Save slots: continue, delete (tap twice) or start a new career in a slot.

const SETUP_SCENE := "res://scenes/career/career_setup.tscn"
const SEASON_SCENE := "res://scenes/career/season_screen.tscn"
const SUMMARY_SCENE := "res://scenes/career/career_summary.tscn"
const MENU_SCENE := "res://scenes/main/main_menu.tscn"
const BUTTON_SIZE := Vector2(180, 88)

var _confirm_delete_slot: int = 0

@onready var _slot_list: VBoxContainer = %SlotList
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	(%BackButton as Button).pressed.connect(
		func() -> void: get_tree().change_scene_to_file(MENU_SCENE)
	)
	refresh()


func refresh() -> void:
	for child: Node in _slot_list.get_children():
		_slot_list.remove_child(child)
		child.queue_free()
	for slot: int in range(1, Session.config.free_save_slots + 1):
		_slot_list.add_child(_slot_row(slot))


## Loads `slot` and opens the right screen (also used by tests).
func play(slot: int) -> void:
	var error := Session.load_career(slot)
	if not error.is_empty():
		_message_label.text = error
		return
	var next := SUMMARY_SCENE if Session.career.retired else SEASON_SCENE
	get_tree().change_scene_to_file(next)


func new_career(slot: int) -> void:
	Session.pending_slot = slot
	get_tree().change_scene_to_file(SETUP_SCENE)


## First press asks to confirm; the second deletes the slot's saves.
func press_delete(slot: int) -> void:
	if _confirm_delete_slot != slot:
		_confirm_delete_slot = slot
		_message_label.text = "Tap Delete again to erase slot %d for good." % slot
		return
	_confirm_delete_slot = 0
	var error := Session.saves.delete(slot)
	_message_label.text = error if not error.is_empty() else "Slot %d is empty now." % slot
	refresh()


func _slot_row(slot: int) -> Control:
	var row := VBoxContainer.new()
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(info)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	row.add_child(buttons)
	var summary := Session.saves.summary(slot)
	if summary.is_empty() and not Session.saves.has_save(slot):
		info.text = "Slot %d · empty" % slot
		buttons.add_child(_button("New career", new_career.bind(slot)))
		return row
	info.text = _describe(slot, summary)
	buttons.add_child(_button("Play", play.bind(slot)))
	buttons.add_child(_button("Delete", press_delete.bind(slot)))
	return row


func _describe(slot: int, summary: Dictionary) -> String:
	if summary.is_empty():
		return "Slot %d · save needs repair (Play tries the backup)" % slot
	var status := "retired" if summary.get("retired", false) else "age %d" % int(summary["age"])
	return (
		(
			"Slot %d · %s · %s\n%s · overall %d · %d seasons"
			% [
				slot,
				summary["display_name"],
				Session.labels.position_name(str(summary["position"])),
				summary["club"],
				int(summary["overall"]),
				int(summary["seasons"]),
			]
		)
		+ " · "
		+ status
	)


func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.pressed.connect(on_press)
	return button
