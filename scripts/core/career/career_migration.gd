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
	if _version(upgraded) == 2:
		_v2_to_v3(upgraded)
	if _version(upgraded) == 3:
		_v3_to_v4(upgraded)
	return upgraded


static func _version(data: Dictionary) -> int:
	var version: Variant = data.get("version")
	return int(version) if DataChecks.is_number(version) else -1


## Version 2 added clubs, contracts, fatigue, trials, retirement, transfers,
## training intensity and key-moment counts.
## Version 4 added cups and the Golden Ball (nothing to rebuild from history).
static func _v3_to_v4(data: Dictionary) -> void:
	data["version"] = 4
	data["cup_runs"] = []
	data["golden_balls"] = []


## Version 3 added the event log. Season events are rebuilt from history so
## older careers still have news; other events cannot be reconstructed.
static func _v2_to_v3(data: Dictionary) -> void:
	data["version"] = 3
	var events: Array[Dictionary] = []
	var history: Variant = data.get("history")
	if typeof(history) == TYPE_ARRAY:
		for entry: Variant in history:
			if typeof(entry) == TYPE_DICTIONARY:
				events.append(_season_event(entry))
	data["events"] = events


static func _season_event(season: Dictionary) -> Dictionary:
	var values := {
		"club": season.get("club_id", ""),
		"overall_before": season.get("overall_before", 0),
		"overall_after": season.get("overall_after", 0),
		"rating": season.get("average_rating", 0.0),
		"moments_won": season.get("key_moments_won", 0),
		"moments_played": season.get("key_moments_played", 0),
	}
	return {
		"type": CareerEvent.SEASON_PLAYED,
		"season_number": season.get("season_number", 0),
		"age": season.get("age", 0),
		"values": values,
	}


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
