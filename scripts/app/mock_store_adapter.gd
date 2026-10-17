class_name MockStoreAdapter
extends StoreAdapter
## Test purchases for debug builds and tests: every purchase succeeds at once,
## no money moves, and "the store's" record of purchases is a local file so
## Restore can be tried. Release builds report that purchases are unavailable.

var _record_path: String = ""
var _enabled: bool = false


func _init(record_path: String, enabled: bool) -> void:
	_record_path = record_path
	_enabled = enabled


func label() -> String:
	return "Test purchases (debug build, nothing is charged)" if _enabled else ""


func is_available() -> bool:
	return _enabled


func platform() -> String:
	return "ios" if OS.get_name() == "iOS" else "android"


func request_purchase(platform_id: String) -> void:
	if not _enabled:
		super(platform_id)
		return
	var record := _record()
	if not record.has(platform_id):
		record.append(platform_id)
		_write(record)
	purchase_finished.emit.call_deferred(platform_id, "")


func request_restore() -> void:
	if not _enabled:
		super()
		return
	restore_finished.emit.call_deferred(_record(), "")


func _record() -> Array[String]:
	var ids: Array[String] = []
	var loaded := JsonLoader.load_dictionary(_record_path)
	if loaded.is_ok() and typeof(loaded.data.get("purchased")) == TYPE_ARRAY:
		for entry: Variant in loaded.data["purchased"]:
			ids.append(str(entry))
	return ids


func _write(ids: Array[String]) -> void:
	var file := FileAccess.open(_record_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"purchased": ids}))
		file.close()
