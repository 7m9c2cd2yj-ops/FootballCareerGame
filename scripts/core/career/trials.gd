class_name Trials
extends RefCounted
## The one trial of a career, at the trial age, before any contract.
## Pass if: overall + key moments won last season * bonus >= club's youth_intake_min.
## Passing signs a youth contract with that club; failing signs one with the
## academy club, so every player has a club afterwards.


static func is_due(career: CareerState, rules: CareerRules) -> bool:
	return (
		not career.retired
		and not career.trial_used
		and career.contract == null
		and career.player.age >= rules.trial_age
	)


## What the club compares with its youth_intake_min. Skill in last season's key
## moments counts, not just the rating.
static func trial_score(career: CareerState, balance: Balance, rules: CareerRules) -> float:
	var moments_won := 0
	if not career.history.is_empty():
		moments_won = career.history[-1].key_moments_won
	var bonus := moments_won * rules.value("trial", "bonus_per_key_moment_won")
	return career.player.overall_rating(balance) + bonus


static func would_pass(
	career: CareerState, club: Club, balance: Balance, rules: CareerRules
) -> bool:
	return trial_score(career, balance, rules) >= club.youth_intake_min


## Clubs the player can try out for, highest intake bar first (not the fallback club).
static func trial_clubs(world: ClubWorld, rules: CareerRules) -> Array[Club]:
	var options: Array[Club] = []
	for club: Club in world.clubs:
		if club.id != rules.fallback_club:
			options.append(club)
	options.sort_custom(
		func(a: Club, b: Club) -> bool: return a.youth_intake_min > b.youth_intake_min
	)
	return options


## Takes the trial at `club`; returns true if passed.
static func take(
	career: CareerState, club: Club, world: ClubWorld, balance: Balance, rules: CareerRules
) -> bool:
	var passed := would_pass(career, club, balance, rules)
	var signing := club if passed else world.club(rules.academy_club)
	var offer := youth_offer(signing, rules)
	career.trial_used = true
	OfferEngine.accept(career, offer)
	if passed:
		CareerEvents.record(career, CareerEvent.TRIAL_PASSED, {"club": club.id})
	else:
		var values := {"club": club.id, "academy": rules.academy_club}
		CareerEvents.record(career, CareerEvent.TRIAL_FAILED, values)
	return passed


static func youth_offer(club: Club, rules: CareerRules) -> Offer:
	var offer := Offer.new()
	offer.club_id = club.id
	offer.wage = roundi(rules.budget_value(club.budget, "youth_wage"))
	offer.years = int(rules.value("contract", "youth_years"))
	offer.release_clause = roundi(offer.wage * rules.value("contract", "release_clause_multiplier"))
	offer.is_youth = true
	return offer
