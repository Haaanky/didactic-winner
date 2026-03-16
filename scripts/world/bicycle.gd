class_name Bicycle
extends StaticBody2D

## Rideable bicycle. Player presses [E] to mount or dismount.
## While mounted the player's movement speed is multiplied.

signal mounted(rider: CharacterBody2D)
signal dismounted()

const MOUNT_RADIUS: float = 80.0
const SPEED_MULTIPLIER: float = 2.5

@onready var sprite: Sprite2D = $Sprite2D

var _rider: PlayerController = null
var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("vehicle")


func _physics_process(_delta: float) -> void:
	_check_player_range()


func _check_player_range() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	var player_ctrl := player as PlayerController
	if player_ctrl == null:
		return
	var dist: float = global_position.distance_to(player_ctrl.global_position)
	var in_range: bool = dist <= MOUNT_RADIUS
	if in_range != _player_in_range:
		_player_in_range = in_range
		if in_range:
			EventBus.interact_prompt_changed.emit("[E] Ride Bicycle")
		else:
			EventBus.interact_prompt_changed.emit("")


func mount(player: PlayerController) -> void:
	if is_instance_valid(_rider):
		return
	_rider = player
	EventBus.interact_prompt_changed.emit("[E] Dismount")
	EventBus.journal_entry_added.emit("You mount the bicycle. Travel faster on clear paths.")
	EventBus.vehicle_mounted.emit("bicycle")
	mounted.emit(_rider)


func dismount() -> void:
	if not is_instance_valid(_rider):
		return
	_rider = null
	EventBus.interact_prompt_changed.emit("")
	dismounted.emit()


func interact(player: PlayerController) -> void:
	if is_instance_valid(_rider):
		if _rider == player:
			dismount()
	elif _player_in_range:
		mount(player)
