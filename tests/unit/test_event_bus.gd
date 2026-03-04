extends GutTest

# Verifies that all required signals are declared on EventBus and that they
# can be emitted and received correctly.


func test_player_died_signal_exists() -> void:
	assert_true(EventBus.has_signal("player_died"))


func test_player_health_changed_signal_exists() -> void:
	assert_true(EventBus.has_signal("player_health_changed"))


func test_game_paused_signal_exists() -> void:
	assert_true(EventBus.has_signal("game_paused"))


func test_need_changed_signal_exists() -> void:
	assert_true(EventBus.has_signal("need_changed"))


func test_need_critical_signal_exists() -> void:
	assert_true(EventBus.has_signal("need_critical"))


func test_need_depleted_signal_exists() -> void:
	assert_true(EventBus.has_signal("need_depleted"))


func test_hour_passed_signal_exists() -> void:
	assert_true(EventBus.has_signal("hour_passed"))


func test_day_passed_signal_exists() -> void:
	assert_true(EventBus.has_signal("day_passed"))


func test_season_changed_signal_exists() -> void:
	assert_true(EventBus.has_signal("season_changed"))


func test_weather_changed_signal_exists() -> void:
	assert_true(EventBus.has_signal("weather_changed"))


func test_temperature_changed_signal_exists() -> void:
	assert_true(EventBus.has_signal("temperature_changed"))


func test_interaction_triggered_signal_exists() -> void:
	assert_true(EventBus.has_signal("interaction_triggered"))


func test_player_died_emits_and_is_received() -> void:
	watch_signals(EventBus)
	EventBus.player_died.emit()
	assert_signal_emitted(EventBus, "player_died")


func test_player_health_changed_carries_value() -> void:
	watch_signals(EventBus)
	EventBus.player_health_changed.emit(42.5)
	assert_signal_emitted_with_parameters(EventBus, "player_health_changed", [42.5])


func test_game_paused_true_carries_value() -> void:
	watch_signals(EventBus)
	EventBus.game_paused.emit(true)
	assert_signal_emitted_with_parameters(EventBus, "game_paused", [true])


func test_game_paused_false_carries_value() -> void:
	watch_signals(EventBus)
	EventBus.game_paused.emit(false)
	assert_signal_emitted_with_parameters(EventBus, "game_paused", [false])


func test_hour_passed_carries_hour_int() -> void:
	watch_signals(EventBus)
	EventBus.hour_passed.emit(14)
	assert_signal_emitted_with_parameters(EventBus, "hour_passed", [14])


func test_need_changed_carries_name_and_value() -> void:
	watch_signals(EventBus)
	EventBus.need_changed.emit("hunger", 55.0)
	assert_signal_emitted_with_parameters(EventBus, "need_changed", ["hunger", 55.0])


func test_temperature_changed_carries_float() -> void:
	watch_signals(EventBus)
	EventBus.temperature_changed.emit(-12.5)
	assert_signal_emitted_with_parameters(EventBus, "temperature_changed", [-12.5])


func test_game_won_signal_exists() -> void:
	assert_true(EventBus.has_signal("game_won"))


func test_stamina_changed_signal_exists() -> void:
	assert_true(EventBus.has_signal("stamina_changed"))


func test_game_won_carries_days_int() -> void:
	watch_signals(EventBus)
	EventBus.game_won.emit(5)
	assert_signal_emitted_with_parameters(EventBus, "game_won", [5])


func test_stamina_changed_carries_float() -> void:
	watch_signals(EventBus)
	EventBus.stamina_changed.emit(75.0)
	assert_signal_emitted_with_parameters(EventBus, "stamina_changed", [75.0])
