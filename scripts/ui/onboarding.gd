extends Control
## First launch: pick a preset name (used for careers and online), learn how a
## career works and try a practice penalty that never counts.

const CAREERS_SCENE := "res://scenes/main/careers_screen.tscn"
const ONBOARDING_SCENE := "res://scenes/main/onboarding.tscn"
const HOW_IT_WORKS: Array[String] = [
	"You start at 8 in a club academy and play until you retire.",
	"Each season you pick two training focuses and how hard to train.",
	(
		"Key moments (penalties, free kicks, one-on-ones, saves) are played with touch."
		+ " Your skill decides them: no dice, no luck, no energy bars."
	),
	(
		"Ratings only change your margin for error. Play well, earn offers, win cups,"
		+ " and aim for the Golden Ball and the Hall of Fame."
	),
]

var _page: VBoxContainer = VBoxContainer.new()
var _name_option: OptionButton = null

@onready var _layout: VBoxContainer = %Layout


func _ready() -> void:
	_page.add_theme_constant_override("separation", 20)
	_layout.add_child(_page)
	if Session.practice_return_scene == ONBOARDING_SCENE:
		Session.practice_return_scene = ""
		show_how_it_works()
	else:
		show_name_page()


func show_name_page() -> void:
	UiParts.clear(_page)
	_page.add_child(UiParts.label(Session.config.disclaimer, 22))
	_page.add_child(UiParts.label("Pick your player's name. It is also your name online."))
	_name_option = OptionButton.new()
	_name_option.custom_minimum_size = Vector2(0, UiParts.BUTTON_HEIGHT)
	for preset: String in Preferences.preset_names:
		_name_option.add_item(preset)
	var current := Preferences.preset_names.find(Preferences.settings.player_name)
	_name_option.select(maxi(0, current))
	_page.add_child(_name_option)
	_page.add_child(UiParts.button("Next", choose_name))


## Keeps the chosen name for new careers and the online profile.
func choose_name() -> void:
	var chosen := Preferences.preset_names[_name_option.selected]
	Preferences.choose_name(chosen)
	Backend.remember_identity(chosen, Backend.server_id)
	show_how_it_works()


func show_how_it_works() -> void:
	UiParts.clear(_page)
	_page.add_child(UiParts.label("How your career works", 34))
	for line: String in HOW_IT_WORKS:
		_page.add_child(UiParts.label("• " + line))
	_page.add_child(UiParts.button("Try a practice penalty", practice))
	_page.add_child(UiParts.button("Start my career", finish))


func practice() -> void:
	Session.start_practice(MomentSpec.PENALTY, ONBOARDING_SCENE)
	get_tree().change_scene_to_file("res://scenes/moments/moment_scene.tscn")


func finish() -> void:
	Preferences.finish_onboarding()
	get_tree().change_scene_to_file(CAREERS_SCENE)
