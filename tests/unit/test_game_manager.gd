extends GutTest

# Tests GameManager state transitions in isolation.
# Each test creates a fresh GameManager instance — it does NOT use the autoload
# singleton so tests remain independent of runtime order.

var _gm: GameManager


func before_each() -> void:
	_gm = GameManager.new()
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
