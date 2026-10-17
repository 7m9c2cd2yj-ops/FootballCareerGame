extends GutTest
## Cup data, draws, the deterministic match rule and the player's influence.

const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")
const CareerFixture := preload("res://tests/helpers/career_fixture.gd")

var _balance: Balance
var _world: ClubWorld
var _rules: CareerRules
var _cups: CupWorld


func before_all() -> void:
	_balance = BalanceFixture.shipped()
	_world = CareerFixture.world()
	_rules = CareerFixture.rules(_world)
	_cups = CareerFixture.cups()


func _data(path: String) -> Dictionary:
	return JsonLoader.load_dictionary(path).data


func _field(cup_id: String) -> Dictionary[String, float]:
	var cup := _cups.cup(cup_id)
	if cup.is_for_nations():
		return CupSeason.nation_entrants(_cups)
	return CupSeason.continental_entrants(cup, _world, _cups)


func _record(club_id: String, age: int, overall: int, rating: float, season: int) -> SeasonRecord:
	var record := SeasonRecord.new()
	record.club_id = club_id
	record.age = age
	record.overall_after = overall
	record.average_rating = rating
	record.season_number = season
	return record


func test_both_cups_have_sixteen_original_teams() -> void:
	for cup_id: String in CupDefinition.IDS:
		var field := _field(cup_id)
		assert_eq(field.size(), CupWorld.BRACKET_SIZE, cup_id)
		for team: String in field:
			assert_eq(ContentRules.problem_in(_cups.team_name(cup_id, team, _world)), "", team)


func test_bad_flag_and_unknown_nation_are_rejected() -> void:
	var nations := _data(CupWorld.NATIONS_PATH)
	var cups := _data(CupWorld.CUPS_PATH)
	nations["nations"][0]["flag"]["pattern"] = "stars"
	cups["foreign_clubs"][0]["nation"] = "atlantis"
	var problems := "\n".join(CupWorld.validate(nations, cups))
	assert_string_contains(problems, "flag.pattern")
	assert_string_contains(problems, "unknown nation")


func test_wrong_number_of_nations_is_rejected() -> void:
	var nations := _data(CupWorld.NATIONS_PATH)
	var list: Array = nations["nations"]
	list.pop_back()
	assert_string_contains(
		"\n".join(CupWorld.validate(nations, _data(CupWorld.CUPS_PATH))), "exactly 16"
	)


func test_draw_keeps_the_top_seeds_apart() -> void:
	var field := _field(CupDefinition.NATIONS)
	var bracket := CupSim.seeded_bracket(field)
	var strongest := bracket.duplicate()
	strongest.sort_custom(func(a: String, b: String) -> bool: return field[a] > field[b])
	assert_eq(bracket[0], strongest[0])
	assert_eq(bracket[1], strongest[15], "top seed meets the bottom seed")
	assert_true(bracket.find(strongest[1]) >= 8, "second seed is in the other half")


func test_a_cup_has_fifteen_matches_and_one_champion() -> void:
	var result := CupSim.play(
		CupDefinition.NATIONS, 7, _field(CupDefinition.NATIONS), "", 0.0, _cups
	)
	assert_eq(result.matches.size(), 15)
	assert_eq(result.matches[-1].round_index, CupSim.ROUNDS - 1)
	assert_eq(result.champion, result.matches[-1].winner)
	for played: CupSim.Match in result.matches:
		assert_ne(played.home_goals, played.away_goals, "knockouts have a winner")
		var home_won := played.home_goals > played.away_goals
		assert_eq(played.winner, played.home if home_won else played.away)


func test_cups_are_deterministic() -> void:
	var field := _field(CupDefinition.CONTINENTAL)
	var first := CupSim.play(CupDefinition.CONTINENTAL, 12, field, "copperlake", 4.0, _cups)
	var again := CupSim.play(CupDefinition.CONTINENTAL, 12, field, "copperlake", 4.0, _cups)
	assert_eq(again.champion, first.champion)
	assert_eq(again.player_wins, first.player_wins)


func test_the_player_lifts_their_team() -> void:
	var field := _field(CupDefinition.NATIONS)
	var total_without := 0
	var total_with := 0
	for season: int in range(1, 41):
		total_without += (
			CupSim.play(CupDefinition.NATIONS, season, field, "valdoria", -6.0, _cups).player_wins
		)
		total_with += (
			CupSim.play(CupDefinition.NATIONS, season, field, "valdoria", 10.0, _cups).player_wins
		)
	assert_gt(total_with, total_without)


func test_contribution_grows_with_level_and_form_and_is_capped() -> void:
	var base := CupSeason.contribution(80, 7.0, 1.0, 75.0, _cups)
	assert_gt(CupSeason.contribution(90, 7.0, 1.0, 75.0, _cups), base)
	assert_gt(CupSeason.contribution(80, 9.0, 1.0, 75.0, _cups), base)
	assert_lt(CupSeason.contribution(80, 7.0, 0.3, 75.0, _cups), base, "bench players add less")
	assert_eq(
		CupSeason.contribution(99, 10.0, 1.0, 40.0, _cups), _cups.match_value("max_contribution")
	)


