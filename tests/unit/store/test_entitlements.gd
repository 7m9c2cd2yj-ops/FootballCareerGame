extends GutTest
## What the player owns: free items, bought products and extra slots.

var _catalog: StoreCatalog = null


func before_each() -> void:
	var errors: Array[String] = []
	_catalog = StoreCatalog.load_file(StoreCatalog.DEFAULT_PATH, errors)


func test_free_items_are_owned_from_the_start() -> void:
	var owned := Entitlements.new()
	assert_true(owned.owns_item("boots_classic", _catalog))
	assert_false(owned.owns_item("boots_neon", _catalog))
	assert_eq(owned.extra_save_slots(_catalog), 0)


func test_buying_a_pack_unlocks_its_items_only() -> void:
	var owned := Entitlements.new()
	owned.grant("boots_pack", _catalog)
	assert_true(owned.owns_item("boots_neon", _catalog))
	assert_true(owned.owns_item("boots_sunset", _catalog))
	assert_false(owned.owns_item("kit_black", _catalog))


func test_extra_save_slots() -> void:
	var owned := Entitlements.new()
	owned.grant("extra_save_slots", _catalog)
	owned.grant("extra_save_slots", _catalog)
	assert_eq(owned.extra_save_slots(_catalog), 3, "a one-time purchase counts once")


func test_unowned_or_wrong_kind_items_fall_back_to_the_default() -> void:
	var owned := Entitlements.new()
	assert_eq(owned.equippable(StoreCatalog.BOOTS, "boots_neon", _catalog), "boots_classic")
	assert_eq(owned.equippable(StoreCatalog.BOOTS, "kit_blue", _catalog), "boots_classic")
	assert_eq(owned.equippable(StoreCatalog.BOOTS, "boots_white", _catalog), "boots_white")


func test_stored_data_keeps_known_products_only() -> void:
	var data := {"owned": ["kit_pack", "gems_1000", 5]}
	var owned := Entitlements.from_dict(data, _catalog)
	assert_eq(owned.owned, ["kit_pack"] as Array[String])
	assert_eq(Entitlements.from_dict({"owned": "all"}, _catalog).owned.size(), 0)
	assert_eq(Entitlements.from_dict(owned.to_dict(), _catalog).owned, owned.owned)
