class_name GameManager
extends Node

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

var current_state: GameState = GameState.MENU


func _ready() -> void:
	EventBus.game_paused.connect(_on_game_paused)


func set_state(new_state: GameState) -> void:
	current_state = new_state


func _on_game_paused(is_paused: bool) -> void:
	if is_paused:
		current_state = GameState.PAUSED
		get_tree().paused = true
	else:
		current_state = GameState.PLAYING
		get_tree().paused = false
