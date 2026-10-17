extends Node
## Autoload "Backend": talks to Supabase for sync, rankings, the ARENA and
## account deletion. Everything is optional: without config or internet the
## game stays fully playable and these calls return a message instead.
## Requests are built (and unit-tested) in SupabaseRequests; decisions about
## saves come from SyncPolicy and SaveSlots.

## Folder for the session and profile files; tools/test_online.sh points it
## elsewhere so tests never touch a player's real online identity.
const STATE_DIR_ENV := "KL_ONLINE_STATE_DIR"
const TIMEOUT_SECONDS := 15.0
const NOT_CONFIGURED := "Online features are not set up in this build."


## Result of one HTTP call: `code` 0 means no response (offline/timeout).
class Response:
	extends RefCounted
	var code: int = 0
	var body: String = ""

	func ok() -> bool:
		return code >= 200 and code < 300


var config: BackendConfig = null
var session: AuthSession = null
## Chosen preset display name and server (also stored on the server profile).
var display_name: String = ""
var server_id: String = ""
var preset_names: Array[String] = []
var servers: Array[Dictionary] = []
## Syncs run one at a time; background requests made meanwhile wait here.
var _syncing: bool = false
var _session_path: String = ""
var _profile_path: String = ""
var _pending_slots: Dictionary[int, bool] = {}


func _ready() -> void:
	var state_dir := OS.get_environment(STATE_DIR_ENV)
	state_dir = state_dir if not state_dir.is_empty() else "user://"
	DirAccess.make_dir_recursive_absolute(state_dir)
	_session_path = state_dir.path_join("online_session.json")
	_profile_path = state_dir.path_join("online_profile.json")
	config = BackendConfig.load_file(BackendConfig.path())
	_load_presets()
	var stored := _read_json(_session_path)
	if not stored.is_empty():
		session = AuthSession.from_dict(stored)
	var profile := _read_json(_profile_path)
	display_name = str(profile.get("display_name", preset_names[0]))
	server_id = str(profile.get("server_id", servers[0]["id"]))


func is_configured() -> bool:
	return config != null


## Picks a preset display name and server; saved locally and on the server.
func choose_identity(name_choice: String, server_choice: String) -> String:
	if not remember_identity(name_choice, server_choice):
		return "Pick one of the preset names."
	if not await _signed_in():
		return _offline_message()
	var request := SupabaseRequests.save_profile(config, session, display_name, server_id)
	return "Profile saved." if (await _send(request)).ok() else "Could not save your profile."


## Stores a preset name and server on this device only; the server profile
## is updated with the next online action. False if the choice is not allowed.
func remember_identity(name_choice: String, server_choice: String) -> bool:
	var known_server := servers.any(
		func(server: Dictionary) -> bool: return server["id"] == server_choice
	)
	if not preset_names.has(name_choice) or not known_server:
		return false
	display_name = name_choice
	server_id = server_choice
	_write_json(_profile_path, {"display_name": display_name, "server_id": server_id})
	return true


func is_syncing() -> bool:
	return _syncing or not _pending_slots.is_empty()


## Syncs one save slot both ways; returns what happened. Waits for any sync
## already running, so two syncs never touch a slot at the same time.
func sync_slot(slot: int, saves: SaveSlots, migrate: Callable, validate: Callable) -> String:
	while _syncing:
		await get_tree().process_frame
	_syncing = true
	var result := await _sync_now(slot, saves, migrate, validate)
	_syncing = false
	return result


func _sync_now(slot: int, saves: SaveSlots, migrate: Callable, validate: Callable) -> String:
	if not await _ready_online():
		return _offline_message()
	var local := saves.load_slot(slot, migrate, validate).envelope
	var remote_response := await _send(SupabaseRequests.get_career(config, session, slot))
	if not remote_response.ok():
		return "Could not reach your online saves."
	var remote := _remote_envelope(remote_response.body, migrate, validate)
	match SyncPolicy.decide(local, remote):
		SyncPolicy.UPLOAD:
			var upload := await _send(SupabaseRequests.upload_career(config, session, slot, local))
			return (
				"Slot %d uploaded." % slot
				if upload.ok()
				else "Upload failed; your save is safe on this device."
			)
		SyncPolicy.DOWNLOAD:
			# Writing keeps the local save as the slot's backup.
			var error := saves.write(slot, remote)
			return "Slot %d updated from your online save." % slot if error.is_empty() else error
	return "Slot %d is up to date." % slot


