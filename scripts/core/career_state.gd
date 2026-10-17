class_name CareerState
extends RefCounted
## One career: the player, their club and contract, fatigue, every completed
## season and every transfer. This is what a save slot stores.

## Bump when the dictionary layout changes and add a step to CareerMigration.
const FORMAT_VERSION := 2

var player: PlayerModel = null
var history: Array[SeasonRecord] = []
## Club the player belongs to: the academy club until a first contract.
var club_id: String = ""
## Null before the first contract (academy years).
var contract: Contract = null
## Built up by training and matches; see Fatigue.
var fatigue: float = 0.0
## True when last season's fatigue caused an injury that affects the next season.
var injured_next_season: bool = false
## The one trial a career gets at the trial age.
var trial_used: bool = false
var retired: bool = false
var transfers: Array[TransferRecord] = []


static func start(
	name: String, position: String, balance: Balance, academy_club: String = ""
) -> CareerState:
	var career := CareerState.new()
	career.player = PlayerModel.create(name, position, balance)
	career.club_id = academy_club
	return career


## The next season to be played, starting at 1.
func next_season_number() -> int:
	return history.size() + 1


## No more seasons once retired or at the balance file's max age.
func is_finished(balance: Balance) -> bool:
	return retired or player.age >= balance.max_age


func has_active_contract() -> bool:
	return contract != null and not contract.has_expired()


func to_dict() -> Dictionary:
	var seasons: Array[Dictionary] = []
	for record: SeasonRecord in history:
		seasons.append(record.to_dict())
	var contract_data: Variant = null
	if contract != null:
		contract_data = contract.to_dict()
	var moves: Array[Dictionary] = []
	for transfer: TransferRecord in transfers:
		moves.append(transfer.to_dict())
	return {
		"version": FORMAT_VERSION,
		"player": player.to_dict(),
		"history": seasons,
		"club_id": club_id,
		"contract": contract_data,
		"fatigue": fatigue,
		"injured_next_season": injured_next_season,
		"trial_used": trial_used,
		"retired": retired,
		"transfers": moves,
	}


## Checks untrusted data (e.g. a save file) before `from_dict`. Older versions
## must go through CareerMigration first.
static func validate_dict(data: Dictionary, balance: Balance, world: ClubWorld) -> Array[String]:
	var problems: Array[String] = []
	var version: Variant = data.get("version")
	if not DataChecks.is_number(version) or not is_equal_approx(float(version), FORMAT_VERSION):
		problems.append("Unsupported career version %s" % str(version))
		return problems
	if typeof(data.get("player")) != TYPE_DICTIONARY:
		problems.append("career.player must be an object")
	else:
		problems.append_array(PlayerModel.validate_dict(data["player"], balance))
	_validate_list(data.get("history"), "history", problems, SeasonRecord.validate_dict)
	_validate_list(data.get("transfers"), "transfers", problems, TransferRecord.validate_dict)
	if typeof(data.get("club_id")) != TYPE_STRING or not world.has_club(str(data.get("club_id"))):
		problems.append("career.club_id is not a known club")
	if typeof(data.get("contract")) == TYPE_DICTIONARY:
		problems.append_array(Contract.validate_dict(data["contract"], world))
	elif data.get("contract") != null:
		problems.append("career.contract must be an object or null")
	if not DataChecks.is_number(data.get("fatigue")):
		problems.append("career.fatigue must be a number")
	for key: String in ["injured_next_season", "trial_used", "retired"]:
		if typeof(data.get(key)) != TYPE_BOOL:
			problems.append("career.%s must be true or false" % key)
	return problems


## Builds a career from data that passed `validate_dict`.
static func from_dict(data: Dictionary) -> CareerState:
	var career := CareerState.new()
	career.player = PlayerModel.from_dict(data["player"])
	for entry: Dictionary in data["history"]:
		career.history.append(SeasonRecord.from_dict(entry))
	for entry: Dictionary in data["transfers"]:
		career.transfers.append(TransferRecord.from_dict(entry))
	career.club_id = data["club_id"]
	if data["contract"] != null:
		career.contract = Contract.from_dict(data["contract"])
	career.fatigue = float(data["fatigue"])
	career.injured_next_season = data["injured_next_season"]
	career.trial_used = data["trial_used"]
	career.retired = data["retired"]
	return career


## `check` validates one entry and returns its problems.
static func _validate_list(
	entries: Variant, label: String, problems: Array[String], check: Callable
) -> void:
	if typeof(entries) != TYPE_ARRAY:
		problems.append("career.%s must be an array" % label)
		return
	for entry: Variant in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("career.%s entries must be objects" % label)
			return
		var found: Array[String] = check.call(entry)
		problems.append_array(found)
