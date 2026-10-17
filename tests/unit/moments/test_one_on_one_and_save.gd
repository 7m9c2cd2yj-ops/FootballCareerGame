extends GutTest
## One-on-one timing and the goalkeeper save resolver.

const Fixture := preload("res://tests/helpers/moment_fixture.gd")
const CORNER := Vector2(3.2, 0.4)

var _tuning: MomentTuning


func before_all() -> void:
	_tuning = Fixture.tuning()


func _one_on_one(spec: MomentSpec, action: String, time: float) -> String:
	return OneOnOneResolver.resolve(spec, action, time, CORNER, _tuning).outcome


## First time (in 0.01 s steps) at which the gap drops to `target_gap` or below.
func _time_at_gap(spec: MomentSpec, target_gap: float) -> float:
	var time := 0.0
	while OneOnOneResolver.gap(spec, time, _tuning) > target_gap:
		time += 0.01
	return time


func test_waiting_too_long_gets_smothered() -> void:
	var spec := Fixture.spec(MomentSpec.ONE_ON_ONE, 0.5, 0.5)
	var limit := OneOnOneResolver.time_limit(spec, _tuning)
	var smother := _tuning.value("one_on_one", "smother_gap")
	assert_almost_eq(OneOnOneResolver.gap(spec, limit, _tuning), smother, 0.001)
	assert_eq(_one_on_one(spec, OneOnOneResolver.SHOOT, limit + 0.05), MomentResult.SAVED)
	assert_eq(_one_on_one(spec, OneOnOneResolver.NONE, 0.5), MomentResult.SAVED)


func test_shooting_from_too_far_is_saved_but_closer_scores() -> void:
	var spec := Fixture.spec(MomentSpec.ONE_ON_ONE, 0.5, 0.5)
	assert_eq(_one_on_one(spec, OneOnOneResolver.SHOOT, 0.2), MomentResult.SAVED)
	assert_eq(_one_on_one(spec, OneOnOneResolver.SHOOT, 1.2), MomentResult.GOAL)


func test_chip_needs_the_keeper_off_their_line() -> void:
	var spec := Fixture.spec(MomentSpec.ONE_ON_ONE, 0.5, 0.5)
	assert_eq(_one_on_one(spec, OneOnOneResolver.CHIP, 0.8), MomentResult.SAVED)
	assert_eq(_one_on_one(spec, OneOnOneResolver.CHIP, 1.5), MomentResult.GOAL)


func test_rounding_the_keeper_is_about_timing() -> void:
	var spec := Fixture.spec(MomentSpec.ONE_ON_ONE, 0.5, 0.5)
	assert_eq(
		_one_on_one(spec, OneOnOneResolver.ROUND, _time_at_gap(spec, 6.0)), MomentResult.SAVED
	)
	assert_eq(_one_on_one(spec, OneOnOneResolver.ROUND, _time_at_gap(spec, 2.5)), MomentResult.GOAL)


func test_dribbling_widens_the_rounding_window() -> void:
	var clumsy := Fixture.spec(MomentSpec.ONE_ON_ONE, 0.5, 0.5)
	clumsy.skills["dribbling"] = 0.0
	var silky := Fixture.spec(MomentSpec.ONE_ON_ONE, 0.5, 0.5)
	silky.skills["dribbling"] = 1.0
	var time := _time_at_gap(clumsy, 3.6)
	assert_eq(_one_on_one(clumsy, OneOnOneResolver.ROUND, time), MomentResult.SAVED)
	assert_eq(_one_on_one(silky, OneOnOneResolver.ROUND, time), MomentResult.GOAL)


func _save(spec: MomentSpec, dive: Vector2, reaction: float) -> MomentResult:
	return SaveResolver.resolve(spec, true, dive, reaction, _tuning)


func test_quick_dive_to_the_ball_saves() -> void:
	var spec := Fixture.spec(MomentSpec.SAVE, 0.5, 0.5)
	var result := _save(spec, spec.shot_target, 0.3)
	assert_eq(result.outcome, MomentResult.SAVED)
	assert_true(result.success)


func test_late_dive_concedes() -> void:
	var spec := Fixture.spec(MomentSpec.SAVE, 0.5, 0.5)
	assert_eq(_save(spec, spec.shot_target, 0.8).outcome, MomentResult.CONCEDED)


func test_diving_the_wrong_way_concedes() -> void:
	var spec := Fixture.spec(MomentSpec.SAVE, 0.5, 0.5)
	assert_eq(_save(spec, Vector2(-2.5, 1.5), 0.2).outcome, MomentResult.CONCEDED)


func test_not_diving_concedes_a_shot_to_the_corner() -> void:
	var spec := Fixture.spec(MomentSpec.SAVE, 0.5, 0.5)
	var result := SaveResolver.resolve(spec, false, Vector2.ZERO, 0.0, _tuning)
	assert_eq(result.outcome, MomentResult.CONCEDED)


func test_better_goalkeeper_has_more_time() -> void:
	var weak := Fixture.spec(MomentSpec.SAVE, 0.0, 0.5)
	var strong := Fixture.spec(MomentSpec.SAVE, 1.0, 0.5)
	assert_eq(_save(weak, weak.shot_target, 0.55).outcome, MomentResult.CONCEDED)
	assert_eq(_save(strong, strong.shot_target, 0.55).outcome, MomentResult.SAVED)
