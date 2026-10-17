extends GutTest
## Club offers follow stated needs; terms, release clauses and transfers.

const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")
const CareerFixture := preload("res://tests/helpers/career_fixture.gd")

var _balance: Balance
var _world: ClubWorld
var _rules: CareerRules


func before_all() -> void:
	_balance = BalanceFixture.shipped()
	_world = CareerFixture.world()
	_rules = CareerFixture.rules(_world)


func _pro(position: String, age: int, rating: float, years_left: int) -> CareerState:
	var career := CareerFixture.career_at(position, age, rating, "westerby", _balance)
	career.contract = CareerFixture.contract("westerby", years_left, 500)
	return career


func _offer_from(offers: Array[Offer], club_id: String) -> Offer:
	for offer: Offer in offers:
		if offer.club_id == club_id:
			return offer
	return null


func test_no_offers_before_a_first_contract() -> void:
	var career := CareerFixture.career_at("FWD", 14, 60.0, _rules.academy_club, _balance)
	assert_eq(OfferEngine.offers_for(career, _world, _balance, _rules).size(), 0)


func test_offers_come_only_from_clubs_whose_open_need_fits() -> void:
	var career := _pro("FWD", 24, 70.0, 2)
	var season := career.next_season_number()
	for offer: Offer in OfferEngine.offers_for(career, _world, _balance, _rules):
		var club := _world.club(offer.club_id)
		var need := OfferEngine.matching_need(
			career, club, _world.club_index(club.id), season, _balance, _rules
		)
		assert_not_null(need, club.id)


func test_better_players_get_offers_from_stronger_clubs() -> void:
	var average := OfferEngine.offers_for(_pro("MID", 25, 55.0, 2), _world, _balance, _rules)
	var star := OfferEngine.offers_for(_pro("MID", 25, 90.0, 2), _world, _balance, _rules)
	assert_gt(star.size(), 0)
	var best_star := _world.club(star[0].club_id).strength
	var best_average := 0.0 if average.is_empty() else _world.club(average[0].club_id).strength
	assert_gt(best_star, best_average)


func test_offers_are_sorted_strongest_first_and_deterministic() -> void:
	var career := _pro("DEF", 26, 80.0, 0)
	var offers := OfferEngine.offers_for(career, _world, _balance, _rules)
	for i: int in range(1, offers.size()):
		var stronger := _world.club(offers[i - 1].club_id).strength
		assert_true(stronger >= _world.club(offers[i].club_id).strength)
	var again := OfferEngine.offers_for(career, _world, _balance, _rules)
	assert_eq(again.size(), offers.size())


func test_wage_rises_with_rating_above_the_need() -> void:
	var club := _world.club("brackenford")
	var good := OfferEngine.build_offer(_pro("FWD", 25, 80, 2), club, 80.0, _balance, _rules)
	var better := OfferEngine.build_offer(_pro("FWD", 25, 90, 2), club, 80.0, _balance, _rules)
	assert_gt(better.wage, good.wage)
	var multiplier := _rules.value("contract", "release_clause_multiplier")
	assert_eq(better.release_clause, roundi(better.wage * multiplier))
	assert_eq(better.years, _rules.contract_years(25))


func test_role_depends_on_rating_versus_club_strength() -> void:
	var club := _world.club("brackenford")
	assert_eq(SeasonContext.role_at(int(club.strength), club, _rules), CareerRules.STARTER)
	assert_eq(SeasonContext.role_at(int(club.strength) - 5, club, _rules), CareerRules.ROTATION)
	assert_eq(SeasonContext.role_at(int(club.strength) - 20, club, _rules), CareerRules.BENCH)


func test_open_needs_rotate_but_are_never_empty() -> void:
	var club := _world.club("copperlake")
	var seen: Dictionary[int, bool] = {}
	for season: int in range(1, 30):
		var open := OfferEngine.open_needs(club, 2, season, _rules)
		assert_gt(open.size(), 0)
		seen[open.size()] = true
	assert_gt(seen.size(), 1, "open needs should vary between seasons")


func test_release_clause_must_be_affordable_mid_contract() -> void:
	var career := _pro("FWD", 24, 75.0, 2)
	career.contract.release_clause = 999999
	var offer := OfferEngine.build_offer(career, _world.club("larkspur"), 60.0, _balance, _rules)
	assert_string_contains(
		OfferEngine.refusal_reason(career, offer, _world, _rules), "release clause"
	)
	career.contract.years_left = 0
	assert_eq(OfferEngine.refusal_reason(career, offer, _world, _rules), "")


func test_accepting_records_the_transfer_and_fee() -> void:
	var career := _pro("FWD", 24, 75.0, 2)
	var offer := OfferEngine.build_offer(career, _world.club("brackenford"), 70.0, _balance, _rules)
	OfferEngine.accept(career, offer)
	assert_eq(career.club_id, "brackenford")
	assert_eq(career.contract.years_left, offer.years)
	assert_eq(career.transfers.size(), 1)
	assert_eq(career.transfers[0].from_club, "westerby")
	assert_eq(career.transfers[0].fee, 500)


func test_expired_contract_brings_renewal_and_fallback() -> void:
	var career := _pro("GK", 30, 45.0, 0)
	var offers := OfferEngine.offers_for(career, _world, _balance, _rules)
	var renewal := _offer_from(offers, "westerby")
	assert_not_null(renewal, "close enough to the club's level to be re-signed")
	assert_true(renewal.is_renewal)
	assert_not_null(_offer_from(offers, _rules.fallback_club))


func test_far_too_weak_player_is_not_renewed_but_never_stranded() -> void:
	var career := _pro("GK", 36, 20.0, 0)
	var offers := OfferEngine.offers_for(career, _world, _balance, _rules)
	assert_null(_offer_from(offers, "westerby"))
	assert_not_null(_offer_from(offers, _rules.fallback_club))
