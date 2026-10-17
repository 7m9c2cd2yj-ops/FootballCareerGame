class_name TrainingPlan
extends RefCounted
## The player's training choice for one season: a primary and a secondary
## focus, and an intensity. Harder training grows attributes faster but builds
## fatigue, which can cause an injury (see Fatigue).

const LIGHT := "light"
const NORMAL := "normal"
const INTENSE := "intense"
const INTENSITIES: Array[String] = [LIGHT, NORMAL, INTENSE]

var primary: String = ""
var secondary: String = ""
var intensity: String = NORMAL


static func create(
	primary_focus: String, secondary_focus: String, training_intensity: String = NORMAL
) -> TrainingPlan:
	var plan := TrainingPlan.new()
	plan.primary = primary_focus
	plan.secondary = secondary_focus
	plan.intensity = training_intensity
	return plan


## Both foci must be known attributes and must differ; the intensity must be known.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if not PlayerModel.ATTRIBUTES.has(primary):
		problems.append("Unknown primary focus '%s'" % primary)
	if not PlayerModel.ATTRIBUTES.has(secondary):
		problems.append("Unknown secondary focus '%s'" % secondary)
	if primary == secondary:
		problems.append("Primary and secondary focus must differ")
	if not INTENSITIES.has(intensity):
		problems.append("Unknown training intensity '%s'" % intensity)
	return problems
