class_name CareerMigration
extends RefCounted
## Upgrades saved career dictionaries from older format versions to
## CareerState.FORMAT_VERSION, one version at a time. Never loses data.


## Returns an upgraded deep copy, or the copy unchanged if already current.
## Unknown or future versions are returned unchanged for validate_dict to reject.
static func migrate(data: Dictionary, academy_club: String) -> Dictionary:
	var upgraded := data.duplicate(true)
	if _version(upgraded) == 1:
		_v1_to_v2(upgraded, academy_club)
	return upgraded


static func _version(data: Dictionary) -> int:
	var version: Variant = data.get("version")
	return int(version) if DataChecks.is_number(version) else -1


## Version 2 added clubs, contracts, fatigue, trials, retirement, transfers,
## training intensity and key-moment counts.
static func _v1_to_v2(data: Dictionary, academy_club: String) -> void:
	data["version"] = 2
	data["club_id"] = academy_club
	data["contract"] = null
	data["fatigue"] = 0.0
	data["injured_next_season"] = false
	data["trial_used"] = false
	data["retired"] = false
	data["transfers"] = []
	var history: Variant = data.get("history")
	if typeof(history) != TYPE_ARRAY:
		return
	for entry: Variant in history:
		if typeof(entry) == TYPE_DICTIONARY:
			var season: Dictionary = entry
			(
				season
				. merge(
					{
						"club_id": academy_club,
						"intensity": TrainingPlan.NORMAL,
						"injured": false,
						"fatigue_after": 0.0,
						"key_moments_played": 0,
						"key_moments_won": 0,
					}
				)
			)
