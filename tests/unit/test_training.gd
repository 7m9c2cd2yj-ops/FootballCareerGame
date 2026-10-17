extends GutTest
## TrainingPlan validation and TrainingAdvisor recommendations.

const Fixture := preload("res://tests/helpers/balance_fixture.gd")


func test_valid_plan() -> void:
	assert_eq(TrainingPlan.create("pace", "shooting").validate().size(), 0)


func test_plan_needs_two_different_foci() -> void:
	assert_string_contains(TrainingPlan.create("pace", "pace").validate()[0], "must differ")


func test_plan_rejects_unknown_attribute() -> void:
	assert_string_contains(TrainingPlan.create("flair", "pace").validate()[0], "flair")


func test_advisor_targets_most_valuable_attributes() -> void:
	var balance := Fixture.shipped()
	var player := PlayerModel.create("Test", "FWD", balance)
	var plan := TrainingAdvisor.recommended_plan(player, balance)
	# Shooting carries the biggest FWD weight (0.4); the runner-up is a 0.2 attribute.
	assert_eq(plan.primary, "shooting")
	assert_eq(balance.weight("FWD", plan.secondary), 0.2)


func test_advisor_moves_on_from_maxed_attributes() -> void:
	var balance := Fixture.shipped()
	var player := PlayerModel.create("Test", "FWD", balance)
	player.attributes["shooting"] = 99.0
	assert_ne(TrainingAdvisor.recommended_plan(player, balance).primary, "shooting")


func test_advisor_plan_is_always_valid() -> void:
	var balance := Fixture.shipped()
	for position: String in balance.positions():
		var player := PlayerModel.create("Test", position, balance)
		assert_eq(TrainingAdvisor.recommended_plan(player, balance).validate().size(), 0)


func test_plan_rejects_unknown_intensity() -> void:
	var problems := TrainingPlan.create("pace", "shooting", "extreme").validate()
	assert_string_contains("\n".join(problems), "intensity")


func test_plan_defaults_to_normal_intensity() -> void:
	assert_eq(TrainingPlan.create("pace", "shooting").intensity, TrainingPlan.NORMAL)
