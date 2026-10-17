class_name Fatigue
extends RefCounted
## Deterministic injuries. Each season adds load from training intensity,
## matches played and age; part of last season's fatigue carries over:
##   fatigue = previous * carryover + intensity_load + match_share * match_load
##             + max(0, age - age_load_from) * age_load_per_year
## Reaching injury_threshold means an injury: the next season loses
## missed_match_share of its matches and of its training, and fatigue drops
## to after_injury.


static func season_load(
	age: int, intensity: String, match_share: float, rules: CareerRules
) -> float:
	var age_years := maxf(0.0, age - rules.value("fatigue", "age_load_from"))
	return (
		rules.intensity_load(intensity)
		+ match_share * rules.value("fatigue", "match_load_at_full_share")
		+ age_years * rules.value("fatigue", "age_load_per_year")
	)


## Fatigue at the end of a season that starts at `current`.
static func after_season(
	current: float, age: int, intensity: String, match_share: float, rules: CareerRules
) -> float:
	var carried := current * rules.value("fatigue", "carryover")
	return carried + season_load(age, intensity, match_share, rules)


static func causes_injury(fatigue: float, rules: CareerRules) -> bool:
	return fatigue >= rules.value("fatigue", "injury_threshold")


## Updates the career after a season played at `age`; returns true if the
## player got injured.
static func apply_season(
	career: CareerState, age: int, intensity: String, match_share: float, rules: CareerRules
) -> bool:
	var fatigue := after_season(career.fatigue, age, intensity, match_share, rules)
	career.injured_next_season = causes_injury(fatigue, rules)
	if career.injured_next_season:
		fatigue = rules.value("fatigue", "after_injury")
	career.fatigue = Progression.round_value(fatigue)
	return career.injured_next_season
