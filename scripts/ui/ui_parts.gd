class_name UiParts
extends RefCounted
## Small builders for the screens that are made in code (store, locker,
## onboarding), so they share sizes and wrapping.

const BUTTON_HEIGHT := 96.0


static func label(text: String, font_size: int = 0) -> Label:
	var built := Label.new()
	built.text = text
	built.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size > 0:
		built.add_theme_font_size_override("font_size", font_size)
	return built


static func button(text: String, on_press: Callable) -> Button:
	var built := Button.new()
	built.text = text
	built.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	built.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	built.pressed.connect(on_press)
	return built


## Removes and frees every child of `container`.
static func clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
