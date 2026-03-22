class_name RockDeposit
extends Node2D

## Rock outcropping that yields stones for crafting tools.
## Depletes after mining and replenishes after REGROW_HOURS game-hours.

signal stones_mined(count: int)
signal replenished()

const STONE_ITEM_ID: StringName = &"stone"
const STONE_WEIGHT: float = 0.8
const YIELD_MIN: int = 2
const YIELD_MAX: int = 5
const REGROW_HOURS: int = 72
const XP_PER_MINE: float = 8.0
const DEPLETED_MODULATE: Color = Color(0.5, 0.5, 0.55, 1.0)

@export var rock_sprite: Sprite2D
@export var interact_area: StaticBody2D

var has_stones: bool = true
var _hours_until_regrow: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	EventBus.hour_passed.connect(_on_hour_passed)
	_update_visuals()


func interact(player: PlayerController) -> void:
	if not has_stones:
		EventBus.journal_entry_added.emit("The rock deposit is tapped out. Come back later.")
		return
	_mine(player)


func get_interact_prompt(_player: PlayerController) -> String:
	if not has_stones:
		return "Rock (depleted)"
	return "[E] Mine Stones"


func _mine(player: PlayerController) -> void:
	var skill_level: int = 0
	if player.skills != null:
		skill_level = player.skills.get_level(SkillComponent.Skill.CARPENTRY)
		player.skills.add_xp(SkillComponent.Skill.CARPENTRY, XP_PER_MINE)
	var yield_count: int = YIELD_MIN + _rng.randi_range(0, YIELD_MAX - YIELD_MIN)
	yield_count += skill_level / 3
	has_stones = false
	_hours_until_regrow = REGROW_HOURS
	if player.inventory != null:
		player.inventory.add_item(STONE_ITEM_ID, yield_count, STONE_WEIGHT)
	EventBus.stone_mined.emit(global_position, yield_count)
	EventBus.journal_entry_added.emit(
		"Mined %d stones. Use [I] inventory to craft a hand axe (2 logs + 3 stones)." % yield_count
	)
	stones_mined.emit(yield_count)
	_update_visuals()


func _update_visuals() -> void:
	if rock_sprite == null:
		return
	rock_sprite.modulate = Color.WHITE if has_stones else DEPLETED_MODULATE


func _on_hour_passed(_hour: int) -> void:
	if has_stones:
		return
	_hours_until_regrow -= 1
	if _hours_until_regrow <= 0:
		has_stones = true
		replenished.emit()
		_update_visuals()
