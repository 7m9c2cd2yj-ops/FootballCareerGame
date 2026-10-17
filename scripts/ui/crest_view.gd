class_name CrestView
extends Control
## Draws a club crest from simple vector shapes: an outline shape filled with
## the primary colour, a pattern in the secondary colour and the club initials.
## Fully original artwork generated from data/clubs.json.

const OUTLINE := Color(1, 1, 1, 0.9)
const OUTLINE_WIDTH := 2.0
## Shapes and patterns in a unit square; scaled to the control's size.
const SHIELD: Array[Vector2] = [
	Vector2(0.1, 0.05),
	Vector2(0.9, 0.05),
	Vector2(0.9, 0.55),
	Vector2(0.5, 0.97),
	Vector2(0.1, 0.55)
]
const DIAMOND: Array[Vector2] = [
	Vector2(0.5, 0.02), Vector2(0.98, 0.5), Vector2(0.5, 0.98), Vector2(0.02, 0.5)
]
const CHEVRON: Array[Vector2] = [
	Vector2(0, 0.35),
	Vector2(0.5, 0.6),
	Vector2(1, 0.35),
	Vector2(1, 0.52),
	Vector2(0.5, 0.77),
	Vector2(0, 0.52)
]

var _club: Club = null


func show_club(club: Club) -> void:
	_club = club
	queue_redraw()


func _draw() -> void:
	if _club == null:
		return
	var outline := _scaled(_shape_points(_club.crest_shape))
	draw_colored_polygon(outline, _club.crest_primary)
	for stripe: PackedVector2Array in _pattern_polygons(_club.crest_pattern):
		for clipped: PackedVector2Array in Geometry2D.intersect_polygons(_scaled(stripe), outline):
			draw_colored_polygon(clipped, _club.crest_secondary)
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, OUTLINE, OUTLINE_WIDTH, true)
	_draw_initials()


func _draw_initials() -> void:
	var font := get_theme_default_font()
	var font_size := int(size.y * 0.26)
	var baseline := Vector2(0, size.y * 0.5 + font_size * 0.35)
	var text := _club.initials()
	draw_string_outline(
		font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, 6, Color.BLACK
	)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color.WHITE)


func _shape_points(shape: String) -> PackedVector2Array:
	match shape:
		"shield":
			return PackedVector2Array(SHIELD)
		"diamond":
			return PackedVector2Array(DIAMOND)
		"hexagon":
			return _regular_polygon(6, PI / 6.0)
	return _regular_polygon(32, 0.0)


func _regular_polygon(sides: int, rotation_offset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in sides:
		var angle := TAU * i / sides + rotation_offset
		points.append(Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * 0.47)
	return points


func _pattern_polygons(pattern: String) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	match pattern:
		"stripes":
			polygons.append(_rect(Vector2(0.2, 0), Vector2(0.4, 1)))
			polygons.append(_rect(Vector2(0.6, 0), Vector2(0.8, 1)))
		"halves":
			polygons.append(_rect(Vector2(0.5, 0), Vector2(1, 1)))
		"band":
			polygons.append(_rect(Vector2(0, 0.62), Vector2(1, 0.8)))
		"chevron":
			polygons.append(PackedVector2Array(CHEVRON))
	return polygons


func _rect(top_left: Vector2, bottom_right: Vector2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			top_left,
			Vector2(bottom_right.x, top_left.y),
			bottom_right,
			Vector2(top_left.x, bottom_right.y),
		]
	)


func _scaled(points: PackedVector2Array) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(point * size)
	return scaled
