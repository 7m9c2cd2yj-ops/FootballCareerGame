extends Node
## Plays the current key moment from Session: builds the stage, routes touch
## input to the right controller and records the result. Landscape on phones.
## A practice moment (onboarding) is played the same way but never recorded.

const SEASON_SCENE := "res://scenes/career/season_screen.tscn"

var _controller: MomentController = null
var _result: MomentResult = null
var _practice: bool = false

@onready var _stage: MomentStage = $Stage
@onready var _hud: MomentHud = %Hud


func _ready() -> void:
	_practice = Session.practice_moment != null
	var spec := Session.practice_moment if _practice else Session.current_moment()
	if spec == null:
		get_tree().change_scene_to_file.call_deferred(SEASON_SCENE)
		return
	_set_landscape(true)
	_stage.build(spec, Session.moment_tuning, _look())
	_hud.set_colors(
		Preferences.color("power"), Preferences.color("success"), Preferences.color("failure")
	)
	_controller = _controller_for(spec)
	_controller.setup(spec, Session.moment_tuning, _stage, _hud)
	_controller.resolved.connect(_on_resolved)
	_hud.action_pressed.connect(_controller.action)
	_hud.continue_pressed.connect(_on_continue)
	_hud.show_title(_title(spec))
	if Preferences.needs_tip(spec.moment_type):
		_hud.show_tip(Session.labels.tip(spec.moment_type))
		_hud.tip_closed.connect(_begin.bind(spec.moment_type), CONNECT_ONE_SHOT)
	else:
		_controller.begin()


func controller() -> MomentController:
	return _controller


func _process(delta: float) -> void:
	if _controller != null and not _hud.is_tip_open():
		_controller.tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _controller == null or _controller.is_done() or _hud.is_tip_open():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_controller.press(touch.position)
		else:
			_controller.release(touch.position)
	elif event is InputEventScreenDrag:
		_controller.drag((event as InputEventScreenDrag).position)


func _begin(moment_type: String) -> void:
	Preferences.mark_tip_seen(moment_type)
	_controller.begin()


func _title(spec: MomentSpec) -> String:
	var moment := Session.labels.moment_name(spec.moment_type)
	if _practice:
		return "Practice · %s" % moment
	var total := Session.season_in_progress.moments.size()
	return "%s · %d of %d" % [moment, spec.index + 1, total]


## Palette colours plus the player's equipped cosmetics (display only).
func _look() -> MomentStage.Look:
	var look := MomentStage.Look.new()
	look.player_kit = Preferences.color("player_kit")
	look.opponent_kit = Preferences.color("opponent_kit")
	look.keeper_kit = Preferences.color("keeper_kit")
	look.aim = Preferences.color("aim")
	var kit := str(Store.equipped(StoreCatalog.KITS).get("color", StoreCatalog.PALETTE_COLOR))
	if kit != StoreCatalog.PALETTE_COLOR:
		look.player_kit = Color.html(kit)
	look.boots = Color.html(str(Store.equipped(StoreCatalog.BOOTS)["color"]))
	look.celebration = str(Store.equipped(StoreCatalog.CELEBRATIONS)["style"])
	return look


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
		_stage.celebrate()
	if _practice:
		text += "\nPractice: this does not count."
	Preferences.pulse(result.success)
	_hud.show_result(text, result.success)


func _on_continue() -> void:
	if _practice:
		_finish_practice()
		return
	Session.record_moment(_result)
	if Session.has_finished_moments():
		_set_landscape(false)
		get_tree().change_scene_to_file(SEASON_SCENE)
	else:
		get_tree().reload_current_scene()


func _finish_practice() -> void:
	var back := Session.practice_return_scene
	Session.practice_moment = null
	_set_landscape(false)
	get_tree().change_scene_to_file(back)


## Phones switch to landscape for moments and back to portrait for menus.
func _set_landscape(landscape: bool) -> void:
	if not OS.has_feature("mobile"):
		return
	var orientation := DisplayServer.SCREEN_PORTRAIT
	if landscape:
		orientation = DisplayServer.SCREEN_SENSOR_LANDSCAPE
	DisplayServer.screen_set_orientation(orientation)
