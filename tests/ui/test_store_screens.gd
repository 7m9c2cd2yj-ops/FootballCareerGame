extends GutTest
## Store wrapper with the mock adapter, the parental gate, the locker and the
## rule that cosmetics never change a moment's result.

const STORE_SCENE := preload("res://scenes/main/store_screen.tscn")
const LOCKER_SCENE := preload("res://scenes/main/locker_screen.tscn")
const MOMENT_SCENE := preload("res://scenes/moments/moment_scene.tscn")
const PreRun := preload("res://tests/helpers/pre_run.gd")
const Fixture := preload("res://tests/helpers/moment_fixture.gd")


func before_each() -> void:
	PreRun.clear(Store.state_dir)
	Store.reload()


func after_each() -> void:
	PreRun.clear(Store.state_dir)
	Store.reload()
	Preferences.reload()
	Session.career = null
	Session.season_in_progress = null


func test_mock_purchase_unlocks_and_persists() -> void:
	assert_true(Store.is_available(), "tests run a debug build")
	assert_string_contains(await Store.purchase("boots_pack"), "unlocked")
	assert_true(Store.entitlements.owns_item("boots_neon", Store.catalog))
	Store.reload()
	assert_true(Store.entitlements.owns_product("boots_pack"), "kept after a restart")
	assert_string_contains(await Store.purchase("boots_pack"), "already own")
	assert_eq(await Store.purchase("loot_box"), "Unknown product.")


func test_restore_brings_back_purchases() -> void:
	await Store.purchase("kit_pack")
	DirAccess.remove_absolute(Store.state_dir.path_join("entitlements.json"))
	Store.reload()
	assert_false(Store.entitlements.owns_product("kit_pack"))
	assert_eq(await Store.restore(), "Restored 1 purchase(s).")
	assert_true(Store.entitlements.owns_product("kit_pack"))


func test_extra_slots_raise_the_slot_count() -> void:
	var free := Session.config.free_save_slots
	assert_eq(Store.slot_count(), free)
	await Store.purchase("extra_save_slots")
	assert_eq(Store.slot_count(), free + 3)


func test_release_builds_without_a_platform_store_refuse_purchases() -> void:
	Store.adapter = MockStoreAdapter.new(Store.state_dir.path_join("x.json"), false)
	assert_false(Store.is_available())
	assert_string_contains(await Store.purchase("boots_pack"), "not available")
	assert_false(Store.entitlements.owns_product("boots_pack"))


func test_wrong_gate_answer_buys_nothing() -> void:
	var screen: Control = add_child_autofree(STORE_SCENE.instantiate())
	screen.call("buy_with_gate", "celebration_pack")
	var dialog: ParentalGateDialog = screen.find_children("*", "ParentalGateDialog", true, false)[0]
	var wrong := dialog.gate.choices.filter(func(c: int) -> bool: return c != dialog.gate.answer())
	dialog.choose(wrong[0])
	await wait_process_frames(2)
	assert_false(Store.entitlements.owns_product("celebration_pack"))


func test_right_gate_answer_buys() -> void:
	var screen: Control = add_child_autofree(STORE_SCENE.instantiate())
	screen.call("buy_with_gate", "celebration_pack")
	var dialog: ParentalGateDialog = screen.find_children("*", "ParentalGateDialog", true, false)[0]
	dialog.choose(dialog.gate.answer())
	await wait_process_frames(4)
	assert_true(Store.entitlements.owns_product("celebration_pack"))


func test_locker_equips_owned_items_only() -> void:
	var screen: Control = add_child_autofree(LOCKER_SCENE.instantiate())
	assert_false(Store.equip("boots_neon"), "not bought yet")
	assert_eq(Store.equipped(StoreCatalog.BOOTS)["id"], "boots_classic")
	assert_true(Store.equip("boots_white"))
	screen.call("refresh")
	var texts: Array[String] = []
	for button: Button in screen.find_children("*", "Button", true, false):
		texts.append(button.text)
	assert_has(texts, "✓ Clean white (equipped)")
	assert_has(texts, "Neon lime · in the store")


func test_cosmetics_never_change_a_result() -> void:
	var plain := await _penalty_result()
	await Store.purchase("boots_pack")
	await Store.purchase("celebration_pack")
	await Store.purchase("kit_pack")
	Store.equip("boots_neon")
	Store.equip("celebration_spin")
	Store.equip("kit_purple")
	var dressed := await _penalty_result()
	assert_eq(dressed, plain)


## The penalty's verdict as [outcome, success, quality, ball, keeper].
func _penalty_result() -> Array:
	Session.start_career("FWD")
	Preferences.settings.tips_seen.assign(MomentSpec.TYPES)
	var season := SeasonInProgress.new()
	season.plan = TrainingPlan.create("shooting", "pace")
	season.moments.append(Fixture.spec(MomentSpec.PENALTY, 0.5, 0.5))
	Session.season_in_progress = season
	var scene: Node = add_child_autofree(MOMENT_SCENE.instantiate())
	var controller: ShotController = scene.call("controller")
	var verdict: Array = []
	controller.resolved.connect(
		func(r: MomentResult) -> void:
			verdict.assign([r.outcome, r.success, r.quality, r.ball_target, r.keeper_target])
	)
	controller.shoot(Vector2(2.9, 0.6), 0.0, 0.7)
	assert_true(await wait_for_signal(controller.resolved, 3.0))
	return verdict
