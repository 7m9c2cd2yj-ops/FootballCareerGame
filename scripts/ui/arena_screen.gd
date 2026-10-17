extends Control
## The ARENA: players on your server with their best career, and the
## all-time global rankings. Shows preset names only. Needs internet.

const MENU_SCENE := "res://scenes/main/main_menu.tscn"

@onready var _list: VBoxContainer = %List
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	(%BackButton as Button).pressed.connect(
		func() -> void: get_tree().change_scene_to_file(MENU_SCENE)
	)
	(%ServerButton as Button).pressed.connect(show_rankings.bind(false))
	(%GlobalButton as Button).pressed.connect(show_rankings.bind(true))
	show_rankings(false)


## `everyone` false = your server, true = all-time global (also used by tests).
func show_rankings(everyone: bool) -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if not Backend.is_configured():
		_status_label.text = Backend.NOT_CONFIGURED
		return
	_status_label.text = "Loading…"
	var rows: Array[Dictionary] = await Backend.rankings(everyone)
	var scope := "All-time global rankings" if everyone else "Your server: %s" % Backend.server_id
	_status_label.text = scope if not rows.is_empty() else "No rankings yet, or you're offline."
	for index: int in rows.size():
		_list.add_child(_row(index + 1, rows[index]))


func _row(rank: int, row: Dictionary) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 24)
	var star := " ★" if row.get("inducted", false) else ""
	label.text = (
		"%d. %s · %s%s\npeak %d · %d trophies · %d Golden Balls · score %d"
		% [
			rank,
			str(row.get("display_name", "?")),
			Session.labels.position_name(str(row.get("position", ""))),
			star,
			int(row.get("peak_overall", 0)),
			int(row.get("trophies", 0)),
			int(row.get("golden_balls", 0)),
			int(row.get("hof_score", 0)),
		]
	)
	return label
