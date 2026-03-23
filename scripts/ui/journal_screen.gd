class_name JournalScreen
extends CanvasLayer

## Scrollable log of all journal entries. Opened with open_journal input action.
## Entries accumulate throughout the session; last MAX_ENTRIES are kept.

const MAX_ENTRIES: int = 60

var _entries: Array[String] = []
var _is_open: bool = false

@onready var entries_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/EntriesList
@onready var scroll_container: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/Footer/CloseButton
@onready var count_label: Label = $Panel/MarginContainer/VBoxContainer/Header/CountLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	EventBus.journal_entry_added.connect(_on_journal_entry_added)
	EventBus.ui_screen_opened.connect(_on_ui_screen_opened)
	close_button.pressed.connect(_close)


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if event.is_action_pressed("open_journal") or event.is_action_pressed("pause"):
				get_viewport().set_input_as_handled()
				_close()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if close_button != null and close_button.get_global_rect().has_point(mb.position):
				get_viewport().set_input_as_handled()
				_close()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and close_button != null and close_button.get_global_rect().has_point(touch.position):
			get_viewport().set_input_as_handled()
			_close()


func _on_journal_entry_added(entry: String) -> void:
	_entries.append(entry)
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()


func _on_ui_screen_opened(screen_name: String) -> void:
	if screen_name == "journal":
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
	get_tree().paused = false
	hide()
	EventBus.ui_screen_closed.emit("journal")


func _refresh() -> void:
	if entries_list == null:
		return
	for child: Node in entries_list.get_children():
		child.queue_free()
	if count_label != null:
		count_label.text = "%d entries" % _entries.size()
	if _entries.is_empty():
		var placeholder: Label = Label.new()
		placeholder.text = "No entries yet. Explore and interact with the world."
		placeholder.add_theme_font_size_override("font_size", 12)
		placeholder.modulate = Color(1.0, 1.0, 1.0, 0.6)
		entries_list.add_child(placeholder)
		return
	var reversed: Array[String] = _entries.duplicate()
	reversed.reverse()
	for entry: String in reversed:
		var label: Label = Label.new()
		label.text = "• " + entry
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		entries_list.add_child(label)
	await get_tree().process_frame
	if scroll_container != null:
		scroll_container.scroll_vertical = 0
