extends RefCounted
## Shipped labels and text templates for news tests.


static func labels() -> GameLabels:
	var errors: Array[String] = []
	var loaded := GameLabels.load_file(GameLabels.DEFAULT_PATH, errors)
	assert(loaded != null, "\n".join(errors))
	return loaded


static func templates() -> TextTemplates:
	var errors: Array[String] = []
	var loaded := TextTemplates.load_file(TextTemplates.DEFAULT_PATH, errors)
	assert(loaded != null, "\n".join(errors))
	return loaded


## One event of every type and variant, with realistic values.
static func every_event(club_id: String, other_club_id: String) -> Array[CareerEvent]:
	var season := {
		"club": club_id,
		"overall_before": 60,
		"overall_after": 64,
		"moments_won": 3,
		"moments_played": 4,
	}
	var events: Array[CareerEvent] = []
	for rating: float in [9.1, 7.0, 4.5]:
		var values := season.duplicate()
		values["rating"] = rating
		events.append(CareerEvent.create(CareerEvent.SEASON_PLAYED, 5, 20, values))
	events.append(
		CareerEvent.create(CareerEvent.MILESTONE, 5, 20, {"club": club_id, "milestone": 60})
	)
	events.append(CareerEvent.create(CareerEvent.INJURY, 6, 21, {"club": club_id}))
	events.append(CareerEvent.create(CareerEvent.TOP_TIER_DEBUT, 7, 22, {"club": club_id}))
	events.append(CareerEvent.create(CareerEvent.TRIAL_PASSED, 9, 16, {"club": club_id}))
	events.append(
		CareerEvent.create(
			CareerEvent.TRIAL_FAILED, 9, 16, {"club": other_club_id, "academy": club_id}
		)
	)
	var move := {"from_club": other_club_id, "to_club": club_id, "fee": 2500, "wage": 640}
	events.append(CareerEvent.create(CareerEvent.TRANSFER, 10, 23, move))
	events.append(
		CareerEvent.create(CareerEvent.RENEWAL, 11, 24, {"club": club_id, "wage": 300, "years": 3})
	)
	for inducted: bool in [true, false]:
		var values := {"club": club_id, "peak_overall": 91, "score": 140, "inducted": inducted}
		events.append(CareerEvent.create(CareerEvent.RETIREMENT, 25, 38, values))
	events.append(CareerEvent.create(CareerEvent.NATIONAL_CALL_UP, 12, 24, {"nation": "valdoria"}))
	for won: bool in [true, false]:
		var run := {
			"cup": CupDefinition.CONTINENTAL, "team": club_id, "wins": 4 if won else 2, "won": won
		}
		events.append(CareerEvent.create(CareerEvent.CUP_RESULT, 12, 24, run))
	var cup := {"cup": CupDefinition.NATIONS, "team": "valdoria", "wins": 1, "won": false}
	events.append(CareerEvent.create(CareerEvent.CUP_RESULT, 12, 24, cup))
	for rank: int in [1, 2]:
		var ball := {"rank": rank, "winner": "Zephyr Calloway"}
		events.append(CareerEvent.create(CareerEvent.GOLDEN_BALL, 13, 25, ball))
	return events
