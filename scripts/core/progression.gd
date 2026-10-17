class_name Progression
extends RefCounted
## The deterministic season growth formula. Same inputs always give the same output.
##
## For each attribute, per season:
##   growth phase (age base_gain >= 0):
##     change = (base_gain * focus * intensity * training_share
##               + performance_bonus * used) * headroom
##   decline phase (age base_gain < 0):
##     change = base_gain * decline_weight * (1 - protection)
##              + performance_bonus * used * headroom
## where
##   focus            = training multiplier (primary / secondary / other)
##   intensity        = training intensity multiplier (light / normal / intense)
##   training_share   = share of training done (below 1 when injured)
##   protection       = training decline protection (primary / secondary / none)
##   headroom         = max(floor, ((max - value) / (max - min)) ^ exponent)
##   performance_bonus = max(0, rating - baseline) * gain_per_point * matches / season_matches
##   used             = 1 if the player's position weights the attribute above 0, else 0
##                      (matches only develop the attributes the position uses)


## Fraction of normal growth left for an attribute at `value`; shrinks towards the cap.
static func headroom(value: float, balance: Balance) -> float:
	var span := balance.attribute_max - balance.attribute_min
	var remaining := clampf((balance.attribute_max - value) / span, 0.0, 1.0)
	return maxf(balance.headroom_floor, pow(remaining, balance.headroom_exponent))


## Bonus growth points earned from playing well; never negative.
static func performance_bonus(
	performance: SeasonPerformance, season_matches: int, balance: Balance
) -> float:
	var above_baseline := maxf(0.0, performance.average_rating - balance.performance_baseline)
	var participation := clampf(float(performance.matches_played) / maxf(season_matches, 1), 0, 1)
	return above_baseline * balance.performance_gain_per_point * participation


## Attribute -> change for one season. Does not modify `player`.
static func season_changes(
	player: PlayerModel, plan: TrainingPlan, performance: SeasonPerformance, balance: Balance
) -> Dictionary[String, float]:
	var base_gain := balance.base_gain_for_age(player.age)
	var intensity: float = balance.intensity[plan.intensity] * performance.training_share
	var bonus := performance_bonus(performance, balance.matches_for_age(player.age), balance)
	var changes: Dictionary[String, float] = {}
	for attribute: String in PlayerModel.ATTRIBUTES:
		var room := headroom(player.attributes[attribute], balance)
		var used := 1.0 if balance.weight(player.position, attribute) > 0.0 else 0.0
		var age_change := 0.0
		if base_gain >= 0.0:
			age_change = base_gain * _focus_multiplier(plan, attribute, balance) * intensity * room
		else:
			var protection := _decline_protection(plan, attribute, balance)
			age_change = base_gain * balance.decline_weights[attribute] * (1.0 - protection)
		changes[attribute] = age_change + bonus * used * room
	return changes


## Rounds to 2 decimals via the decimal text, giving the double nearest to that
## decimal. snappedf alone can land 1 ulp off (1.6500000000000001), which JSON
## writes as "1.65" and reads back as a different number, so a reloaded save
## would drift from the original. Every stored float goes through this.
static func round_value(value: float) -> float:
	return ("%.2f" % value).to_float()


## Applies `changes` to `player`, clamped to the attribute range and rounded with round_value.
static func apply_changes(
	player: PlayerModel, changes: Dictionary[String, float], balance: Balance
) -> void:
	for attribute: String in PlayerModel.ATTRIBUTES:
		var change: float = changes.get(attribute, 0.0)
		var value := player.attributes[attribute] + change
		value = clampf(value, balance.attribute_min, balance.attribute_max)
		player.attributes[attribute] = round_value(value)


static func _focus_multiplier(plan: TrainingPlan, attribute: String, balance: Balance) -> float:
	if attribute == plan.primary:
		return balance.training["primary_multiplier"]
	if attribute == plan.secondary:
		return balance.training["secondary_multiplier"]
	return balance.training["other_multiplier"]


static func _decline_protection(plan: TrainingPlan, attribute: String, balance: Balance) -> float:
	if attribute == plan.primary:
		return balance.training["primary_decline_protection"]
	if attribute == plan.secondary:
		return balance.training["secondary_decline_protection"]
	return 0.0
