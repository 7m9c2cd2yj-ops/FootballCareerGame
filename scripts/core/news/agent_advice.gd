class_name AgentAdvice
extends RefCounted
## The agent's live advice, worked out from the career as it is now (not
## stored). Each tip is a key from TextTemplates.ADVICE plus its values.

const SALT_ADVICE := 31


## Advice keys that apply now, most urgent first; "all_quiet" if none.
static func current_keys(
	career: CareerState, world: ClubWorld, balance: Balance, rules: CareerRules
) -> Array[String]:
	var keys: Array[String] = []
	if Trials.is_due(career, rules):
		keys.append("trials_due")
	if career.contract != null and career.contract.has_expired():
		keys.append("contract_ended")
	elif career.contract != null and career.contract.years_left == 1:
		keys.append("contract_final_year")
	if _heavy_season_would_injure(career, world, balance, rules):
		keys.append("fatigue_high")
	if interested_clubs(career, world, balance, rules) > 0:
		keys.append("clubs_interested")
	if CareerSeason.can_retire(career, rules):
		keys.append("retirement_option")
	if keys.is_empty():
		keys.append("all_quiet")
	return keys


## Filled advice texts for the Messages app.
static func current_texts(
	career: CareerState,
	world: ClubWorld,
	balance: Balance,
	rules: CareerRules,
	labels: GameLabels,
	templates: TextTemplates
) -> Array[String]:
	var values := {
		"player": career.player.display_name,
		"position": labels.position_name(career.player.position),
		"age": str(career.player.age),
		"season": str(career.next_season_number()),
		"fatigue": str(roundi(career.fatigue)),
		"threshold": str(roundi(rules.value("fatigue", "injury_threshold"))),
		"club": world.club(career.club_id).name,
		"count": str(interested_clubs(career, world, balance, rules)),
	}
	var texts: Array[String] = []
	for key: String in current_keys(career, world, balance, rules):
		var options := templates.advice_for(key)
		var choice := int(
			Variety.unit(career.next_season_number(), texts.size(), SALT_ADVICE) * options.size()
		)
		texts.append(str(options[choice]).format(values))
	return texts


## Clubs (other than the player's) with an open need the player fits this window.
static func interested_clubs(
	career: CareerState, world: ClubWorld, balance: Balance, rules: CareerRules
) -> int:
	if career.retired or career.player.age < rules.trial_age:
		return 0
	var count := 0
	for index: int in world.clubs.size():
		var club := world.clubs[index]
		if club.id == career.club_id or club.id == rules.fallback_club:
			continue
		var season := career.next_season_number()
		if OfferEngine.matching_need(career, club, index, season, balance, rules) != null:
			count += 1
	return count


static func _heavy_season_would_injure(
	career: CareerState, world: ClubWorld, balance: Balance, rules: CareerRules
) -> bool:
	if career.retired or career.fatigue <= 0.0:
		return false
	var share := SeasonContext.match_share(career, world, balance, rules)
	var heavy := Fatigue.after_season(
		career.fatigue, career.player.age, TrainingPlan.INTENSE, share, rules
	)
	return Fatigue.causes_injury(heavy, rules)
