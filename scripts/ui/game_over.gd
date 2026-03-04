class_name GameOverScreen
extends Control

## Displayed when the player dies. Shows days survived and a return button.
## Handles mouse click, keyboard Enter, and touch tap on the button.

const _CLICK_SFX: AudioStream = preload("res://assets/audio/menu_click.wav")

@onready var days_label: Label = $CenterContainer/VBoxContainer/DaysLabel
@onready var retry_button: Button = $CenterContainer/VBoxContainer/RetryButton


func _ready() -> void:
	retry_button.pressed.connect(_on_retry_pressed)
	var days: int = TimeManager.total_days_elapsed
	days_label.text = "You survived %d day%s." % [days, "" if days == 1 else "s"]


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if not touch.pressed:
		return
	if retry_button.get_global_rect().has_point(touch.position):
		get_viewport().set_input_as_handled()
		_on_retry_pressed()


func _on_retry_pressed() -> void:
	AudioManager.play_sfx_global(_CLICK_SFX)
	SceneManager.go_to_main_menu()
