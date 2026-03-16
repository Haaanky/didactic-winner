class_name Dog
extends CharacterBody2D

## Dog companion. Initially stray. Player presses [E] to adopt.
## Once adopted the dog follows the player at a short distance.

enum DogState { STRAY, FOLLOWING }

const FOLLOW_SPEED: float = 180.0
const FOLLOW_DISTANCE: float = 64.0
const ADOPT_RADIUS: float = 80.0

@export var dog_name: String = "Kodiak"

var _state: DogState = DogState.STRAY
var _player: CharacterBody2D = null
var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("dog")


func _physics_process(_delta: float) -> void:
	_update_player_ref()
	_check_adopt_range()
	_follow_player()


func _update_player_ref() -> void:
	if is_instance_valid(_player):
		return
	var node: Node = get_tree().get_first_node_in_group("player")
	if is_instance_valid(node) and node is CharacterBody2D:
		_player = node as CharacterBody2D


func _check_adopt_range() -> void:
	if _state == DogState.FOLLOWING:
		return
	if not is_instance_valid(_player):
		return
	var dist: float = global_position.distance_to(_player.global_position)
	var in_range: bool = dist <= ADOPT_RADIUS
	if in_range != _player_in_range:
		_player_in_range = in_range
		if in_range:
			EventBus.interact_prompt_changed.emit("[E] Adopt %s" % dog_name)
		else:
			EventBus.interact_prompt_changed.emit("")


func _follow_player() -> void:
	if _state != DogState.FOLLOWING:
		return
	if not is_instance_valid(_player):
		return
	var dist: float = global_position.distance_to(_player.global_position)
	if dist > FOLLOW_DISTANCE:
		velocity = global_position.direction_to(_player.global_position) * FOLLOW_SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func interact(_player: PlayerController) -> void:
	if _state == DogState.FOLLOWING:
		return
	if not _player_in_range:
		return
	_state = DogState.FOLLOWING
	EventBus.interact_prompt_changed.emit("")
	EventBus.journal_entry_added.emit("%s has decided to follow you." % dog_name)
	EventBus.companion_adopted.emit(dog_name)
