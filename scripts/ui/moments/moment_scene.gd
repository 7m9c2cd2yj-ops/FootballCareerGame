extends Node
## Plays the current key moment from Session: builds the stage, routes touch
## input to the right controller and records the result. Landscape on phones.

const SEASON_SCENE := "res://scenes/career/season_screen.tscn"

var _controller: MomentController = null
var _result: MomentResult = null

@onready var _stage: MomentStage = $Stage
@onready var _hud: MomentHud = %Hud


func _ready() -> void:
	var spec := Session.current_moment()
	if spec == null:
		get_tree().change_scene_to_file.call_deferred(SEASON_SCENE)
		return
	_set_landscape(true)
	_stage.build(spec, Session.moment_tuning)
	_controller = _controller_for(spec)
	_controller.setup(spec, Session.moment_tuning, _stage, _hud)
	_controller.resolved.connect(_on_resolved)
	_hud.action_pressed.connect(_controller.action)
	_hud.continue_pressed.connect(_on_continue)
	var season := Session.season_in_progress
	_hud.show_title(
		(
			"%s · %d of %d"
			% [Session.labels.moment_name(spec.moment_type), spec.index + 1, season.moments.size()]
		)
	)
	_controller.begin()


func controller() -> MomentController:
	return _controller


func _process(delta: float) -> void:
	if _controller != null:
		_controller.tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _controller == null or _controller.is_done():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_controller.press(touch.position)
		else:
			_controller.release(touch.position)
	elif event is InputEventScreenDrag:
		_controller.drag((event as InputEventScreenDrag).position)


func _controller_for(spec: MomentSpec) -> MomentController:
	match spec.moment_type:
		MomentSpec.ONE_ON_ONE:
			return OneOnOneController.new()
		MomentSpec.SAVE, MomentSpec.PENALTY_SAVE:
			return SaveController.new()
	return ShotController.new()


func _on_resolved(result: MomentResult) -> void:
	_result = result
	var text := Session.labels.outcome_name(result.outcome)
	if result.success:
		text += "\nQuality %d%%" % roundi(result.quality * 100)
	_hud.show_result(text)


func _on_continue() -> void:
	Session.record_moment(_result)
	if Session.has_finished_moments():
		_set_landscape(false)
		get_tree().change_scene_to_file(SEASON_SCENE)
	else:
		get_tree().reload_current_scene()


## Phones switch to landscape for moments and back to portrait for menus.
func _set_landscape(landscape: bool) -> void:
	if not OS.has_feature("mobile"):
		return
	var orientation := DisplayServer.SCREEN_PORTRAIT
	if landscape:
		orientation = DisplayServer.SCREEN_SENSOR_LANDSCAPE
	DisplayServer.screen_set_orientation(orientation)
