extends GutTest
## Penalty and free-kick resolvers: placement and timing decide, ratings only
## widen or narrow the margin for error.

const Fixture := preload("res://tests/helpers/moment_fixture.gd")

var _tuning: MomentTuning


func before_all() -> void:
	_tuning = Fixture.tuning()


func _penalty(aim: Vector2, power: float, skill: float = 0.5, opponent: float = 0.5) -> String:
	var spec := Fixture.spec(MomentSpec.PENALTY, skill, opponent)
	return PenaltyResolver.resolve(spec, aim, power, _tuning).outcome


func test_power_bar_sweeps_up_and_down() -> void:
	assert_eq(PowerBar.value_at(0.0, 1.0), 0.0)
	assert_almost_eq(PowerBar.value_at(0.5, 1.0), 1.0, 1e-6)
	assert_almost_eq(PowerBar.value_at(0.25, 1.0), 0.5, 1e-6)
	assert_almost_eq(PowerBar.value_at(1.25, 1.0), 0.5, 1e-6)


func test_better_shooters_get_a_slower_power_bar() -> void:
	assert_gt(PowerBar.period(1.0, _tuning), PowerBar.period(0.0, _tuning))


func test_penalty_into_the_corner_scores() -> void:
	assert_eq(_penalty(Vector2(3.3, 0.3), 0.75), MomentResult.GOAL)


func test_central_penalty_is_saved() -> void:
	assert_eq(_penalty(Vector2(0.6, 0.8), 0.75), MomentResult.SAVED)


func test_penalty_wide_of_the_post_misses() -> void:
	assert_eq(_penalty(Vector2(4.5, 1.0), 0.75), MomentResult.MISSED)


func test_overhit_penalty_sails_over() -> void:
	assert_eq(_penalty(Vector2(2.8, 2.1), 1.0, 0.0), MomentResult.MISSED)
	assert_eq(_penalty(Vector2(2.8, 2.1), 0.75, 0.0), MomentResult.GOAL)


func test_skill_reduces_overhit_error() -> void:
	var weak := PenaltyResolver.aimed_target(Vector2(2.8, 1.5), 1.0, 0.0, _tuning)
	var strong := PenaltyResolver.aimed_target(Vector2(2.8, 1.5), 1.0, 1.0, _tuning)
	assert_gt(weak.y, strong.y)


func test_aim_assist_rescues_near_misses_for_skilled_shooters() -> void:
	var just_wide := Vector2(3.7, 1.0)
	assert_eq(_penalty(just_wide, 0.75, 0.1), MomentResult.MISSED)
	assert_eq(_penalty(just_wide, 0.75, 1.0), MomentResult.GOAL)


func test_stronger_keeper_reaches_further() -> void:
	var aim := Vector2(1.8, 1.0)
	assert_eq(_penalty(aim, 0.85, 0.5, 0.1), MomentResult.GOAL)
	assert_eq(_penalty(aim, 0.85, 0.5, 0.9), MomentResult.SAVED)


func test_goal_quality_rewards_better_placement() -> void:
	var spec := Fixture.spec(MomentSpec.PENALTY, 0.5, 0.5)
	var near := PenaltyResolver.resolve(spec, Vector2(2.6, 1.0), 0.8, _tuning)
	var corner := PenaltyResolver.resolve(spec, Vector2(3.4, 0.2), 0.8, _tuning)
	assert_true(near.success and corner.success)
	assert_gt(corner.quality, near.quality)


func test_same_input_same_result() -> void:
	var spec := Fixture.spec(MomentSpec.PENALTY, 0.37, 0.61)
	var first := PenaltyResolver.resolve(spec, Vector2(2.2, 1.3), 0.71, _tuning)
	for i: int in 10:
		var again := PenaltyResolver.resolve(spec, Vector2(2.2, 1.3), 0.71, _tuning)
		assert_eq([again.outcome, again.quality], [first.outcome, first.quality])


func _free_kick(spec: MomentSpec, aim: Vector2, curl: float, power: float) -> String:
	return FreeKickResolver.resolve(spec, aim, curl, power, _tuning).outcome


func test_low_free_kick_into_the_wall_is_blocked() -> void:
	var spec := Fixture.spec(MomentSpec.FREE_KICK, 0.5, 0.5)
	assert_eq(_free_kick(spec, Vector2(0.5, 0.5), 0.0, 0.75), MomentResult.BLOCKED)


func test_curl_takes_the_ball_round_the_wall() -> void:
	var spec := Fixture.spec(MomentSpec.FREE_KICK, 0.5, 0.5)
	assert_eq(_free_kick(spec, Vector2(-2.5, 1.0), 0.0, 0.75), MomentResult.BLOCKED)
	assert_ne(_free_kick(spec, Vector2(-2.5, 1.0), -1.0, 0.75), MomentResult.BLOCKED)


func test_soft_shot_dips_over_the_wall() -> void:
	var spec := Fixture.spec(MomentSpec.FREE_KICK, 0.5, 0.5)
	assert_eq(_free_kick(spec, Vector2(0.8, 2.2), 0.0, 0.85), MomentResult.BLOCKED)
	assert_ne(_free_kick(spec, Vector2(0.8, 2.2), 0.0, 0.45), MomentResult.BLOCKED)


func test_passing_skill_adds_curl() -> void:
	var weak := Fixture.spec(MomentSpec.FREE_KICK, 0.5, 0.5)
	weak.skills["passing"] = 0.0
	var strong := Fixture.spec(MomentSpec.FREE_KICK, 0.5, 0.5)
	strong.skills["passing"] = 1.0
	var aim := Vector2(0.5, 0.8)
	assert_eq(_free_kick(weak, aim, 0.6, 0.75), MomentResult.BLOCKED)
	assert_ne(_free_kick(strong, aim, 0.6, 0.75), MomentResult.BLOCKED)


func test_free_kick_to_the_corner_beats_the_keeper() -> void:
	var spec := Fixture.spec(MomentSpec.FREE_KICK, 0.5, 0.5)
	assert_eq(_free_kick(spec, Vector2(3.0, 2.0), 0.0, 0.75), MomentResult.GOAL)
