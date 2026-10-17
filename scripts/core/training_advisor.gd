class_name TrainingAdvisor
extends RefCounted
## Suggests a training plan: the two attributes where focused training raises
## the overall rating most (position weight x remaining headroom).
## The player is free to ignore it; this only pre-selects the UI.


static func recommended_plan(player: PlayerModel, balance: Balance) -> TrainingPlan:
	var best := ""
	var second := ""
	for attribute: String in PlayerModel.ATTRIBUTES:
		var score := _score(player, attribute, balance)
		if best.is_empty() or score > _score(player, best, balance):
			second = best
			best = attribute
		elif second.is_empty() or score > _score(player, second, balance):
			second = attribute
	return TrainingPlan.create(best, second)


## Strict `>` above means equal scores keep the earlier attribute in ATTRIBUTES order.
static func _score(player: PlayerModel, attribute: String, balance: Balance) -> float:
	var room := Progression.headroom(player.attributes[attribute], balance)
	return balance.weight(player.position, attribute) * room