## Fire-and-forget after an autosave: sync the slot and, if it was uploaded,
## refresh its ranking. Failures are silent: the save is safe locally and the
## next sync tries again.
func background_sync(slot: int, saves: SaveSlots, migrate: Callable, validate: Callable) -> void:
	if not is_configured():
		return
	if _pending_slots.has(slot):
		return  # Already queued or running; the next autosave syncs again.
	_pending_slots[slot] = true
	var result := await sync_slot(slot, saves, migrate, validate)
	if result.contains("uploaded"):
		await submit_ranking(slot)
	_pending_slots.erase(slot)


## Asks the server to check the slot's uploaded career and rank it.
func submit_ranking(slot: int) -> String:
	if not await _ready_online():
		return _offline_message()
	var response := await _send(SupabaseRequests.submit_ranking(config, session, slot))
	if response.ok():
		return "Ranking updated."
	if response.code == 422:
		return "Ranking not accepted: the server could not verify this career."
	if response.code == HTTPClient.RESPONSE_NOT_FOUND:
		return "Ranking not accepted yet: sync this slot first."
	return "Could not reach the rankings right now."


## Rows for the ARENA: `everyone` false = your server, true = global.
func rankings(everyone: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not await _ready_online():
		return rows
	var request := SupabaseRequests.arena(config, session, server_id)
	if everyone:
		request = SupabaseRequests.global_rankings(config, session)
	var response := await _send(request)
	if response.ok():
		var parsed: Variant = JSON.parse_string(response.body)
		if typeof(parsed) == TYPE_ARRAY:
			for row: Variant in parsed:
				if typeof(row) == TYPE_DICTIONARY:
					rows.append(row)
	return rows


## Deletes the online account and all its data (store requirement). Local
## saves stay unless the player deletes them too.
func delete_account() -> String:
	if not await _ready_online():
		return _offline_message()
	var response := await _send(SupabaseRequests.delete_account(config, session))
	if not response.ok():
		return "Could not delete your account right now. Please try again."
	_forget_session()
	return "Your online account and data are deleted."


## Signed in with a profile on the server. A stored session the server no
## longer accepts (401: revoked, or the account was removed) is dropped and
## replaced by a fresh sign-in once.
func _ready_online() -> bool:
	for attempt: int in 2:
		if not await _signed_in():
			return false
		var request := SupabaseRequests.save_profile(config, session, display_name, server_id)
		var profile := await _send(request)
		if profile.code != HTTPClient.RESPONSE_UNAUTHORIZED:
			return profile.ok()
		_forget_session()
	return false


func _forget_session() -> void:
	session = null
	if FileAccess.file_exists(_session_path):
		DirAccess.remove_absolute(_session_path)


## Signs in anonymously on first use and refreshes expired sessions.
func _signed_in() -> bool:
	if config == null:
		return false
	var now := int(Time.get_unix_time_from_system())
	if session != null and not session.is_expired(now):
		return true
	var request := SupabaseRequests.sign_up_anonymously(config)
	if session != null and not session.refresh_token.is_empty():
		request = SupabaseRequests.refresh(config, session.refresh_token)
	var response := await _send(request)
	session = AuthSession.from_response(response.body, now) if response.ok() else null
	if session != null:
		_write_json(_session_path, session.to_dict())
	return session != null


func _send(request: SupabaseRequests.Request) -> Response:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SECONDS
	add_child(http)
	var result := Response.new()
	if http.request(request.url, request.headers, request.method, request.body) == OK:
		var reply: Array = await http.request_completed
		if int(reply[0]) == HTTPRequest.RESULT_SUCCESS:
			result.code = int(reply[1])
			var bytes: PackedByteArray = reply[3]
			result.body = bytes.get_string_from_utf8()
	http.queue_free()
	return result


func _remote_envelope(body: String, migrate: Callable, validate: Callable) -> SaveEnvelope:
	var parsed: Variant = JSON.parse_string(body)
	if typeof(parsed) != TYPE_ARRAY:
		return null
	var rows: Array = parsed
	if rows.is_empty() or typeof(rows[0]) != TYPE_DICTIONARY:
		return null
	var row: Dictionary = rows[0]
	var errors: Array[String] = []
	var envelope := SaveEnvelope.parse(JSON.stringify(row.get("envelope")), errors)
	if envelope == null:
		return null
	envelope.career = migrate.call(envelope.career)
	var problems: Array[String] = validate.call(envelope.career)
	return envelope if problems.is_empty() else null


func _offline_message() -> String:
	return (
		NOT_CONFIGURED if config == null else "You're offline. Your career is safe on this device."
	)


func _load_presets() -> void:
	preset_names.assign(JsonLoader.load_dictionary("res://data/preset_names.json").data["names"])
	var online := JsonLoader.load_dictionary("res://data/online.json").data
	servers.assign(online["servers"])


static func _read_json(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var loaded := JsonLoader.load_dictionary(file_path)
	return loaded.data if loaded.is_ok() else {}


static func _write_json(file_path: String, data: Dictionary) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()
