class_name CareerState
extends RefCounted
## One career: the player plus every completed season. This is what a save slot stores.

## Bump when the dictionary layout changes; M7 adds migrations between versions.
const FORMAT_VERSION := 1

var player: PlayerModel = null
var history: Array[SeasonRecord] = []


static func start(name: String, position: String, balance: Balance) -> CareerState:
	var career := CareerState.new()
	career.player = PlayerModel.create(name, position, balance)
	return career


## The next season to be played, starting at 1.
func next_season_number() -> int:
	return history.size() + 1


## No more seasons can be played once the player reaches the balance file's max age.
func is_finished(balance: Balance) -> bool:
	return player.age >= balance.max_age


func to_dict() -> Dictionary:
	var seasons: Array[Dictionary] = []
	for record: SeasonRecord in history:
		seasons.append(record.to_dict())
	return {"version": FORMAT_VERSION, "player": player.to_dict(), "history": seasons}


## Checks untrusted data (e.g. a save file) before `from_dict`.
static func validate_dict(data: Dictionary, balance: Balance) -> Array[String]:
	var problems: Array[String] = []
	var version: Variant = data.get("version")
	var is_number := typeof(version) == TYPE_INT or typeof(version) == TYPE_FLOAT
	if not is_number or not is_equal_approx(float(version), FORMAT_VERSION):
		problems.append("Unsupported career version %s" % str(version))
		return problems
	if typeof(data.get("player")) != TYPE_DICTIONARY:
		problems.append("career.player must be an object")
	else:
		problems.append_array(PlayerModel.validate_dict(data["player"], balance))
	if typeof(data.get("history")) != TYPE_ARRAY:
		problems.append("career.history must be an array")
		return problems
	for entry: Variant in data["history"]:
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("career.history entries must be objects")
			return problems
		problems.append_array(SeasonRecord.validate_dict(entry))
	return problems


## Builds a career from data that passed `validate_dict`.
static func from_dict(data: Dictionary) -> CareerState:
	var career := CareerState.new()
	career.player = PlayerModel.from_dict(data["player"])
	for entry: Dictionary in data["history"]:
		career.history.append(SeasonRecord.from_dict(entry))
	return career
