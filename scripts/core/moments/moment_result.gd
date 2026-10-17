class_name MomentResult
extends RefCounted
## Outcome of one key moment, plus the points the scene animates the ball and keeper to.

const GOAL := "goal"
const SAVED := "saved"
const MISSED := "missed"
const BLOCKED := "blocked"
const CONCEDED := "conceded"

var moment_type: String = ""
var outcome: String = ""
## True when the outcome is good for the player (a goal, or a save as goalkeeper).
var success: bool = false
## How clean the success was, 0..1 (0 for failures).
var quality: float = 0.0
## Goal-plane points: where the ball ends and where the keeper ends.
var ball_target: Vector2 = Vector2.ZERO
var keeper_target: Vector2 = Vector2.ZERO


static func create(
	spec: MomentSpec, result_outcome: String, result_quality: float, ball: Vector2, keeper: Vector2
) -> MomentResult:
	var result := MomentResult.new()
	result.moment_type = spec.moment_type
	result.outcome = result_outcome
	if spec.is_save():
		result.success = result_outcome == SAVED
	else:
		result.success = result_outcome == GOAL
	result.quality = clampf(result_quality, 0.0, 1.0) if result.success else 0.0
	result.ball_target = ball
	result.keeper_target = keeper
	return result


## Contribution to the season's average match rating, before weighting.
func rating_delta(tuning: MomentTuning) -> float:
	if not success:
		return tuning.value("rating", "failure")
	return tuning.by_skill("rating", "success_min", "success_max", quality)
