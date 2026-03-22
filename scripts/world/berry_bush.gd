class_name BerryBush
extends Node2D

## Wild berry bush. Yields berries that restore hunger.
## Depletes after harvest and regrows after REGROW_HOURS game hours.
## Does not yield berries in winter.

signal berries_harvested(count: int)
signal regrew()

const BERRY_ITEM_ID: StringName = &"berries"
const BERRY_WEIGHT: float = 0.1
const BASE_YIELD_MIN: int = 2
const BASE_YIELD_MAX: int = 5
const REGROW_HOURS: int = 48
const XP_PER_HARVEST: float = 8.0
const DEPLETED_MODULATE: Color = Color(0.5, 0.4, 0.3, 1.0)

@export var bush_sprite: Sprite2D
@export var interact_area: StaticBody2D

var has_berries: bool = true
var _hours_until_regrow: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	EventBus.hour_passed.connect(_on_hour_passed)
	EventBus.season_changed.connect(_on_season_changed)
	_update_visuals()


func interact(player: PlayerController) -> void:
	if not has_berries:
		EventBus.journal_entry_added.emit("The berry bush is bare. Come back later.")
		return
	if TimeManager.current_season == TimeManager.Season.WINTER:
		EventBus.journal_entry_added.emit("No berries in winter.")
		return
	_harvest(player)


func get_interact_prompt(_player: PlayerController) -> String:
	if not has_berries or TimeManager.current_season == TimeManager.Season.WINTER:
		return "Bush (empty)"
	return "[E] Pick Berries"


func _harvest(player: PlayerController) -> void:
	var skill_level: int = 0
	if player.skills != null:
		skill_level = player.skills.get_level(SkillComponent.Skill.FARMING)
		player.skills.add_xp(SkillComponent.Skill.FARMING, XP_PER_HARVEST)
	var yield_count: int = BASE_YIELD_MIN + _rng.randi_range(0, BASE_YIELD_MAX - BASE_YIELD_MIN)
	yield_count += skill_level / 4
	has_berries = false
	_hours_until_regrow = REGROW_HOURS
	if player.inventory != null:
		player.inventory.add_item(BERRY_ITEM_ID, yield_count, BERRY_WEIGHT)
	EventBus.berries_gathered.emit(global_position, yield_count)
	EventBus.journal_entry_added.emit("Picked %d berries. Eat them [F] or dry at campfire." % yield_count)
	berries_harvested.emit(yield_count)
	_update_visuals()


func _update_visuals() -> void:
	if bush_sprite == null:
		return
	bush_sprite.modulate = Color.WHITE if has_berries else DEPLETED_MODULATE


func _on_hour_passed(_hour: int) -> void:
	if has_berries:
		return
	if TimeManager.current_season == TimeManager.Season.WINTER:
		return
	_hours_until_regrow -= 1
	if _hours_until_regrow <= 0:
		has_berries = true
		regrew.emit()
		_update_visuals()


func _on_season_changed(_season: int) -> void:
	if TimeManager.current_season == TimeManager.Season.SPRING and not has_berries:
		has_berries = true
		regrew.emit()
		_update_visuals()
