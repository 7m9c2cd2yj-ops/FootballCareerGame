class_name ParentalGate
extends RefCounted
## A grown-up check shown before purchases and links that leave the game:
## a multiplication most young children cannot do at a glance, answered by
## tapping one of four choices (no keyboard). A wrong answer closes the gate.

const CHOICES := 4
const VARIETY_LEFT := 1
const VARIETY_RIGHT := 2
const VARIETY_ORDER := 3
const VARIETY_OFFSET := 4

var left: int = 0
var right: int = 0
var choices: Array[int] = []


## A question picked from `seed` (the screen passes the clock, so it changes).
static func create(seed_value: int) -> ParentalGate:
	var gate := ParentalGate.new()
	gate.left = 12 + int(Variety.unit(seed_value, 0, VARIETY_LEFT) * 18)  # 12..29
	gate.right = 6 + int(Variety.unit(seed_value, 0, VARIETY_RIGHT) * 4)  # 6..9
	var correct := gate.answer()
	# Wrong choices sit close to the answer so guessing from size does not work.
	var offsets: Array[int] = [gate.right, -gate.right, 10, -10, gate.left, 2 * gate.right]
	var start := int(Variety.unit(seed_value, 0, VARIETY_OFFSET) * 6)
	var wrong: Array[int] = []
	for i: int in offsets.size():
		var candidate := correct + offsets[(start + i) % offsets.size()]
		if wrong.size() < CHOICES - 1 and candidate > 0 and not wrong.has(candidate):
			wrong.append(candidate)
	var slot := int(Variety.unit(seed_value, 0, VARIETY_ORDER) * CHOICES)
	gate.choices = wrong
	gate.choices.insert(slot, correct)
	return gate


func answer() -> int:
	return left * right


func question() -> String:
	return "Ask a grown-up: what is %d × %d?" % [left, right]


func is_correct(choice: int) -> bool:
	return choice == answer()
