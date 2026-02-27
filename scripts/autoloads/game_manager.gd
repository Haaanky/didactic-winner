class_name GameManager
extends Node

## Global state manager. Handles pause, difficulty, and top-level game flow.

enum DifficultyMode { EASY, NORMAL, HARDCORE }
enum GameState { MAIN_MENU, PLAYING, PAUSED, DEAD, LOADING }

const DEFAULT_DIFFICULTY: DifficultyMode = DifficultyMode.NORMAL

var difficulty: DifficultyMode = DEFAULT_DIFFICULTY
var game_state: GameState = GameState.MAIN_MENU


func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and game_state == GameState.PLAYING:
		pause_game()
	elif event.is_action_pressed("pause") and game_state == GameState.PAUSED:
		resume_game()


func start_game() -> void:
	game_state = GameState.PLAYING
	TimeManager.set_paused(false)


func pause_game() -> void:
	game_state = GameState.PAUSED
	TimeManager.set_paused(true)
	EventBus.ui_screen_opened.emit("pause_menu")


func resume_game() -> void:
	game_state = GameState.PLAYING
	TimeManager.set_paused(false)
	EventBus.ui_screen_closed.emit("pause_menu")


func set_difficulty(mode: DifficultyMode) -> void:
	difficulty = mode


func is_playing() -> bool:
	return game_state == GameState.PLAYING


func _on_player_died() -> void:
	game_state = GameState.DEAD
	TimeManager.set_paused(true)
