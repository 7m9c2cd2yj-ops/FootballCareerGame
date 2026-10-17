extends Control
## End of a career: the summary and the Hall of Fame verdict.

const MAIN_MENU_SCENE := "res://scenes/main/main_menu.tscn"

@onready var _summary_label: Label = %SummaryLabel
@onready var _verdict_label: Label = %VerdictLabel


func _ready() -> void:
	(%MenuButton as Button).pressed.connect(_on_menu_pressed)
	if Session.career == null:
		get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
		return
	var summary := HallOfFame.summarize(Session.career, Session.world, Session.rules)
	_summary_label.text = _describe(summary)
	if summary.inducted:
		_verdict_label.text = "Inducted into the Hall of Fame!"
	else:
		_verdict_label.text = "Not inducted into the Hall of Fame"


func _describe(summary: HallOfFame.Summary) -> String:
	var player := Session.career.player
	var club_names: Array[String] = []
	for club_id: String in summary.clubs:
		club_names.append(Session.world.club(club_id).name)
	var lines: Array[String] = [
		"%s · %s" % [player.display_name, Session.labels.position_name(player.position)],
		"Seasons played: %d" % summary.seasons,
		"Peak overall: %d (age %d)" % [summary.peak_overall, summary.peak_age],
		"Top-tier seasons: %d" % summary.top_tier_seasons,
		"Key moments won: %d" % summary.key_moments_won,
		"Clubs: %s" % ", ".join(club_names),
		"Hall of Fame score: %d" % roundi(summary.score),
	]
	return "\n".join(lines)


func _on_menu_pressed() -> void:
	Session.career = null
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
