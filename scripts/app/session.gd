extends Node
## Autoload "Session": data and the active career shared between screens.
## Holds state and forwards to scripts/core; it adds no game rules itself.

const SAVE_ROOT := "user://saves"

var config: GameConfig = null
var balance: Balance = null
var labels: GameLabels = null
var moment_tuning: MomentTuning = null
var world: ClubWorld = null
var rules: CareerRules = null
var templates: TextTemplates = null
var cups: CupWorld = null
var career: CareerState = null
## Save slot of the active career (1-based), or 0 if none.
var slot: int = 0
## Slot chosen on the Careers screen for the next new career.
var pending_slot: int = 1
var saves: SaveSlots = SaveSlots.new(SAVE_ROOT)
## The season whose key moments are being played, or null between seasons.
var season_in_progress: SeasonInProgress = null
## A tutorial moment being played (never recorded) and the screen to return to.
var practice_moment: MomentSpec = null
var practice_return_scene: String = ""
## Phone app -> how many of its items the player has already seen (this session).
var phone_seen: Dictionary[String, int] = {}
## Problems found while loading data files; screens show these instead of crashing.
var load_errors: Array[String] = []


func _ready() -> void:
	config = GameConfig.load_file(GameConfig.DEFAULT_PATH, load_errors)
	balance = Balance.load_file(Balance.DEFAULT_PATH, load_errors)
	labels = GameLabels.load_file(GameLabels.DEFAULT_PATH, load_errors)
	moment_tuning = MomentTuning.load_file(MomentTuning.DEFAULT_PATH, load_errors)
	templates = TextTemplates.load_file(TextTemplates.DEFAULT_PATH, load_errors)
	cups = CupWorld.load_files(CupWorld.NATIONS_PATH, CupWorld.CUPS_PATH, load_errors)
	if balance != null:
		world = ClubWorld.load_file(ClubWorld.DEFAULT_PATH, balance.positions(), load_errors)
	if world != null:
		rules = CareerRules.load_file(CareerRules.DEFAULT_PATH, world, balance.max_age, load_errors)
	for error: String in load_errors:
		push_error(error)


func is_ready() -> bool:
	return load_errors.is_empty()


## Starts a new career in `career_slot` and saves it at once.
func start_career(position: String, career_slot: int = 1) -> void:
	var player_name := Preferences.player_name(config.default_player_name)
	career = CareerState.start(player_name, position, balance, rules.academy_club)
	slot = career_slot
	season_in_progress = null
	phone_seen.clear()
	save_career()


## Loads the newest valid save of `career_slot`; returns "" or why it failed.
func load_career(career_slot: int) -> String:
	var loaded := saves.load_slot(
		career_slot, CareerSaves.migrator(rules), CareerSaves.validator(balance, world)
	)
	if loaded.envelope == null:
		return "No valid save in this slot. %s" % "; ".join(loaded.errors)
	career = CareerState.from_dict(loaded.envelope.career)
	slot = career_slot
	season_in_progress = null
	phone_seen.clear()
	return ""


## Writes the active career to its slot (autosave); returns "" or the error.
func save_career() -> String:
	if career == null or slot <= 0:
		return ""
	var now := int(Time.get_unix_time_from_system())
	var envelope := CareerSaves.envelope_for(
		career, balance, world, saves.latest_revision(slot), now
	)
	var error := saves.write(slot, envelope)
	if not error.is_empty():
		push_warning("Save failed: %s" % error)
	else:
		var migrate := CareerSaves.migrator(rules)
		Backend.background_sync(slot, saves, migrate, CareerSaves.validator(balance, world))
	return error


## Why the next season cannot be played yet, or "" if it can.
func season_blocker() -> String:
	return CareerSeason.blocker(career, balance, rules)


func expected_performance() -> SeasonPerformance:
	return SeasonContext.expected_performance(career, world, balance, rules)


## Plans the season's key moments; the moment scene then plays them one by one.
func begin_season(plan: TrainingPlan) -> void:
	var strength := SeasonContext.competition_strength(career, world, balance, rules)
	season_in_progress = SeasonInProgress.start(
		career, plan, expected_performance(), strength, balance, moment_tuning
	)


## Sets up a practice `moment_type` for an academy-age forward; the moment
## scene plays it and returns to `return_scene` without recording anything.
func start_practice(moment_type: String, return_scene: String) -> void:
	var player := PlayerModel.create(config.default_player_name, "FWD", balance)
	var strength := balance.competition_strength_for_age(player.age)
	practice_moment = MomentPlanner.practice(player, moment_type, strength, balance, moment_tuning)
	practice_return_scene = return_scene


func current_moment() -> MomentSpec:
	return null if season_in_progress == null else season_in_progress.current_moment()


func record_moment(result: MomentResult) -> void:
	season_in_progress.record(result)


func has_finished_moments() -> bool:
	return season_in_progress != null and season_in_progress.is_complete()


## Applies a season whose moments are all played. Returns null (and fills
## `errors`) if it cannot be played.
func finish_season(errors: Array[String]) -> SeasonRecord:
	var season := season_in_progress
	season_in_progress = null
	var performance := season.performance(moment_tuning)
	return _saved(
		CareerSeason.play(career, season.plan, performance, world, balance, rules, cups, errors)
	)


## Plays a season without key moments, at the expected rating.
func sim_season(plan: TrainingPlan, errors: Array[String]) -> SeasonRecord:
	var performance := expected_performance()
	return _saved(CareerSeason.play(career, plan, performance, world, balance, rules, cups, errors))


## Autosaves after a season that was played; passes the record through.
func _saved(record: SeasonRecord) -> SeasonRecord:
	if record != null:
		save_career()
	return record


func offers() -> Array[Offer]:
	return OfferEngine.offers_for(career, world, balance, rules)


## Signs `offer` if allowed; returns the refusal reason or "".
func accept_offer(offer: Offer) -> String:
	var reason := OfferEngine.refusal_reason(career, offer, world, rules)
	if reason.is_empty():
		OfferEngine.accept(career, offer)
		save_career()
	return reason


## Items in `app` the player has not opened yet (`total` = items it has now).
func unread(app: String, total: int) -> int:
	return maxi(0, total - phone_seen.get(app, 0))


func mark_seen(app: String, total: int) -> void:
	phone_seen[app] = total


## Names and templates for turning the career's events into text.
func text_context() -> EventText.Context:
	return EventText.Context.create(world, cups, labels, templates)


func take_trial(club: Club) -> bool:
	var passed := Trials.take(career, club, world, balance, rules)
	save_career()
	return passed


func retire() -> bool:
	var retired := CareerSeason.retire(career, world, rules)
	if retired:
		save_career()
	return retired
