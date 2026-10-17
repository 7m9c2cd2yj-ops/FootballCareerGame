class_name SaveSlots
extends RefCounted
## One career per slot, stored under `root` (user://saves in the game).
## Each slot keeps the current save and one backup:
##   slot_N.json        current
##   slot_N.backup.json the save before it
##   slot_N.tmp.json    only while writing
## Writing: write tmp, read it back and verify, remove old backup, move current
## to backup, move tmp to current. No step renames onto an existing file, and
## loading also considers a verified tmp, so an interrupted save never loses a
## career.

const CURRENT := "current"
const TEMP := "tmp"
const BACKUP := "backup"


## Result of loading a slot: the newest valid envelope and where it came from.
class Loaded:
	extends RefCounted
	var envelope: SaveEnvelope = null
	## CURRENT, TEMP or BACKUP.
	var source: String = ""
	var errors: Array[String] = []


var root: String = ""


func _init(save_root: String) -> void:
	root = save_root


func path(slot: int, kind: String) -> String:
	var suffix := ".json" if kind == CURRENT else ".%s.json" % kind
	return root.path_join("slot_%d%s" % [slot, suffix])


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(path(slot, CURRENT)) or FileAccess.file_exists(path(slot, BACKUP))


## Writes `envelope` safely; returns "" or a description of what went wrong.
func write(slot: int, envelope: SaveEnvelope) -> String:
	var error := DirAccess.make_dir_recursive_absolute(root)
	if error != OK:
		return "could not create %s (%s)" % [root, error_string(error)]
	var text := JSON.stringify(envelope.to_dict(), "", true)
	var temp := path(slot, TEMP)
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return "could not write %s (%s)" % [temp, error_string(FileAccess.get_open_error())]
	file.store_string(text)
	file.close()
	var check: Array[String] = []
	if SaveEnvelope.parse(FileAccess.get_file_as_string(temp), check) == null:
		return "written save failed verification: %s" % "; ".join(check)
	return _rotate(slot)


## The newest valid save in the slot. `validate` receives the career dictionary
## (already migrated by the caller's `migrate`) and returns problems.
func load_slot(slot: int, migrate: Callable, validate: Callable) -> Loaded:
	var result := Loaded.new()
	var candidates: Array[SaveEnvelope] = []
	var sources: Array[String] = []
	for kind: String in [CURRENT, TEMP, BACKUP]:
		var envelope := _read_valid(slot, kind, migrate, validate, result.errors)
		if envelope != null:
			candidates.append(envelope)
			sources.append(kind)
	for i: int in candidates.size():
		if result.envelope == null or is_newer(candidates[i], result.envelope):
			result.envelope = candidates[i]
			result.source = sources[i]
	return result


## Removes the slot's files; returns "" or what failed.
func delete(slot: int) -> String:
	for kind: String in [CURRENT, TEMP, BACKUP]:
		if FileAccess.file_exists(path(slot, kind)):
			var error := DirAccess.remove_absolute(path(slot, kind))
			if error != OK:
				return "could not delete %s (%s)" % [path(slot, kind), error_string(error)]
	return ""


## Summary of the slot's current save for the slot list, or {} if empty/damaged.
func summary(slot: int) -> Dictionary:
	for kind: String in [CURRENT, BACKUP]:
		if FileAccess.file_exists(path(slot, kind)):
			var errors: Array[String] = []
			var envelope := SaveEnvelope.parse(
				FileAccess.get_file_as_string(path(slot, kind)), errors
			)
			if envelope != null:
				return envelope.summary
	return {}


## The latest revision written to the slot (0 if empty), for the next save.
func latest_revision(slot: int) -> int:
	var latest := 0
	for kind: String in [CURRENT, TEMP, BACKUP]:
		if FileAccess.file_exists(path(slot, kind)):
			var errors: Array[String] = []
			var envelope := SaveEnvelope.parse(
				FileAccess.get_file_as_string(path(slot, kind)), errors
			)
			if envelope != null:
				latest = maxi(latest, envelope.revision)
	return latest


func _rotate(slot: int) -> String:
	var steps: Array[Array] = []
	if FileAccess.file_exists(path(slot, BACKUP)):
		steps.append(["remove", path(slot, BACKUP), ""])
	if FileAccess.file_exists(path(slot, CURRENT)):
		steps.append(["rename", path(slot, CURRENT), path(slot, BACKUP)])
	steps.append(["rename", path(slot, TEMP), path(slot, CURRENT)])
	for step: Array in steps:
		var error := OK
		if step[0] == "remove":
			error = DirAccess.remove_absolute(step[1])
		else:
			error = DirAccess.rename_absolute(step[1], step[2])
		if error != OK:
			return "could not %s %s (%s)" % [step[0], step[1], error_string(error)]
	return ""


func _read_valid(
	slot: int, kind: String, migrate: Callable, validate: Callable, errors: Array[String]
) -> SaveEnvelope:
	var file_path := path(slot, kind)
	if not FileAccess.file_exists(file_path):
		return null
	var problems: Array[String] = []
	var envelope := SaveEnvelope.parse(FileAccess.get_file_as_string(file_path), problems)
	if envelope != null:
		envelope.career = migrate.call(envelope.career)
		var invalid: Array[String] = validate.call(envelope.career)
		problems.append_array(invalid)
	if not problems.is_empty():
		errors.append("%s: %s" % [file_path, "; ".join(problems)])
		return null
	return envelope


## Further along wins; then the later save; then the higher revision.
static func is_newer(a: SaveEnvelope, b: SaveEnvelope) -> bool:
	if a.season_count() != b.season_count():
		return a.season_count() > b.season_count()
	if a.saved_at_unix != b.saved_at_unix:
		return a.saved_at_unix > b.saved_at_unix
	return a.revision > b.revision
