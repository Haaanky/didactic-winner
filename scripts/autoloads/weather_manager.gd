class_name WeatherManager
extends Node

## Manages ambient temperature and weather events.
## Temperature and weather affect needs drain rates and gameplay conditions.

enum WeatherType { CLEAR, OVERCAST, RAIN, SNOW, BLIZZARD }

const SEASON_DAY_TEMPS: Array[float] = [8.0, 18.0, 2.0, -15.0]
const SEASON_NIGHT_TEMPS: Array[float] = [-5.0, 5.0, -10.0, -28.0]
const WEATHER_OFFSETS: Dictionary = {
	WeatherType.CLEAR: 3.0,
	WeatherType.OVERCAST: 0.0,
	WeatherType.RAIN: -2.0,
	WeatherType.SNOW: -5.0,
	WeatherType.BLIZZARD: -10.0,
}

const WEATHER_DAMAGE_RATES: Dictionary = {
	WeatherType.CLEAR: 0.0,
	WeatherType.OVERCAST: 0.0,
	WeatherType.RAIN: 1.0,
	WeatherType.SNOW: 1.5,
	WeatherType.BLIZZARD: 4.0,
}

var current_temperature: float = 15.0
var current_weather: WeatherType = WeatherType.CLEAR

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hours_until_weather_change: int = 6


func _ready() -> void:
	_rng.randomize()
	EventBus.hour_passed.connect(_on_hour_passed)
	EventBus.season_changed.connect(_on_season_changed)


func get_weather_damage_rate() -> float:
	return WEATHER_DAMAGE_RATES.get(current_weather, 0.0)


func is_freezing() -> bool:
	return current_temperature <= 0.0


func serialise() -> Dictionary:
	return {
		"current_weather": current_weather,
		"current_temperature": current_temperature,
		"hours_until_weather_change": _hours_until_weather_change,
	}


func deserialise(data: Dictionary) -> void:
	current_weather = data.get("current_weather", WeatherType.CLEAR) as WeatherType
	current_temperature = data.get("current_temperature", 15.0)
	_hours_until_weather_change = data.get("hours_until_weather_change", 6)
	EventBus.weather_changed.emit(current_weather)
	EventBus.temperature_changed.emit(current_temperature)


func _update_temperature() -> void:
	var season_index: int = TimeManager.current_season
	var base_temp: float
	if TimeManager.is_daytime():
		base_temp = SEASON_DAY_TEMPS[season_index]
	else:
		base_temp = SEASON_NIGHT_TEMPS[season_index]
	current_temperature = base_temp + WEATHER_OFFSETS.get(current_weather, 0.0)
	EventBus.temperature_changed.emit(current_temperature)


func _roll_weather_change() -> void:
	var season: int = TimeManager.current_season
	var new_weather: WeatherType = _pick_weather_for_season(season)
	if new_weather != current_weather:
		current_weather = new_weather
		EventBus.weather_changed.emit(current_weather)
	_hours_until_weather_change = _rng.randi_range(4, 12)


func _pick_weather_for_season(season: int) -> WeatherType:
	match season:
		TimeManager.Season.SPRING:
			var roll: int = _rng.randi_range(0, 9)
			if roll < 5: return WeatherType.CLEAR
			elif roll < 8: return WeatherType.OVERCAST
			else: return WeatherType.RAIN
		TimeManager.Season.SUMMER:
			var roll: int = _rng.randi_range(0, 9)
			if roll < 7: return WeatherType.CLEAR
			elif roll < 9: return WeatherType.OVERCAST
			else: return WeatherType.RAIN
		TimeManager.Season.AUTUMN:
			var roll: int = _rng.randi_range(0, 9)
			if roll < 3: return WeatherType.CLEAR
			elif roll < 6: return WeatherType.OVERCAST
			elif roll < 8: return WeatherType.RAIN
			else: return WeatherType.SNOW
		TimeManager.Season.WINTER:
			var roll: int = _rng.randi_range(0, 9)
			if roll < 2: return WeatherType.CLEAR
			elif roll < 4: return WeatherType.OVERCAST
			elif roll < 7: return WeatherType.SNOW
			else: return WeatherType.BLIZZARD
	return WeatherType.CLEAR


func _on_hour_passed(_hour: int) -> void:
	_update_temperature()
	_hours_until_weather_change -= 1
	if _hours_until_weather_change <= 0:
		_roll_weather_change()


func _on_season_changed(_season: int) -> void:
	_roll_weather_change()
	_update_temperature()
