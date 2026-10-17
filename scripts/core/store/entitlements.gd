class_name Entitlements
extends RefCounted
## Products the player owns on this device. Only unlocks cosmetics and extra
## save slots; nothing in career or moment logic reads it.

var owned: Array[String] = []


func owns_product(product_id: String) -> bool:
	return owned.has(product_id)


## Records a completed purchase or restore; unknown products are ignored.
func grant(product_id: String, catalog: StoreCatalog) -> void:
	if catalog.product(product_id) != null and not owned.has(product_id):
		owned.append(product_id)


## True if `item_id` is free or comes with an owned product.
func owns_item(item_id: String, catalog: StoreCatalog) -> bool:
	if catalog.free_items.has(item_id):
		return true
	var product := catalog.product_for_item(item_id)
	return product != null and owned.has(product.id)


## Extra career slots from owned convenience products.
func extra_save_slots(catalog: StoreCatalog) -> int:
	var slots := 0
	for product_id: String in owned:
		var product := catalog.product(product_id)
		if product != null:
			slots += product.extra_save_slots
	return slots


## `wanted` if it is a `kind` item the player owns, else the kind's default.
func equippable(kind: String, wanted: String, catalog: StoreCatalog) -> String:
	if catalog.kind_of(wanted) == kind and owns_item(wanted, catalog):
		return wanted
	return catalog.default_item(kind)


func to_dict() -> Dictionary:
	return {"owned": owned.duplicate()}


## Reads stored entitlements, keeping only known products (bad data owns nothing).
static func from_dict(data: Dictionary, catalog: StoreCatalog) -> Entitlements:
	var entitlements := Entitlements.new()
	var stored: Variant = data.get("owned")
	if typeof(stored) != TYPE_ARRAY:
		return entitlements
	for product_id: Variant in stored:
		if typeof(product_id) == TYPE_STRING:
			entitlements.grant(str(product_id), catalog)
	return entitlements
