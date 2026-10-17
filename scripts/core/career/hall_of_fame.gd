class_name HallOfFame
extends RefCounted
## Career summary and the Hall of Fame verdict, from fixed points:
##   score = peak_overall * points_per_peak_overall
##         + top-tier senior seasons * points_per_top_tier_season
##         + key moments won * points_per_key_moment_won
##         + trophies * points_per_trophy
##         + Golden Balls * points_per_golden_ball
## Inducted if peak >= min_peak_overall and score >= induction_score.


class Summary:
	extends RefCounted
	var seasons: int = 0
	var peak_overall: int = 0
	var peak_age: int = 0
	var top_tier_seasons: int = 0
	var key_moments_won: int = 0
	var trophies: int = 0
	var golden_balls: int = 0
	var clubs: Array[String] = []
	var score: float = 0.0
	var inducted: bool = false


static func summarize(career: CareerState, world: ClubWorld, rules: CareerRules) -> Summary:
	var summary := Summary.new()
	summary.seasons = career.history.size()
	for record: SeasonRecord in career.history:
		if record.overall_after > summary.peak_overall:
			summary.peak_overall = record.overall_after
			summary.peak_age = record.age + 1
		summary.key_moments_won += record.key_moments_won
		if not summary.clubs.has(record.club_id):
			summary.clubs.append(record.club_id)
		var top_tier := world.has_club(record.club_id) and world.league_of(record.club_id).tier == 1
		if top_tier and record.age >= rules.senior_age:
			summary.top_tier_seasons += 1
	for run: CupRun in career.cup_runs:
		if run.won:
			summary.trophies += 1
	for standing: GoldenBall.Standing in career.golden_balls:
		if standing.rank == 1:
			summary.golden_balls += 1
	summary.score = (
		summary.peak_overall * rules.value("hall_of_fame", "points_per_peak_overall")
		+ summary.top_tier_seasons * rules.value("hall_of_fame", "points_per_top_tier_season")
		+ summary.key_moments_won * rules.value("hall_of_fame", "points_per_key_moment_won")
		+ summary.trophies * rules.value("hall_of_fame", "points_per_trophy")
		+ summary.golden_balls * rules.value("hall_of_fame", "points_per_golden_ball")
	)
	summary.inducted = (
		summary.peak_overall >= rules.value("hall_of_fame", "min_peak_overall")
		and summary.score >= rules.value("hall_of_fame", "induction_score")
	)
	return summary
