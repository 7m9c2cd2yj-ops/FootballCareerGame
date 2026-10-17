extends SceneTree
## Writes real, game-produced careers to backend/tests/fixtures/ so the
## backend's plausibility check is tested against what the game really makes.
## Run: godot --headless -s tools/export_test_careers.gd

const Flow := preload("res://tests/helpers/career_flow_sim.gd")
const CareerFixture := preload("res://tests/helpers/career_fixture.gd")
const BalanceFixture := preload("res://tests/helpers/balance_fixture.gd")
const OUT := "res://backend/tests/fixtures/"


func _initialize() -> void:
	var balance := BalanceFixture.shipped()
	var world := CareerFixture.world()
	var rules := CareerFixture.rules(world)
	var cups := CareerFixture.cups()
	var careers := {
		"elite_forward": Flow.run("FWD", 9.7, TrainingPlan.NORMAL, world, balance, rules, cups),
		"average_keeper": Flow.run("GK", 6.5, TrainingPlan.NORMAL, world, balance, rules, cups),
		"extreme_intense": Flow.run("MID", 10.0, TrainingPlan.INTENSE, world, balance, rules, cups),
	}
	for name: String in careers:
		var outcome: Flow.Outcome = careers[name]
		var file := FileAccess.open(OUT + name + ".json", FileAccess.WRITE)
		file.store_string(JSON.stringify(outcome.career.to_dict(), "\t", true))
		file.close()
		_write_summary(name, HallOfFame.summarize(outcome.career, world, rules))
		print("wrote %s (%d seasons)" % [name, outcome.career.history.size()])
	quit()


## The game's own ranking summary, which the backend must reproduce exactly.
func _write_summary(name: String, summary: HallOfFame.Summary) -> void:
	var expected := {
		"peak_overall": summary.peak_overall,
		"seasons": summary.seasons,
		"trophies": summary.trophies,
		"golden_balls": summary.golden_balls,
		"hof_score": roundi(summary.score),
		"inducted": summary.inducted,
	}
	var file := FileAccess.open(OUT + name + ".summary.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(expected, "\t", true))
	file.close()
