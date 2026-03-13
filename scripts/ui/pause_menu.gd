class_name PauseMenu
extends CanvasLayer

## Pause overlay shown when the game is paused.
## Processes in ALWAYS mode so it remains interactive while the tree is paused.

const _CLICK_SFX: AudioStream = preload("res://assets/audio/menu_click.wav")

@onready var resume_button: Button = $Background/CenterContainer/VBoxContainer/ResumeButton
@onready var save_button: Button = $Background/CenterContainer/VBoxContainer/SaveButton
@onready var menu_button: Button = $Background/CenterContainer/VBoxContainer/MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	EventBus.game_paused.connect(_on_game_paused)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if not touch.pressed:
		return
	if resume_button.get_global_rect().has_point(touch.position):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()
	elif save_button.get_global_rect().has_point(touch.position):
		get_viewport().set_input_as_handled()
		_on_save_pressed()
	elif menu_button.get_global_rect().has_point(touch.position):
		get_viewport().set_input_as_handled()
		_on_menu_pressed()


func _on_game_paused(is_paused: bool) -> void:
	visible = is_paused


func _on_resume_pressed() -> void:
	AudioManager.play_sfx_global(_CLICK_SFX)
	EventBus.game_paused.emit(false)


func _on_save_pressed() -> void:
	AudioManager.play_sfx_global(_CLICK_SFX)
	EventBus.game_paused.emit(false)
	EventBus.ui_screen_opened.emit("save_load")


func _on_menu_pressed() -> void:
	AudioManager.play_sfx_global(_CLICK_SFX)
	get_tree().paused = false
	SceneManager.go_to_main_menu()
