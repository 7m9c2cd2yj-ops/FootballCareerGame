extends RefCounted
## Plays a whole career through the career layer with a simple policy: take the
## best trial you would pass, sign the strongest affordable offer each window,
## train with the advisor at `intensity`, and rate every season `match_rating`.
## Shared by the integration tests.


class Outcome:
	extends RefCounted
	var career: CareerState = null
	var stuck_reason: String = ""
	var peak_overall: int = 0
	var final_tier: int = 0


static func run(
	position: String,
	match_rating: float,
	intensity: String,
	world: ClubWorld,
	balance: Balance,
	rules: CareerRules,
	cups: CupWorld
) -> Outcome:
	var outcome := Outcome.new()
	var career := CareerState.start("Sim", position, balance, rules.academy_club)
	outcome.career = career
	var errors: Array[String] = []
	while not career.is_finished(balance):
		_handle_window(career, world, balance, rules)
		var blocker := CareerSeason.blocker(career, balance, rules)
		if not blocker.is_empty():
			outcome.stuck_reason = blocker
			break
		var plan := TrainingAdvisor.recommended_plan(career.player, balance)
		plan.intensity = intensity
		var expected := SeasonContext.expected_performance(career, world, balance, rules)
		var performance := SeasonPerformance.create(expected.matches_played, match_rating)
		performance.training_share = expected.training_share
		CareerSeason.play(career, plan, performance, world, balance, rules, cups, errors)
		outcome.peak_overall = maxi(outcome.peak_overall, career.player.overall_rating(balance))
	outcome.final_tier = world.league_of(career.club_id).tier
	return outcome


static func _handle_window(
	career: CareerState, world: ClubWorld, balance: Balance, rules: CareerRules
) -> void:
	if Trials.is_due(career, rules):
		var choice := world.club(rules.academy_club)
		for club: Club in Trials.trial_clubs(world, rules):
			if Trials.would_pass(career, club, balance, rules):
				choice = club
				break
		Trials.take(career, choice, world, balance, rules)
		return
	for offer: Offer in OfferEngine.offers_for(career, world, balance, rules):
		var current_strength := world.club(career.club_id).strength
		var better := world.club(offer.club_id).strength > current_strength
		var needed := not career.has_active_contract()
		if (
			(better or needed)
			and OfferEngine.refusal_reason(career, offer, world, rules).is_empty()
		):
			OfferEngine.accept(career, offer)
			return
