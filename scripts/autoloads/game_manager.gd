extends Node

## Global state manager. Handles pause, difficulty, and top-level game flow.
## State transitions can be driven directly or via EventBus.game_paused.

enum DifficultyMode { EASY, NORMAL, HARDCORE }
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

const DEFAULT_DIFFICULTY: DifficultyMode = DifficultyMode.NORMAL

var difficulty: DifficultyMode = DEFAULT_DIFFICULTY
var current_state: GameState = GameState.MENU


func _ready() -> void:
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.player_died.connect(_on_player_died)


func set_state(new_state: GameState) -> void:
	current_state = new_state


func set_difficulty(mode: DifficultyMode) -> void:
	difficulty = mode


func is_playing() -> bool:
	return current_state == GameState.PLAYING


func _on_game_paused(is_paused: bool) -> void:
	if is_paused:
		current_state = GameState.PAUSED
		get_tree().paused = true
		TimeManager.set_paused(true)
	else:
		current_state = GameState.PLAYING
		get_tree().paused = false
		TimeManager.set_paused(false)


func _on_player_died() -> void:
	current_state = GameState.GAME_OVER
	TimeManager.set_paused(true)
