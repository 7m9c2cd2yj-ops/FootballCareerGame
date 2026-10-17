class_name OfferEngine
extends RefCounted
## Builds the club offers for a transfer window (between seasons). A club
## offers a contract when one of its needs that are open this season fits the
## player's position, overall and age. Terms scale with how far the player
## exceeds the need and with the club's budget. Fully deterministic.

const VARIETY_NEEDS := 11


## Needs of `club` that are open in `season_number` (deterministic rotation,
## at least one is always open).
static func open_needs(
	club: Club, club_index: int, season_number: int, rules: CareerRules
) -> Array[ClubNeed]:
	var share := rules.value("needs", "open_share")
	var open: Array[ClubNeed] = []
	for i: int in club.needs.size():
		if Variety.unit(season_number, club_index * 16 + i, VARIETY_NEEDS) < share:
			open.append(club.needs[i])
	if open.is_empty():
		open.append(club.needs[season_number % club.needs.size()])
	return open


## The first open need of `club` the player fits, or null.
static func matching_need(
	career: CareerState,
	club: Club,
	club_index: int,
	season_number: int,
	balance: Balance,
	rules: CareerRules
) -> ClubNeed:
	var player := career.player
	var overall := player.overall_rating(balance)
	for need: ClubNeed in open_needs(club, club_index, season_number, rules):
		if need.accepts(player.position, overall, player.age):
			return need
	return null


## Offers for the window before `career.next_season_number()`, strongest club first.
## Empty before the trial age or while the trial is still to be taken.
static func offers_for(
	career: CareerState, world: ClubWorld, balance: Balance, rules: CareerRules
) -> Array[Offer]:
	var offers: Array[Offer] = []
	if career.retired or career.contract == null:
		return offers
	var season := career.next_season_number()
	for index: int in world.clubs.size():
		var club := world.clubs[index]
		if club.id == career.club_id:
			continue
		var need := matching_need(career, club, index, season, balance, rules)
		if need != null:
			offers.append(build_offer(career, club, need.min_rating, balance, rules))
	var renewal := _renewal(career, world, balance, rules)
	if renewal != null:
		offers.append(renewal)
	if career.contract.has_expired() and not _has_club(offers, rules.fallback_club):
		var fallback := world.club(rules.fallback_club)
		offers.append(build_offer(career, fallback, fallback.youth_intake_min, balance, rules))
	offers.sort_custom(
		func(a: Offer, b: Offer) -> bool:
			return world.club(a.club_id).strength > world.club(b.club_id).strength
	)
	return offers


static func build_offer(
	career: CareerState, club: Club, need_rating: float, balance: Balance, rules: CareerRules
) -> Offer:
	var overall := career.player.overall_rating(balance)
	var offer := Offer.new()
	offer.club_id = club.id
	var above := maxf(0.0, overall - need_rating)
	var raise := 1.0 + above * rules.value("contract", "wage_per_point_above_need")
	offer.wage = roundi(rules.budget_value(club.budget, "wage_base") * raise)
	offer.years = rules.contract_years(career.player.age)
	offer.release_clause = roundi(offer.wage * rules.value("contract", "release_clause_multiplier"))
	offer.role = SeasonContext.role_at(overall, club, rules)
	return offer


## Empty string if the player may accept `offer`, otherwise the reason not.
static func refusal_reason(
	career: CareerState, offer: Offer, world: ClubWorld, rules: CareerRules
) -> String:
	if offer.club_id == career.club_id or not career.has_active_contract():
		return ""
	var budget := rules.budget_value(world.club(offer.club_id).budget, "transfer_budget")
	if budget < career.contract.release_clause:
		return "Their transfer budget cannot cover your release clause"
	return ""


## Signs `offer`, recording a transfer if the club changes. Trials record
## their own event, so youth signings are not reported as transfers.
static func accept(career: CareerState, offer: Offer) -> void:
	if offer.club_id == career.club_id and offer.is_renewal:
		var values := {"club": offer.club_id, "wage": offer.wage, "years": offer.years}
		CareerEvents.record(career, CareerEvent.RENEWAL, values)
	if offer.club_id != career.club_id:
		var transfer := TransferRecord.new()
		transfer.season_number = career.next_season_number()
		transfer.from_club = career.club_id
		transfer.to_club = offer.club_id
		transfer.fee = career.contract.release_clause if career.has_active_contract() else 0
		transfer.wage = offer.wage
		career.transfers.append(transfer)
		if not offer.is_youth:
			var values := {
				"from_club": transfer.from_club,
				"to_club": transfer.to_club,
				"fee": transfer.fee,
				"wage": transfer.wage,
			}
			CareerEvents.record(career, CareerEvent.TRANSFER, values)
	career.club_id = offer.club_id
	career.contract = offer.to_contract()


## When the contract runs out, the club re-signs players still close to its level.
static func _renewal(
	career: CareerState, world: ClubWorld, balance: Balance, rules: CareerRules
) -> Offer:
	if not career.contract.has_expired():
		return null
	var club := world.club(career.club_id)
	var overall := career.player.overall_rating(balance)
	if overall < club.strength - rules.value("contract", "renewal_margin"):
		return null
	var offer := build_offer(career, club, club.strength, balance, rules)
	offer.is_renewal = true
	return offer


static func _has_club(offers: Array[Offer], club_id: String) -> bool:
	for offer: Offer in offers:
		if offer.club_id == club_id:
			return true
	return false
