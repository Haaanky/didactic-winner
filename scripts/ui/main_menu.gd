class_name MainMenu
extends Control

## Handles main menu navigation for both mouse/keyboard and touch input.
## Touch is handled explicitly via _input() because Godot 4 web export does not
## reliably convert InputEventScreenTouch to mouse events through the GUI system.

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

var _transitioning: bool = false


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _input(event: InputEvent) -> void:
	if _transitioning or not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if not touch.pressed:
		return
	if play_button.get_global_rect().has_point(touch.position):
		get_viewport().set_input_as_handled()
		_on_play_pressed()
	elif quit_button.get_global_rect().has_point(touch.position):
		get_viewport().set_input_as_handled()
		_on_quit_pressed()


func _on_play_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	SceneManager.go_to_level_01()


func _on_quit_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	get_tree().quit()
