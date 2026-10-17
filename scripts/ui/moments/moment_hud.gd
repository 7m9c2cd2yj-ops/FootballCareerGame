class_name MomentHud
extends Control
## 2D overlay for a key moment: instructions, power bar, curl readout,
## one-on-one action buttons and the result panel. Display and buttons only.

signal action_pressed(action: String)
signal continue_pressed

@onready var _title_label: Label = %TitleLabel
@onready var _instruction_label: Label = %InstructionLabel
@onready var _power_bar: ProgressBar = %PowerBar
@onready var _curl_label: Label = %CurlLabel
@onready var _action_bar: HBoxContainer = %ActionBar
@onready var _result_panel: PanelContainer = %ResultPanel
@onready var _result_label: Label = %ResultLabel


func _ready() -> void:
	(%ChipButton as Button).pressed.connect(action_pressed.emit.bind(OneOnOneResolver.CHIP))
	(%RoundButton as Button).pressed.connect(action_pressed.emit.bind(OneOnOneResolver.ROUND))
	(%ContinueButton as Button).pressed.connect(continue_pressed.emit)
	hide_power()
	hide_curl()
	show_actions(false)
	_result_panel.visible = false


func show_title(text: String) -> void:
	_title_label.text = text


func show_instruction(text: String) -> void:
	_instruction_label.text = text


func show_power(value: float) -> void:
	_power_bar.visible = true
	_power_bar.value = value * 100.0


func hide_power() -> void:
	_power_bar.visible = false


## `curl` is -1..1; shown as a direction and strength.
func show_curl(curl: float) -> void:
	_curl_label.visible = true
	var direction := "left" if curl < 0.0 else "right"
	_curl_label.text = (
		"Curl: none"
		if is_zero_approx(curl)
		else "Curl %s %d%%" % [direction, absi(roundi(curl * 100))]
	)


func hide_curl() -> void:
	_curl_label.visible = false


func show_actions(visible_now: bool) -> void:
	_action_bar.visible = visible_now


func show_result(text: String) -> void:
	_instruction_label.text = ""
	hide_power()
	hide_curl()
	show_actions(false)
	_result_label.text = text
	_result_panel.visible = true
