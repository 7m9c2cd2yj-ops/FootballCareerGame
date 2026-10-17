class_name SaveEnvelope
extends RefCounted
## What is written to disk (and to the backend) for one career: the career
## dictionary plus metadata to list slots, detect corruption and resolve sync
## conflicts.

const FORMAT := 1

## Bumped on every save of this slot; helps sync spot divergent histories.
var revision: int = 0
var saved_at_unix: int = 0
## Short summary for the slot list (no need to validate the whole career).
var summary: Dictionary = {}
var career: Dictionary = {}
## SHA-256 of the career JSON; a mismatch means the file is damaged.
var checksum: String = ""


static func create(
	career_data: Dictionary, summary_data: Dictionary, previous_revision: int, now_unix: int
) -> SaveEnvelope:
	var envelope := SaveEnvelope.new()
	envelope.revision = previous_revision + 1
	envelope.saved_at_unix = now_unix
	envelope.summary = summary_data
	# Store the career exactly as it reads back from JSON (numbers become
	# floats), so the checksum matches when the file is loaded again.
	var stored: Dictionary = JSON.parse_string(JSON.stringify(career_data, "", true))
	envelope.career = stored
	envelope.checksum = career_checksum(stored)
	return envelope


## Seasons played; the main "how far along" measure for conflicts.
func season_count() -> int:
	if typeof(career.get("history")) != TYPE_ARRAY:
		return 0
	var history: Array = career["history"]
	return history.size()


static func career_checksum(career_data: Dictionary) -> String:
	return JSON.stringify(career_data, "", true).sha256_text()


func to_dict() -> Dictionary:
	return {
		"format": FORMAT,
		"revision": revision,
		"saved_at_unix": saved_at_unix,
		"summary": summary,
		"career": career,
		"checksum": checksum,
	}


## Parses `text`; returns null and appends to `errors` if it is not an intact save.
static func parse(text: String, errors: Array[String]) -> SaveEnvelope:
	var loaded := JsonLoader.parse_dictionary(text, "save")
	if not loaded.is_ok():
		errors.append(loaded.error)
		return null
	var data := loaded.data
	if not DataChecks.is_number(data.get("format")) or int(data["format"]) != FORMAT:
		errors.append("save: unsupported envelope format")
		return null
	for key: String in ["revision", "saved_at_unix"]:
		if not DataChecks.is_number(data.get(key)):
			errors.append("save: %s must be a number" % key)
			return null
	if (
		typeof(data.get("career")) != TYPE_DICTIONARY
		or typeof(data.get("summary")) != TYPE_DICTIONARY
	):
		errors.append("save: career and summary must be objects")
		return null
	if typeof(data.get("checksum")) != TYPE_STRING:
		errors.append("save: checksum missing")
		return null
	var envelope := SaveEnvelope.new()
	envelope.revision = int(data["revision"])
	envelope.saved_at_unix = int(data["saved_at_unix"])
	envelope.summary = data["summary"]
	envelope.career = data["career"]
	envelope.checksum = data["checksum"]
	if career_checksum(envelope.career) != envelope.checksum:
		errors.append("save: checksum mismatch (file damaged)")
		return null
	return envelope
