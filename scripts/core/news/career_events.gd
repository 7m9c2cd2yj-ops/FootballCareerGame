class_name CareerEvents
extends RefCounted
## Records CareerEvents on a career. Called by the career rules at the moment
## something happens, so news always reflects real career events.

## Overall ratings that make the news when first reached.
const MILESTONES: Array[int] = [50, 60, 70, 80, 90, 99]


static func record(career: CareerState, type: String, values: Dictionary) -> void:
	var event := CareerEvent.create(type, career.next_season_number(), career.player.age, values)
	career.events.append(event)


## Events for a season just played (`record` is already in the history).
static func record_season(
	career: CareerState, season: SeasonRecord, world: ClubWorld, rules: CareerRules
) -> void:
	var values := {
		"club": season.club_id,
		"overall_before": season.overall_before,
		"overall_after": season.overall_after,
		"rating": season.average_rating,
		"moments_won": season.key_moments_won,
		"moments_played": season.key_moments_played,
	}
	_record_at(career, CareerEvent.SEASON_PLAYED, season, values)
	for milestone: int in MILESTONES:
		if season.overall_before < milestone and season.overall_after >= milestone:
			_record_at(
				career,
				CareerEvent.MILESTONE,
				season,
				{"club": season.club_id, "milestone": milestone}
			)
	if _is_top_tier_debut(career, season, world, rules):
		_record_at(career, CareerEvent.TOP_TIER_DEBUT, season, {"club": season.club_id})
	if career.injured_next_season:
		_record_at(career, CareerEvent.INJURY, season, {"club": season.club_id})


static func record_retirement(career: CareerState, world: ClubWorld, rules: CareerRules) -> void:
	var summary := HallOfFame.summarize(career, world, rules)
	var values := {
		"club": career.club_id,
		"peak_overall": summary.peak_overall,
		"score": roundi(summary.score),
		"inducted": summary.inducted,
	}
	record(career, CareerEvent.RETIREMENT, values)


## Events of a season carry that season's number and age, not the next one's.
static func record_at_season(
	career: CareerState, type: String, season: SeasonRecord, values: Dictionary
) -> void:
	_record_at(career, type, season, values)


static func _record_at(
	career: CareerState, type: String, season: SeasonRecord, values: Dictionary
) -> void:
	career.events.append(CareerEvent.create(type, season.season_number, season.age, values))


## First senior season at a top-tier club.
static func _is_top_tier_debut(
	career: CareerState, season: SeasonRecord, world: ClubWorld, rules: CareerRules
) -> bool:
	if season.age < rules.senior_age or world.league_of(season.club_id).tier != 1:
		return false
	for earlier: SeasonRecord in career.history:
		if earlier == season:
			return true
		var top := world.has_club(earlier.club_id) and world.league_of(earlier.club_id).tier == 1
		if top and earlier.age >= rules.senior_age:
			return false
	return true
