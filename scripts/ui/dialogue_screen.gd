class_name DialogueScreen
extends Control

## Displays NPC dialogue lines one at a time. Player advances with [E] or click.

const LINES_END_TEXT: String = "(End of conversation)"

@onready var speaker_label: Label = $Background/MarginContainer/VBoxContainer/SpeakerLabel
@onready var line_label: Label = $Background/MarginContainer/VBoxContainer/LineLabel
@onready var next_button: Button = $Background/MarginContainer/VBoxContainer/NextButton

var _lines: Array[String] = []
var _current_line: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	next_button.pressed.connect(_advance)
	hide()
	EventBus.ui_screen_opened.connect(_on_ui_screen_opened)
	EventBus.dialogue_started.connect(_on_dialogue_started)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		_advance()
		get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and next_button.get_global_rect().has_point(touch.position):
			get_viewport().set_input_as_handled()
			_advance()


func open(speaker: String, lines: Array[String]) -> void:
	_lines = lines
	_current_line = 0
	if speaker_label != null:
		speaker_label.text = speaker
	_show_current_line()
	show()


func close() -> void:
	hide()
	EventBus.interact_prompt_changed.emit("")


func _advance() -> void:
	_current_line += 1
	if _current_line >= _lines.size():
		close()
	else:
		_show_current_line()


func _show_current_line() -> void:
	if line_label == null:
		return
	if _current_line < _lines.size():
		line_label.text = _lines[_current_line]
	else:
		line_label.text = LINES_END_TEXT


func _on_ui_screen_opened(screen_name: String) -> void:
	if screen_name != "dialogue" and visible:
		close()


func _on_dialogue_started(speaker: String, lines: Array) -> void:
	var typed_lines: Array[String] = []
	for line in lines:
		typed_lines.append(str(line))
	open(speaker, typed_lines)
