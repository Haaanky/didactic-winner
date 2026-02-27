class_name SkillComponent
extends Node

## Tracks XP and levels for all 9 player skills.
## Skills improve through repeated use via add_xp().

enum Skill {
	LUMBERJACKING,
	FISHING,
	HUNTING,
	TAXIDERMY,
	COOKING,
	CARPENTRY,
	MECHANICS,
	SEWING,
	FARMING,
}

const MAX_LEVEL: int = 10
const XP_PER_LEVEL: float = 100.0

var skill_levels: Dictionary = {}
var skill_xp: Dictionary = {}


func _ready() -> void:
	for skill: int in Skill.values():
		skill_levels[skill] = 0
		skill_xp[skill] = 0.0


func add_xp(skill: Skill, amount: float) -> void:
	skill_xp[skill] += amount
	EventBus.skill_xp_gained.emit(Skill.keys()[skill], amount)
	if skill_xp[skill] >= XP_PER_LEVEL and skill_levels[skill] < MAX_LEVEL:
		skill_xp[skill] -= XP_PER_LEVEL
		_level_up(skill)


func get_level(skill: Skill) -> int:
	return skill_levels.get(skill, 0)


func has_level(skill: Skill, required_level: int) -> bool:
	return get_level(skill) >= required_level


func serialise() -> Dictionary:
	return {
		"skill_levels": skill_levels.duplicate(),
		"skill_xp": skill_xp.duplicate(),
	}


func deserialise(data: Dictionary) -> void:
	var saved_levels: Dictionary = data.get("skill_levels", {})
	var saved_xp: Dictionary = data.get("skill_xp", {})
	for skill: int in Skill.values():
		if saved_levels.has(str(skill)):
			skill_levels[skill] = saved_levels[str(skill)]
		if saved_xp.has(str(skill)):
			skill_xp[skill] = saved_xp[str(skill)]


func _level_up(skill: Skill) -> void:
	skill_levels[skill] = mini(skill_levels[skill] + 1, MAX_LEVEL)
	var skill_name: String = Skill.keys()[skill]
	EventBus.skill_leveled_up.emit(skill_name, skill_levels[skill])
	EventBus.journal_entry_added.emit(
		"Skill up: %s is now level %d." % [skill_name.capitalize(), skill_levels[skill]]
	)
