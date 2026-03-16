class_name CraftingScreen
extends CanvasLayer

## Crafting screen. Shows available recipes filtered by context.
## Opens from campfire (at_campfire=true) or from inventory (at_campfire=false).
## Campfire recipes are only shown when at_campfire is true.

const _CLICK_SFX: AudioStream = preload("res://assets/audio/menu_click.wav")

@export var player: PlayerController

@onready var recipe_list: VBoxContainer = $Background/MarginContainer/VBoxContainer/ScrollContainer/RecipeList
@onready var close_button: Button = $Background/MarginContainer/VBoxContainer/HeaderRow/CloseButton
@onready var context_label: Label = $Background/MarginContainer/VBoxContainer/ContextLabel
@onready var hint_label: Label = $Background/MarginContainer/VBoxContainer/HintLabel

var _is_open: bool = false
var _at_campfire: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	close_button.pressed.connect(_close)
	EventBus.crafting_opened.connect(_on_crafting_opened)
	EventBus.crafting_closed.connect(_close)


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and close_button.get_global_rect().has_point(touch.position):
			get_viewport().set_input_as_handled()
			_close()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("open_inventory") or event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()


func open(at_campfire: bool) -> void:
	if _is_open:
		return
	_is_open = true
	_at_campfire = at_campfire
	get_tree().paused = true
	_refresh()
	show()


func _close() -> void:
	if not _is_open:
		return
	AudioManager.play_sfx_global(_CLICK_SFX)
	_is_open = false
	get_tree().paused = false
	hide()
	EventBus.crafting_closed.emit()


func _refresh() -> void:
	for child: Node in recipe_list.get_children():
		child.queue_free()
	if not is_instance_valid(player) or player.inventory == null:
		return
	if _at_campfire:
		context_label.text = "Campfire Crafting"
		hint_label.text = "Cook food and preserve items at the campfire."
	else:
		context_label.text = "Field Crafting"
		hint_label.text = "Craft basic tools and supplies without fire."
	var craftable_ids: Array[String] = ItemDatabase.get_all_craftable_ids()
	craftable_ids.sort()
	for output_id: String in craftable_ids:
		var recipe: Dictionary = ItemDatabase.get_recipe(output_id)
		var needs_campfire: bool = bool(recipe.get("campfire", false))
		if needs_campfire and not _at_campfire:
			continue
		if not needs_campfire and _at_campfire:
			continue
		_add_recipe_row(output_id, recipe)


func _add_recipe_row(output_id: String, recipe: Dictionary) -> void:
	var can_make: bool = ItemDatabase.can_craft(output_id, player.inventory, _at_campfire)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var info_col: VBoxContainer = VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 2)

	var name_lbl: Label = Label.new()
	name_lbl.text = ItemDatabase.get_display_name(output_id)
	name_lbl.add_theme_font_size_override("font_size", 13)
	if not can_make:
		name_lbl.modulate = Color(0.6, 0.6, 0.6, 1.0)
	info_col.add_child(name_lbl)

	var ingredients: Dictionary = recipe.get("ingredients", {})
	var ing_parts: Array[String] = []
	for ing_id: String in ingredients.keys():
		var needed: int = int(ingredients[ing_id])
		var have: int = player.inventory.get_quantity(ing_id)
		var ing_name: String = ItemDatabase.get_display_name(ing_id)
		ing_parts.append("%d/%d %s" % [mini(have, needed), needed, ing_name])
	var req_lbl: Label = Label.new()
	req_lbl.text = "Needs: " + ", ".join(ing_parts)
	req_lbl.add_theme_font_size_override("font_size", 11)
	req_lbl.modulate = Color(1.0, 1.0, 1.0, 0.65)
	info_col.add_child(req_lbl)

	row.add_child(info_col)

	var craft_btn: Button = Button.new()
	craft_btn.text = "Craft"
	craft_btn.custom_minimum_size = Vector2(56, 0)
	craft_btn.disabled = not can_make
	craft_btn.add_theme_font_size_override("font_size", 12)
	craft_btn.pressed.connect(_craft_item.bind(output_id))
	row.add_child(craft_btn)

	recipe_list.add_child(row)

	var sep: HSeparator = HSeparator.new()
	recipe_list.add_child(sep)


func _craft_item(output_id: String) -> void:
	if not is_instance_valid(player) or player.inventory == null:
		return
	var success: bool = ItemDatabase.craft(output_id, player.inventory, _at_campfire)
	if success:
		AudioManager.play_sfx_global(_CLICK_SFX)
		EventBus.item_crafted.emit(output_id)
		_refresh()


func _on_crafting_opened(at_campfire: bool) -> void:
	open(at_campfire)
