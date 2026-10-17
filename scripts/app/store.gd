extends Node
## Autoload "Store": the single wrapper for in-app purchases. Screens call
## `purchase`/`restore` here and never a platform store directly. Products
## only unlock cosmetics and extra save slots (rules in StoreCatalog).

signal changed

const STATE_DIR := "user://store"

var catalog: StoreCatalog = null
var entitlements: Entitlements = Entitlements.new()
var adapter: StoreAdapter = null
## Where owned products are stored; tests point this at a throwaway folder.
var state_dir: String = STATE_DIR


func _ready() -> void:
	var errors: Array[String] = []
	catalog = StoreCatalog.load_file(StoreCatalog.DEFAULT_PATH, errors)
	for error: String in errors:
		push_error(error)
	reload()


## Re-reads owned products and rebuilds the adapter for `state_dir`.
func reload() -> void:
	DirAccess.make_dir_recursive_absolute(state_dir)
	var stored := JsonLoader.load_dictionary(_entitlements_path())
	entitlements = Entitlements.from_dict(stored.data if stored.is_ok() else {}, catalog)
	adapter = _make_adapter()
	changed.emit()


func is_available() -> bool:
	return adapter.is_available()


## Buys `product_id`; returns a message for the player. The caller shows the
## parental gate first.
func purchase(product_id: String) -> String:
	var product := catalog.product(product_id)
	if product == null:
		return "Unknown product."
	if entitlements.owns_product(product_id):
		return "You already own %s." % product.name
	var platform_id: String = product.platform_ids.get(adapter.platform(), "")
	adapter.request_purchase(platform_id)
	var reply: Array = await adapter.purchase_finished
	var error: String = reply[1]
	if reply[0] != platform_id or not error.is_empty():
		return error if not error.is_empty() else "The purchase did not complete."
	_grant([product_id])
	return "%s unlocked. Thank you!" % product.name


## Asks the platform store for everything already bought (new phone, reinstall).
func restore() -> String:
	adapter.request_restore()
	var reply: Array = await adapter.restore_finished
	var error: String = reply[1]
	if not error.is_empty():
		return error
	var owned: Array = reply[0]
	var found: Array[String] = []
	for product: StoreCatalog.Product in catalog.products:
		if owned.has(product.platform_ids.get(adapter.platform(), "")):
			found.append(product.id)
	_grant(found)
	return "Restored %d purchase(s)." % found.size()


## The equipped item of `kind` (always one the player owns).
func equipped(kind: String) -> Dictionary:
	var wanted: String = Preferences.settings.equipped.get(kind, "")
	return catalog.item(entitlements.equippable(kind, wanted, catalog))


## Equips `item_id` if the player owns it; returns whether it was equipped.
func equip(item_id: String) -> bool:
	var kind := catalog.kind_of(item_id)
	if kind.is_empty() or not entitlements.owns_item(item_id, catalog):
		return false
	Preferences.settings.equipped[kind] = item_id
	Preferences.save()
	changed.emit()
	return true


## Career save slots on this device: the free ones plus any bought.
func slot_count() -> int:
	return Session.config.free_save_slots + entitlements.extra_save_slots(catalog)


func _grant(product_ids: Array[String]) -> void:
	for product_id: String in product_ids:
		entitlements.grant(product_id, catalog)
	var file := FileAccess.open(_entitlements_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(entitlements.to_dict()))
		file.close()
	changed.emit()


## Platform adapters are added here once their plugins are set up (TODO.md, docs/STORE.md).
func _make_adapter() -> StoreAdapter:
	return MockStoreAdapter.new(state_dir.path_join("test_purchases.json"), OS.is_debug_build())


func _entitlements_path() -> String:
	return state_dir.path_join("entitlements.json")
