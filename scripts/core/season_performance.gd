class_name SeasonPerformance
extends RefCounted
## How the player performed over a season: appearances and average match rating (0-10).
## Later milestones fill this from 3D moments and match simulation; until then
## `expected_for` gives the deterministic baseline.

const MIN_RATING := 0.0
const MAX_RATING := 10.0

var matches_played: int = 0
var average_rating: float = 0.0


static func create(matches: int, rating: float) -> SeasonPerformance:
	var performance := SeasonPerformance.new()
	performance.matches_played = maxi(matches, 0)
	performance.average_rating = clampf(rating, MIN_RATING, MAX_RATING)
	return performance


## Rating a player of `overall` earns against `competition_strength` with no
## standout moments: stronger than the competition means a higher rating.
static func expected_rating(overall: int, competition_strength: float, balance: Balance) -> float:
	var gap := float(overall) - competition_strength
	var rating := balance.expected_neutral + gap * balance.expected_per_overall_point
	return clampf(rating, balance.expected_min, balance.expected_max)


## Full season at the player's age-group competition with the expected rating.
static func expected_for(player: PlayerModel, balance: Balance) -> SeasonPerformance:
	var strength := balance.competition_strength_for_age(player.age)
	var rating := expected_rating(player.overall_rating(balance), strength, balance)
	return create(balance.matches_for_age(player.age), rating)
