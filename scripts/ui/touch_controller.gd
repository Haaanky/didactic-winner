class_name TouchController
extends CanvasLayer

## On-screen virtual controls for touchscreen devices.
## A floating virtual joystick on the left half of the screen handles 8-directional movement.
## Fixed action buttons on the bottom-right handle interact, check_needs, and pause.
## Auto-hides on devices where DisplayServer.is_touchscreen_available() returns false.

const JOYSTICK_RADIUS: float = 80.0
const JOYSTICK_DEAD_ZONE: float = 12.0
const TOUCH_LAYER: int = 10

var _joystick_touch_index: int = -1
var _joystick_origin: Vector2 = Vector2.ZERO

@onready var joystick_base: Control = $JoystickBase
@onready var joystick_knob: Control = $JoystickBase/JoystickKnob
@onready var interact_button: Button = $ActionButtons/InteractButton
@onready var needs_button: Button = $ActionButtons/NeedsButton
@onready var pause_button: Button = $ActionButtons/PauseButton


func _ready() -> void:
	layer = TOUCH_LAYER
	hide()
	joystick_base.hide()
	interact_button.button_down.connect(_on_interact_down)
	interact_button.button_up.connect(_on_interact_up)
	needs_button.button_down.connect(_on_needs_down)
	needs_button.button_up.connect(_on_needs_up)
	pause_button.button_down.connect(_on_pause_down)
	pause_button.button_up.connect(_on_pause_up)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not visible:
			show()
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		if not visible:
			return
		_handle_screen_drag(event as InputEventScreenDrag)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var half_width: float = get_viewport().get_visible_rect().size.x * 0.5
	if event.pressed:
		if event.position.x < half_width and _joystick_touch_index == -1:
			_joystick_touch_index = event.index
			_joystick_origin = event.position
			joystick_base.position = _joystick_origin - joystick_base.size * 0.5
			joystick_base.show()
			get_viewport().set_input_as_handled()
	else:
		if event.index == _joystick_touch_index:
			_joystick_touch_index = -1
			joystick_base.hide()
			_release_movement()
			get_viewport().set_input_as_handled()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != _joystick_touch_index:
		return
	var offset: Vector2 = event.position - _joystick_origin
	var clamped: Vector2 = offset.limit_length(JOYSTICK_RADIUS)
	joystick_knob.position = clamped + joystick_base.size * 0.5 - joystick_knob.size * 0.5
	_update_movement(offset)
	get_viewport().set_input_as_handled()


func _update_movement(offset: Vector2) -> void:
	_release_movement()
	if offset.length() < JOYSTICK_DEAD_ZONE:
		return
	if offset.x < -JOYSTICK_DEAD_ZONE:
		Input.action_press("move_left", clampf(absf(offset.x) / JOYSTICK_RADIUS, 0.0, 1.0))
	elif offset.x > JOYSTICK_DEAD_ZONE:
		Input.action_press("move_right", clampf(offset.x / JOYSTICK_RADIUS, 0.0, 1.0))
	if offset.y < -JOYSTICK_DEAD_ZONE:
		Input.action_press("move_up", clampf(absf(offset.y) / JOYSTICK_RADIUS, 0.0, 1.0))
	elif offset.y > JOYSTICK_DEAD_ZONE:
		Input.action_press("move_down", clampf(offset.y / JOYSTICK_RADIUS, 0.0, 1.0))


func _release_movement() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")


func _emit_action(action_name: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _on_interact_down() -> void:
	_emit_action(&"interact", true)


func _on_interact_up() -> void:
	_emit_action(&"interact", false)


func _on_needs_down() -> void:
	_emit_action(&"check_needs", true)


func _on_needs_up() -> void:
	_emit_action(&"check_needs", false)


func _on_pause_down() -> void:
	_emit_action(&"pause", true)


func _on_pause_up() -> void:
	_emit_action(&"pause", false)
