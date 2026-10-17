extends GutTest
## Smoke tests: the moment scene builds every moment type, drives the
## controller and shows the resolver's verdict.

const MOMENT_SCENE := preload("res://scenes/moments/moment_scene.tscn")
const Fixture := preload("res://tests/helpers/moment_fixture.gd")


func before_each() -> void:
	Session.start_career("FWD")
	Preferences.settings.tips_seen.assign(MomentSpec.TYPES)


func after_each() -> void:
	Session.career = null
	Session.season_in_progress = null
	Session.practice_moment = null
	Preferences.reload()


func _open(moment_type: String) -> Node:
	var season := SeasonInProgress.new()
	season.plan = TrainingPlan.create("shooting", "pace")
	season.moments.append(Fixture.spec(moment_type, 0.5, 0.5))
	Session.season_in_progress = season
	return add_child_autofree(MOMENT_SCENE.instantiate())


func _result_text(scene: Node) -> String:
	return (scene.get_node("%ResultLabel") as Label).text


func test_penalty_goal_is_shown() -> void:
	var scene := _open(MomentSpec.PENALTY)
	var controller: ShotController = scene.call("controller")
	controller.shoot(Vector2(3.3, 0.3), 0.0, 0.75)
	await wait_for_signal(controller.resolved, 3.0)
	assert_true((scene.get_node("%ResultPanel") as Control).visible)
	assert_string_contains(_result_text(scene), Session.labels.outcome_name(MomentResult.GOAL))


func test_free_kick_into_the_wall_is_shown() -> void:
	var scene := _open(MomentSpec.FREE_KICK)
	var controller: ShotController = scene.call("controller")
	controller.shoot(Vector2(0.5, 0.5), 0.0, 0.75)
	await wait_for_signal(controller.resolved, 3.0)
	assert_eq(_result_text(scene), Session.labels.outcome_name(MomentResult.BLOCKED))


func test_one_on_one_times_out_into_a_smother() -> void:
	var scene := _open(MomentSpec.ONE_ON_ONE)
	var controller: OneOnOneController = scene.call("controller")
	await wait_for_signal(controller.resolved, 5.0)
	assert_eq(_result_text(scene), Session.labels.outcome_name(MomentResult.SAVED))


func test_save_scene_accepts_a_dive() -> void:
	var scene := _open(MomentSpec.SAVE)
	var controller: SaveController = scene.call("controller")
	var spec := Session.current_moment()
	controller.dive(spec.shot_target, 0.2)
	await wait_for_signal(controller.resolved, 5.0)
	assert_string_contains(_result_text(scene), Session.labels.outcome_name(MomentResult.SAVED))


func test_screen_to_goal_round_trips_through_the_camera() -> void:
	var scene := _open(MomentSpec.PENALTY)
	var stage: MomentStage = scene.get_node("Stage")
	var camera := get_viewport().get_camera_3d()
	var screen := camera.unproject_position(Vector3(2.0, 1.2, 0.0))
	assert_almost_eq(stage.screen_to_goal(screen), Vector2(2.0, 1.2), Vector2(0.01, 0.01))


func test_first_moment_of_a_type_waits_behind_its_tip() -> void:
	Preferences.settings.tips_seen.clear()
	var scene := _open(MomentSpec.ONE_ON_ONE)
	assert_true((scene.get_node("%TipPanel") as Control).visible)
	assert_string_contains((scene.get_node("%TipLabel") as Label).text, "keeper is rushing out")
	await wait_seconds(0.5)
	var controller: OneOnOneController = scene.call("controller")
	assert_false(controller.is_done(), "the run must not start while the tip is open")
	(scene.get_node("%TipButton") as Button).pressed.emit()
	assert_true(Preferences.settings.tips_seen.has(MomentSpec.ONE_ON_ONE))
	assert_false(Preferences.needs_tip(MomentSpec.ONE_ON_ONE))


func test_practice_penalty_is_never_recorded() -> void:
	var season := SeasonInProgress.new()
	season.plan = TrainingPlan.create("shooting", "pace")
	season.moments.append(Fixture.spec(MomentSpec.PENALTY, 0.5, 0.5))
	Session.season_in_progress = season
	Session.start_practice(MomentSpec.PENALTY, "res://scenes/main/main_menu.tscn")
	var scene: Node = add_child_autofree(MOMENT_SCENE.instantiate())
	assert_string_contains((scene.get_node("%TitleLabel") as Label).text, "Practice")
	var controller: ShotController = scene.call("controller")
	controller.shoot(Vector2(3.3, 0.3), 0.0, 0.75)
	await wait_for_signal(controller.resolved, 3.0)
	assert_string_contains(_result_text(scene), "does not count")
	assert_eq(season.results.size(), 0, "the real season gets no result")


func test_result_text_uses_the_palette() -> void:
	Preferences.settings.palette = "colorblind"
	var scene := _open(MomentSpec.PENALTY)
	var controller: ShotController = scene.call("controller")
	controller.shoot(Vector2(3.3, 0.3), 0.0, 0.75)
	await wait_for_signal(controller.resolved, 3.0)
	var label: Label = scene.get_node("%ResultLabel")
	assert_eq(label.get_theme_color("font_color"), Preferences.color("success"))
	assert_eq(Preferences.color("success"), Color.html("#56b4e9"))
