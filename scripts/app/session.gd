extends Node
## Autoload "Session": data and the active career shared between screens.
## Holds state and forwards to scripts/core; it adds no game rules itself.

var config: GameConfig = null
var balance: Balance = null
var labels: GameLabels = null
var moment_tuning: MomentTuning = null
var world: ClubWorld = null
var rules: CareerRules = null
var career: CareerState = null
## The season whose key moments are being played, or null between seasons.
var season_in_progress: SeasonInProgress = null
## Problems found while loading data files; screens show these instead of crashing.
var load_errors: Array[String] = []


func _ready() -> void:
	config = GameConfig.load_file(GameConfig.DEFAULT_PATH, load_errors)
	balance = Balance.load_file(Balance.DEFAULT_PATH, load_errors)
	labels = GameLabels.load_file(GameLabels.DEFAULT_PATH, load_errors)
	moment_tuning = MomentTuning.load_file(MomentTuning.DEFAULT_PATH, load_errors)
	if balance != null:
		world = ClubWorld.load_file(ClubWorld.DEFAULT_PATH, balance.positions(), load_errors)
	if world != null:
		rules = CareerRules.load_file(CareerRules.DEFAULT_PATH, world, balance.max_age, load_errors)
	for error: String in load_errors:
		push_error(error)


func is_ready() -> bool:
	return load_errors.is_empty()


func start_career(position: String) -> void:
	career = CareerState.start(config.default_player_name, position, balance, rules.academy_club)
	season_in_progress = null


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
	return CareerSeason.play(career, season.plan, performance, world, balance, rules, errors)


## Plays a season without key moments, at the expected rating.
func sim_season(plan: TrainingPlan, errors: Array[String]) -> SeasonRecord:
	var performance := expected_performance()
	return CareerSeason.play(career, plan, performance, world, balance, rules, errors)


func offers() -> Array[Offer]:
	return OfferEngine.offers_for(career, world, balance, rules)


## Signs `offer` if allowed; returns the refusal reason or "".
func accept_offer(offer: Offer) -> String:
	var reason := OfferEngine.refusal_reason(career, offer, world, rules)
	if reason.is_empty():
		OfferEngine.accept(career, offer)
	return reason


func take_trial(club: Club) -> bool:
	return Trials.take(career, club, world, balance, rules)


func retire() -> bool:
	return CareerSeason.retire(career, rules)
