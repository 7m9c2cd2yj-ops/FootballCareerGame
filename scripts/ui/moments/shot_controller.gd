class_name ShotController
extends MomentController
## Penalty and free kick: drag on the goal to aim, (free kick only) drag left
## or right to curl, then hold anywhere and release to set the power.

enum Step { AIM, CURL, POWER_READY, POWERING }

## Horizontal drag, in viewport pixels, that gives full curl.
const FULL_CURL_DRAG := 240.0

var _step: Step = Step.AIM
var _aim: Vector2 = Vector2.ZERO
var _has_aim: bool = false
var _curl: float = 0.0
var _curl_origin_x: float = 0.0
var _hold_time: float = 0.0
var _bar_period: float = 1.0


func begin() -> void:
	_bar_period = PowerBar.period(spec.skill("shooting"), tuning)
	hud.show_instruction("Drag on the goal to aim")


func press(screen: Vector2) -> void:
	match _step:
		Step.AIM:
			_set_aim(stage.screen_to_goal(screen))
		Step.CURL:
			_curl_origin_x = screen.x
		Step.POWER_READY:
			_step = Step.POWERING
			_hold_time = 0.0


func drag(screen: Vector2) -> void:
	match _step:
		Step.AIM:
			_set_aim(stage.screen_to_goal(screen))
		Step.CURL:
			_curl = clampf((screen.x - _curl_origin_x) / FULL_CURL_DRAG, -1.0, 1.0)
			hud.show_curl(_curl)


func release(_screen: Vector2) -> void:
	match _step:
		Step.AIM:
			if _has_aim:
				_advance_from_aim()
		Step.CURL:
			_ready_for_power()
		Step.POWERING:
			shoot(_aim, _curl, PowerBar.value_at(_hold_time, _bar_period))


func tick(delta: float) -> void:
	if _step == Step.POWERING and not is_done():
		_hold_time += delta
		hud.show_power(PowerBar.value_at(_hold_time, _bar_period))


## Resolves the shot with explicit inputs (also used by tests).
func shoot(aim: Vector2, curl: float, power: float) -> void:
	if is_done():
		return
	var result: MomentResult
	if spec.moment_type == MomentSpec.FREE_KICK:
		result = FreeKickResolver.resolve(spec, aim, curl, power, tuning)
	else:
		result = PenaltyResolver.resolve(spec, aim, power, tuning)
	var duration := spec.distance / ShotModel.speed(power, tuning)
	# Visual only: the path bows the same way the curl pushed it past the wall.
	finish(result, duration, curl * tuning.value("free_kick", "curl_bend"))


func _set_aim(point: Vector2) -> void:
	_aim = point
	_has_aim = true
	stage.show_aim(point)


func _advance_from_aim() -> void:
	if spec.moment_type == MomentSpec.FREE_KICK:
		_step = Step.CURL
		hud.show_curl(0.0)
		hud.show_instruction("Drag left or right to curl it round the wall, then let go")
	else:
		_ready_for_power()


func _ready_for_power() -> void:
	_step = Step.POWER_READY
	hud.show_power(0.0)
	hud.show_instruction("Hold to power up, release to shoot")
