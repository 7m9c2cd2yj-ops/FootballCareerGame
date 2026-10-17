extends Control
## Entry screen: title, version, legal disclaimer and the way to your careers,
## the ARENA, the locker and settings.
## Display only; data comes from the Session autoload.

const CAREERS_SCENE := "res://scenes/main/careers_screen.tscn"
const ARENA_SCENE := "res://scenes/main/arena_screen.tscn"
const SETTINGS_SCENE := "res://scenes/main/settings_screen.tscn"
const ONBOARDING_SCENE := "res://scenes/main/onboarding.tscn"
const LOCKER_SCENE := "res://scenes/main/locker_screen.tscn"

@onready var _title_label: Label = %TitleLabel
@onready var _version_label: Label = %VersionLabel
@onready var _disclaimer_label: Label = %DisclaimerLabel
@onready var _new_career_button: Button = %NewCareerButton


func _ready() -> void:
	_new_career_button.pressed.connect(_on_new_career_pressed)
	(%ArenaButton as Button).pressed.connect(
		func() -> void: get_tree().change_scene_to_file(ARENA_SCENE)
	)
	(%SettingsButton as Button).pressed.connect(
		func() -> void: get_tree().change_scene_to_file(SETTINGS_SCENE)
	)
	(%LockerButton as Button).pressed.connect(
		func() -> void: get_tree().change_scene_to_file(LOCKER_SCENE)
	)
	if not Session.is_ready():
		_title_label.text = "Data error"
		_disclaimer_label.text = "\n".join(Session.load_errors)
		_new_career_button.disabled = true
		return
	_title_label.text = Session.config.title
	_version_label.text = "v%s" % Session.config.version
	_disclaimer_label.text = Session.config.disclaimer
	get_window().title = Session.config.title


## First launch goes through onboarding before the careers screen.
func _on_new_career_pressed() -> void:
	var done := Preferences.settings.onboarding_done
	get_tree().change_scene_to_file(CAREERS_SCENE if done else ONBOARDING_SCENE)
