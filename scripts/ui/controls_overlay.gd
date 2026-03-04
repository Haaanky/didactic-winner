class_name ControlsOverlay
extends CanvasLayer

## Shows a control-scheme reference overlay when a level starts.
## Dismissed by any mouse click, key press, or touch tap.

signal dismissed

const _ROWS := [
	["Action", "Keyboard", "Gamepad"],
	["Move", "W A S D", "Left Stick"],
	["Sprint", "Shift", "LB"],
	["Interact", "E", "A (×)"],
	["Eat Food", "F", "B (○)"],
	["Check Needs", "T", "Y (△)"],
	["Inventory", "I", "X (□)"],
	["Pause", "Esc", "Start"],
]

@onready var controls_grid: GridContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ControlsGrid


func _ready() -> void:
	_populate_grid()


func _input(event: InputEvent) -> void:
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
