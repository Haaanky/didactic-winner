class_name MainMenu
extends Control

## Handles main menu navigation for both mouse/keyboard and touch input.
## Touch is handled explicitly via _input() because Godot 4 web export does not
## reliably convert InputEventScreenTouch to mouse events through the GUI system.

const _CLICK_SFX: AudioStream = preload("res://assets/audio/menu_click.wav")

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var easy_button: Button = $CenterContainer/VBoxContainer/DifficultyRow/EasyButton
@onready var normal_button: Button = $CenterContainer/VBoxContainer/DifficultyRow/NormalButton
@onready var hardcore_button: Button = $CenterContainer/VBoxContainer/DifficultyRow/HardcoreButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	easy_button.pressed.connect(_on_easy_pressed)
	normal_button.pressed.connect(_on_normal_pressed)
	hardcore_button.pressed.connect(_on_hardcore_pressed)
	_check_test_goto()


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
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
	elif easy_button.get_global_rect().has_point(touch.position):
		get_viewport().set_input_as_handled()
		_on_easy_pressed()
	elif normal_button.get_global_rect().has_point(touch.position):
		get_viewport().set_input_as_handled()
		_on_normal_pressed()
	elif hardcore_button.get_global_rect().has_point(touch.position):
		get_viewport().set_input_as_handled()
		_on_hardcore_pressed()


func _on_play_pressed() -> void:
	AudioManager.play_sfx_global(_CLICK_SFX)
	SceneManager.go_to_level_01()


func _on_quit_pressed() -> void:
	AudioManager.play_sfx_global(_CLICK_SFX)
	get_tree().quit()


func _on_easy_pressed() -> void:
	AudioManager.play_sfx_global(_CLICK_SFX)
	GameManager.set_difficulty(GameManager.DifficultyMode.EASY)


func _on_normal_pressed() -> void:
	AudioManager.play_sfx_global(_CLICK_SFX)
	GameManager.set_difficulty(GameManager.DifficultyMode.NORMAL)


func _on_hardcore_pressed() -> void:
	AudioManager.play_sfx_global(_CLICK_SFX)
	GameManager.set_difficulty(GameManager.DifficultyMode.HARDCORE)


func _check_test_goto() -> void:
	if not OS.has_feature("web"):
		return
	var goto: String = JavaScriptBridge.eval(
		"new URL(window.location.href).searchParams.get('goto') || ''"
	)
	if goto == "gameover":
		SceneManager.go_to_game_over()
