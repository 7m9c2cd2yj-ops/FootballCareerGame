class_name SaveController
extends MomentController
## Save: after a short run-up the opponent shoots. Tap or swipe where the ball
## is going to dive there; the earlier you react, the further you can reach.

const RUN_UP_TIME := 1.0

var _clock: float = 0.0
var _shot_started: bool = false
var _has_dive: bool = false
var _dive_target: Vector2 = Vector2.ZERO
var _reaction_time: float = 0.0


func begin() -> void:
	hud.show_instruction("Get ready…")
	stage.run_up(RUN_UP_TIME)


func tick(delta: float) -> void:
	if is_done():
		return
	_clock += delta
	if not _shot_started and _clock >= RUN_UP_TIME:
		_shot_started = true
		hud.show_instruction("Tap where the ball is going!")
		var target := Vector3(spec.shot_target.x, spec.shot_target.y, 0.0)
		stage.animate_ball(target, SaveResolver.flight_time(spec), 0.0)
	if _shot_started and _shot_time() >= SaveResolver.flight_time(spec):
		_resolve()


func press(screen: Vector2) -> void:
	if _shot_started:
		dive(stage.screen_to_goal(screen), _shot_time())


## Commits the dive (also used by tests). Only the first dive counts.
func dive(target: Vector2, reaction_time: float) -> void:
	if is_done() or _has_dive:
		return
	_has_dive = true
	_dive_target = target
	_reaction_time = reaction_time
	var preview := SaveResolver.resolve(spec, true, target, reaction_time, tuning)
	stage.dive_keeper(
		preview.keeper_target, maxf(SaveResolver.flight_time(spec) - reaction_time, 0.1)
	)


func _shot_time() -> float:
	return _clock - RUN_UP_TIME


func _resolve() -> void:
	var result := SaveResolver.resolve(spec, _has_dive, _dive_target, _reaction_time, tuning)
	# The ball is already at the goal line; a short beat lets the dive land.
	finish(result, 0.0, 0.0)
