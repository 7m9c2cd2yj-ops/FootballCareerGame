extends GutTest
## Smoke tests for the Clubs app and the career summary.

const CLUBS_SCENE := preload("res://scenes/career/clubs_app.tscn")
const SUMMARY_SCENE := preload("res://scenes/career/career_summary.tscn")
const SEASON_SCENE := preload("res://scenes/career/season_screen.tscn")


func before_each() -> void:
	Session.start_career("FWD")


func after_each() -> void:
	Session.career = null


func _set_overall(rating: float) -> void:
	for attribute: String in PlayerModel.ATTRIBUTES:
		Session.career.player.attributes[attribute] = rating


func _texts(node: Node) -> String:
	var found: Array[String] = []
	for child: Node in node.find_children("*", "Label", true, false):
		found.append((child as Label).text)
	return "\n".join(found)


func test_academy_player_sees_every_club_and_its_needs() -> void:
	var app: Control = add_child_autofree(CLUBS_SCENE.instantiate())
	var text := _texts(app)
	assert_string_contains(text, "Academy player")
	for club: Club in Session.world.clubs:
		assert_string_contains(text, club.name)
	assert_eq(
		app.find_children("*", "CrestView", true, false).size(), Session.world.clubs.size() + 1
	)


func test_trial_signs_a_contract() -> void:
	Session.career.player.age = Session.rules.trial_age
	_set_overall(40.0)
	var app: Control = add_child_autofree(CLUBS_SCENE.instantiate())
	assert_string_contains(_texts(app), "Trials")
	app.call("try_out", "brackenford")
	assert_eq(Session.career.club_id, "brackenford")
	assert_string_contains((app.get_node("%MessageLabel") as Label).text, "Trial passed")


func test_accepting_an_offer_moves_the_player() -> void:
	Session.career.player.age = 24
	_set_overall(90.0)
	Session.career.trial_used = true
	Session.career.contract = Contract.new()
	Session.career.contract.club_id = Session.career.club_id
	var offers := Session.offers()
	assert_gt(offers.size(), 0)
	var app: Control = add_child_autofree(CLUBS_SCENE.instantiate())
	app.call("accept_offer_from", offers[0].club_id)
	assert_eq(Session.career.club_id, offers[0].club_id)


func test_season_screen_blocks_until_the_trial_is_taken() -> void:
	Session.career.player.age = Session.rules.trial_age
	var screen: Control = add_child_autofree(SEASON_SCENE.instantiate())
	assert_true((screen.get_node("%PlayButton") as Button).disabled)
	assert_string_contains((screen.get_node("%SeasonInfoLabel") as Label).text, "Trials")


func test_summary_shows_the_verdict() -> void:
	Session.career.retired = true
	var summary: Control = add_child_autofree(SUMMARY_SCENE.instantiate())
	assert_string_contains((summary.get_node("%VerdictLabel") as Label).text, "Hall of Fame")
	assert_string_contains((summary.get_node("%SummaryLabel") as Label).text, "Seasons played")
