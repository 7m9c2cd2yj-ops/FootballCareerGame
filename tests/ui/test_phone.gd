extends GutTest
## Smoke tests for the phone: home icons, badges and each app.

const PHONE_SCENE := preload("res://scenes/phone/phone.tscn")


func before_each() -> void:
	Session.start_career("FWD")


func after_each() -> void:
	Session.career = null


func _sim_season() -> void:
	var errors: Array[String] = []
	Session.sim_season(TrainingPlan.create("shooting", "pace"), errors)


func _labels_text(node: Node) -> String:
	var texts: Array[String] = []
	for child: Node in node.find_children("*", "Label", true, false):
		texts.append((child as Label).text)
	for child: Node in node.find_children("*", "Button", true, false):
		texts.append((child as Button).text)
	return "\n".join(texts)


func test_home_shows_the_four_apps() -> void:
	var phone: Control = add_child_autofree(PHONE_SCENE.instantiate())
	var text := _labels_text(phone.get_node("%Home"))
	for title: String in ["Clubs", "News", "Messages", "Kickfie", "Cups"]:
		assert_string_contains(text, title)


func test_news_badge_appears_and_clears_when_read() -> void:
	_sim_season()
	var phone: Control = add_child_autofree(PHONE_SCENE.instantiate())
	assert_gt(phone.get_node("%Home").find_children("Badge", "", true, false).size(), 0)
	phone.call("open_app", "news")
	assert_string_contains(_labels_text(phone.get_node("%AppHost")), "Season 1")
	phone.call("show_home")
	assert_eq(Session.unread("news", Session.career.events.size()), 0)


func test_messages_and_kickfie_show_content() -> void:
	_sim_season()
	var phone: Control = add_child_autofree(PHONE_SCENE.instantiate())
	phone.call("open_app", "messages")
	assert_string_contains(_labels_text(phone.get_node("%AppHost")), "Agent")
	phone.call("open_app", "kickfie")
	assert_string_contains(_labels_text(phone.get_node("%AppHost")), "@")


func test_clubs_app_opens_inside_the_phone_and_closes_home() -> void:
	var phone: Control = add_child_autofree(PHONE_SCENE.instantiate())
	phone.call("open_app", "clubs")
	var host: Control = phone.get_node("%AppHost")
	assert_string_contains(_labels_text(host), "Your club")
	var clubs := host.get_child(0)
	clubs.emit_signal("closed")
	assert_true((phone.get_node("%Home") as Control).visible)


func test_cups_app_shows_the_cabinet_and_brackets() -> void:
	_sim_season()
	var phone: Control = add_child_autofree(PHONE_SCENE.instantiate())
	phone.call("open_app", "cups")
	var text := _labels_text(phone.get_node("%AppHost"))
	assert_string_contains(text, "Trophy cabinet")
	assert_string_contains(text, "Continental Cup · season 1")
	assert_string_contains(text, "Final")
	assert_gt(phone.get_node("%AppHost").find_children("*", "CrestView", true, false).size(), 0)
