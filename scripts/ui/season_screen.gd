extends Control
## Season screen: the player, their club, training choices (two foci and an
## intensity), fatigue, and the ways on: play the season's key moments, quick
## sim, open the Clubs app or retire. Rules live in scripts/core.

const MAIN_MENU_SCENE := "res://scenes/main/main_menu.tscn"
const MOMENT_SCENE := "res://scenes/moments/moment_scene.tscn"
const PHONE_SCENE := "res://scenes/phone/phone.tscn"
const SUMMARY_SCENE := "res://scenes/career/career_summary.tscn"

var _confirming_retirement: bool = false

@onready var _header_label: Label = %HeaderLabel
@onready var _club_label: Label = %ClubLabel
@onready var _overall_label: Label = %OverallLabel
@onready var _attribute_grid: GridContainer = %AttributeGrid
@onready var _primary_option: OptionButton = %PrimaryOption
@onready var _secondary_option: OptionButton = %SecondaryOption
@onready var _intensity_option: OptionButton = %IntensityOption
@onready var _fatigue_label: Label = %FatigueLabel
@onready var _season_info_label: Label = %SeasonInfoLabel
@onready var _play_button: Button = %PlayButton
@onready var _sim_button: Button = %SimButton
@onready var _phone_button: Button = %PhoneButton
@onready var _retire_button: Button = %RetireButton
@onready var _result_label: Label = %ResultLabel


func _ready() -> void:
	if Session.career == null:
		get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
		return
	_fill_options()
	_play_button.pressed.connect(play_key_moments)
	_sim_button.pressed.connect(sim_season)
	_phone_button.pressed.connect(_on_phone_pressed)
	_retire_button.pressed.connect(press_retire)
	_select_recommended_plan()
	if Session.has_finished_moments():
		_complete_season(Session.finish_season)
	_refresh()


