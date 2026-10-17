class_name OneOnOneController
extends MomentController
## One-on-one: the run starts at once. Tap the goal to shoot there, or press
## Chip / Round. Wait too long and the keeper smothers the ball.

var _time: float = 0.0
var _limit: float = 0.0


func begin() -> void:
	_limit = OneOnOneResolver.time_limit(spec, tuning)
	hud.show_actions(true)
	hud.show_instruction("Tap the goal to shoot, or Chip / Round the keeper")


func tick(delta: float) -> void:
	if is_done():
		return
	_time += delta
	var run_time := minf(_time, _limit)
	stage.set_run(
		OneOnOneResolver.attacker_distance(spec, run_time, tuning),
		OneOnOneResolver.keeper_out(run_time, tuning)
	)
	if _time >= _limit:
		act(OneOnOneResolver.NONE, Vector2.ZERO)


func press(screen: Vector2) -> void:
	act(OneOnOneResolver.SHOOT, stage.screen_to_goal(screen))


func action(name: String) -> void:
	act(name, Vector2.ZERO)


## Resolves the chosen action at the current run time (also used by tests).
func act(action_name: String, aim: Vector2) -> void:
	if is_done():
		return
	hud.show_actions(false)
	var result := OneOnOneResolver.resolve(spec, action_name, _time, aim, tuning)
	var distance := OneOnOneResolver.attacker_distance(spec, _time, tuning)
	finish(result, distance / tuning.value("one_on_one", "shot_speed"), 0.0)
