extends GutTest

# Tests TimeManager time-advance logic in isolation.
# A local instance is used so the global autoload singleton is not mutated.

const _TimeManagerScript := preload("res://scripts/autoloads/time_manager.gd")

var _tm: Node


func before_each() -> void:
	_tm = _TimeManagerScript.new()
	add_child(_tm)


func after_each() -> void:
	_tm.queue_free()


# ── Initial state ─────────────────────────────────────────────────────────────

func test_initial_hour_is_8() -> void:
	assert_eq(_tm.game_hour, 8)


func test_initial_day_is_1() -> void:
	assert_eq(_tm.game_day, 1)


func test_initial_season_is_spring() -> void:
	assert_eq(_tm.current_season, _tm.Season.SPRING)


func test_initial_total_days_is_zero() -> void:
	assert_eq(_tm.total_days_elapsed, 0)


func test_initial_not_paused() -> void:
	assert_false(_tm._is_paused)


# ── is_daytime ────────────────────────────────────────────────────────────────

func test_is_daytime_true_at_hour_6() -> void:
	_tm.game_hour = 6
	assert_true(_tm.is_daytime())


func test_is_daytime_true_at_noon() -> void:
	_tm.game_hour = 12
	assert_true(_tm.is_daytime())


func test_is_daytime_true_at_hour_20() -> void:
	_tm.game_hour = 20
	assert_true(_tm.is_daytime())


func test_is_daytime_false_at_midnight() -> void:
	_tm.game_hour = 0
	assert_false(_tm.is_daytime())


func test_is_daytime_false_at_hour_5() -> void:
	_tm.game_hour = 5
	assert_false(_tm.is_daytime())


func test_is_daytime_false_at_hour_21() -> void:
	_tm.game_hour = 21
	assert_false(_tm.is_daytime())


# ── get_season_name ───────────────────────────────────────────────────────────

func test_get_season_name_spring() -> void:
	_tm.current_season = _tm.Season.SPRING
	assert_eq(_tm.get_season_name(), "Spring")


func test_get_season_name_summer() -> void:
	_tm.current_season = _tm.Season.SUMMER
	assert_eq(_tm.get_season_name(), "Summer")


func test_get_season_name_autumn() -> void:
	_tm.current_season = _tm.Season.AUTUMN
	assert_eq(_tm.get_season_name(), "Autumn")


func test_get_season_name_winter() -> void:
	_tm.current_season = _tm.Season.WINTER
	assert_eq(_tm.get_season_name(), "Winter")


# ── _advance_hour ─────────────────────────────────────────────────────────────

func test_advance_hour_increments_hour() -> void:
	_tm.game_hour = 8
	_tm._advance_hour()
	assert_eq(_tm.game_hour, 9)


func test_advance_hour_emits_hour_passed() -> void:
	_tm.game_hour = 10
	watch_signals(EventBus)
	_tm._advance_hour()
	assert_signal_emitted_with_parameters(EventBus, "hour_passed", [11])


func test_advance_hour_wraps_at_24() -> void:
	_tm.game_hour = 23
	_tm._advance_hour()
	assert_eq(_tm.game_hour, 0)


func test_hour_wrap_triggers_day_advance() -> void:
	_tm.game_hour = 23
	_tm._advance_hour()
	assert_eq(_tm.game_day, 2)


# ── _advance_day ──────────────────────────────────────────────────────────────

func test_advance_day_increments_game_day() -> void:
	_tm.game_day = 5
	_tm._advance_day()
	assert_eq(_tm.game_day, 6)


func test_advance_day_increments_total_days() -> void:
	_tm._advance_day()
	assert_eq(_tm.total_days_elapsed, 1)


func test_advance_day_emits_day_passed() -> void:
	_tm.game_day = 3
	watch_signals(EventBus)
	_tm._advance_day()
	assert_signal_emitted_with_parameters(EventBus, "day_passed", [4])


func test_advance_day_wraps_at_days_per_season() -> void:
	_tm.game_day = _tm.DAYS_PER_SEASON
	_tm._advance_day()
	assert_eq(_tm.game_day, 1)


func test_day_wrap_triggers_season_advance() -> void:
	_tm.game_day = _tm.DAYS_PER_SEASON
	_tm._advance_day()
	assert_eq(_tm.current_season, _tm.Season.SUMMER)


# ── _advance_season ───────────────────────────────────────────────────────────

func test_advance_season_from_spring_to_summer() -> void:
	_tm.current_season = _tm.Season.SPRING
	_tm._advance_season()
	assert_eq(_tm.current_season, _tm.Season.SUMMER)


func test_advance_season_from_autumn_to_winter() -> void:
	_tm.current_season = _tm.Season.AUTUMN
	_tm._advance_season()
	assert_eq(_tm.current_season, _tm.Season.WINTER)


func test_advance_season_wraps_winter_to_spring() -> void:
	_tm.current_season = _tm.Season.WINTER
	_tm._advance_season()
	assert_eq(_tm.current_season, _tm.Season.SPRING)


func test_advance_season_emits_season_changed() -> void:
	_tm.current_season = _tm.Season.SPRING
	watch_signals(EventBus)
	_tm._advance_season()
	assert_signal_emitted_with_parameters(EventBus, "season_changed", [_tm.Season.SUMMER])


# ── set_paused ────────────────────────────────────────────────────────────────

func test_set_paused_true_sets_flag() -> void:
	_tm.set_paused(true)
	assert_true(_tm._is_paused)


func test_set_paused_false_clears_flag() -> void:
	_tm.set_paused(true)
	_tm.set_paused(false)
	assert_false(_tm._is_paused)


func test_paused_process_does_not_accumulate() -> void:
	_tm.set_paused(true)
	_tm._process(50.0)
	assert_eq(_tm._hour_accumulator, 0.0)


# ── serialise / deserialise ───────────────────────────────────────────────────

func test_serialise_captures_all_time_state() -> void:
	_tm.game_hour = 14
	_tm.game_day = 7
	_tm.current_season = _tm.Season.AUTUMN
	_tm.total_days_elapsed = 63
	_tm._hour_accumulator = 30.0
	var data: Dictionary = _tm.serialise()
	assert_eq(data["game_hour"], 14)
	assert_eq(data["game_day"], 7)
	assert_eq(data["current_season"], _tm.Season.AUTUMN)
	assert_eq(data["total_days_elapsed"], 63)
	assert_eq(data["hour_accumulator"], 30.0)


func test_deserialise_restores_time_state() -> void:
	var data: Dictionary = {
		"game_hour": 20,
		"game_day": 15,
		"current_season": _tm.Season.WINTER,
		"total_days_elapsed": 99,
		"hour_accumulator": 10.0,
	}
	_tm.deserialise(data)
	assert_eq(_tm.game_hour, 20)
	assert_eq(_tm.game_day, 15)
	assert_eq(_tm.current_season, _tm.Season.WINTER)
	assert_eq(_tm.total_days_elapsed, 99)
	assert_eq(_tm._hour_accumulator, 10.0)
