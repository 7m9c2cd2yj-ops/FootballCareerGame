class_name MomentController
extends RefCounted
## Base for the per-moment input handlers. A controller turns touches into the
## inputs a resolver needs, resolves the moment, asks the stage to animate it
## and then emits `resolved`. Subclasses override the input hooks they use.

signal resolved(result: MomentResult)

var spec: MomentSpec = null
var tuning: MomentTuning = null
var stage: MomentStage = null
var hud: MomentHud = null
var _done: bool = false


func setup(
	moment_spec: MomentSpec,
	moment_tuning: MomentTuning,
	moment_stage: MomentStage,
	moment_hud: MomentHud
) -> void:
	spec = moment_spec
	tuning = moment_tuning
	stage = moment_stage
	hud = moment_hud


func is_done() -> bool:
	return _done


func begin() -> void:
	pass


func press(_screen: Vector2) -> void:
	pass


func drag(_screen: Vector2) -> void:
	pass


func release(_screen: Vector2) -> void:
	pass


func tick(_delta: float) -> void:
	pass


func action(_name: String) -> void:
	pass


## Animates `result` for `duration` seconds, then emits `resolved` once.
func finish(result: MomentResult, duration: float, bend: float) -> void:
	_done = true
	stage.hide_aim()
	stage.play_result(result, duration, bend)
	await stage.animation_finished
	resolved.emit(result)
