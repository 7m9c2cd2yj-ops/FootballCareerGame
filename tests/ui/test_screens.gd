extends GutTest
## Smoke tests for the M2 screens: they build from data and drive the core loop.

const SEASON_SCENE := preload("res://scenes/career/season_screen.tscn")
const SETUP_SCENE := preload("res://scenes/career/career_setup.tscn")
const MENU_SCENE := preload("res://scenes/main/main_menu.tscn")


func before_each() -> void:
	Session.career = CareerState.start("Test", "MID", Session.balance)


func after_each() -> void:
	Session.career = null
	Session.season_in_progress = null


func test_session_loaded_all_data() -> void:
	assert_true(Session.is_ready(), "\n".join(Session.load_errors))


func test_main_menu_shows_title_and_enables_new_career() -> void:
	var menu: Control = add_child_autofree(MENU_SCENE.instantiate())
	assert_eq((menu.get_node("%TitleLabel") as Label).text, Session.config.title)
	assert_false((menu.get_node("%NewCareerButton") as Button).disabled)


func test_setup_offers_every_position() -> void:
	var setup: Control = add_child_autofree(SETUP_SCENE.instantiate())
	var buttons := setup.get_node("%PositionList").get_child_count()
	assert_eq(buttons, Session.balance.positions().size())


func test_season_screen_quick_sims_a_season() -> void:
	var screen: Control = add_child_autofree(SEASON_SCENE.instantiate())
	screen.call("sim_season")
	assert_eq(Session.career.history.size(), 1)
	assert_string_contains((screen.get_node("%HeaderLabel") as Label).text, "Age 9")
	assert_string_contains((screen.get_node("%ResultLabel") as Label).text, "Season 1")


func test_season_finishes_after_its_key_moments() -> void:
	Session.begin_season(TrainingPlan.create("passing", "dribbling"))
	while not Session.has_finished_moments():
		var spec := Session.current_moment()
		Session.record_moment(
			MomentResult.create(spec, MomentResult.GOAL, 1.0, Vector2.ZERO, Vector2.ZERO)
		)
	var screen: Control = add_child_autofree(SEASON_SCENE.instantiate())
	assert_null(Session.season_in_progress)
	assert_eq(Session.career.history.size(), 1)
	var record := Session.career.history[0]
	assert_eq(record.key_moments_won, record.key_moments_played)
	assert_eq(record.primary_focus, "passing")
	assert_string_contains((screen.get_node("%ResultLabel") as Label).text, "Key moments")


func test_same_focus_twice_disables_play() -> void:
	var screen: Control = add_child_autofree(SEASON_SCENE.instantiate())
	var primary: OptionButton = screen.get_node("%PrimaryOption")
	var secondary: OptionButton = screen.get_node("%SecondaryOption")
	secondary.select(primary.selected)
	secondary.item_selected.emit(primary.selected)
	assert_true((screen.get_node("%PlayButton") as Button).disabled)


func test_finished_career_disables_play() -> void:
	Session.career.player.age = Session.balance.max_age
	var screen: Control = add_child_autofree(SEASON_SCENE.instantiate())
	var play: Button = screen.get_node("%PlayButton")
	assert_true(play.disabled)
	assert_eq(play.text, "Career complete")
