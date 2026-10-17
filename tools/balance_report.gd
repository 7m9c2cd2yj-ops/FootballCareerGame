extends SceneTree
## Prints full-career overall curves for every position and a few play styles,
## so balance.json changes can be judged at a glance. Run tools/balance_report.sh.

const CareerSim := preload("res://tests/helpers/career_sim.gd")
const REPORT_AGES: Array[int] = [8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40]


func _init() -> void:
	var errors: Array[String] = []
	var balance := Balance.load_file(Balance.DEFAULT_PATH, errors)
	if balance == null:
		printerr("\n".join(errors))
		quit(1)
		return
	var styles: Dictionary[String, float] = {
		"perfect (10)": 10.0,
		"elite (9.7)": 9.7,
		"star (9.0)": 9.0,
		"good (7.5)": 7.5,
		"expected": CareerSim.EXPECTED_RATING,
		"poor (5.0)": 5.0,
	}
	var header := "%-6s %-12s" % ["pos", "style"]
	for age: int in REPORT_AGES:
		header += "%4d" % age
	print(header + "   peak@age")
	for position: String in balance.positions():
		for style: String in styles:
			var curve := CareerSim.overall_by_age(position, styles[style], null, balance)
			var line := "%-6s %-12s" % [position, style]
			for age: int in REPORT_AGES:
				line += "%4d" % curve[age]
			var best := CareerSim.peak(curve)
			print(line + "   %d@%d" % [best.y, best.x])
	quit(0)
