class_name SeasonInProgress
extends RefCounted
## A season whose key moments are being played one by one. Once every moment
## has a result, `performance` gives the season's rating for SeasonLoop.

var plan: TrainingPlan = null
var moments: Array[MomentSpec] = []
var results: Array[MomentResult] = []


static func start(
	career: CareerState, training: TrainingPlan, balance: Balance, tuning: MomentTuning
) -> SeasonInProgress:
	var season := SeasonInProgress.new()
	season.plan = training
	var strength := balance.competition_strength_for_age(career.player.age)
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


func performance(player: PlayerModel, balance: Balance, tuning: MomentTuning) -> SeasonPerformance:
	var expected := SeasonPerformance.expected_for(player, balance)
	return SeasonMoments.performance(expected, results, tuning)
