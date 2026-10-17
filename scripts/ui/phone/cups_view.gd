class_name CupsView
extends RefCounted
## The phone's Cups app: trophy cabinet, Golden Ball finishes and the latest
## season's cup brackets (recomputed from the season record). Display only.

const ROUND_NAMES: Array[String] = ["Round of 16", "Quarter-finals", "Semi-finals", "Final"]
const BADGE_SIZE := Vector2(48, 48)
const FLAG_SIZE := Vector2(60, 40)


static func build() -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	_add_cabinet(list)
	var career := Session.career
	if career.history.is_empty():
		list.add_child(_label("Cups start once you have played a season.", 22))
		return scroll
	var last := career.history[-1]
	for result: CupSim.Result in CupSeason.results_for(
		last, Session.world, Session.rules, Session.cups
	):
		_add_bracket(list, result)
	return scroll


static func _add_cabinet(list: VBoxContainer) -> void:
	var career := Session.career
	var wins: Dictionary[String, int] = {}
	for run: CupRun in career.cup_runs:
		if run.won:
			wins[run.cup_id] = wins.get(run.cup_id, 0) + 1
	var golden := 0
	var podiums := 0
	for standing: GoldenBall.Standing in career.golden_balls:
		golden += 1 if standing.rank == 1 else 0
		podiums += 1 if standing.rank <= 3 else 0
	list.add_child(_label("Trophy cabinet", 34))
	for cup: CupDefinition in Session.cups.cups:
		list.add_child(_label("%s: %d" % [cup.name, wins.get(cup.id, 0)], 26))
	list.add_child(_label("Golden Balls: %d (top 3 finishes: %d)" % [golden, podiums], 26))


static func _add_bracket(list: VBoxContainer, result: CupSim.Result) -> void:
	var cups := Session.cups
	var cup := cups.cup(result.cup_id)
	var champion := cups.team_name(cup.id, result.champion, Session.world)
	list.add_child(_label("%s · season %d" % [cup.name, result.season_number], 32))
	list.add_child(_label("Winners: %s" % champion, 24))
	if result.player_team.is_empty():
		list.add_child(_label("You did not take part.", 22))
	for round_index: int in range(CupSim.ROUNDS - 1, -1, -1):
		list.add_child(_label(ROUND_NAMES[round_index], 26))
		for played: CupSim.Match in result.matches:
			if played.round_index == round_index:
				list.add_child(_match_row(cup, played, result.player_team))


static func _match_row(cup: CupDefinition, played: CupSim.Match, player_team: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_team_badge(cup, played.home))
	var names := _label(
		(
			"%s %d–%d %s"
			% [
				Session.cups.team_name(cup.id, played.home, Session.world),
				played.home_goals,
				played.away_goals,
				Session.cups.team_name(cup.id, played.away, Session.world),
			]
		),
		20
	)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if played.home == player_team or played.away == player_team:
		names.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	row.add_child(names)
	row.add_child(_team_badge(cup, played.away))
	return row


static func _team_badge(cup: CupDefinition, team: String) -> Control:
	if cup.is_for_nations():
		var flag := FlagView.new()
		flag.custom_minimum_size = FLAG_SIZE
		flag.show_nation(Session.cups.nation(team))
		return flag
	var crest := CrestView.new()
	crest.custom_minimum_size = BADGE_SIZE
	if Session.cups.has_foreign_club(team):
		crest.show_club(Session.cups.foreign_club(team))
	else:
		crest.show_club(Session.world.club(team))
	return crest


static func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label
