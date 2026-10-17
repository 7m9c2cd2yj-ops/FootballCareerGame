class_name ParentalGateDialog
extends PanelContainer
## Full-screen grown-up check (ParentalGate) shown before a purchase or a link
## out of the game. `ask` adds it over `host` and waits for the answer.

signal answered(passed: bool)

const BUTTON_HEIGHT := 96.0
const BACKDROP := Color(0.06, 0.08, 0.12, 0.97)

var gate: ParentalGate = null


## True only if a grown-up picked the right answer.
static func ask(host: Control, reason: String) -> bool:
	var dialog := ParentalGateDialog.new()
	dialog.gate = ParentalGate.create(Time.get_ticks_usec())
	host.add_child(dialog)
	dialog.build(reason)
	var passed: bool = await dialog.answered
	dialog.queue_free()
	return passed


func build(reason: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = BACKDROP
	add_theme_stylebox_override("panel", backdrop)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 20)
	margin.add_child(layout)
	layout.add_child(_label(reason))
	layout.add_child(_label(gate.question()))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	layout.add_child(grid)
	for choice: int in gate.choices:
		var button := _button(str(choice), choose.bind(choice))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
	layout.add_child(_button("Cancel", answered.emit.bind(false)))


## Picks an answer (also used by tests).
func choose(choice: int) -> void:
	answered.emit(gate.is_correct(choice))


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.pressed.connect(on_press)
	return button
