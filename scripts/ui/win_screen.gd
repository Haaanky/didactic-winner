class_name WinScreen
extends Control

## Displayed when the player survives the required number of days.
## Handles mouse click, keyboard Enter, and touch tap on the button.

const _CLICK_SFX: AudioStream = preload("res://assets/audio/menu_click.wav")

@onready var stats_label: Label = $CenterContainer/VBoxContainer/StatsLabel
@onready var play_again_button: Button = $CenterContainer/VBoxContainer/PlayAgainButton


func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again_pressed)
	var days: int = TimeManager.total_days_elapsed
	var season: String = TimeManager.get_season_name()
	stats_label.text = "Survived %d days\nSeason: %s" % [days, season]


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if not touch.pressed:
		return
	if play_again_button.get_global_rect().has_point(touch.position):
		get_viewport().set_input_as_handled()
		_on_play_again_pressed()


func _on_play_again_pressed() -> void:
	AudioManager.play_sfx_global(_CLICK_SFX)
	SceneManager.go_to_main_menu()
