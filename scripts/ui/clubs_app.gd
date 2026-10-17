extends Control
## The Clubs app (inside the phone): your club and contract, trials (once, at
## the trial age), offers in the transfer window, and what every club wants.
## Display and buttons only; all decisions come from scripts/core/career.

signal closed

const CREST_SIZE := Vector2(80, 80)
const BUTTON_SIZE := Vector2(170, 80)
const MATCH_MARK := "✓ "

@onready var _content: VBoxContainer = %Content
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	(%BackButton as Button).pressed.connect(closed.emit)
	refresh()


func refresh() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_add_current_club()
	if Trials.is_due(Session.career, Session.rules):
		_add_trials()
	elif Session.career.contract != null:
		_add_offers()
	_add_all_clubs()


## Takes the trial at `club_id` (also used by tests).
func try_out(club_id: String) -> void:
	var club := Session.world.club(club_id)
	if Session.take_trial(club):
		_message_label.text = "Trial passed! You signed a youth contract with %s." % club.name
	else:
		var academy := Session.world.club(Session.career.club_id).name
		_message_label.text = "Not this time. %s gave you a youth contract." % academy
	refresh()


## Accepts the offer from `club_id` in the current list (also used by tests).
func accept_offer_from(club_id: String) -> void:
	for offer: Offer in Session.offers():
		if offer.club_id == club_id:
			var reason := Session.accept_offer(offer)
			if reason.is_empty():
				_message_label.text = "Signed with %s!" % Session.world.club(club_id).name
			else:
				_message_label.text = reason
	refresh()


func _add_current_club() -> void:
	var career := Session.career
	var club := Session.world.club(career.club_id)
	var lines: Array[String] = [Session.world.league_of(club.id).name]
	if career.contract == null:
		lines.append("Academy player · trials at %d" % Session.rules.trial_age)
	else:
		lines.append(_contract_text(career.contract))
	_add_heading("Your club")
	_content.add_child(_club_row(club, club.name, lines, null))


func _add_trials() -> void:
	var score := Trials.trial_score(Session.career, Session.balance, Session.rules)
	_add_heading("Trials: you get one")
	var bonus := roundi(Session.rules.value("trial", "bonus_per_key_moment_won"))
	_add_note(
		(
			(
				"Trial score %d (overall + %d per key moment won last season). "
				% [roundi(score), bonus]
			)
			+ "Pass if it reaches the club's intake bar."
		)
	)

	for club: Club in Trials.trial_clubs(Session.world, Session.rules):
		var passes := Trials.would_pass(Session.career, club, Session.balance, Session.rules)
		var lines: Array[String] = [
			(
				"Intake bar %d · %s"
				% [roundi(club.youth_intake_min), Session.world.league_of(club.id).name]
			),
			"You would pass" if passes else "You would fall short",
		]
		var button := _button("Try out", try_out.bind(club.id))
		_content.add_child(_club_row(club, club.name, lines, button))


func _add_offers() -> void:
	_add_heading("Offers · transfer window open")
	var offers := Session.offers()
	if offers.is_empty():
		_add_note("No offers yet. Clubs sign players who meet their needs: keep improving.")
	for offer: Offer in offers:
		var club := Session.world.club(offer.club_id)
		var lines: Array[String] = [
			(
				"%s · %s"
				% [Session.world.league_of(club.id).name, Session.labels.role_name(offer.role)]
			),
			(
				"%dk/season · %d years · release clause %dk"
				% [offer.wage, offer.years, offer.release_clause]
			),
		]
		var reason := OfferEngine.refusal_reason(
			Session.career, offer, Session.world, Session.rules
		)
		var label := "Renew" if offer.is_renewal else "Sign"
		var button := _button(label, accept_offer_from.bind(offer.club_id))
		if not reason.is_empty():
			button.disabled = true
			lines.append(reason)
		_content.add_child(_club_row(club, club.name, lines, button))


func _add_all_clubs() -> void:
	var career := Session.career
	var season := career.next_season_number()
	var overall := career.player.overall_rating(Session.balance)
	_add_heading("What clubs want this window")
	for league: League in Session.world.leagues:
		_add_note("%s (tier %d)" % [league.name, league.tier])
		for club: Club in Session.world.clubs_in_league(league.id):
			var index := Session.world.club_index(club.id)
			var wants: Array[String] = []
			for need: ClubNeed in OfferEngine.open_needs(club, index, season, Session.rules):
				var fits := need.accepts(career.player.position, overall, career.player.age)
				wants.append((MATCH_MARK if fits else "") + need.describe())
			var lines: Array[String] = [
				"Strength %d" % roundi(club.strength), "Wants: " + ", ".join(wants)
			]
			_content.add_child(_club_row(club, club.name, lines, null))


func _contract_text(contract: Contract) -> String:
	var kind := "Youth contract" if contract.is_youth else "Contract"
	if contract.has_expired():
		return "%s ended: choose a club below" % kind
	return "%s · %dk/season · %d years left" % [kind, contract.wage, contract.years_left]


func _club_row(club: Club, title: String, lines: Array[String], button: Button) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var crest := CrestView.new()
	crest.custom_minimum_size = CREST_SIZE
	crest.show_club(club)
	row.add_child(crest)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = title
	text.add_child(name_label)
	for line: String in lines:
		var detail := Label.new()
		detail.text = line
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_size_override("font_size", 22)
		text.add_child(detail)
	row.add_child(text)
	if button != null:
		row.add_child(button)
	return row


func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(on_press)
	return button


func _add_heading(text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 34)
	_content.add_child(heading)


func _add_note(text: String) -> void:
	var note := Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 22)
	note.modulate = Color(1, 1, 1, 0.8)
	_content.add_child(note)
