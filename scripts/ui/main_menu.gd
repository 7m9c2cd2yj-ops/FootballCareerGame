extends Control
## Entry screen: shows the game title, version and legal disclaimer.
## Display only; all data comes from GameConfig.

@onready var _title_label: Label = %TitleLabel
@onready var _version_label: Label = %VersionLabel
@onready var _disclaimer_label: Label = %DisclaimerLabel


func _ready() -> void:
	var errors: Array[String] = []
	var config := GameConfig.load_file(GameConfig.DEFAULT_PATH, errors)
	if config == null:
		for error: String in errors:
			push_error(error)
		_title_label.text = "Configuration error"
		return
	_title_label.text = config.title
	_version_label.text = "v%s" % config.version
	_disclaimer_label.text = config.disclaimer
	get_window().title = config.title
