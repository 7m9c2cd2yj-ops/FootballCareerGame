extends GutTest
## Expected match ratings and input clamping.

const Fixture := preload("res://tests/helpers/balance_fixture.gd")


func test_create_clamps_inputs() -> void:
	var performance := SeasonPerformance.create(-3, 14.0)
	assert_eq(performance.matches_played, 0)
	assert_eq(performance.average_rating, SeasonPerformance.MAX_RATING)


func test_expected_rating_is_neutral_when_evenly_matched() -> void:
	var balance := Fixture.shipped()
	assert_eq(SeasonPerformance.expected_rating(60, 60.0, balance), balance.expected_neutral)


func test_expected_rating_rises_with_the_gap_and_is_clamped() -> void:
	var balance := Fixture.shipped()
	var above := SeasonPerformance.expected_rating(70, 60.0, balance)
	assert_almost_eq(
		above, balance.expected_neutral + 10 * balance.expected_per_overall_point, 1e-6
	)
	assert_eq(SeasonPerformance.expected_rating(99, 1.0, balance), balance.expected_max)
	assert_eq(SeasonPerformance.expected_rating(1, 99.0, balance), balance.expected_min)


func test_expected_for_uses_age_group_matches() -> void:
	var balance := Fixture.shipped()
	var player := PlayerModel.create("Test", "MID", balance)
	var performance := SeasonPerformance.expected_for(player, balance)
	assert_eq(performance.matches_played, balance.matches_for_age(player.age))
