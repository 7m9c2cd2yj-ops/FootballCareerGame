extends GutTest
## The grown-up check: one right answer among four close choices.


func test_choices_hold_the_answer_once() -> void:
	for seed_value: int in 200:
		var gate := ParentalGate.create(seed_value)
		assert_eq(gate.choices.size(), ParentalGate.CHOICES)
		assert_eq(gate.choices.count(gate.answer()), 1)
		var unique: Dictionary[int, bool] = {}
		for choice: int in gate.choices:
			unique[choice] = true
		assert_eq(unique.size(), ParentalGate.CHOICES, "seed %d" % seed_value)


func test_questions_are_not_trivial() -> void:
	for seed_value: int in 200:
		var gate := ParentalGate.create(seed_value)
		assert_between(gate.left, 12, 29)
		assert_between(gate.right, 6, 9)


func test_same_seed_same_question_and_seeds_vary() -> void:
	assert_eq(ParentalGate.create(42).question(), ParentalGate.create(42).question())
	var questions: Dictionary[String, bool] = {}
	for seed_value: int in 50:
		questions[ParentalGate.create(seed_value).question()] = true
	assert_gt(questions.size(), 20)


func test_answer_position_varies() -> void:
	var positions: Dictionary[int, bool] = {}
	for seed_value: int in 100:
		var gate := ParentalGate.create(seed_value)
		positions[gate.choices.find(gate.answer())] = true
	assert_eq(positions.size(), ParentalGate.CHOICES)


func test_only_the_answer_passes() -> void:
	var gate := ParentalGate.create(7)
	for choice: int in gate.choices:
		assert_eq(gate.is_correct(choice), choice == gate.answer())
