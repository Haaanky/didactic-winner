extends GutTest

# Tests SkillComponent XP and level-up logic.
# Deserialise uses string-keyed dictionaries because JSON round-trips
# convert integer keys to strings.

var _skill: SkillComponent


func before_each() -> void:
	_skill = SkillComponent.new()
	add_child(_skill)


func after_each() -> void:
	_skill.queue_free()


# ── Initial state ─────────────────────────────────────────────────────────────

func test_all_skills_start_at_level_zero() -> void:
	for skill: int in SkillComponent.Skill.values():
		assert_eq(_skill.skill_levels[skill], 0)


func test_all_skills_start_at_zero_xp() -> void:
	for skill: int in SkillComponent.Skill.values():
		assert_eq(_skill.skill_xp[skill], 0.0)


# ── add_xp ────────────────────────────────────────────────────────────────────

func test_add_xp_increases_skill_xp() -> void:
	_skill.add_xp(SkillComponent.Skill.FISHING, 30.0)
	assert_eq(_skill.skill_xp[SkillComponent.Skill.FISHING], 30.0)


func test_add_xp_emits_skill_xp_gained() -> void:
	watch_signals(EventBus)
	_skill.add_xp(SkillComponent.Skill.COOKING, 25.0)
	assert_signal_emitted_with_parameters(EventBus, "skill_xp_gained", ["COOKING", 25.0])


func test_add_xp_triggers_level_up_at_threshold() -> void:
	_skill.add_xp(SkillComponent.Skill.FISHING, SkillComponent.XP_PER_LEVEL)
	assert_eq(_skill.skill_levels[SkillComponent.Skill.FISHING], 1)


func test_level_up_emits_skill_leveled_up() -> void:
	watch_signals(EventBus)
	_skill.add_xp(SkillComponent.Skill.HUNTING, SkillComponent.XP_PER_LEVEL)
	assert_signal_emitted_with_parameters(EventBus, "skill_leveled_up", ["HUNTING", 1])


func test_level_up_emits_journal_entry() -> void:
	watch_signals(EventBus)
	_skill.add_xp(SkillComponent.Skill.CARPENTRY, SkillComponent.XP_PER_LEVEL)
	assert_signal_emitted(EventBus, "journal_entry_added")


func test_xp_carries_over_after_level_up() -> void:
	_skill.add_xp(SkillComponent.Skill.FISHING, SkillComponent.XP_PER_LEVEL + 40.0)
	assert_eq(_skill.skill_xp[SkillComponent.Skill.FISHING], 40.0)


func test_level_up_does_not_exceed_max_level() -> void:
	for _i: int in SkillComponent.MAX_LEVEL + 5:
		_skill.add_xp(SkillComponent.Skill.FARMING, SkillComponent.XP_PER_LEVEL)
	assert_eq(_skill.skill_levels[SkillComponent.Skill.FARMING], SkillComponent.MAX_LEVEL)


func test_no_level_up_below_threshold() -> void:
	_skill.add_xp(SkillComponent.Skill.FISHING, SkillComponent.XP_PER_LEVEL - 1.0)
	assert_eq(_skill.skill_levels[SkillComponent.Skill.FISHING], 0)


# ── get_level ─────────────────────────────────────────────────────────────────

func test_get_level_returns_current_level() -> void:
	_skill.add_xp(SkillComponent.Skill.LUMBERJACKING, SkillComponent.XP_PER_LEVEL)
	assert_eq(_skill.get_level(SkillComponent.Skill.LUMBERJACKING), 1)


func test_get_level_returns_zero_for_unlevelled_skill() -> void:
	assert_eq(_skill.get_level(SkillComponent.Skill.TAXIDERMY), 0)


# ── has_level ─────────────────────────────────────────────────────────────────

func test_has_level_true_when_at_required() -> void:
	_skill.add_xp(SkillComponent.Skill.SEWING, SkillComponent.XP_PER_LEVEL)
	assert_true(_skill.has_level(SkillComponent.Skill.SEWING, 1))


func test_has_level_true_when_above_required() -> void:
	_skill.add_xp(SkillComponent.Skill.SEWING, SkillComponent.XP_PER_LEVEL * 3.0)
	assert_true(_skill.has_level(SkillComponent.Skill.SEWING, 2))


func test_has_level_false_when_below_required() -> void:
	assert_false(_skill.has_level(SkillComponent.Skill.SEWING, 1))


# ── serialise / deserialise ───────────────────────────────────────────────────

func test_serialise_preserves_skill_levels() -> void:
	_skill.add_xp(SkillComponent.Skill.MECHANICS, SkillComponent.XP_PER_LEVEL)
	var data: Dictionary = _skill.serialise()
	assert_eq(data["skill_levels"][SkillComponent.Skill.MECHANICS], 1)


func test_serialise_preserves_skill_xp() -> void:
	_skill.add_xp(SkillComponent.Skill.MECHANICS, 55.0)
	var data: Dictionary = _skill.serialise()
	assert_eq(data["skill_xp"][SkillComponent.Skill.MECHANICS], 55.0)


func test_deserialise_restores_skill_level_from_string_key() -> void:
	# JSON round-trips convert int keys to strings — deserialise must handle "0", "1" etc.
	var lumberjacking_id: int = SkillComponent.Skill.LUMBERJACKING
	var data: Dictionary = {
		"skill_levels": {str(lumberjacking_id): 3},
		"skill_xp": {str(lumberjacking_id): 70.0},
	}
	_skill.deserialise(data)
	assert_eq(_skill.skill_levels[lumberjacking_id], 3)
	assert_eq(_skill.skill_xp[lumberjacking_id], 70.0)


func test_deserialise_leaves_unmentioned_skills_unchanged() -> void:
	var data: Dictionary = {"skill_levels": {}, "skill_xp": {}}
	_skill.deserialise(data)
	for skill: int in SkillComponent.Skill.values():
		assert_eq(_skill.skill_levels[skill], 0)
