extends RefCounted
## Builds moment specs with chosen skills for resolver tests.


static func tuning() -> MomentTuning:
	var errors: Array[String] = []
	var loaded := MomentTuning.load_file(MomentTuning.DEFAULT_PATH, errors)
	assert(loaded != null, "\n".join(errors))
	return loaded


## A spec of `moment_type` where every player skill is `skill` and the opponent is `opponent`.
static func spec(moment_type: String, skill: float, opponent: float) -> MomentSpec:
	var tuned := tuning()
	var built := MomentSpec.new()
	built.moment_type = moment_type
	built.opponent_skill = opponent
	for attribute: String in PlayerModel.ATTRIBUTES:
		built.skills[attribute] = skill
	match moment_type:
		MomentSpec.PENALTY:
			built.distance = tuned.value("penalty", "distance")
		MomentSpec.FREE_KICK:
			built.distance = 22.0
			built.wall_center_x = 0.0
			built.keeper_x = 0.0
		MomentSpec.ONE_ON_ONE:
			built.distance = tuned.value("one_on_one", "start_distance")
		MomentSpec.SAVE, MomentSpec.PENALTY_SAVE:
			built.distance = 18.0
			built.shot_speed = tuned.value("save", "open_play_speed")
			built.shot_target = Vector2(2.5, 1.5)
	return built
