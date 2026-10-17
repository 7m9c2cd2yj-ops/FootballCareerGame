extends GutTest
## Design targets for data/balance.json (see docs/BALANCE.md). These simulate
## whole careers; if a tuning change breaks one, either fix the numbers or
## update the target here and in docs/BALANCE.md on purpose.

const CareerSim := preload("res://tests/helpers/career_sim.gd")
const Fixture := preload("res://tests/helpers/balance_fixture.gd")

var _balance: Balance


func before_all() -> void:
	_balance = Fixture.shipped()


func _peak(position: String, rating: float) -> Vector2i:
	return CareerSim.peak(CareerSim.overall_by_age(position, rating, null, _balance))


func test_near_perfect_play_reaches_99_in_the_late_twenties() -> void:
	for position: String in _balance.positions():
		var peak := _peak(position, 9.7)
		assert_eq(peak.y, 99, "%s elite peak" % position)
		assert_between(peak.x, 25, 30, "%s elite peak age" % position)


func test_star_play_peaks_in_the_high_nineties() -> void:
	for position: String in _balance.positions():
		assert_between(_peak(position, 9.0).y, 95, 99, "%s star peak" % position)


func test_good_play_peaks_in_the_eighties() -> void:
	for position: String in _balance.positions():
		assert_between(_peak(position, 7.5).y, 80, 90, "%s good peak" % position)


func test_unremarkable_play_peaks_well_short_of_elite() -> void:
	for position: String in _balance.positions():
		var peak := _peak(position, CareerSim.EXPECTED_RATING)
		assert_between(peak.y, 55, 72, "%s expected peak" % position)


func test_no_prodigy_reaches_elite_level_as_a_teenager() -> void:
	for position: String in _balance.positions():
		var curve := CareerSim.overall_by_age(position, 10.0, null, _balance)
		assert_lt(curve[18], 85, "%s perfect play at 18" % position)


func test_veterans_decline() -> void:
	for position: String in _balance.positions():
		var curve := CareerSim.overall_by_age(position, 7.5, null, _balance)
		var peak := CareerSim.peak(curve)
		assert_lte(curve[36], peak.y - 4, "%s at 36 vs peak" % position)


func test_positions_are_fair_to_each_other() -> void:
	var peaks: Array[int] = []
	for position: String in _balance.positions():
		peaks.append(_peak(position, 7.5).y)
	assert_lte(peaks.max() - peaks.min(), 4, "good-play peaks by position: %s" % str(peaks))


func test_careers_are_deterministic() -> void:
	var first := CareerSim.overall_by_age("MID", 8.2, null, _balance)
	assert_eq(CareerSim.overall_by_age("MID", 8.2, null, _balance), first)


## No position should be a trap: same play, similar peak (M8 tuning pass).
func test_positions_peak_within_four_points_of_each_other() -> void:
	for rating: float in [7.5, CareerSim.EXPECTED_RATING]:
		var peaks: Array[int] = []
		for position: String in _balance.positions():
			peaks.append(_peak(position, rating).y)
		assert_lte(peaks.max() - peaks.min(), 4, "peaks %s at rating %s" % [peaks, rating])
