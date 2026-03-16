class_name BuildMenu
extends Control

## Displayed when the player presses the build_mode action.
## Lists buildable structures. Selecting one enters placement mode.

signal recipe_selected(recipe_id: String)

const RECIPES: Array[Dictionary] = [
	{"id": "campfire", "label": "Campfire", "desc": "Warmth and cooking. Costs: 5x Wood."},
	{"id": "shelter",  "label": "Lean-to Shelter", "desc": "Rest spot. Costs: 8x Wood, 2x Rope."},
	{"id": "trap",     "label": "Snare Trap", "desc": "Catches small animals. Costs: 3x Rope."},
]

@onready var recipe_list: ItemList = $Background/MarginContainer/VBoxContainer/RecipeList
@onready var desc_label: Label = $Background/MarginContainer/VBoxContainer/DescLabel
@onready var build_button: Button = $Background/MarginContainer/VBoxContainer/FooterRow/BuildButton
@onready var close_button: Button = $Background/MarginContainer/VBoxContainer/FooterRow/CloseButton

var _selected_index: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	recipe_list.item_selected.connect(_on_item_selected)
	build_button.pressed.connect(_on_build_pressed)
	close_button.pressed.connect(_on_close_pressed)
	_populate_list()
	hide()
	EventBus.ui_screen_opened.connect(_on_ui_screen_opened)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		if close_button.get_global_rect().has_point(touch.position):
			get_viewport().set_input_as_handled()
			_on_close_pressed()
		elif build_button.get_global_rect().has_point(touch.position):
			get_viewport().set_input_as_handled()
			_on_build_pressed()


func _populate_list() -> void:
	recipe_list.clear()
	for recipe in RECIPES:
		recipe_list.add_item(recipe["label"])


func open() -> void:
	_selected_index = -1
	if desc_label != null:
		desc_label.text = "Select a structure to build."
	show()


func close() -> void:
	hide()


func _on_item_selected(index: int) -> void:
	_selected_index = index
	if index >= 0 and index < RECIPES.size() and desc_label != null:
		desc_label.text = RECIPES[index]["desc"]


func _on_build_pressed() -> void:
	if _selected_index < 0 or _selected_index >= RECIPES.size():
		return
	recipe_selected.emit(RECIPES[_selected_index]["id"])
	close()


func _on_close_pressed() -> void:
	close()


func _on_ui_screen_opened(screen_name: String) -> void:
	if screen_name == "build_menu":
		open()
	elif visible:
		close()
