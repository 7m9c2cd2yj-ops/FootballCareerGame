extends Node
## Autoload "ScreenFit": keeps UI at a readable size in both orientations by
## switching the 2D base resolution between portrait and landscape whenever
## the window's shape changes (menus are portrait, 3D moments landscape).

const PORTRAIT_BASE := Vector2i(720, 1280)
const LANDSCAPE_BASE := Vector2i(1280, 720)


func _ready() -> void:
	get_tree().root.size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	var window := get_tree().root
	var landscape := window.size.x > window.size.y
	window.content_scale_size = LANDSCAPE_BASE if landscape else PORTRAIT_BASE
