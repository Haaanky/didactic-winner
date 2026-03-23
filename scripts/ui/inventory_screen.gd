class_name InventoryScreen
extends CanvasLayer

## Full-screen inventory overlay.
## Press I (or the inventory input action) to open/close.
## Shows items with names, quantity, weight, and allows consuming food or dropping items.

const _CLICK_SFX: AudioStream = preload("res://assets/audio/menu_click.wav")

@export var player: PlayerController

@onready var background: Panel = $Background
@onready var item_list: VBoxContainer = $Background/MarginContainer/VBoxContainer/ScrollContainer/ItemList
@onready var weight_label: Label = $Background/MarginContainer/VBoxContainer/FooterRow/WeightLabel
@onready var close_button: Button = $Background/MarginContainer/VBoxContainer/HeaderRow/CloseButton
@onready var craft_button: Button = $Background/MarginContainer/VBoxContainer/FooterRow/CraftButton
@onready var scroll_container: ScrollContainer = $Background/MarginContainer/VBoxContainer/ScrollContainer
@onready var hint_label: Label = $Background/MarginContainer/VBoxContainer/HintLabel

var _is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	close_button.pressed.connect(_close)
	craft_button.pressed.connect(_open_crafting)
	EventBus.ui_screen_opened.connect(_on_ui_screen_opened)
	EventBus.ui_screen_closed.connect(_on_ui_screen_closed)


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if craft_button.get_global_rect().has_point(mb.position):
				get_viewport().set_input_as_handled()
				_open_crafting()
			elif close_button.get_global_rect().has_point(mb.position):
				get_viewport().set_input_as_handled()
				_close()
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


func open() -> void:
	if _is_open:
		return
	_is_open = true
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
	EventBus.ui_screen_closed.emit("inventory")


func _open_crafting() -> void:
	AudioManager.play_sfx_global(_CLICK_SFX)
	_close()
	EventBus.crafting_opened.emit(false)


func _refresh() -> void:
	for child: Node in item_list.get_children():
		child.queue_free()
	if not is_instance_valid(player) or player.inventory == null:
		return
	var inv: InventoryComponent = player.inventory
	var sorted_ids: Array = inv.items.keys()
	sorted_ids.sort()
	for item_id: String in sorted_ids:
		var data: Dictionary = inv.items[item_id]
		var qty: int = int(data.get("quantity", 0))
		var wpu: float = float(data.get("weight_per_unit", 0.0))
		_add_item_row(item_id, qty, wpu)
	var total: float = snapped(inv.total_weight, 0.1)
	weight_label.text = "Weight: %.1f / %.0f kg" % [total, InventoryComponent.MAX_WEIGHT]
	if inv.items.is_empty():
		hint_label.text = "Your pack is empty. Explore the wilderness!"
	else:
		hint_label.text = "[F] eats best food  •  [I] closes inventory  •  [Craft] opens crafting"


func _add_item_row(item_id: String, qty: int, weight_per_unit: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl: Label = Label.new()
	name_lbl.text = ItemDatabase.get_display_name(item_id)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(name_lbl)

	var qty_lbl: Label = Label.new()
	qty_lbl.text = "x%d" % qty
	qty_lbl.custom_minimum_size = Vector2(36, 0)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(qty_lbl)

	var wt_lbl: Label = Label.new()
	wt_lbl.text = "%.1f kg" % (qty * weight_per_unit)
	wt_lbl.custom_minimum_size = Vector2(52, 0)
	wt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wt_lbl.add_theme_font_size_override("font_size", 11)
	wt_lbl.modulate = Color(1.0, 1.0, 1.0, 0.65)
	row.add_child(wt_lbl)

	if ItemDatabase.is_food(item_id):
		var eat_btn: Button = Button.new()
		eat_btn.text = "Eat"
		eat_btn.custom_minimum_size = Vector2(44, 0)
		eat_btn.add_theme_font_size_override("font_size", 12)
		eat_btn.pressed.connect(_consume_item.bind(item_id))
		row.add_child(eat_btn)

	var drop_btn: Button = Button.new()
	drop_btn.text = "Drop"
	drop_btn.custom_minimum_size = Vector2(44, 0)
	drop_btn.add_theme_font_size_override("font_size", 12)
	drop_btn.pressed.connect(_drop_item.bind(item_id))
	row.add_child(drop_btn)

	item_list.add_child(row)


func _consume_item(item_id: String) -> void:
	if not is_instance_valid(player):
		return
	if not ItemDatabase.is_food(item_id):
		return
	if player.inventory == null or not player.inventory.has_item(item_id):
		return
	var food_value: float = ItemDatabase.get_food_value(item_id)
	var warmth_value: float = ItemDatabase.get_warmth_value(item_id)
	player.inventory.remove_item(item_id, 1)
	if player.needs != null:
		player.needs.restore_need("hunger", food_value)
		if warmth_value > 0.0:
			player.needs.restore_need("warmth", warmth_value)
	EventBus.item_consumed.emit(item_id, food_value)
	EventBus.journal_entry_added.emit("Ate %s." % ItemDatabase.get_display_name(item_id))
	AudioManager.play_sfx_global(_CLICK_SFX)
	_refresh()


func _drop_item(item_id: String) -> void:
	if not is_instance_valid(player) or player.inventory == null:
		return
	player.inventory.remove_item(item_id, 1)
	EventBus.journal_entry_added.emit("Dropped %s." % ItemDatabase.get_display_name(item_id))
	AudioManager.play_sfx_global(_CLICK_SFX)
	_refresh()


func _on_ui_screen_opened(screen_name: String) -> void:
	if screen_name == "inventory":
		open()


func _on_ui_screen_closed(screen_name: String) -> void:
	if screen_name == "inventory" and _is_open:
		_close()
