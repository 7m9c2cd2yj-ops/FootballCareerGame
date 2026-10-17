class_name MomentSpec
extends RefCounted
## Everything needed to stage and resolve one key moment. Built by MomentPlanner;
## the scene displays it and the resolvers judge the player's input against it.

const PENALTY := "penalty"
const FREE_KICK := "free_kick"
const ONE_ON_ONE := "one_on_one"
const SAVE := "save"
const PENALTY_SAVE := "penalty_save"
const TYPES: Array[String] = [PENALTY, FREE_KICK, ONE_ON_ONE, SAVE, PENALTY_SAVE]

var moment_type: String = ""
## Position of this moment within its season, starting at 0.
var index: int = 0
## Attribute -> player skill 0..1 (attribute value / attribute max).
var skills: Dictionary[String, float] = {}
## Strength of the opposition 0..1 (their keeper or shooter).
var opponent_skill: float = 0.0
## Shooting distance from the goal line in metres.
var distance: float = 0.0
## Free kick: centre of the wall, in goal-plane x metres, and the keeper's start x.
var wall_center_x: float = 0.0
var keeper_x: float = 0.0
## Save moments: where the opponent's shot crosses the goal line, and its speed.
var shot_target: Vector2 = Vector2.ZERO
var shot_speed: float = 0.0


func skill(attribute: String) -> float:
	return skills.get(attribute, 0.0)


## True when the player is the goalkeeper in this moment.
func is_save() -> bool:
	return moment_type == SAVE or moment_type == PENALTY_SAVE
