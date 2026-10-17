extends Control
## Settings: accessibility (text size, colours, haptics), the tutorial, the
## preset name and server, sync, the privacy policy (behind the parental gate)
## and account deletion (required by both app stores). No free text anywhere.

const MENU_SCENE := "res://scenes/main/main_menu.tscn"

var _confirming_delete: bool = false

@onready var _status_label: Label = %StatusLabel
@onready var _name_option: OptionButton = %NameOption
@onready var _server_option: OptionButton = %ServerOption
@onready var _delete_local_check: CheckBox = %DeleteLocalCheck
@onready var _delete_button: Button = %DeleteButton
@onready var _message_label: Label = %MessageLabel
@onready var _text_size_option: OptionButton = %TextSizeOption
@onready var _palette_option: OptionButton = %PaletteOption
@onready var _haptics_check: CheckButton = %HapticsCheck


func _ready() -> void:
	(%BackButton as Button).pressed.connect(
		func() -> void: get_tree().change_scene_to_file(MENU_SCENE)
	)
	(%SaveProfileButton as Button).pressed.connect(save_profile)
	(%SyncButton as Button).pressed.connect(sync_careers)
	_delete_button.pressed.connect(press_delete)
	(%PrivacyButton as Button).pressed.connect(open_privacy_policy)
	(%TutorialButton as Button).pressed.connect(replay_tutorial)
	_setup_accessibility()
	for preset: String in Backend.preset_names:
		_name_option.add_item(preset)
	_name_option.select(maxi(0, Backend.preset_names.find(Backend.display_name)))
	for server: Dictionary in Backend.servers:
		_server_option.add_item(str(server["name"]))
		if server["id"] == Backend.server_id:
			_server_option.select(_server_option.item_count - 1)
	if Backend.is_configured():
		_status_label.text = "Online features are available. Your careers always stay on this device too."
	else:
		_status_label.text = Backend.NOT_CONFIGURED + " Everything else works offline."


func save_profile() -> void:
	var server: Dictionary = Backend.servers[_server_option.selected]
	var chosen := Backend.preset_names[_name_option.selected]
	Preferences.choose_name(chosen)
	_message_label.text = "Saving…"
	_message_label.text = await Backend.choose_identity(chosen, str(server["id"]))


func choose_text_size(index: int) -> void:
	Preferences.set_text_size(Preferences.accessibility.text_size_ids[index])


func choose_palette(index: int) -> void:
	Preferences.set_palette(Preferences.accessibility.palette_ids[index])


func replay_tutorial() -> void:
	Preferences.replay_tutorial()
	_message_label.text = "The tutorial and moment tips will show again."


## Links out only after the parental gate.
func open_privacy_policy() -> void:
	if await ParentalGateDialog.ask(self, "This opens a website."):
		OS.shell_open(Session.config.privacy_policy_url)


## Syncs every slot with a save, then submits rankings for them.
func sync_careers() -> void:
	var lines: Array[String] = []
	var migrate := CareerSaves.migrator(Session.rules)
	var validate := CareerSaves.validator(Session.balance, Session.world)
	_message_label.text = "Syncing…"
	for slot: int in range(1, Store.slot_count() + 1):
		if Session.saves.has_save(slot) or Backend.is_configured():
			var result: String = await Backend.sync_slot(slot, Session.saves, migrate, validate)
			lines.append(result)
			if Session.saves.has_save(slot) and not result.contains("offline"):
				lines.append(await Backend.submit_ranking(slot))
		if not Backend.is_configured():
			break
	_message_label.text = "\n".join(lines)


## First press asks to confirm; the second deletes the online account.
func press_delete() -> void:
	if not _confirming_delete:
		_confirming_delete = true
		_delete_button.text = "Tap again to delete for good"
		_message_label.text = "This deletes your online account, online saves and rankings."
		return
	_confirming_delete = false
	_delete_button.text = "Delete my account"
	var result: String = await Backend.delete_account()
	if _delete_local_check.button_pressed:
		for slot: int in range(1, Store.slot_count() + 1):
			Session.saves.delete(slot)
		result += " Careers on this device were deleted too."
	_message_label.text = result


func _setup_accessibility() -> void:
	var options := Preferences.accessibility
	for id: String in options.text_size_ids:
		_text_size_option.add_item(options.text_label(id))
	_text_size_option.select(options.text_size_ids.find(Preferences.settings.text_size))
	_text_size_option.item_selected.connect(choose_text_size)
	for id: String in options.palette_ids:
		_palette_option.add_item(options.palette_label(id))
	_palette_option.select(options.palette_ids.find(Preferences.settings.palette))
	_palette_option.item_selected.connect(choose_palette)
	_haptics_check.button_pressed = Preferences.settings.haptics
	_haptics_check.toggled.connect(Preferences.set_haptics)
