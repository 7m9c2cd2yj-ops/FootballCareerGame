extends GutTest
## The fictional club world: valid data, original names, deterministic needs.

const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")
const CareerFixture := preload("res://tests/helpers/career_fixture.gd")

var _world: ClubWorld


func before_all() -> void:
	_world = CareerFixture.world()


func _data() -> Dictionary:
	return JsonLoader.load_dictionary(ClubWorld.DEFAULT_PATH).data


func _problems(data: Dictionary) -> String:
	return "\n".join(ClubWorld.validate(data, BalanceFixture.shipped().positions()))


func test_names_are_original() -> void:
	var names: Array[String] = [_world.nation]
	for league: League in _world.leagues:
		names.append(league.name)
	for club: Club in _world.clubs:
		names.append(club.name)
	for title: String in names:
		assert_eq(ContentRules.problem_in(title), "", title)


func test_leagues_have_distinct_tiers_and_falling_strength() -> void:
	var previous := 100.0
	for tier: int in range(1, _world.leagues.size() + 1):
		var found: Array[League] = []
		for league: League in _world.leagues:
			if league.tier == tier:
				found.append(league)
		assert_eq(found.size(), 1, "tier %d" % tier)
		assert_lt(found[0].strength, previous)
		previous = found[0].strength


func test_every_position_is_wanted_somewhere() -> void:
	for position: String in BalanceFixture.shipped().positions():
		var wanted := false
		for club: Club in _world.clubs:
			for need: ClubNeed in club.needs:
				wanted = wanted or need.position == position
		assert_true(wanted, position)


func test_initials() -> void:
	var club := Club.new()
	club.name = "Wyvern Point Rovers"
	assert_eq(club.initials(), "WPR")


func test_unknown_league_is_rejected() -> void:
	var data := _data()
	data["clubs"][0]["league"] = "moon_league"
	assert_string_contains(_problems(data), "unknown league")


func test_bad_crest_is_rejected() -> void:
	var data := _data()
	data["clubs"][1]["crest"]["primary"] = "not-a-colour"
	data["clubs"][1]["crest"]["shape"] = "star"
	var problems := _problems(data)
	assert_string_contains(problems, "crest.primary")
	assert_string_contains(problems, "crest.shape")


func test_need_with_unknown_position_is_rejected() -> void:
	var data := _data()
	data["clubs"][2]["needs"][0]["position"] = "STRIKER"
	assert_string_contains(_problems(data), "unknown position")


func test_duplicate_club_id_is_rejected() -> void:
	var data := _data()
	data["clubs"][3]["id"] = data["clubs"][4]["id"]
	assert_string_contains(_problems(data), "duplicate id")


func test_strength_out_of_range_is_rejected() -> void:
	var data := _data()
	data["clubs"][0]["strength"] = 140
	assert_string_contains(_problems(data), "between 1 and 99")


func test_need_age_limit() -> void:
	var need := ClubNeed.from_dict({"position": "FWD", "min_rating": 70, "max_age": 30})
	assert_true(need.accepts("FWD", 70, 30))
	assert_false(need.accepts("FWD", 69, 25))
	assert_false(need.accepts("FWD", 80, 31))
	assert_false(need.accepts("MID", 80, 25))
	assert_eq(need.describe(), "FWD 70+ (age ≤ 30)")


func test_lower_leagues_never_have_bigger_budgets() -> void:
	var rules := CareerFixture.rules(_world)
	for club: Club in _world.clubs:
		var tier := _world.league_of(club.id).tier
		var base := rules.budget_value(club.budget, "wage_base")
		for other: Club in _world.clubs:
			if _world.league_of(other.id).tier < tier:
				assert_true(
					rules.budget_value(other.budget, "wage_base") >= base,
					"%s (lower league) out-pays %s" % [club.id, other.id]
				)
