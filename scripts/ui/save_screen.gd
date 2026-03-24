class_name SaveScreen
extends CanvasLayer

## Save / Load slot selection screen.
## Opened via EventBus.ui_screen_opened("save_load"), e.g. from pause menu.

const SLOT_COUNT: int = 3

var _is_open: bool = false

@onready var slots_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/SlotsContainer
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/Footer/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	EventBus.ui_screen_opened.connect(_on_ui_screen_opened)
	close_button.pressed.connect(_close)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if not touch.pressed:
		return
	if close_button != null and close_button.get_global_rect().has_point(touch.position):
		get_viewport().set_input_as_handled()
		_close()


func _on_ui_screen_opened(screen_name: String) -> void:
	if screen_name == "save_load":
		_open()


func _open() -> void:
	if _is_open:
		return
	_is_open = true
	get_tree().paused = true
	_refresh()
	show()


func _close() -> void:
	_is_open = false
	hide()
	get_tree().paused = false
	EventBus.ui_screen_closed.emit("save_load")


func _refresh() -> void:
	if slots_container == null:
		return
	for child: Node in slots_container.get_children():
		child.queue_free()
	for i: int in range(SLOT_COUNT):
		_add_slot_row(i)


func _add_slot_row(slot: int) -> void:
	var has_data: bool = SaveManager.slot_exists(slot)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var slot_label: Label = Label.new()
	slot_label.text = "Slot %d" % (slot + 1)
	slot_label.custom_minimum_size = Vector2(60, 0)
	slot_label.add_theme_font_size_override("font_size", 13)
	row.add_child(slot_label)

	var status_label: Label = Label.new()
	status_label.text = "[Saved]" if has_data else "[Empty]"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.modulate = Color(0.8, 1.0, 0.8, 0.9) if has_data else Color(1.0, 1.0, 1.0, 0.5)
	row.add_child(status_label)

	var save_btn: Button = Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(70, 32)
	save_btn.add_theme_font_size_override("font_size", 12)
	save_btn.pressed.connect(_save_to_slot.bind(slot))
	row.add_child(save_btn)

	var load_btn: Button = Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(70, 32)
	load_btn.add_theme_font_size_override("font_size", 12)
	load_btn.disabled = not has_data
	load_btn.pressed.connect(_load_from_slot.bind(slot))
	row.add_child(load_btn)

	slots_container.add_child(row)


func _save_to_slot(slot: int) -> void:
	SaveManager.save(slot)
	EventBus.journal_entry_added.emit("Game saved to Slot %d." % (slot + 1))
	_refresh()


func _load_from_slot(slot: int) -> void:
	var ok: bool = SaveManager.load_slot(slot)
	if ok:
		EventBus.journal_entry_added.emit("Game loaded from Slot %d." % (slot + 1))
	else:
		push_warning("SaveScreen: failed to load slot %d" % slot)
	_close()
