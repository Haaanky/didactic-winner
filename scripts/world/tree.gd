class_name WorldTree
extends Node2D

## Choppable tree. Yields logs based on player lumberjacking skill.
## Uses multiple interaction chops before falling.

const LOG_ITEM_ID: StringName = &"log"
const LOG_WEIGHT: float = 2.0
const BASE_CHOPS_REQUIRED: int = 5
const BASE_LOG_YIELD: int = 3
const XP_PER_CHOP: float = 10.0

@export var trunk_sprite: Sprite2D
@export var stump_sprite: Sprite2D
@export var interact_area: Area2D

var chops_remaining: int = BASE_CHOPS_REQUIRED
var is_chopped: bool = false


func _ready() -> void:
	_update_visuals()


func interact(player: PlayerController) -> void:
	if is_chopped:
		return
	if not player.inventory.has_item("hand_axe"):
		return
	_apply_chop(player)


func _apply_chop(player: PlayerController) -> void:
	var skill_level: int = player.skills.get_level(SkillComponent.Skill.LUMBERJACKING)
	player.skills.add_xp(SkillComponent.Skill.LUMBERJACKING, XP_PER_CHOP)
	chops_remaining -= 1
	if chops_remaining <= 0:
		_fell(player, skill_level)
	else:
		_update_visuals()


func _fell(player: PlayerController, skill_level: int) -> void:
	is_chopped = true
	var log_yield: int = BASE_LOG_YIELD + (skill_level / 3)
	player.inventory.add_item(LOG_ITEM_ID, log_yield, LOG_WEIGHT)
	EventBus.tree_chopped.emit(global_position, log_yield)
	EventBus.journal_entry_added.emit("Chopped down a tree. Got %d logs." % log_yield)
	_update_visuals()


func _update_visuals() -> void:
	if trunk_sprite != null:
		trunk_sprite.visible = not is_chopped
	if stump_sprite != null:
		stump_sprite.visible = is_chopped
