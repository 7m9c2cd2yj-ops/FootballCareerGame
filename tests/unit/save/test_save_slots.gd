extends GutTest
## Local saves: one career per slot, current + backup, never lose a career.

const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")
const CareerFixture := preload("res://tests/helpers/career_fixture.gd")
const PreRun := preload("res://tests/helpers/pre_run.gd")
const ROOT := "user://test_saves_unit"

var _balance: Balance
var _world: ClubWorld
var _rules: CareerRules
var _slots: SaveSlots


func before_all() -> void:
	_balance = BalanceFixture.shipped()
	_world = CareerFixture.world()
	_rules = CareerFixture.rules(_world)


func before_each() -> void:
	PreRun.clear(ROOT)
	_slots = SaveSlots.new(ROOT)


func _career(age: int, seasons: int) -> CareerState:
	var career := CareerFixture.career_at("FWD", age, 60.0, "tidewell", _balance)
	for i: int in seasons:
		var record := SeasonRecord.new()
		record.season_number = i + 1
		record.club_id = "tidewell"
		career.history.append(record)
	return career


func _save(career: CareerState, now: int) -> String:
	var envelope := CareerSaves.envelope_for(
		career, _balance, _world, _slots.latest_revision(1), now
	)
	return _slots.write(1, envelope)


func _load() -> SaveSlots.Loaded:
	return _slots.load_slot(
		1, CareerSaves.migrator(_rules), CareerSaves.validator(_balance, _world)
	)


func _write_raw(kind: String, text: String) -> void:
	var file := FileAccess.open(_slots.path(1, kind), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_save_and_load_round_trip() -> void:
	var career := _career(20, 3)
	assert_eq(_save(career, 1000), "")
	var loaded := _load()
	assert_eq(loaded.source, SaveSlots.CURRENT)
	var restored := CareerState.from_dict(loaded.envelope.career)
	assert_eq(
		JSON.stringify(restored.to_dict()),
		JSON.stringify(
			CareerState.from_dict(JSON.parse_string(JSON.stringify(career.to_dict()))).to_dict()
		)
	)
	assert_eq(_slots.summary(1)["club"], "Tidewell FC")


func test_previous_save_becomes_the_backup() -> void:
	_save(_career(20, 3), 1000)
	_save(_career(21, 4), 2000)
	assert_true(FileAccess.file_exists(_slots.path(1, SaveSlots.BACKUP)))
	assert_false(FileAccess.file_exists(_slots.path(1, SaveSlots.TEMP)))
	assert_eq(_load().envelope.season_count(), 4)
	assert_eq(_slots.latest_revision(1), 2)


func test_damaged_save_falls_back_to_the_backup() -> void:
	_save(_career(20, 3), 1000)
	_save(_career(21, 4), 2000)
	_write_raw(SaveSlots.CURRENT, '{"format": 1, "revis')
	var loaded := _load()
	assert_eq(loaded.source, SaveSlots.BACKUP)
	assert_eq(loaded.envelope.season_count(), 3)
	assert_gt(loaded.errors.size(), 0, "the damage is reported")


func test_tampered_career_fails_the_checksum() -> void:
	_save(_career(20, 3), 1000)
	_save(_career(21, 4), 2000)
	var text := FileAccess.get_file_as_string(_slots.path(1, SaveSlots.CURRENT))
	_write_raw(SaveSlots.CURRENT, text.replace('"fatigue":0.0', '"fatigue":5.0'))
	assert_eq(_load().source, SaveSlots.BACKUP)


func test_interrupted_save_is_recovered_from_the_temp_file() -> void:
	_save(_career(20, 3), 1000)
	_save(_career(21, 4), 2000)
	# Simulate a crash after current -> backup but before temp -> current.
	var newer := CareerSaves.envelope_for(_career(22, 5), _balance, _world, 2, 3000)
	_write_raw(SaveSlots.TEMP, JSON.stringify(newer.to_dict(), "", true))
	DirAccess.remove_absolute(_slots.path(1, SaveSlots.BACKUP))
	DirAccess.rename_absolute(_slots.path(1, SaveSlots.CURRENT), _slots.path(1, SaveSlots.BACKUP))
	var loaded := _load()
	assert_eq(loaded.source, SaveSlots.TEMP)
	assert_eq(loaded.envelope.season_count(), 5)


func test_invalid_career_is_never_loaded() -> void:
	var career := _career(20, 3)
	career.club_id = "real_club_fc"
	_save(_career(20, 2), 1000)
	_save(career, 2000)
	var loaded := _load()
	assert_eq(loaded.source, SaveSlots.BACKUP, "the invalid newer save is skipped")


func test_older_save_formats_are_migrated_on_load() -> void:
	var data := _career(20, 0).to_dict()
	data["version"] = 3
	data.erase("cup_runs")
	data.erase("golden_balls")
	var envelope := SaveEnvelope.create(data, {}, 0, 1000)
	assert_eq(_slots.write(1, envelope), "")
	var loaded := _load()
	assert_not_null(loaded.envelope, "\n".join(loaded.errors))
	assert_eq(int(loaded.envelope.career["version"]), CareerState.FORMAT_VERSION)


func test_empty_and_deleted_slots() -> void:
	assert_false(_slots.has_save(1))
	assert_null(_load().envelope)
	_save(_career(20, 3), 1000)
	assert_true(_slots.has_save(1))
	assert_eq(_slots.delete(1), "")
	assert_false(_slots.has_save(1))
	assert_eq(_slots.summary(1), {})


func test_newer_means_further_along_then_later() -> void:
	var early := SaveEnvelope.create(_career(20, 3).to_dict(), {}, 0, 9000)
	var further := SaveEnvelope.create(_career(21, 4).to_dict(), {}, 0, 1000)
	assert_true(SaveSlots.is_newer(further, early), "more seasons beats a later clock")
	var later := SaveEnvelope.create(_career(20, 3).to_dict(), {}, 0, 9500)
	assert_true(SaveSlots.is_newer(later, early))
