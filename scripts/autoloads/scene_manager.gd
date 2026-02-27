class_name SceneManager
extends Node

const MAIN_MENU_SCENE := "res://scenes/main.tscn"
const LEVEL_01_SCENE := "res://scenes/levels/level_01.tscn"


func go_to_main_menu() -> void:
	get_tree().paused = false
	GameManager.set_state(GameManager.GameState.MENU)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func go_to_level(scene_path: String) -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)
	get_tree().change_scene_to_file(scene_path)


func go_to_level_01() -> void:
	go_to_level(LEVEL_01_SCENE)
