extends Control
## New-career screen: the player picks a starting position.
## Buttons are built from the positions defined in data/balance.json.

const SEASON_SCENE := "res://scenes/career/season_screen.tscn"
const BUTTON_HEIGHT := 112.0

@onready var _position_list: VBoxContainer = %PositionList


func _ready() -> void:
	for position_code: String in Session.balance.positions():
		var button := Button.new()
		button.text = Session.labels.position_name(position_code)
		button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
		button.pressed.connect(choose_position.bind(position_code))
		_position_list.add_child(button)


func choose_position(position_code: String) -> void:
	Session.start_career(position_code, Session.pending_slot)
	get_tree().change_scene_to_file(SEASON_SCENE)
