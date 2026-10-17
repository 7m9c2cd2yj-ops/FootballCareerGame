extends Control
## Season screen: shows the player, lets them pick two training foci and play
## the season, then shows what changed. Rules live in SeasonLoop/Progression.

const MAIN_MENU_SCENE := "res://scenes/main/main_menu.tscn"
const MOMENT_SCENE := "res://scenes/moments/moment_scene.tscn"

@onready var _header_label: Label = %HeaderLabel
@onready var _overall_label: Label = %OverallLabel
@onready var _attribute_grid: GridContainer = %AttributeGrid
@onready var _primary_option: OptionButton = %PrimaryOption
@onready var _secondary_option: OptionButton = %SecondaryOption
@onready var _season_info_label: Label = %SeasonInfoLabel
@onready var _play_button: Button = %PlayButton
@onready var _sim_button: Button = %SimButton
@onready var _result_label: Label = %ResultLabel


func _ready() -> void:
	if Session.career == null:
		get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
		return
	for option: OptionButton in [_primary_option, _secondary_option]:
		for attribute: String in PlayerModel.ATTRIBUTES:
			option.add_item(Session.labels.attribute_name(attribute))
		option.item_selected.connect(_on_focus_changed)
	_play_button.pressed.connect(play_key_moments)
	_sim_button.pressed.connect(sim_season)
	_select_recommended_plan()
	if Session.has_finished_moments():
		_complete_season(Session.finish_season)
	_refresh()


## Pre-selects the advisor's plan; the player may change it freely.
func _select_recommended_plan() -> void:
	var plan := TrainingAdvisor.recommended_plan(Session.career.player, Session.balance)
	_primary_option.select(PlayerModel.ATTRIBUTES.find(plan.primary))
	_secondary_option.select(PlayerModel.ATTRIBUTES.find(plan.secondary))


func selected_plan() -> TrainingPlan:
	return TrainingPlan.create(
		PlayerModel.ATTRIBUTES[_primary_option.selected],
		PlayerModel.ATTRIBUTES[_secondary_option.selected]
	)


## Starts the season's key moments; the season finishes when they are done.
func play_key_moments() -> void:
	Session.begin_season(selected_plan())
	get_tree().change_scene_to_file(MOMENT_SCENE)


## Plays the season without key moments, at the expected rating.
func sim_season() -> void:
	var plan := selected_plan()
	_complete_season(
		func(errors: Array[String]) -> SeasonRecord: return Session.sim_season(plan, errors)
	)
	_refresh()


## `play` takes an errors array and returns the finished season's record or null.
func _complete_season(play: Callable) -> void:
	var errors: Array[String] = []
	var record: SeasonRecord = play.call(errors)
	if record == null:
		_result_label.text = "\n".join(errors)
		return
	_result_label.text = _describe(record)
	_select_recommended_plan()


func _on_focus_changed(_index: int) -> void:
	_refresh()


func _refresh() -> void:
	var player := Session.career.player
	var balance := Session.balance
	_header_label.text = (
		"%s · %s · Age %d"
		% [player.display_name, Session.labels.position_name(player.position), player.age]
	)
	_overall_label.text = "Overall %d" % player.overall_rating(balance)
	_fill_attribute_grid(player)
	var finished := Session.career.is_finished(balance)
	var plan_ok := selected_plan().validate().is_empty()
	_play_button.disabled = finished or not plan_ok
	_sim_button.disabled = _play_button.disabled
	var moments := MomentPlanner.moment_count(player, Session.moment_tuning)
	_play_button.text = "Play season · %d key moments" % moments
	if finished:
		_play_button.text = "Career complete"
		_season_info_label.text = "No more seasons to play."
	elif not plan_ok:
		_season_info_label.text = "Pick two different training focuses."
	else:
		var expected := SeasonPerformance.expected_for(player, balance)
		_season_info_label.text = (
			"Season %d · %d matches · expected rating %.1f"
			% [
				Session.career.next_season_number(),
				expected.matches_played,
				expected.average_rating
			]
		)


func _fill_attribute_grid(player: PlayerModel) -> void:
	for child: Node in _attribute_grid.get_children():
		_attribute_grid.remove_child(child)
		child.queue_free()
	for attribute: String in PlayerModel.ATTRIBUTES:
		var name_label := Label.new()
		name_label.text = Session.labels.attribute_name(attribute)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value_label := Label.new()
		value_label.text = str(floori(player.attributes[attribute]))
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_attribute_grid.add_child(name_label)
		_attribute_grid.add_child(value_label)


func _describe(record: SeasonRecord) -> String:
	var lines: Array[String] = [
		(
			"Season %d (age %d): overall %d → %d"
			% [record.season_number, record.age, record.overall_before, record.overall_after]
		)
	]
	if record.key_moments_played > 0:
		lines.append(
			(
				"Key moments %d/%d · season rating %.1f"
				% [record.key_moments_won, record.key_moments_played, record.average_rating]
			)
		)
	else:
		lines.append("Quick sim · season rating %.1f" % record.average_rating)
	for attribute: String in PlayerModel.ATTRIBUTES:
		var change := record.attribute_changes[attribute]
		if absf(change) >= 0.05:
			lines.append("%s %+.1f" % [Session.labels.attribute_name(attribute), change])
	return "\n".join(lines)
