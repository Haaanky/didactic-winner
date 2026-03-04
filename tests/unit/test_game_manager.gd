extends GutTest

# Tests GameManager state transitions in isolation.
# Each test creates a fresh GameManager instance — it does NOT use the autoload
# singleton so tests remain independent of runtime order.

const _GameManagerScript := preload("res://scripts/autoloads/game_manager.gd")

var _gm: Node


func before_each() -> void:
	_gm = _GameManagerScript.new()
	add_child(_gm)


func after_each() -> void:
	_gm.queue_free()


func test_initial_state_is_menu() -> void:
	assert_eq(_gm.current_state, GameManager.GameState.MENU)


func test_set_state_playing() -> void:
	_gm.set_state(GameManager.GameState.PLAYING)
	assert_eq(_gm.current_state, GameManager.GameState.PLAYING)


func test_set_state_paused() -> void:
	_gm.set_state(GameManager.GameState.PAUSED)
	assert_eq(_gm.current_state, GameManager.GameState.PAUSED)


func test_set_state_game_over() -> void:
	_gm.set_state(GameManager.GameState.GAME_OVER)
	assert_eq(_gm.current_state, GameManager.GameState.GAME_OVER)


func test_set_state_back_to_menu() -> void:
	_gm.set_state(GameManager.GameState.PLAYING)
	_gm.set_state(GameManager.GameState.MENU)
	assert_eq(_gm.current_state, GameManager.GameState.MENU)


func test_all_four_states_are_distinct() -> void:
	var states := [
		GameManager.GameState.MENU,
		GameManager.GameState.PLAYING,
		GameManager.GameState.PAUSED,
		GameManager.GameState.GAME_OVER,
	]
	assert_eq(states.size(), 4)
	for i: int in states.size():
		for j: int in states.size():
			if i != j:
				assert_ne(states[i], states[j], "States %d and %d must differ" % [i, j])


func test_game_paused_signal_pauses_tree() -> void:
	_gm.set_state(GameManager.GameState.PLAYING)
	EventBus.game_paused.emit(true)
	assert_eq(_gm.current_state, GameManager.GameState.PAUSED)
	assert_true(get_tree().paused)
	get_tree().paused = false


func test_game_paused_false_resumes_playing() -> void:
	get_tree().paused = false
	_gm.set_state(GameManager.GameState.PAUSED)
	EventBus.game_paused.emit(false)
	assert_eq(_gm.current_state, GameManager.GameState.PLAYING)
	assert_false(get_tree().paused)


# ── player_died ────────────────────────────────────────────────────────────────

func test_player_died_sets_game_over_state() -> void:
	_gm.set_state(GameManager.GameState.PLAYING)
	_gm._on_player_died()
	assert_eq(_gm.current_state, GameManager.GameState.GAME_OVER)
	TimeManager.set_paused(false)


func test_player_died_twice_is_idempotent() -> void:
	_gm.set_state(GameManager.GameState.PLAYING)
	_gm._on_player_died()
	_gm._on_player_died()
	assert_eq(_gm.current_state, GameManager.GameState.GAME_OVER)
	TimeManager.set_paused(false)


# ── win condition ─────────────────────────────────────────────────────────────

func test_day_passed_below_goal_keeps_playing_state() -> void:
	_gm.set_state(GameManager.GameState.PLAYING)
	var old_days: int = TimeManager.total_days_elapsed
	TimeManager.total_days_elapsed = 0
	_gm._on_day_passed(1)
	assert_eq(_gm.current_state, GameManager.GameState.PLAYING)
	TimeManager.total_days_elapsed = old_days


func test_day_passed_at_goal_sets_game_over_state() -> void:
	_gm.set_state(GameManager.GameState.PLAYING)
	var old_days: int = TimeManager.total_days_elapsed
	TimeManager.total_days_elapsed = GameManager.SURVIVAL_GOAL_DAYS
	_gm._on_day_passed(GameManager.SURVIVAL_GOAL_DAYS)
	assert_eq(_gm.current_state, GameManager.GameState.GAME_OVER)
	TimeManager.total_days_elapsed = old_days
	TimeManager.set_paused(false)


func test_day_passed_at_goal_emits_game_won() -> void:
	_gm.set_state(GameManager.GameState.PLAYING)
	var old_days: int = TimeManager.total_days_elapsed
	TimeManager.total_days_elapsed = GameManager.SURVIVAL_GOAL_DAYS
	watch_signals(EventBus)
	_gm._on_day_passed(GameManager.SURVIVAL_GOAL_DAYS)
	assert_signal_emitted(EventBus, "game_won")
	TimeManager.total_days_elapsed = old_days
	TimeManager.set_paused(false)


func test_survival_goal_is_positive() -> void:
	assert_gt(GameManager.SURVIVAL_GOAL_DAYS, 0)
