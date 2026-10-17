class_name StoreCatalog
extends RefCounted
## Cosmetics and products from data/store.json. Validation enforces the store
## rules: every product is a one-time purchase with fixed, listed contents
## (no random rewards, no currencies) that only grants cosmetics or extra
## save slots, never anything that affects play.

const DEFAULT_PATH := "res://data/store.json"
const BOOTS := "boots"
const CELEBRATIONS := "celebrations"
const KITS := "kits"
const KINDS: Array[String] = [BOOTS, CELEBRATIONS, KITS]
const COSMETIC := "cosmetic"
const CONVENIENCE := "convenience"
const PLATFORMS: Array[String] = ["ios", "android"]
const CELEBRATION_STYLES: Array[String] = ["jump", "spin", "slide", "bow"]
## A kit whose colour is "palette" uses the accessibility palette's player kit colour.
const PALETTE_COLOR := "palette"
## Products may hold exactly these keys, so nothing else (odds, currencies,
## stat boosts) can be added without changing this rule and its tests.
const PRODUCT_KEYS: Array[String] = [
	"id", "kind", "name", "description", "platform_ids", "grants", "extra_save_slots"
]
const ITEM_KEYS: Array[String] = ["id", "name", "color", "style"]


class Product:
	extends RefCounted
	var id: String = ""
	var kind: String = ""
	var name: String = ""
	var description: String = ""
	## Platform ("ios"/"android") -> store product id.
	var platform_ids: Dictionary[String, String] = {}
	## Cosmetic item ids this product unlocks.
	var grants: Array[String] = []
	var extra_save_slots: int = 0


## Cosmetic kind -> list of item dictionaries (id, name, color or style), in file order.
var items: Dictionary[String, Array] = {}
var free_items: Array[String] = []
var products: Array[Product] = []


static func load_file(path: String, errors: Array[String]) -> StoreCatalog:
	var loaded := JsonLoader.load_dictionary(path)
	if not loaded.is_ok():
		errors.append(loaded.error)
		return null
	var problems := validate(loaded.data)
	if not problems.is_empty():
		for problem: String in problems:
			errors.append("%s: %s" % [path, problem])
		return null
	return from_dictionary(loaded.data)