func selected_plan() -> TrainingPlan:
	return TrainingPlan.create(
		PlayerModel.ATTRIBUTES[_primary_option.selected],
		PlayerModel.ATTRIBUTES[_secondary_option.selected],
		TrainingPlan.INTENSITIES[_intensity_option.selected]
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


## First press asks for confirmation; the second retires.
func press_retire() -> void:
	if not _confirming_retirement:
		_confirming_retirement = true
		_retire_button.text = "Tap again to retire"
		return
	if Session.retire():
		_show_summary()


func _fill_options() -> void:
	for option: OptionButton in [_primary_option, _secondary_option]:
		for attribute: String in PlayerModel.ATTRIBUTES:
			option.add_item(Session.labels.attribute_name(attribute))
		option.item_selected.connect(_on_choice_changed)
	for intensity: String in TrainingPlan.INTENSITIES:
		_intensity_option.add_item(Session.labels.intensity_name(intensity))
	_intensity_option.select(TrainingPlan.INTENSITIES.find(TrainingPlan.NORMAL))
	_intensity_option.item_selected.connect(_on_choice_changed)


## Pre-selects the advisor's foci; the player may change them freely.
func _select_recommended_plan() -> void:
	var plan := TrainingAdvisor.recommended_plan(Session.career.player, Session.balance)
	_primary_option.select(PlayerModel.ATTRIBUTES.find(plan.primary))
	_secondary_option.select(PlayerModel.ATTRIBUTES.find(plan.secondary))


## `play` takes an errors array and returns the finished season's record or null.
func _complete_season(play: Callable) -> void:
	var errors: Array[String] = []
	var record: SeasonRecord = play.call(errors)
	if record == null:
		_result_label.text = "\n".join(errors)
		return
	_result_label.text = _describe(record)
	_select_recommended_plan()
	if Session.career.retired:
		_show_summary()


func _on_choice_changed(_index: int) -> void:
	_refresh()


func _refresh() -> void:
	var career := Session.career
	var player := career.player
	_header_label.text = (
		"%s · %s · Age %d"
		% [player.display_name, Session.labels.position_name(player.position), player.age]
	)
	_club_label.text = _club_text()
	_overall_label.text = "Overall %d" % player.overall_rating(Session.balance)
	_fill_attribute_grid(player)
	_fatigue_label.text = _fatigue_text()
	var blocker := Session.season_blocker()
	var plan_problems := selected_plan().validate()
	_play_button.disabled = not blocker.is_empty() or not plan_problems.is_empty()
	_sim_button.disabled = _play_button.disabled
	var moments := MomentPlanner.moment_count(player, Session.moment_tuning)
	_play_button.text = "Play season · %d key moments" % moments
	_retire_button.visible = CareerSeason.can_retire(career, Session.rules)
	var news := Session.unread("news", career.events.size())
	_phone_button.text = "Phone · %d new" % news if news > 0 else "Phone"
	if not blocker.is_empty():
		_season_info_label.text = blocker
	elif not plan_problems.is_empty():
		_season_info_label.text = "Pick two different training focuses."
	else:
		_season_info_label.text = _season_preview()


func _club_text() -> String:
	var career := Session.career
	var club := Session.world.club(career.club_id)
	var league := Session.world.league_of(club.id).name
	if career.contract == null:
		return "%s academy · %s" % [club.name, league]
	if career.player.age < Session.rules.senior_age:
		return "%s youth team · %s" % [club.name, league]
	var role := SeasonContext.role(career, Session.world, Session.balance, Session.rules)
	return "%s · %s · %s" % [club.name, league, Session.labels.role_name(role)]


## Current fatigue and what the selected intensity would lead to.
func _fatigue_text() -> String:
	var career := Session.career
	var rules := Session.rules
	var threshold := rules.value("fatigue", "injury_threshold")
	var text := "Fatigue %d/%d" % [roundi(career.fatigue), roundi(threshold)]
	if career.injured_next_season:
		text += " · Injured: you miss half of this season"
	var share := SeasonContext.match_share(career, Session.world, Session.balance, rules)
	var intensity := TrainingPlan.INTENSITIES[_intensity_option.selected]
	var after := Fatigue.after_season(career.fatigue, career.player.age, intensity, share, rules)
	if Fatigue.causes_injury(after, rules):
		text += "\nWarning: this training load ends the season injured"
	return text


func _season_preview() -> String:
	var expected := Session.expected_performance()
	return (
		"Season %d · %d matches · expected rating %.1f"
		% [Session.career.next_season_number(), expected.matches_played, expected.average_rating]
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
	lines.append_array(_honours(record.season_number))
	if record.injured:
		lines.append("Injury kept you out of half the matches.")
	if Session.career.injured_next_season:
		lines.append("Too much fatigue: you are injured for next season.")
	for attribute: String in PlayerModel.ATTRIBUTES:
		var change := record.attribute_changes[attribute]
		if absf(change) >= 0.05:
			lines.append("%s %+.1f" % [Session.labels.attribute_name(attribute), change])
	return "\n".join(lines)


## Cup runs and the Golden Ball finish of `season_number`, as text lines.
func _honours(season_number: int) -> Array[String]:
	var lines: Array[String] = []
	for run: CupRun in Session.career.cup_runs:
		if run.season_number == season_number:
			var cup_name := Session.cups.cup(run.cup_id).name
			if run.won:
				lines.append("%s: champions!" % cup_name)
			else:
				lines.append("%s: out in %s" % [cup_name, EventText.round_reached(run.wins)])
	for standing: GoldenBall.Standing in Session.career.golden_balls:
		if standing.season_number == season_number:
			lines.append("Golden Ball: #%d (won by %s)" % [standing.rank, standing.winner])
	return lines


func _on_phone_pressed() -> void:
	get_tree().change_scene_to_file(PHONE_SCENE)


func _show_summary() -> void:
	get_tree().change_scene_to_file.call_deferred(SUMMARY_SCENE)
