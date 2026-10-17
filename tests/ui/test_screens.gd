extends GutTest
## Smoke tests for the M2 screens: they build from data and drive the core loop.

const SEASON_SCENE := preload("res://scenes/career/season_screen.tscn")
const SETUP_SCENE := preload("res://scenes/career/career_setup.tscn")
const MENU_SCENE := preload("res://scenes/main/main_menu.tscn")


func before_each() -> void:
	Session.career = CareerState.start("Test", "MID", Session.balance)


func after_each() -> void:
	Session.career = null


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


func test_season_screen_plays_a_season() -> void:
	var screen: Control = add_child_autofree(SEASON_SCENE.instantiate())
	screen.call("play_season")
	assert_eq(Session.career.history.size(), 1)
	assert_string_contains((screen.get_node("%HeaderLabel") as Label).text, "Age 9")
	assert_string_contains((screen.get_node("%ResultLabel") as Label).text, "Season 1")


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
