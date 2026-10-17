class_name ClubNeed
extends RefCounted
## One stated need of a club: a position, a minimum overall and an optional age limit.

## 0 means "any age".
const NO_AGE_LIMIT := 0

var position: String = ""
var min_rating: float = 0.0
var max_age: int = NO_AGE_LIMIT


static func from_dict(data: Dictionary) -> ClubNeed:
	var need := ClubNeed.new()
	need.position = data["position"]
	need.min_rating = float(data["min_rating"])
	need.max_age = int(data.get("max_age", NO_AGE_LIMIT))
	return need


func accepts(position_code: String, overall: int, age: int) -> bool:
	if position_code != position or overall < min_rating:
		return false
	return max_age == NO_AGE_LIMIT or age <= max_age


## Short text for the Clubs app, e.g. "FWD 75+ (age ≤ 30)".
func describe() -> String:
	var text := "%s %d+" % [position, roundi(min_rating)]
	if max_age != NO_AGE_LIMIT:
		text += " (age ≤ %d)" % max_age
	return text
