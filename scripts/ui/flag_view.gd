class_name FlagView
extends Control
## Draws a fictional nation's flag from data/nations.json: stripes, a cross,
## a diagonal split or a disc, in the nation's colours.

const BORDER := Color(1, 1, 1, 0.7)

var _nation: Nation = null


func show_nation(nation: Nation) -> void:
	_nation = nation
	queue_redraw()


func _draw() -> void:
	if _nation == null:
		return
	var colors := _nation.flag_colors
	var full := Rect2(Vector2.ZERO, size)
	match _nation.flag_pattern:
		"horizontal":
			_stripes(colors, false)
		"vertical":
			_stripes(colors, true)
		"cross":
			draw_rect(full, colors[0])
			draw_rect(Rect2(size.x * 0.3, 0, size.x * 0.16, size.y), colors[1])
			draw_rect(Rect2(0, size.y * 0.42, size.x, size.y * 0.16), colors[1])
		"diagonal":
			draw_rect(full, colors[0])
			draw_colored_polygon(
				PackedVector2Array([Vector2(size.x, 0), size, Vector2(0, size.y)]), colors[1]
			)
		_:
			draw_rect(full, colors[0])
			draw_circle(size / 2.0, size.y * 0.3, colors[1])
	draw_rect(full, BORDER, false, 2.0)


func _stripes(colors: Array[Color], vertical: bool) -> void:
	var count := colors.size()
	for i: int in count:
		var stripe := Rect2(0, size.y * i / count, size.x, size.y / count)
		if vertical:
			stripe = Rect2(size.x * i / count, 0, size.x / count, size.y)
		draw_rect(stripe, colors[i])
