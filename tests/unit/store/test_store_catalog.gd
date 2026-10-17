extends GutTest
## The store file can only hold fixed, one-time cosmetic or convenience
## products: anything random, consumable or gameplay-related is rejected.

const MIN_KIT_DISTANCE := 0.3


func _data() -> Dictionary:
	return JsonLoader.load_dictionary(StoreCatalog.DEFAULT_PATH).data


func _shipped() -> StoreCatalog:
	var errors: Array[String] = []
	var catalog := StoreCatalog.load_file(StoreCatalog.DEFAULT_PATH, errors)
	assert_not_null(catalog, "\n".join(errors))
	return catalog


func _product(data: Dictionary, index: int) -> Dictionary:
	var products: Array = data["products"]
	return products[index]


func _problems(data: Dictionary) -> String:
	return "\n".join(StoreCatalog.validate(data))


func test_shipped_catalog_is_valid() -> void:
	var catalog := _shipped()
	assert_eq(catalog.products.size(), 4)
	for kind: String in StoreCatalog.KINDS:
		assert_ne(catalog.default_item(kind), "", kind)


func test_there_is_no_ad_free_product_while_there_are_no_ads() -> void:
	for product: StoreCatalog.Product in _shipped().products:
		assert_false(product.id.contains("ad"), product.id)


func test_random_rewards_and_stat_boosts_cannot_be_added() -> void:
	var data := _data()
	_product(data, 0)["drop_chances"] = {"boots_neon": 0.5}
	_product(data, 1)["rating_bonus"] = 2
	var problems := _problems(data)
	assert_string_contains(problems, "boots_pack has unknown key drop_chances")
	assert_string_contains(problems, "celebration_pack has unknown key rating_bonus")


func test_only_cosmetic_and_convenience_kinds_are_allowed() -> void:
	var data := _data()
	_product(data, 0)["kind"] = "consumable"
	assert_string_contains(_problems(data), "kind must be cosmetic or convenience")


func test_cosmetic_products_cannot_grant_slots_and_vice_versa() -> void:
	var data := _data()
	_product(data, 0)["extra_save_slots"] = 1
	var grants: Array = _product(data, 3)["grants"]
	grants.append("kit_white")
	var problems := _problems(data)
	assert_string_contains(problems, "cosmetic product boots_pack must grant cosmetics only")
	assert_string_contains(problems, "convenience product extra_save_slots must grant 1-9")


func test_every_cosmetic_is_free_or_sold_exactly_once() -> void:
	var data := _data()
	var grants: Array = _product(data, 0)["grants"]
	grants.erase("boots_sunset")
	var kit_grants: Array = _product(data, 2)["grants"]
	kit_grants.append("boots_neon")
	var problems := _problems(data)
	assert_string_contains(problems, "boots_sunset is neither free nor in a product")
	assert_string_contains(problems, "boots_neon is in more than one product")


func test_unknown_cosmetic_and_missing_platform_id_are_reported() -> void:
	var data := _data()
	var grants: Array = _product(data, 0)["grants"]
	grants.append("boots_rocket")
	var ids: Dictionary = _product(data, 1)["platform_ids"]
	ids.erase("ios")
	var problems := _problems(data)
	assert_string_contains(problems, "grants unknown cosmetic boots_rocket")
	assert_string_contains(problems, "platform_ids.ios must be text")


func test_each_kind_needs_a_free_item() -> void:
	var data := _data()
	var free: Array = data["free_items"]
	free.erase("celebration_fist")
	var grants: Array = _product(data, 1)["grants"]
	grants.append("celebration_fist")
	assert_string_contains(_problems(data), "celebrations needs at least one free item")


func test_kit_colours_stay_clear_of_opponents_and_keepers() -> void:
	var errors: Array[String] = []
	var options := Accessibility.load_file(Accessibility.DEFAULT_PATH, errors)
	for kit: Dictionary in _shipped().items[StoreCatalog.KITS]:
		if kit["color"] == StoreCatalog.PALETTE_COLOR:
			continue
		var color := Color.html(str(kit["color"]))
		for palette: String in options.palette_ids:
			for role: String in ["opponent_kit", "keeper_kit"]:
				var other := options.color(palette, role)
				var gap := Vector3(color.r - other.r, color.g - other.g, color.b - other.b).length()
				assert_gt(gap, MIN_KIT_DISTANCE, "%s vs %s (%s)" % [kit["id"], role, palette])
