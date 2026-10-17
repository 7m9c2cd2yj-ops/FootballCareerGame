class_name SeasonMoments
extends RefCounted
## Turns a season's key-moment results into its average match rating:
##   rating = expected rating + mean(result deltas) * rating.weight
## With the default weight, perfect moments add up to +4 and failures cost 1.2.


static func performance(
	expected: SeasonPerformance, results: Array[MomentResult], tuning: MomentTuning
) -> SeasonPerformance:
	if results.is_empty():
		return expected
	var total := 0.0
	for result: MomentResult in results:
		total += result.rating_delta(tuning)
	var shift := total / results.size() * tuning.value("rating", "weight")
	var with_moments := SeasonPerformance.create(
		expected.matches_played, expected.average_rating + shift
	)
	with_moments.key_moments_played = results.size()
	with_moments.key_moments_won = successes(results)
	return with_moments


static func successes(results: Array[MomentResult]) -> int:
	var count := 0
	for result: MomentResult in results:
		if result.success:
			count += 1
	return count
