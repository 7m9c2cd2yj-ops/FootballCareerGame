extends Node
## Autoload "Session": data and the active career shared between screens.
## Holds state only; game rules live in scripts/core.

var config: GameConfig = null
var balance: Balance = null
var labels: GameLabels = null
var moment_tuning: MomentTuning = null
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
	for error: String in load_errors:
		push_error(error)


func is_ready() -> bool:
	return load_errors.is_empty()


func start_career(position: String) -> void:
	career = CareerState.start(config.default_player_name, position, balance)
	season_in_progress = null


## Plans the season's key moments; the moment scene then plays them one by one.
func begin_season(plan: TrainingPlan) -> void:
	season_in_progress = SeasonInProgress.start(career, plan, balance, moment_tuning)


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
	var performance := season.performance(career.player, balance, moment_tuning)
	return SeasonLoop.play_season(career, season.plan, performance, balance, errors)


## Plays a season without key moments, at the expected rating.
func sim_season(plan: TrainingPlan, errors: Array[String]) -> SeasonRecord:
	var performance := SeasonPerformance.expected_for(career.player, balance)
	return SeasonLoop.play_season(career, plan, performance, balance, errors)
