class_name TrainingPlan
extends RefCounted
## The player's training choice for one season: a primary and a secondary focus.

var primary: String = ""
var secondary: String = ""


static func create(primary_focus: String, secondary_focus: String) -> TrainingPlan:
	var plan := TrainingPlan.new()
	plan.primary = primary_focus
	plan.secondary = secondary_focus
	return plan


## Both foci must be known attributes and must differ.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if not PlayerModel.ATTRIBUTES.has(primary):
		problems.append("Unknown primary focus '%s'" % primary)
	if not PlayerModel.ATTRIBUTES.has(secondary):
		problems.append("Unknown secondary focus '%s'" % secondary)
	if primary == secondary:
		problems.append("Primary and secondary focus must differ")
	return problems
