class_name DayNightLayer
extends CanvasModulate

## Modulates the entire scene colour to simulate day/night lighting.
## Colour interpolates smoothly over in-game hours.

const HOUR_COLOURS: Dictionary = {
	0: Color(0.05, 0.05, 0.15),   # midnight — deep blue-black
	4: Color(0.08, 0.08, 0.20),   # pre-dawn
	5: Color(0.30, 0.20, 0.25),   # dawn
	6: Color(0.70, 0.55, 0.45),   # sunrise — warm orange
	8: Color(1.00, 1.00, 1.00),   # morning — full daylight
	12: Color(1.00, 1.00, 0.95),  # noon — slightly warm white
	17: Color(1.00, 0.95, 0.80),  # late afternoon — golden
	19: Color(0.90, 0.65, 0.45),  # sunset
	20: Color(0.45, 0.30, 0.45),  # dusk
	21: Color(0.15, 0.12, 0.25),  # early night
	22: Color(0.08, 0.07, 0.18),  # night
}

const WINTER_DARKNESS_OFFSET: float = 0.15


func _ready() -> void:
	EventBus.hour_passed.connect(_on_hour_passed)
	EventBus.season_changed.connect(_on_season_changed)
	_update_colour(TimeManager.game_hour)


func _on_hour_passed(hour: int) -> void:
	_update_colour(hour)


func _on_season_changed(_season: int) -> void:
	_update_colour(TimeManager.game_hour)


func _update_colour(hour: int) -> void:
	var target_colour: Color = _sample_colour(hour)
	if TimeManager.current_season == TimeManager.Season.WINTER:
		target_colour = target_colour.darkened(WINTER_DARKNESS_OFFSET)
	var tween: Tween = create_tween()
	tween.tween_property(self, "color", target_colour, 4.0)


func _sample_colour(hour: int) -> Color:
	var hours: Array = HOUR_COLOURS.keys()
	hours.sort()
	var prev_hour: int = hours[0]
	var next_hour: int = hours[0]
	for h: int in hours:
		if h <= hour:
			prev_hour = h
		if h > hour and next_hour == hours[0]:
			next_hour = h
	if prev_hour == next_hour:
		return HOUR_COLOURS[prev_hour]
	var span: float = float(next_hour - prev_hour)
	var t: float = float(hour - prev_hour) / span
	return HOUR_COLOURS[prev_hour].lerp(HOUR_COLOURS[next_hour], t)
