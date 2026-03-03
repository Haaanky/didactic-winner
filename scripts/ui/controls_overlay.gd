class_name ControlsOverlay
extends CanvasLayer

## Shows a control-scheme reference overlay when a level starts.
## Dismissed by any mouse click, key press, or touch tap.

signal dismissed

const _ROWS := [
	["Action", "Keyboard", "Gamepad"],
	["Move", "W A S D", "Left Stick"],
	["Interact", "E", "A (×)"],
	["Check Needs", "T", "Y (△)"],
	["Inventory", "I", "X (□)"],
	["Journal", "J", "—"],
	["Map", "M", "—"],
	["Pause", "Esc", "Start"],
]

@export var controls_grid: GridContainer

var _accepting_input: bool = false


func _ready() -> void:
	if controls_grid == null:
		push_error("ControlsOverlay: controls_grid export not set")
		return
	_populate_grid()
	await get_tree().process_frame
	_accepting_input = true


func _input(event: InputEvent) -> void:
	if not _accepting_input:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_dismiss()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_dismiss()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			_dismiss()


func _populate_grid() -> void:
	for row: Array in _ROWS:
		for cell: String in row:
			var label := Label.new()
			label.text = cell
			controls_grid.add_child(label)


func _dismiss() -> void:
	get_viewport().set_input_as_handled()
	dismissed.emit()
	queue_free()
