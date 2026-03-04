extends Node

## Global state manager. Handles pause, difficulty, win/lose, and top-level game flow.
## State transitions can be driven directly or via EventBus signals.

enum DifficultyMode { EASY, NORMAL, HARDCORE }
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

const DEFAULT_DIFFICULTY: DifficultyMode = DifficultyMode.NORMAL
const SURVIVAL_GOAL_DAYS: int = 3
const GAME_OVER_DELAY: float = 1.5
const WIN_DELAY: float = 1.5

var difficulty: DifficultyMode = DEFAULT_DIFFICULTY
var current_state: GameState = GameState.MENU


func _ready() -> void:
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.player_died.connect(_on_player_died)
	EventBus.day_passed.connect(_on_day_passed)


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
	if current_state == GameState.GAME_OVER:
		return
	current_state = GameState.GAME_OVER
	TimeManager.set_paused(true)
	get_tree().create_timer(GAME_OVER_DELAY).timeout.connect(
		func() -> void:
			get_tree().paused = false
			SceneManager.go_to_game_over()
	)


func _on_day_passed(_day: int) -> void:
	if current_state != GameState.PLAYING:
		return
	if TimeManager.total_days_elapsed >= SURVIVAL_GOAL_DAYS:
		current_state = GameState.GAME_OVER
		TimeManager.set_paused(true)
		EventBus.game_won.emit(TimeManager.total_days_elapsed)
		get_tree().create_timer(WIN_DELAY).timeout.connect(
			func() -> void:
				get_tree().paused = false
				SceneManager.go_to_win_screen()
		)
