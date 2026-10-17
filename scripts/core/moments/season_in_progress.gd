class_name SeasonInProgress
extends RefCounted
## A season whose key moments are being played one by one. Once every moment
## has a result, `performance` gives the season's rating for SeasonLoop.

var plan: TrainingPlan = null
## The season's baseline (matches and expected rating) before moments.
var expected: SeasonPerformance = null
var moments: Array[MomentSpec] = []
var results: Array[MomentResult] = []


## `baseline` and `strength` come from the career context (SeasonContext).
static func start(
	career: CareerState,
	training: TrainingPlan,
	baseline: SeasonPerformance,
	strength: float,
	balance: Balance,
	tuning: MomentTuning
) -> SeasonInProgress:
	var season := SeasonInProgress.new()
	season.plan = training
	season.expected = baseline
	season.moments = MomentPlanner.plan_season(
		career.player, career.next_season_number(), strength, balance, tuning
	)
	return season


func is_complete() -> bool:
	return results.size() >= moments.size()


## The next moment to play, or null when all are done.
func current_moment() -> MomentSpec:
	return null if is_complete() else moments[results.size()]


func record(result: MomentResult) -> void:
	if not is_complete():
		results.append(result)


func performance(tuning: MomentTuning) -> SeasonPerformance:
	return SeasonMoments.performance(expected, results, tuning)
