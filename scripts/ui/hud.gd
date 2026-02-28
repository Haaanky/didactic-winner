class_name HUD
extends CanvasLayer

## Diegetic-first HUD. Needs bars are hidden by default.
## Critical icons appear when any need drops below 20%.
## Pressing "check_needs" shows the full needs panel for a few seconds.
## Health bar updates via EventBus.player_health_changed.

const DISPLAY_DURATION: float = 4.0
const CRITICAL_THRESHOLD: float = 20.0
const HEALTH_MAX: float = 100.0

@export var needs_panel: Control
@export var hunger_bar: ProgressBar
@export var warmth_bar: ProgressBar
@export var rest_bar: ProgressBar
@export var morale_bar: ProgressBar
@export var health_bar: ProgressBar
@export var health_label: Label
@export var critical_icons: Control
@export var hunger_critical_icon: TextureRect
@export var warmth_critical_icon: TextureRect
@export var rest_critical_icon: TextureRect
@export var morale_critical_icon: TextureRect
@export var season_day_label: Label

var _hide_timer: float = 0.0
var _showing_needs: bool = false


func _ready() -> void:
	EventBus.need_changed.connect(_on_need_changed)
	EventBus.need_critical.connect(_on_need_critical)
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.hour_passed.connect(_on_hour_passed)
	EventBus.ui_screen_opened.connect(_on_ui_screen_opened)
	if needs_panel != null:
		needs_panel.hide()
	_refresh_health(HEALTH_MAX)


func _process(delta: float) -> void:
	if _showing_needs:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_showing_needs = false
			if needs_panel != null:
				needs_panel.hide()


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


func _on_hour_passed(_hour: int) -> void:
	if season_day_label != null:
		var season_name: String = TimeManager.get_season_name()
		season_day_label.text = "%s — Day %d" % [season_name, TimeManager.game_day]


func _on_ui_screen_opened(screen_name: String) -> void:
	if screen_name == "needs_hud":
		_show_needs_panel()
