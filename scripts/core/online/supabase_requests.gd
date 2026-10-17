class_name SupabaseRequests
extends RefCounted
## Builds the HTTP requests the game sends to Supabase (Auth, PostgREST, Edge
## Functions). Pure: no networking here, so every request is unit-tested.
## Endpoint shapes follow @supabase/auth-js and postgrest-js 2.118.


class Request:
	extends RefCounted
	var method: int = HTTPClient.METHOD_GET
	var url: String = ""
	var headers: PackedStringArray = PackedStringArray()
	var body: String = ""


static func sign_up_anonymously(config: BackendConfig) -> Request:
	return _build(config, "", HTTPClient.METHOD_POST, "/auth/v1/signup", {"data": {}})


static func refresh(config: BackendConfig, refresh_token: String) -> Request:
	var path := "/auth/v1/token?grant_type=refresh_token"
	return _build(config, "", HTTPClient.METHOD_POST, path, {"refresh_token": refresh_token})


static func get_profile(config: BackendConfig, session: AuthSession) -> Request:
	var path := "/rest/v1/profiles?select=display_name,server_id&id=eq.%s" % _q(session.user_id)
	return _build(config, session.access_token, HTTPClient.METHOD_GET, path, null)


static func save_profile(
	config: BackendConfig, session: AuthSession, display_name: String, server_id: String
) -> Request:
	var row := {"id": session.user_id, "display_name": display_name, "server_id": server_id}
	return _upsert(config, session, "profiles", "id", row)


static func get_career(config: BackendConfig, session: AuthSession, slot: int) -> Request:
	var path := "/rest/v1/careers?select=envelope&slot=eq.%d" % slot
	return _build(config, session.access_token, HTTPClient.METHOD_GET, path, null)


static func upload_career(
	config: BackendConfig, session: AuthSession, slot: int, envelope: SaveEnvelope
) -> Request:
	var row := {
		"owner": session.user_id,
		"slot": slot,
		"revision": envelope.revision,
		"saved_at": Time.get_datetime_string_from_unix_time(envelope.saved_at_unix) + "Z",
		"season_count": envelope.season_count(),
		"envelope": envelope.to_dict(),
	}
	return _upsert(config, session, "careers", "owner,slot", row)


static func submit_ranking(config: BackendConfig, session: AuthSession, slot: int) -> Request:
	var path := "/functions/v1/submit-ranking"
	return _build(config, session.access_token, HTTPClient.METHOD_POST, path, {"slot": slot})


## Best career of each player on `server_id`, best first.
static func arena(config: BackendConfig, session: AuthSession, server_id: String) -> Request:
	var path := (
		"/rest/v1/arena_entries?select=display_name,position,peak_overall,seasons,trophies,"
		+ (
			"golden_balls,hof_score,inducted,retired&server_id=eq.%s&order=hof_score.desc&limit=50"
			% _q(server_id)
		)
	)
	return _build(config, session.access_token, HTTPClient.METHOD_GET, path, null)


## All-time best careers anywhere.
static func global_rankings(config: BackendConfig, session: AuthSession) -> Request:
	var path := (
		"/rest/v1/arena_entries?select=display_name,position,peak_overall,seasons,trophies,"
		+ "golden_balls,hof_score,inducted,retired&order=hof_score.desc&limit=100"
	)
	return _build(config, session.access_token, HTTPClient.METHOD_GET, path, null)


static func delete_account(config: BackendConfig, session: AuthSession) -> Request:
	var path := "/rest/v1/rpc/delete_my_account"
	return _build(config, session.access_token, HTTPClient.METHOD_POST, path, {})


static func _upsert(
	config: BackendConfig, session: AuthSession, table: String, conflict: String, row: Dictionary
) -> Request:
	var path := "/rest/v1/%s?on_conflict=%s" % [table, conflict]
	var request := _build(config, session.access_token, HTTPClient.METHOD_POST, path, row)
	request.headers.append("Prefer: resolution=merge-duplicates,return=minimal")
	return request


## `token` empty means "not signed in yet" (the anon key is used as bearer).
static func _build(
	config: BackendConfig, token: String, method: int, path: String, payload: Variant
) -> Request:
	var request := Request.new()
	request.method = method
	request.url = config.url + path
	var bearer := token if not token.is_empty() else config.anon_key
	request.headers = PackedStringArray(
		[
			"apikey: " + config.anon_key,
			"Authorization: Bearer " + bearer,
			"Content-Type: application/json",
		]
	)
	if payload != null:
		request.body = JSON.stringify(payload)
	return request


static func _q(value: String) -> String:
	return value.uri_encode()
