extends GutTest
## Pure online pieces: config, session parsing, request shapes, sync decisions.

const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")
const CareerFixture := preload("res://tests/helpers/career_fixture.gd")


func _config() -> BackendConfig:
	return BackendConfig.from_dictionary({"url": "https://abc.supabase.co/", "anon_key": "anon"})


func _session() -> AuthSession:
	var session := AuthSession.new()
	session.access_token = "user-token"
	session.user_id = "11111111-2222-3333-4444-555555555555"
	return session


func _envelope(seasons: int, saved_at: int) -> SaveEnvelope:
	var balance := BalanceFixture.shipped()
	var career := CareerFixture.career_at("FWD", 8 + seasons, 50.0, "tidewell", balance)
	for i: int in seasons:
		career.history.append(SeasonRecord.new())
	return SaveEnvelope.create(career.to_dict(), {}, 0, saved_at)


func test_missing_or_incomplete_config_means_offline() -> void:
	assert_null(BackendConfig.load_file("res://config/does_not_exist.json"))
	assert_null(BackendConfig.from_dictionary({"url": "", "anon_key": "x"}))
	assert_null(BackendConfig.from_dictionary({"url": "ftp://x", "anon_key": "x"}))
	assert_eq(_config().url, "https://abc.supabase.co", "trailing slash removed")


func test_session_parsing_and_expiry() -> void:
	var text := JSON.stringify(
		{"access_token": "a", "refresh_token": "r", "expires_in": 3600, "user": {"id": "u1"}}
	)
	var session := AuthSession.from_response(text, 1000)
	assert_eq(session.user_id, "u1")
	assert_eq(session.expires_at_unix, 4600)
	assert_false(session.is_expired(4000))
	assert_true(session.is_expired(4550), "refreshed a minute early")
	assert_null(AuthSession.from_response('{"error": "nope"}', 1000))
	assert_eq(AuthSession.from_dict(session.to_dict()).refresh_token, "r")


func test_anonymous_sign_up_request() -> void:
	var request := SupabaseRequests.sign_up_anonymously(_config())
	assert_eq(request.method, HTTPClient.METHOD_POST)
	assert_eq(request.url, "https://abc.supabase.co/auth/v1/signup")
	assert_true(request.headers.has("apikey: anon"))
	assert_true(request.headers.has("Authorization: Bearer anon"))
	assert_eq(JSON.parse_string(request.body), {"data": {}})


func test_signed_in_requests_use_the_user_token() -> void:
	var request := SupabaseRequests.get_career(_config(), _session(), 2)
	assert_eq(request.url, "https://abc.supabase.co/rest/v1/careers?select=envelope&slot=eq.2")
	assert_true(request.headers.has("Authorization: Bearer user-token"))


func test_upload_is_an_upsert_on_owner_and_slot() -> void:
	var request := SupabaseRequests.upload_career(_config(), _session(), 1, _envelope(3, 0))
	assert_string_contains(request.url, "/rest/v1/careers?on_conflict=owner,slot")
	assert_true(request.headers.has("Prefer: resolution=merge-duplicates,return=minimal"))
	var row: Dictionary = JSON.parse_string(request.body)
	assert_eq(row["owner"], _session().user_id)
	assert_eq(int(row["season_count"]), 3)
	assert_eq(row["saved_at"], "1970-01-01T00:00:00Z")


func test_ranking_and_account_requests() -> void:
	var submit := SupabaseRequests.submit_ranking(_config(), _session(), 3)
	assert_eq(submit.url, "https://abc.supabase.co/functions/v1/submit-ranking")
	assert_eq(JSON.parse_string(submit.body), {"slot": 3.0})
	var arena := SupabaseRequests.arena(_config(), _session(), "europe")
	assert_string_contains(arena.url, "/rest/v1/arena_entries?")
	assert_string_contains(arena.url, "server_id=eq.europe")
	var delete := SupabaseRequests.delete_account(_config(), _session())
	assert_eq(delete.url, "https://abc.supabase.co/rest/v1/rpc/delete_my_account")


func test_sync_keeps_the_newest_valid_save() -> void:
	var older := _envelope(3, 5000)
	var newer := _envelope(4, 1000)
	assert_eq(SyncPolicy.decide(null, null), SyncPolicy.NOTHING)
	assert_eq(SyncPolicy.decide(older, null), SyncPolicy.UPLOAD)
	assert_eq(SyncPolicy.decide(null, older), SyncPolicy.DOWNLOAD)
	assert_eq(SyncPolicy.decide(older, newer), SyncPolicy.DOWNLOAD, "remote is further along")
	assert_eq(SyncPolicy.decide(newer, older), SyncPolicy.UPLOAD)
	assert_eq(SyncPolicy.decide(older, older), SyncPolicy.NOTHING)
