extends GutTest
## The agent's live advice reflects the career right now.

const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")
const CareerFixture := preload("res://tests/helpers/career_fixture.gd")
const NewsFixture := preload("res://tests/helpers/news_fixture.gd")

var _balance: Balance
var _world: ClubWorld
var _rules: CareerRules


func before_all() -> void:
	_balance = BalanceFixture.shipped()
	_world = CareerFixture.world()
	_rules = CareerFixture.rules(_world)


func _keys(career: CareerState) -> Array[String]:
	return AgentAdvice.current_keys(career, _world, _balance, _rules)


func test_young_academy_player_hears_all_quiet() -> void:
	var career := CareerFixture.career_at("MID", 10, 20.0, _rules.academy_club, _balance)
	assert_eq(_keys(career), ["all_quiet"] as Array[String])


func test_trial_age_brings_trial_advice() -> void:
	var career := CareerFixture.career_at(
		"MID", _rules.trial_age, 30.0, _rules.academy_club, _balance
	)
	assert_true(_keys(career).has("trials_due"))


func test_contract_state_is_advised() -> void:
	var career := CareerFixture.career_at("MID", 25, 60.0, "tidewell", _balance)
	career.contract = CareerFixture.contract("tidewell", 1, 100)
	assert_true(_keys(career).has("contract_final_year"))
	career.contract.years_left = 0
	assert_true(_keys(career).has("contract_ended"))


func test_high_fatigue_is_warned_about() -> void:
	var career := CareerFixture.career_at("MID", 25, 60.0, "tidewell", _balance)
	career.contract = CareerFixture.contract("tidewell", 3, 100)
	career.fatigue = 60.0
	assert_true(_keys(career).has("fatigue_high"))
	career.fatigue = 5.0
	assert_false(_keys(career).has("fatigue_high"))


func test_interested_clubs_are_counted() -> void:
	var star := CareerFixture.career_at("FWD", 25, 92.0, "tidewell", _balance)
	star.contract = CareerFixture.contract("tidewell", 3, 100)
	assert_gt(AgentAdvice.interested_clubs(star, _world, _balance, _rules), 0)
	assert_true(_keys(star).has("clubs_interested"))


func test_advice_texts_are_fully_filled() -> void:
	var career := CareerFixture.career_at("FWD", 34, 92.0, "tidewell", _balance)
	career.contract = CareerFixture.contract("tidewell", 1, 100)
	career.fatigue = 70.0
	var texts := AgentAdvice.current_texts(
		career, _world, _balance, _rules, NewsFixture.labels(), NewsFixture.templates()
	)
	assert_gt(texts.size(), 2)
	for text: String in texts:
		assert_false(text.contains("{"), text)
