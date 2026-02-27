class_name TimeManager
extends Node

## Advances in-game time and emits signals for all time-dependent systems.
## Real-time seconds per game hour is configurable.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const REAL_SECONDS_PER_GAME_HOUR: float = 60.0
const HOURS_PER_DAY: int = 24
const DAYS_PER_SEASON: int = 28

var game_hour: int = 8
var game_day: int = 1
var current_season: Season = Season.SPRING
var total_days_elapsed: int = 0

var _hour_accumulator: float = 0.0
var _is_paused: bool = false


func _ready() -> void:
	EventBus.hour_passed.connect(_on_hour_passed)


func _process(delta: float) -> void:
	if _is_paused:
		return
	_hour_accumulator += delta
	if _hour_accumulator >= REAL_SECONDS_PER_GAME_HOUR:
		_hour_accumulator -= REAL_SECONDS_PER_GAME_HOUR
		_advance_hour()


func get_season_name() -> String:
	match current_season:
		Season.SPRING: return "Spring"
		Season.SUMMER: return "Summer"
		Season.AUTUMN: return "Autumn"
		Season.WINTER: return "Winter"
	return ""


func is_daytime() -> bool:
	return game_hour >= 6 and game_hour < 21


func set_paused(paused: bool) -> void:
	_is_paused = paused


func serialise() -> Dictionary:
	return {
		"game_hour": game_hour,
		"game_day": game_day,
		"current_season": current_season,
		"total_days_elapsed": total_days_elapsed,
		"hour_accumulator": _hour_accumulator,
	}


func deserialise(data: Dictionary) -> void:
	game_hour = data.get("game_hour", 8)
	game_day = data.get("game_day", 1)
	current_season = data.get("current_season", Season.SPRING) as Season
	total_days_elapsed = data.get("total_days_elapsed", 0)
	_hour_accumulator = data.get("hour_accumulator", 0.0)


func _advance_hour() -> void:
	game_hour = (game_hour + 1) % HOURS_PER_DAY
	EventBus.hour_passed.emit(game_hour)
	if game_hour == 0:
		_advance_day()


func _advance_day() -> void:
	game_day += 1
	total_days_elapsed += 1
	EventBus.day_passed.emit(game_day)
	if game_day > DAYS_PER_SEASON:
		game_day = 1
		_advance_season()


func _advance_season() -> void:
	var next_season_index: int = (current_season + 1) % 4
	current_season = next_season_index as Season
	EventBus.season_changed.emit(current_season)


func _on_hour_passed(_hour: int) -> void:
	pass