static func validate(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var item_ids := _validate_cosmetics(data.get("cosmetics"), problems)
	var free: Array = []
	if typeof(data.get("free_items")) == TYPE_ARRAY:
		free = data["free_items"]
	else:
		problems.append("free_items must be an array")
	for item_id: Variant in free:
		if not item_ids.has(item_id):
			problems.append("free item %s is not a cosmetic" % str(item_id))
	if typeof(data.get("products")) != TYPE_ARRAY:
		problems.append("products must be an array")
		return problems
	var granted: Array[String] = []
	for entry: Variant in data["products"]:
		_validate_product(entry, item_ids, granted, problems)
	for item_id: String in item_ids:
		if not free.has(item_id) and not granted.has(item_id):
			problems.append("cosmetic %s is neither free nor in a product" % item_id)
	if typeof(data.get("cosmetics")) == TYPE_DICTIONARY:
		for kind: String in KINDS:
			if not _kind_has_free_item(data["cosmetics"], kind, free):
				problems.append("%s needs at least one free item" % kind)
	return problems


static func from_dictionary(data: Dictionary) -> StoreCatalog:
	var catalog := StoreCatalog.new()
	var cosmetics: Dictionary = data["cosmetics"]
	for kind: String in KINDS:
		var entries: Array = cosmetics[kind]
		catalog.items[kind] = entries.duplicate(true)
	catalog.free_items.assign(data["free_items"])
	for entry: Dictionary in data["products"]:
		var built := Product.new()
		built.id = entry["id"]
		built.kind = entry["kind"]
		built.name = entry["name"]
		built.description = entry["description"]
		built.platform_ids.assign(entry["platform_ids"])
		built.grants.assign(entry["grants"])
		built.extra_save_slots = int(entry["extra_save_slots"])
		catalog.products.append(built)
	return catalog


func product(product_id: String) -> Product:
	for candidate: Product in products:
		if candidate.id == product_id:
			return candidate
	return null


## The item dictionary for `item_id`, or {} if unknown.
func item(item_id: String) -> Dictionary:
	for kind: String in KINDS:
		for entry: Dictionary in items[kind]:
			if entry["id"] == item_id:
				return entry
	return {}


func kind_of(item_id: String) -> String:
	for kind: String in KINDS:
		for entry: Dictionary in items[kind]:
			if entry["id"] == item_id:
				return kind
	return ""


## The first free item of `kind`: what is equipped until the player picks another.
func default_item(kind: String) -> String:
	for entry: Dictionary in items[kind]:
		if free_items.has(entry["id"]):
			return entry["id"]
	return ""


## The product that unlocks `item_id`, or null if it is free or unknown.
func product_for_item(item_id: String) -> Product:
	for candidate: Product in products:
		if candidate.grants.has(item_id):
			return candidate
	return null


static func _validate_cosmetics(cosmetics: Variant, problems: Array[String]) -> Array[String]:
	var ids: Array[String] = []
	if typeof(cosmetics) != TYPE_DICTIONARY:
		problems.append("cosmetics must be an object")
		return ids
	var by_kind: Dictionary = cosmetics
	for kind: String in KINDS:
		var entries: Array = by_kind.get(kind) if typeof(by_kind.get(kind)) == TYPE_ARRAY else []
		if entries.is_empty():
			problems.append("cosmetics.%s must be a non-empty array" % kind)
		for entry: Variant in entries:
			_validate_item(entry, kind, ids, problems)
	return ids


static func _validate_item(
	entry: Variant, kind: String, ids: Array[String], problems: Array[String]
) -> void:
	if not _has_text_id(entry):
		problems.append("cosmetics.%s entries need a text id" % kind)
		return
	var data: Dictionary = entry
	var id := str(data["id"])
	if ids.has(id):
		problems.append("cosmetic id %s is used twice" % id)
	ids.append(id)
	for key: String in data:
		if not ITEM_KEYS.has(key):
			problems.append("cosmetic %s has unknown key %s" % [id, key])
	if typeof(data.get("name")) != TYPE_STRING:
		problems.append("cosmetic %s needs a name" % id)
	if kind == CELEBRATIONS:
		if not CELEBRATION_STYLES.has(data.get("style")):
			problems.append("celebration %s: style must be one of %s" % [id, CELEBRATION_STYLES])
	elif not _is_item_color(data.get("color"), kind):
		problems.append("cosmetic %s: color must be a colour like #1a2b3c" % id)


static func _is_item_color(value: Variant, kind: String) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	if kind == KITS and value == PALETTE_COLOR:
		return true
	return Color.html_is_valid(str(value))


static func _validate_product(
	entry: Variant, item_ids: Array[String], granted: Array[String], problems: Array[String]
) -> void:
	if not _has_text_id(entry):
		problems.append("products entries need a text id")
		return
	var data: Dictionary = entry
	var id := str(data["id"])
	for key: String in data:
		if not PRODUCT_KEYS.has(key):
			problems.append("product %s has unknown key %s" % [id, key])
	for key: String in ["name", "description"]:
		if typeof(data.get(key)) != TYPE_STRING or str(data.get(key)).is_empty():
			problems.append("product %s needs a %s" % [id, key])
	_validate_platform_ids(data.get("platform_ids"), id, problems)
	var slots: Variant = data.get("extra_save_slots")
	if typeof(data.get("grants")) != TYPE_ARRAY or not DataChecks.is_number(slots):
		problems.append("product %s needs grants (array) and extra_save_slots (number)" % id)
		return
	var grants: Array = data["grants"]
	for item_id: Variant in grants:
		if not item_ids.has(item_id):
			problems.append("product %s grants unknown cosmetic %s" % [id, str(item_id)])
		elif granted.has(item_id):
			problems.append("cosmetic %s is in more than one product" % str(item_id))
		else:
			granted.append(str(item_id))
	match data.get("kind"):
		COSMETIC:
			if grants.is_empty() or int(slots) != 0:
				problems.append("cosmetic product %s must grant cosmetics only" % id)
		CONVENIENCE:
			if not grants.is_empty() or int(slots) < 1 or int(slots) > 9:
				problems.append("convenience product %s must grant 1-9 save slots only" % id)
		_:
			problems.append("product %s: kind must be cosmetic or convenience" % id)


static func _validate_platform_ids(
	ids: Variant, product_id: String, problems: Array[String]
) -> void:
	if typeof(ids) != TYPE_DICTIONARY:
		problems.append("product %s: platform_ids must be an object" % product_id)
		return
	var by_platform: Dictionary = ids
	for platform: String in PLATFORMS:
		var value: Variant = by_platform.get(platform)
		if typeof(value) != TYPE_STRING or str(value).is_empty():
			problems.append("product %s: platform_ids.%s must be text" % [product_id, platform])


static func _kind_has_free_item(cosmetics: Dictionary, kind: String, free: Array) -> bool:
	if typeof(cosmetics.get(kind)) != TYPE_ARRAY:
		return true  # Reported by _validate_cosmetics.
	for entry: Variant in cosmetics[kind]:
		if _has_text_id(entry):
			var data: Dictionary = entry
			if free.has(data["id"]):
				return true
	return false


static func _has_text_id(entry: Variant) -> bool:
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = entry
	return typeof(data.get("id")) == TYPE_STRING
