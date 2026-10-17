extends GutTest
## Career rules validation.

const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")
const CareerFixture := preload("res://tests/helpers/career_fixture.gd")

var _world: ClubWorld


func before_all() -> void:
	_world = CareerFixture.world()


func _problems(change: Callable) -> String:
	var data := JsonLoader.load_dictionary(CareerRules.DEFAULT_PATH).data
	change.call(data)
	return "\n".join(CareerRules.validate(data, _world, BalanceFixture.shipped().max_age))


func test_shipped_rules_are_valid() -> void:
	assert_eq(_problems(func(_d: Dictionary) -> void: pass), "")


func test_unknown_academy_club_is_rejected() -> void:
	var problems := _problems(func(d: Dictionary) -> void: d["academy_club"] = "nowhere")
	assert_string_contains(problems, "academy_club")


func test_contract_table_must_cover_every_age() -> void:
	var problems := _problems(func(d: Dictionary) -> void: d["contract_years"][0]["to_age"] = 20)
	assert_string_contains(problems, "contract_years")


func test_every_club_budget_must_exist() -> void:
	var remove_low := func(d: Dictionary) -> void:
		var budgets: Dictionary = d["budgets"]
		budgets.erase("low")
	assert_string_contains(_problems(remove_low), "unknown budget 'low'")


func test_intensity_loads_are_required() -> void:
	var remove_intense := func(d: Dictionary) -> void:
		var loads: Dictionary = d["fatigue"]["intensity_load"]
		loads.erase("intense")
	assert_string_contains(_problems(remove_intense), "intensity_load.intense")


func test_contract_years_shrink_with_age() -> void:
	var rules := CareerFixture.rules(_world)
	assert_gt(rules.contract_years(20), rules.contract_years(35))
