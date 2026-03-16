class_name HUD
extends CanvasLayer

## Diegetic-first HUD. Needs bars are hidden by default.
## Critical icons appear when any need drops below 20%.
## Pressing "check_needs" shows the full needs panel for a few seconds.
## Health bar, time, weather, stamina, and journal notifications update via EventBus.

const DISPLAY_DURATION: float = 4.0
const CRITICAL_THRESHOLD: float = 20.0
const HEALTH_MAX: float = 100.0
const STAMINA_MAX: float = 100.0
const JOURNAL_DISPLAY_DURATION: float = 3.5

@onready var needs_panel: Control = $NeedsPanel
@onready var hunger_bar: ProgressBar = $NeedsPanel/MarginContainer/VBoxContainer/HungerRow/HungerBar
@onready var warmth_bar: ProgressBar = $NeedsPanel/MarginContainer/VBoxContainer/WarmthRow/WarmthBar
@onready var rest_bar: ProgressBar = $NeedsPanel/MarginContainer/VBoxContainer/RestRow/RestBar
@onready var morale_bar: ProgressBar = $NeedsPanel/MarginContainer/VBoxContainer/MoraleRow/MoraleBar
@onready var health_bar: ProgressBar = $HealthPanel/VBoxContainer/HealthBar
@onready var health_label: Label = $HealthPanel/VBoxContainer/HealthLabel
@onready var stamina_bar: ProgressBar = $HealthPanel/VBoxContainer/StaminaBar
@onready var critical_icons: Control = $CriticalIcons
@onready var hunger_critical_icon: TextureRect = $CriticalIcons/HungerCriticalIcon
@onready var warmth_critical_icon: TextureRect = $CriticalIcons/WarmthCriticalIcon
@onready var rest_critical_icon: TextureRect = $CriticalIcons/RestCriticalIcon
@onready var morale_critical_icon: TextureRect = $CriticalIcons/MoraleCriticalIcon
@onready var season_day_label: Label = $InfoPanel/VBoxContainer/SeasonDayLabel
@onready var time_label: Label = $InfoPanel/VBoxContainer/TimeLabel
@onready var weather_label: Label = $InfoPanel/VBoxContainer/WeatherLabel
@onready var journal_notification: Label = $JournalNotification
@onready var interact_prompt_label: Label = $InteractPromptLabel

var _hide_timer: float = 0.0
var _showing_needs: bool = false
var _journal_timer: float = 0.0
var _journal_queue: Array[String] = []


func _ready() -> void:
	EventBus.need_changed.connect(_on_need_changed)
	EventBus.need_critical.connect(_on_need_critical)
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.hour_passed.connect(_on_hour_passed)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.temperature_changed.connect(_on_temperature_changed)
	EventBus.ui_screen_opened.connect(_on_ui_screen_opened)
	EventBus.journal_entry_added.connect(_on_journal_entry_added)
	EventBus.interact_prompt_changed.connect(_on_interact_prompt_changed)
	if needs_panel != null:
		needs_panel.hide()
	if journal_notification != null:
		journal_notification.hide()
	if stamina_bar != null:
		stamina_bar.hide()
	if interact_prompt_label != null:
		interact_prompt_label.hide()
	_refresh_health(HEALTH_MAX)
	_refresh_time(TimeManager.game_hour)
	_refresh_weather_display()


func _process(delta: float) -> void:
	if _showing_needs:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_showing_needs = false
			if needs_panel != null:
				needs_panel.hide()
	if _journal_timer > 0.0:
		_journal_timer -= delta
		if _journal_timer <= 0.0:
			_journal_timer = 0.0
			if not _journal_queue.is_empty():
				_journal_queue.pop_front()
				if _journal_queue.is_empty():
					if journal_notification != null:
						journal_notification.hide()
				else:
					_show_next_journal_entry()


func _show_needs_panel() -> void:
	_showing_needs = true
	_hide_timer = DISPLAY_DURATION
	if needs_panel != null:
		needs_panel.show()


func _refresh_health(value: float) -> void:
	if health_bar != null:
		health_bar.value = value
	if health_label != null:
		health_label.text = "Health: %d" % int(value)


func _refresh_time(hour: int) -> void:
	if time_label == null:
		return
	var am_pm: String = "AM" if hour < 12 else "PM"
	var display_hour: int = hour % 12
	if display_hour == 0:
		display_hour = 12
	time_label.text = "%d:00 %s" % [display_hour, am_pm]


func _refresh_weather_display() -> void:
	if weather_label == null:
		return
	var weather_name: String = _get_weather_name(WeatherManager.current_weather)
	var temp: int = int(WeatherManager.current_temperature)
	weather_label.text = "%s, %d°C" % [weather_name, temp]


func _get_weather_name(weather: int) -> String:
	match weather:
		WeatherManager.WeatherType.CLEAR: return "Clear"
		WeatherManager.WeatherType.OVERCAST: return "Overcast"
		WeatherManager.WeatherType.RAIN: return "Rain"
		WeatherManager.WeatherType.SNOW: return "Snow"
		WeatherManager.WeatherType.BLIZZARD: return "Blizzard"
	return "Clear"


func _show_next_journal_entry() -> void:
	if _journal_queue.is_empty():
		return
	if journal_notification != null:
		journal_notification.text = _journal_queue[0]
		journal_notification.show()
	_journal_timer = JOURNAL_DISPLAY_DURATION


func _on_need_changed(need: String, value: float) -> void:
	match need:
		"hunger":
			if hunger_bar != null:
				hunger_bar.value = value
			if hunger_critical_icon != null:
				hunger_critical_icon.visible = value <= CRITICAL_THRESHOLD
		"warmth":
			if warmth_bar != null:
				warmth_bar.value = value
			if warmth_critical_icon != null:
				warmth_critical_icon.visible = value <= CRITICAL_THRESHOLD
		"rest":
			if rest_bar != null:
				rest_bar.value = value
			if rest_critical_icon != null:
				rest_critical_icon.visible = value <= CRITICAL_THRESHOLD
		"morale":
			if morale_bar != null:
				morale_bar.value = value
			if morale_critical_icon != null:
				morale_critical_icon.visible = value <= CRITICAL_THRESHOLD


func _on_need_critical(_need: String) -> void:
	_show_needs_panel()


func _on_player_health_changed(value: float) -> void:
	_refresh_health(value)


func _on_stamina_changed(value: float) -> void:
	if stamina_bar == null:
		return
	stamina_bar.value = value
	stamina_bar.visible = value < STAMINA_MAX


func _on_hour_passed(hour: int) -> void:
	if season_day_label != null:
		var season_name: String = TimeManager.get_season_name()
		season_day_label.text = "%s — Day %d" % [season_name, TimeManager.game_day]
	_refresh_time(hour)


func _on_weather_changed(_weather_type: int) -> void:
	_refresh_weather_display()


func _on_temperature_changed(_temp: float) -> void:
	_refresh_weather_display()


func _on_ui_screen_opened(screen_name: String) -> void:
	if screen_name == "needs_hud":
		_show_needs_panel()


func _on_journal_entry_added(entry: String) -> void:
	_journal_queue.append(entry)
	if _journal_timer <= 0.0:
		_show_next_journal_entry()


func _on_interact_prompt_changed(prompt: String) -> void:
	if interact_prompt_label == null:
		return
	if prompt.is_empty():
		interact_prompt_label.hide()
	else:
		interact_prompt_label.text = prompt
		interact_prompt_label.show()
