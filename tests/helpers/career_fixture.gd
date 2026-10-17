extends RefCounted
## Loads the shipped club world and career rules for tests.

const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")


static func world() -> ClubWorld:
	var errors: Array[String] = []
	var loaded := ClubWorld.load_file(
		ClubWorld.DEFAULT_PATH, BalanceFixture.shipped().positions(), errors
	)
	assert(loaded != null, "\n".join(errors))
	return loaded


static func rules(club_world: ClubWorld) -> CareerRules:
	var errors: Array[String] = []
	var max_age := BalanceFixture.shipped().max_age
	var loaded := CareerRules.load_file(CareerRules.DEFAULT_PATH, club_world, max_age, errors)
	assert(loaded != null, "\n".join(errors))
	return loaded


## A career for `position` aged `age` whose attributes are all `rating`
## (so its overall is `rating`), at `club_id`.
static func career_at(
	position: String, age: int, rating: float, club_id: String, balance: Balance
) -> CareerState:
	var career := CareerState.start("Test", position, balance, club_id)
	career.player.age = age
	for attribute: String in PlayerModel.ATTRIBUTES:
		career.player.attributes[attribute] = rating
	return career


## A contract at `club_id` with `years_left` remaining.
static func contract(club_id: String, years_left: int, release_clause: int) -> Contract:
	var signed := Contract.new()
	signed.club_id = club_id
	signed.wage = 100
	signed.years_left = years_left
	signed.release_clause = release_clause
	return signed
