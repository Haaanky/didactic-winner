class_name NPC
extends CharacterBody2D

## Static NPC with simple dialogue. Player presses [E] to talk.
## Emits EventBus.dialogue_started when interaction begins.

const INTERACT_RADIUS: float = 80.0

@export var npc_name: String = "Stranger"
@export var dialogue_lines: Array[String] = [
	"Harsh winter this year. Stock up before heading into the wilderness.",
	"The fishing hole south of town is still open. Good luck out there.",
]

@onready var name_label: Label = $NameLabel

var _player_in_range: bool = false
var _cached_player: Node2D = null


func _ready() -> void:
	add_to_group("npc")
	_update_label()
	_cached_player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(_delta: float) -> void:
	_check_player_proximity()


func _check_player_proximity() -> void:
	if not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player") as Node2D
		if _cached_player == null:
			return
	var dist: float = global_position.distance_to(_cached_player.global_position)
	var in_range: bool = dist <= INTERACT_RADIUS
	if in_range != _player_in_range:
		_player_in_range = in_range
		if in_range:
			EventBus.interact_prompt_changed.emit("[E] Talk to %s" % npc_name)
		else:
			EventBus.interact_prompt_changed.emit("")


func interact(_player: PlayerController) -> void:
	if not _player_in_range:
		return
	EventBus.ui_screen_opened.emit("dialogue")
	EventBus.dialogue_started.emit(npc_name, dialogue_lines)


func _update_label() -> void:
	if name_label != null:
		name_label.text = npc_name
