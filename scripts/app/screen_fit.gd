extends Node
## Autoload "ScreenFit": keeps UI at a readable size in both orientations by
## switching the 2D base resolution between portrait and landscape whenever
## the window's shape changes (menus are portrait, 3D moments landscape).
## Also applies the text-size setting (as a UI scale) and keeps controls in
## the "safe_area" group clear of notches and rounded corners on phones.

const PORTRAIT_BASE := Vector2i(720, 1280)
const LANDSCAPE_BASE := Vector2i(1280, 720)
const SAFE_AREA_GROUP := "safe_area"
## Offsets a safe-area control had in its scene, before any insets.
const BASE_OFFSETS_META := &"safe_area_base_offsets"


func _ready() -> void:
	get_tree().root.size_changed.connect(_fit)
	get_tree().node_added.connect(_on_node_added)
	Preferences.changed.connect(_fit)
	_fit()


## Safe-area margins in canvas units; zero off phones.
func margins() -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var window := get_tree().root
	var window_rect := Rect2i(window.position, window.size)
	var canvas := window.get_visible_rect().size
	return SafeArea.margins(DisplayServer.get_display_safe_area(), window_rect, canvas)


func _fit() -> void:
	var window := get_tree().root
	var landscape := window.size.x > window.size.y
	window.content_scale_size = LANDSCAPE_BASE if landscape else PORTRAIT_BASE
	window.content_scale_factor = Preferences.text_scale()
	for node: Node in get_tree().get_nodes_in_group(SAFE_AREA_GROUP):
		_apply(node as Control)


func _on_node_added(node: Node) -> void:
	if node is Control and node.is_in_group(SAFE_AREA_GROUP):
		_apply(node as Control)


## Adds the safe-area margins to the control's own offsets from its scene.
func _apply(control: Control) -> void:
	if control == null:
		return
	if not control.has_meta(BASE_OFFSETS_META):
		var scene_offsets := Vector4(
			control.offset_left, control.offset_top, control.offset_right, control.offset_bottom
		)
		control.set_meta(BASE_OFFSETS_META, scene_offsets)
	var base: Vector4 = control.get_meta(BASE_OFFSETS_META)
	var inset := margins()
	control.offset_left = base.x + inset.x
	control.offset_top = base.y + inset.y
	control.offset_right = base.z - inset.z
	control.offset_bottom = base.w - inset.w
