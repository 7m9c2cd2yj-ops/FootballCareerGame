extends Control
## Entry screen: title, version, legal disclaimer and the way into a new career.
## Display only; data comes from the Session autoload.

const CAREER_SETUP_SCENE := "res://scenes/career/career_setup.tscn"

@onready var _title_label: Label = %TitleLabel
@onready var _version_label: Label = %VersionLabel
@onready var _disclaimer_label: Label = %DisclaimerLabel
@onready var _new_career_button: Button = %NewCareerButton


func _ready() -> void:
	_new_career_button.pressed.connect(_on_new_career_pressed)
	if not Session.is_ready():
		_title_label.text = "Data error"
		_disclaimer_label.text = "\n".join(Session.load_errors)
		_new_career_button.disabled = true
		return
	_title_label.text = Session.config.title
	_version_label.text = "v%s" % Session.config.version
	_disclaimer_label.text = Session.config.disclaimer
	get_window().title = Session.config.title


func _on_new_career_pressed() -> void:
	get_tree().change_scene_to_file(CAREER_SETUP_SCENE)
