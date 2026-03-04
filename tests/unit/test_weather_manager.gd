extends GutTest

# Tests WeatherManager temperature and weather logic.
# Uses a local WeatherManager instance. Tests that query temperature set the
# global TimeManager singleton state and restore it in after_each.

const _WeatherManagerScript := preload("res://scripts/autoloads/weather_manager.gd")

var _wm: Node
var _saved_season: int
var _saved_hour: int


func before_each() -> void:
	_saved_season = TimeManager.current_season
	_saved_hour = TimeManager.game_hour
	_wm = _WeatherManagerScript.new()
	add_child(_wm)


func after_each() -> void:
	TimeManager.current_season = _saved_season as TimeManager.Season
	TimeManager.game_hour = _saved_hour
	_wm.queue_free()


# ── Initial state ─────────────────────────────────────────────────────────────

func test_initial_weather_is_clear() -> void:
	assert_eq(_wm.current_weather, _wm.WeatherType.CLEAR)


func test_initial_temperature_is_positive() -> void:
	assert_gt(_wm.current_temperature, 0.0)


# ── get_weather_damage_rate ───────────────────────────────────────────────────

func test_clear_weather_has_zero_damage_rate() -> void:
	_wm.current_weather = _wm.WeatherType.CLEAR
	assert_eq(_wm.get_weather_damage_rate(), 0.0)


func test_overcast_has_zero_damage_rate() -> void:
	_wm.current_weather = _wm.WeatherType.OVERCAST
	assert_eq(_wm.get_weather_damage_rate(), 0.0)


func test_rain_damage_rate_is_positive() -> void:
	_wm.current_weather = _wm.WeatherType.RAIN
	assert_gt(_wm.get_weather_damage_rate(), 0.0)


func test_blizzard_has_highest_damage_rate() -> void:
	_wm.current_weather = _wm.WeatherType.BLIZZARD
	assert_eq(_wm.get_weather_damage_rate(), 4.0)


func test_snow_damage_rate_less_than_blizzard() -> void:
	_wm.current_weather = _wm.WeatherType.SNOW
	var snow_rate: float = _wm.get_weather_damage_rate()
	_wm.current_weather = _wm.WeatherType.BLIZZARD
	assert_lt(snow_rate, _wm.get_weather_damage_rate())


# ── is_freezing ───────────────────────────────────────────────────────────────

func test_is_freezing_true_at_zero() -> void:
	_wm.current_temperature = 0.0
	assert_true(_wm.is_freezing())


func test_is_freezing_true_below_zero() -> void:
	_wm.current_temperature = -5.0
	assert_true(_wm.is_freezing())


func test_is_freezing_false_above_zero() -> void:
	_wm.current_temperature = 1.0
	assert_false(_wm.is_freezing())


# ── _update_temperature ───────────────────────────────────────────────────────

func test_update_temperature_uses_daytime_base_in_spring() -> void:
	TimeManager.current_season = TimeManager.Season.SPRING
	TimeManager.game_hour = 12  # daytime
	_wm.current_weather = _wm.WeatherType.OVERCAST  # offset = 0
	_wm._update_temperature()
	assert_eq(_wm.current_temperature, _wm.SEASON_DAY_TEMPS[TimeManager.Season.SPRING])


func test_update_temperature_uses_nighttime_base_in_spring() -> void:
	TimeManager.current_season = TimeManager.Season.SPRING
	TimeManager.game_hour = 2  # nighttime
	_wm.current_weather = _wm.WeatherType.OVERCAST  # offset = 0
	_wm._update_temperature()
	assert_eq(_wm.current_temperature, _wm.SEASON_NIGHT_TEMPS[TimeManager.Season.SPRING])


func test_update_temperature_applies_weather_offset() -> void:
	TimeManager.current_season = TimeManager.Season.SPRING
	TimeManager.game_hour = 12
	_wm.current_weather = _wm.WeatherType.CLEAR  # offset = +3
	_wm._update_temperature()
	var expected: float = _wm.SEASON_DAY_TEMPS[TimeManager.Season.SPRING] + 3.0
	assert_eq(_wm.current_temperature, expected)


func test_update_temperature_emits_temperature_changed() -> void:
	TimeManager.current_season = TimeManager.Season.SPRING
	TimeManager.game_hour = 12
	watch_signals(EventBus)
	_wm._update_temperature()
	assert_signal_emitted(EventBus, "temperature_changed")


func test_winter_daytime_temperature_is_very_cold() -> void:
	TimeManager.current_season = TimeManager.Season.WINTER
	TimeManager.game_hour = 12
	_wm.current_weather = _wm.WeatherType.OVERCAST
	_wm._update_temperature()
	assert_lt(_wm.current_temperature, 0.0)


# ── hour_passed triggers temperature update ───────────────────────────────────

func test_hour_passed_triggers_temperature_update() -> void:
	TimeManager.current_season = TimeManager.Season.SPRING
	TimeManager.game_hour = 12
	var before: float = _wm.current_temperature
	TimeManager.game_hour = 2  # switch to night before emitting
	EventBus.hour_passed.emit(2)
	assert_ne(_wm.current_temperature, before)


# ── serialise / deserialise ───────────────────────────────────────────────────

func test_serialise_captures_weather_and_temperature() -> void:
	_wm.current_weather = _wm.WeatherType.SNOW
	_wm.current_temperature = -8.0
	_wm._hours_until_weather_change = 5
	var data: Dictionary = _wm.serialise()
	assert_eq(data["current_weather"], _wm.WeatherType.SNOW)
	assert_eq(data["current_temperature"], -8.0)
	assert_eq(data["hours_until_weather_change"], 5)


func test_deserialise_restores_weather_and_temperature() -> void:
	var data: Dictionary = {
		"current_weather": _wm.WeatherType.BLIZZARD,
		"current_temperature": -20.0,
		"hours_until_weather_change": 3,
	}
	_wm.deserialise(data)
	assert_eq(_wm.current_weather, _wm.WeatherType.BLIZZARD)
	assert_eq(_wm.current_temperature, -20.0)
	assert_eq(_wm._hours_until_weather_change, 3)


func test_deserialise_emits_weather_changed() -> void:
	watch_signals(EventBus)
	_wm.deserialise({
		"current_weather": _wm.WeatherType.RAIN,
		"current_temperature": 4.0,
		"hours_until_weather_change": 6,
	})
	assert_signal_emitted(EventBus, "weather_changed")


func test_deserialise_emits_temperature_changed() -> void:
	watch_signals(EventBus)
	_wm.deserialise({
		"current_weather": _wm.WeatherType.CLEAR,
		"current_temperature": 10.0,
		"hours_until_weather_change": 6,
	})
	assert_signal_emitted(EventBus, "temperature_changed")
