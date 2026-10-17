extends Node
## Autoload "Session": data and the active career shared between screens.
## Holds state only; game rules live in scripts/core.

var config: GameConfig = null
var balance: Balance = null
var labels: GameLabels = null
var career: CareerState = null
## Problems found while loading data files; screens show these instead of crashing.
var load_errors: Array[String] = []


func _ready() -> void:
	config = GameConfig.load_file(GameConfig.DEFAULT_PATH, load_errors)
	balance = Balance.load_file(Balance.DEFAULT_PATH, load_errors)
	labels = GameLabels.load_file(GameLabels.DEFAULT_PATH, load_errors)
	for error: String in load_errors:
		push_error(error)


func is_ready() -> bool:
	return load_errors.is_empty()


func start_career(position: String) -> void:
	career = CareerState.start(config.default_player_name, position, balance)
