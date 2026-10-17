class_name AuthSession
extends RefCounted
## A signed-in (anonymous) Supabase session.

## Refresh this many seconds before the access token expires.
const EXPIRY_MARGIN := 60

var access_token: String = ""
var refresh_token: String = ""
var expires_at_unix: int = 0
var user_id: String = ""


func is_expired(now_unix: int) -> bool:
	return now_unix >= expires_at_unix - EXPIRY_MARGIN


## Parses Supabase's session response (signup or token refresh), or null.
static func from_response(text: String, now_unix: int) -> AuthSession:
	var parsed := JsonLoader.parse_dictionary(text, "auth")
	if not parsed.is_ok():
		return null
	var data := parsed.data
	var user: Variant = data.get("user")
	if typeof(data.get("access_token")) != TYPE_STRING or typeof(user) != TYPE_DICTIONARY:
		return null
	var user_data: Dictionary = user
	var session := AuthSession.new()
	session.access_token = data["access_token"]
	session.refresh_token = str(data.get("refresh_token", ""))
	session.expires_at_unix = now_unix + int(data.get("expires_in", 0))
	session.user_id = str(user_data.get("id", ""))
	return session if not session.user_id.is_empty() else null


func to_dict() -> Dictionary:
	return {
		"access_token": access_token,
		"refresh_token": refresh_token,
		"expires_at_unix": expires_at_unix,
		"user_id": user_id,
	}


static func from_dict(data: Dictionary) -> AuthSession:
	if (
		typeof(data.get("refresh_token")) != TYPE_STRING
		or typeof(data.get("user_id")) != TYPE_STRING
	):
		return null
	var session := AuthSession.new()
	session.access_token = str(data.get("access_token", ""))
	session.refresh_token = data["refresh_token"]
	session.expires_at_unix = int(data.get("expires_at_unix", 0))
	session.user_id = data["user_id"]
	return session
