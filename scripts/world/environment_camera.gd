class_name EnvironmentCamera
extends Camera2D

## Smooth exploration camera for the Alaskan environment.
## Follows the player with lag, supports zoom via scroll/keys,
## and enforces world bounds so the camera never shows empty space.

const ZOOM_MIN: float = 0.25    # max zoom out (wide view)
const ZOOM_MAX: float = 2.80    # max zoom in (close-up detail)
const ZOOM_STEP: float = 0.12
const ZOOM_SMOOTH: float = 8.0  # lerp speed for zoom animation

const PAN_SPEED: float = 420.0  # pixels/sec when panning without player
const FOLLOW_SMOOTHING: float = 5.5

const WORLD_HALF: float = 6144.0   # matches WorldBackground

@export var target: Node2D          # usually the Player node
@export var allow_free_pan: bool = false   # enable WASD camera pan when no player

var _target_zoom: float = 1.0
var _current_zoom: float = 1.0


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = FOLLOW_SMOOTHING
	_target_zoom = zoom.x
	_current_zoom = zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_scroll(event as InputEventMouseButton)
	elif event is InputEventKey:
		_handle_key_zoom(event as InputEventKey)


func _handle_scroll(ev: InputEventMouseButton) -> void:
	if ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
		_target_zoom = clampf(_target_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
	elif ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_target_zoom = clampf(_target_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)


func _handle_key_zoom(ev: InputEventKey) -> void:
	if not ev.pressed:
		return
	if ev.keycode == KEY_EQUAL or ev.keycode == KEY_KP_ADD:
		_target_zoom = clampf(_target_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
	elif ev.keycode == KEY_MINUS or ev.keycode == KEY_KP_SUBTRACT:
		_target_zoom = clampf(_target_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
	elif ev.keycode == KEY_0 or ev.keycode == KEY_KP_0:
		_target_zoom = 1.0   # reset to default


func _process(delta: float) -> void:
	# Smooth zoom animation
	_current_zoom = lerpf(_current_zoom, _target_zoom, ZOOM_SMOOTH * delta)
	zoom = Vector2(_current_zoom, _current_zoom)

	# Free pan when no player target
	if allow_free_pan and not is_instance_valid(target):
		var pan_dir := Vector2.ZERO
		if Input.is_action_pressed("move_left"):
			pan_dir.x -= 1.0
		if Input.is_action_pressed("move_right"):
			pan_dir.x += 1.0
		if Input.is_action_pressed("move_up"):
			pan_dir.y -= 1.0
		if Input.is_action_pressed("move_down"):
			pan_dir.y += 1.0
		if pan_dir != Vector2.ZERO:
			position += pan_dir.normalized() * PAN_SPEED * delta

	# Clamp camera to world bounds (accounting for zoom)
	_clamp_to_world()


func _clamp_to_world() -> void:
	var vp: Viewport = get_viewport()
	if not is_instance_valid(vp):
		return
	var vp_size: Vector2 = vp.get_visible_rect().size
	var half_vp: Vector2 = vp_size / (2.0 * _current_zoom)
	position.x = clampf(position.x, -WORLD_HALF + half_vp.x, WORLD_HALF - half_vp.x)
	position.y = clampf(position.y, -WORLD_HALF + half_vp.y, WORLD_HALF - half_vp.y)
