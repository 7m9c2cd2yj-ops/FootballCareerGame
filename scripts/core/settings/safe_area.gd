class_name SafeArea
extends RefCounted
## Converts the device's safe area (the screen minus notches and rounded
## corners, in screen pixels) into margins in the UI's canvas units.


## Margins (left, top, right, bottom) to keep inside the safe area. `safe` and
## `window` are screen-pixel rects; `canvas_size` is the UI's size in canvas
## units. An empty safe area means "no restriction".
static func margins(safe: Rect2i, window: Rect2i, canvas_size: Vector2) -> Vector4:
	if safe.size.x <= 0 or safe.size.y <= 0 or window.size.x <= 0 or window.size.y <= 0:
		return Vector4.ZERO
	var inside := safe.intersection(window)
	if inside.size.x <= 0 or inside.size.y <= 0:
		return Vector4.ZERO
	var scale := canvas_size / Vector2(window.size)
	var left := (inside.position.x - window.position.x) * scale.x
	var top := (inside.position.y - window.position.y) * scale.y
	var right := (window.end.x - inside.end.x) * scale.x
	var bottom := (window.end.y - inside.end.y) * scale.y
	return Vector4(left, top, right, bottom)
