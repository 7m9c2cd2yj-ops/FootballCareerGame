extends SceneTree
## End-to-end check of the online client against tools/mock_supabase.py.
## Run through tools/test_online.sh (which starts the mock and points the
## game at it). Exits 1 on the first failed check.

const SLOT := 1

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session: Node = root.get_node("Session")
	var backend: Node = root.get_node("Backend")
	var saves := SaveSlots.new("user://online_smoke")
	saves.delete(SLOT)
	session.set("saves", saves)
	var rules: CareerRules = session.get("rules")
	var migrate := CareerSaves.migrator(rules)
	var validate := CareerSaves.validator(session.get("balance"), session.get("world"))

	session.call("start_career", "FWD", SLOT)
	_play_seasons(session, 12)
	await _idle(backend)
	# Autosave already synced in the background and refreshed the ranking.
	_expect(await backend.call("sync_slot", SLOT, saves, migrate, validate), "up to date")
	var ranked: Array[Dictionary] = await backend.call("rankings", true)
	_check(ranked.size() == 1, "background sync ranked the career")

	saves.delete(SLOT)
	_expect(
		await backend.call("sync_slot", SLOT, saves, migrate, validate),
		"updated from your online save"
	)
	_check(session.call("load_career", SLOT) == "", "restored save loads")
	await _idle(backend)
	var career: CareerState = session.get("career")
	_check(career.history.size() == 12, "restored career has 12 seasons")

	_play_seasons(session, 1)
	await _idle(backend)
	_expect(await backend.call("sync_slot", SLOT, saves, migrate, validate), "up to date")
	_expect(await backend.call("submit_ranking", SLOT), "Ranking updated")
	var mine: Array[Dictionary] = await backend.call("rankings", false)
	_check(
		mine.size() == 1 and mine[0]["display_name"] == backend.get("display_name"),
		"ARENA lists me"
	)
	var everyone: Array[Dictionary] = await backend.call("rankings", true)
	_check(everyone.size() == 1, "global rankings list me")

	_expect(await backend.call("choose_identity", "Not A Preset", "europe"), "preset names")
	_expect(await backend.call("choose_identity", "BraveBadger", "americas"), "Profile saved")

	await _forge_and_upload(career, session, saves, backend, migrate, validate)
	_expect(await backend.call("submit_ranking", SLOT), "not accepted")

	_expect(await backend.call("delete_account"), "deleted")
	var after: Array[Dictionary] = await backend.call("rankings", true)
	_check(after.is_empty(), "deleted account leaves no rankings")

	var config: BackendConfig = backend.get("config")
	config.url = "http://127.0.0.1:9"
	backend.set("session", null)
	_expect(await backend.call("sync_slot", SLOT, saves, migrate, validate), "offline")
	saves.delete(SLOT)
	print("online_smoke: %s" % ("all checks passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures > 0 else 0)


func _play_seasons(session: Node, count: int) -> void:
	var errors: Array[String] = []
	for i: int in count:
		var career: CareerState = session.get("career")
		if Trials.is_due(career, session.get("rules")):
			var world: ClubWorld = session.get("world")
			session.call("take_trial", world.club("fernwick"))
		elif career.contract != null and career.contract.has_expired():
			var offers: Array[Offer] = session.call("offers")
			session.call("accept_offer", offers[0])
		var plan := TrainingAdvisor.recommended_plan(career.player, session.get("balance"))
		session.call("sim_season", plan, errors)


## Rewrites the local save with an impossible jump (valid checksum) and syncs.
func _forge_and_upload(
	career: CareerState,
	session: Node,
	saves: SaveSlots,
	backend: Node,
	migrate: Callable,
	validate: Callable
) -> void:
	career.history[3].overall_after = 99
	career.history[4].overall_before = 99
	session.call("save_career")
	await _idle(backend)
	_expect(await backend.call("sync_slot", SLOT, saves, migrate, validate), "up to date")


func _idle(backend: Node) -> void:
	while backend.call("is_syncing"):
		await process_frame


func _expect(message: Variant, part: String) -> void:
	_check(str(message).contains(part), "'%s' should contain '%s'" % [message, part])


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok  %s" % description)
	else:
		_failures += 1
		printerr("  FAIL %s" % description)
