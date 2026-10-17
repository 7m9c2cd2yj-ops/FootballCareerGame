extends Control
## The in-game phone: a home screen with Clubs, News, Messages, Kickfie and Cups,
## unread badges, and each app opened inside the phone. Display only.

const SEASON_SCENE := "res://scenes/career/season_screen.tscn"
const CLUBS_APP := preload("res://scenes/career/clubs_app.tscn")
const ICON_SIZE := Vector2(250, 210)
const APPS: Array[String] = ["clubs", "news", "messages", "kickfie", "cups"]
const APP_TITLES: Dictionary = {
	"clubs": "Clubs", "news": "News", "messages": "Messages", "kickfie": "Kickfie", "cups": "Cups"
}
const APP_COLORS: Dictionary = {
	"clubs": Color(0.13, 0.45, 0.85),
	"news": Color(0.85, 0.3, 0.2),
	"messages": Color(0.2, 0.65, 0.35),
	"kickfie": Color(0.75, 0.25, 0.75),
	"cups": Color(0.85, 0.65, 0.1),
}

@onready var _status_label: Label = %StatusLabel
@onready var _home: GridContainer = %Home
@onready var _app_host: Control = %AppHost
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	if Session.career == null:
		get_tree().change_scene_to_file.call_deferred(SEASON_SCENE)
		return
	_back_button.pressed.connect(_on_back_pressed)
	show_home()


func show_home() -> void:
	_clear_app()
	_app_host.visible = false
	_home.visible = true
	_back_button.text = "Back to season"
	var player := Session.career.player
	_status_label.text = "Season %d · Age %d" % [Session.career.next_season_number(), player.age]
	for child: Node in _home.get_children():
		_home.remove_child(child)
		child.queue_free()
	for app: String in APPS:
		_home.add_child(_app_icon(app))


## Opens `app` (one of APPS); also used by tests.
func open_app(app: String) -> void:
	_clear_app()
	_home.visible = false
	_app_host.visible = true
	_back_button.text = "Home"
	_status_label.text = APP_TITLES[app]
	if app == "clubs":
		var clubs: Control = CLUBS_APP.instantiate()
		clubs.connect("closed", show_home)
		_app_host.add_child(clubs)
	elif app == "cups":
		_app_host.add_child(CupsView.build())
	else:
		_app_host.add_child(PhoneFeeds.build(app))
	Session.mark_seen(app, unread_total(app))


## How many items `app` currently has (badges compare it with what was seen).
func unread_total(app: String) -> int:
	match app:
		"news":
			return Session.career.events.size()
		"messages":
			return Session.agent_messages().size()
		"kickfie":
			return Session.kickfie_feed().size()
		"cups":
			return Session.career.cup_runs.size()
	return Session.offers().size() + (1 if Trials.is_due(Session.career, Session.rules) else 0)


func _app_icon(app: String) -> Control:
	var icon := Button.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.text = APP_TITLES[app]
	icon.add_theme_font_size_override("font_size", 34)
	var style := StyleBoxFlat.new()
	style.bg_color = APP_COLORS[app]
	style.set_corner_radius_all(36)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		icon.add_theme_stylebox_override(state, style)
	icon.pressed.connect(open_app.bind(app))
	var count := Session.unread(app, unread_total(app))
	if count > 0:
		icon.add_child(_badge(count))
	return icon


func _badge(count: int) -> Control:
	var badge := Label.new()
	badge.name = "Badge"
	badge.text = str(count)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(56, 56)
	badge.position = Vector2(ICON_SIZE.x - 64, 8)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.15, 0.15)
	style.set_corner_radius_all(28)
	badge.add_theme_stylebox_override("normal", style)
	return badge


func _clear_app() -> void:
	for child: Node in _app_host.get_children():
		_app_host.remove_child(child)
		child.queue_free()


func _on_back_pressed() -> void:
	if _app_host.visible:
		show_home()
	else:
		get_tree().change_scene_to_file(SEASON_SCENE)
