extends GutTest
## Safe-area margins convert screen pixels to canvas units.


func test_notch_and_home_bar_become_margins() -> void:
	# 1080x2340 phone, 120 px notch at the top, 60 px home bar, canvas 720 wide.
	var window := Rect2i(0, 0, 1080, 2340)
	var safe := Rect2i(0, 120, 1080, 2160)
	var margins := SafeArea.margins(safe, window, Vector2(720, 1560))
	assert_almost_eq(margins.x, 0.0, 0.001)
	assert_almost_eq(margins.y, 80.0, 0.001)
	assert_almost_eq(margins.z, 0.0, 0.001)
	assert_almost_eq(margins.w, 40.0, 0.001)


func test_landscape_cutout_on_the_left() -> void:
	var window := Rect2i(0, 0, 2340, 1080)
	var safe := Rect2i(132, 0, 2142, 1080)
	var margins := SafeArea.margins(safe, window, Vector2(1560, 720))
	assert_almost_eq(margins.x, 88.0, 0.001)
	assert_almost_eq(margins.z, 44.0, 0.001)


func test_full_or_unknown_safe_area_means_no_margins() -> void:
	var window := Rect2i(0, 0, 1080, 1920)
	assert_eq(SafeArea.margins(window, window, Vector2(720, 1280)), Vector4.ZERO)
	assert_eq(SafeArea.margins(Rect2i(), window, Vector2(720, 1280)), Vector4.ZERO)
	var elsewhere := Rect2i(5000, 5000, 10, 10)
	assert_eq(SafeArea.margins(elsewhere, window, Vector2(720, 1280)), Vector4.ZERO)