func test_cup_calendar() -> void:
	var nations := _cups.cup(CupDefinition.NATIONS)
	var held := 0
	for season: int in range(1, 13):
		assert_true(_cups.cup(CupDefinition.CONTINENTAL).is_held(season))
		if nations.is_held(season):
			held += 1
	assert_eq(held, 3, "the World Nations Cup is every 4 seasons")


func test_who_plays_for_whom() -> void:
	var nations := _cups.cup(CupDefinition.NATIONS)
	var continental := _cups.cup(CupDefinition.CONTINENTAL)
	var field := _field(CupDefinition.CONTINENTAL)
	var young := _record("brackenford", 16, 90, 8.0, 3)
	assert_eq(CupSeason.player_team(continental, young, field, _rules, _cups), "")
	var senior := _record("brackenford", 24, 65, 8.0, 3)
	assert_eq(CupSeason.player_team(continental, senior, field, _rules, _cups), "brackenford")
	assert_eq(
		CupSeason.player_team(nations, senior, field, _rules, _cups), "", "below the call-up bar"
	)
	senior.overall_after = int(nations.call_up_min)
	assert_eq(CupSeason.player_team(nations, senior, field, _rules, _cups), _cups.home_nation)
	var small_club := _record("tidewell", 24, 90, 8.0, 3)
	assert_eq(CupSeason.player_team(continental, small_club, field, _rules, _cups), "")


func test_applying_a_season_stores_runs_and_news() -> void:
	var career := CareerFixture.career_at("FWD", 24, 85.0, "brackenford", _balance)
	var season := 1
	while not _cups.cup(CupDefinition.NATIONS).is_held(season):
		season += 1
	var record := _record("brackenford", 24, 85, 8.5, season)
	CupSeason.apply(career, record, _world, _rules, _cups)
	assert_eq(career.cup_runs.size(), 2)
	var types: Array[String] = []
	for event: CareerEvent in career.events:
		types.append(event.type)
	assert_eq(types.count(CareerEvent.CUP_RESULT), 2)
	assert_eq(types.count(CareerEvent.NATIONAL_CALL_UP), 1)
	CupSeason.apply(career, record, _world, _rules, _cups)
	var again: Array[String] = []
	for event: CareerEvent in career.events:
		again.append(event.type)
	assert_eq(again.count(CareerEvent.NATIONAL_CALL_UP), 1, "only the first call-up is news")


func test_golden_ball_rewards_better_seasons() -> void:
	var best_rank := 99
	var worst_rank := 0
	for rating: float in [6.0, 9.5]:
		var standing := GoldenBall.standing(
			_record("brackenford", 26, 95, rating, 9), 1, "Test", _cups
		)
		if rating > 9.0:
			best_rank = standing.rank
		else:
			worst_rank = standing.rank
	assert_lt(best_rank, worst_rank)


func test_golden_ball_winner_is_named() -> void:
	var top := GoldenBall.standing(_record("brackenford", 26, 99, 10.0, 9), 2, "Test", _cups)
	assert_eq(top.rank, 1)
	assert_eq(top.winner, "Test")
	var low := GoldenBall.standing(_record("tidewell", 26, 60, 6.0, 9), 0, "Test", _cups)
	assert_gt(low.rank, 1)
	assert_ne(low.winner, "Test")


func test_juniors_are_not_ranked_for_the_golden_ball() -> void:
	var career := CareerFixture.career_at("FWD", 15, 80.0, _rules.academy_club, _balance)
	GoldenBall.apply(career, _record(_rules.academy_club, 15, 80, 9.9, 5), 0, _rules, _cups)
	assert_eq(career.golden_balls.size(), 0)


func test_hall_of_fame_counts_trophies_and_golden_balls() -> void:
	var career := CareerFixture.career_at("FWD", 34, 80.0, "brackenford", _balance)
	var before := HallOfFame.summarize(career, _world, _rules).score
	var run := CupRun.new()
	run.cup_id = CupDefinition.CONTINENTAL
	run.won = true
	career.cup_runs.append(run)
	var ball := GoldenBall.Standing.new()
	ball.rank = 1
	career.golden_balls.append(ball)
	var summary := HallOfFame.summarize(career, _world, _rules)
	assert_eq(summary.trophies, 1)
	assert_eq(summary.golden_balls, 1)
	var expected := (
		_rules.value("hall_of_fame", "points_per_trophy")
		+ _rules.value("hall_of_fame", "points_per_golden_ball")
	)
	assert_eq(summary.score, before + expected)


func test_v3_saves_migrate_to_v4() -> void:
	var data := CareerState.start("Old", "MID", _balance, _rules.academy_club).to_dict()
	data["version"] = 3
	data.erase("cup_runs")
	data.erase("golden_balls")
	var migrated := CareerMigration.migrate(data, _rules.academy_club)
	assert_eq(CareerState.validate_dict(migrated, _balance, _world), [] as Array[String])
