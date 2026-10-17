class_name StoreAdapter
extends RefCounted
## The one place that talks to a platform store. The Store autoload calls
## `request_purchase`/`request_restore` and waits for the matching signal.
## A platform adapter (App Store, Google Play) subclasses this; see docs/STORE.md.

## `error` is "" when the purchase went through.
signal purchase_finished(platform_id: String, error: String)
## Every platform id the store says this player owns, or an error.
signal restore_finished(platform_ids: Array[String], error: String)


## Name shown on the store screen, e.g. "Test purchases".
func label() -> String:
	return ""


## False when this build cannot take purchases at all.
func is_available() -> bool:
	return false


## The platform key used in data/store.json platform_ids ("ios" or "android").
func platform() -> String:
	return ""


func request_purchase(platform_id: String) -> void:
	purchase_finished.emit.call_deferred(platform_id, "Purchases are not available in this build.")


func request_restore() -> void:
	var none: Array[String] = []
	restore_finished.emit.call_deferred(none, "Purchases are not available in this build.")
