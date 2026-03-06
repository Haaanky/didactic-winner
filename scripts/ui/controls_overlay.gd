class_name ControlsOverlay
extends CanvasLayer

## Shows a control-scheme reference overlay when a level starts.
## Dismissed by any mouse click, key press, touch tap, or gamepad button.
## Blocks all recognised input from reaching the game while visible — including
## during the first frame before dismissal is armed — so that a held Escape key
## cannot pause the game before the player has seen the overlay.

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

var _accepting_input: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_populate_grid()
	await get_tree().process_frame
	_accepting_input = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			get_viewport().set_input_as_handled()
			if _accepting_input:
				_dismiss()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			get_viewport().set_input_as_handled()
			if _accepting_input:
				_dismiss()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			get_viewport().set_input_as_handled()
			if _accepting_input:
				_dismiss()
	elif event is InputEventJoypadButton:
		var btn := event as InputEventJoypadButton
		if btn.pressed:
			get_viewport().set_input_as_handled()
			if _accepting_input:
				_dismiss()


func _populate_grid() -> void:
	for row: Array in _ROWS:
		for cell: String in row:
			var label := Label.new()
			label.text = cell
			controls_grid.add_child(label)


func _dismiss() -> void:
	dismissed.emit()
	queue_free()
