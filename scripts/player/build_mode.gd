class_name BuildMode
extends Node

## Handles player building mode. Press the "build_mode" input action to open
## the build menu. Selecting a recipe places a ghost preview; confirming places
## the structure if the player has the required items.

signal build_menu_opened()
signal build_menu_closed()
signal structure_placed(structure_id: String, world_position: Vector2)

enum BuildState { CLOSED, MENU_OPEN, PLACING }

const PLACEMENT_RANGE: float = 160.0

var player: CharacterBody2D

var _state: BuildState = BuildState.CLOSED
var _selected_recipe: String = ""


func _ready() -> void:
	EventBus.ui_screen_opened.connect(_on_ui_screen_opened)
	var node: Node = get_tree().get_first_node_in_group("player")
	if is_instance_valid(node) and node is CharacterBody2D:
		player = node as CharacterBody2D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_mode"):
		_toggle_menu()
		get_viewport().set_input_as_handled()


func open_menu() -> void:
	if _state != BuildState.CLOSED:
		return
	_state = BuildState.MENU_OPEN
	EventBus.ui_screen_opened.emit("build_menu")
	build_menu_opened.emit()


func close_menu() -> void:
	if _state == BuildState.CLOSED:
		return
	_state = BuildState.CLOSED
	_selected_recipe = ""
	build_menu_closed.emit()


func select_recipe(recipe_id: String) -> void:
	if _state != BuildState.MENU_OPEN:
		return
	_selected_recipe = recipe_id
	_state = BuildState.PLACING


func confirm_placement() -> void:
	if _state != BuildState.PLACING or _selected_recipe.is_empty():
		return
	if not is_instance_valid(player):
		push_error("BuildMode: player reference is invalid")
		return
	var pos: Vector2 = player.global_position
	structure_placed.emit(_selected_recipe, pos)
	_state = BuildState.CLOSED
	_selected_recipe = ""


func _toggle_menu() -> void:
	if _state == BuildState.CLOSED:
		open_menu()
	else:
		close_menu()


func _on_ui_screen_opened(screen_name: String) -> void:
	if screen_name != "build_menu" and _state == BuildState.MENU_OPEN:
		close_menu()
