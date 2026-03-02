extends GutTest

# Tests AppearanceComponent: hair/beard growth, dirt, clothing durability,
# rugged level, hair styling, serialisation, and error-path guards.

var _subject: AppearanceComponent


func before_each() -> void:
	_subject = AppearanceComponent.new()
	add_child(_subject)


func after_each() -> void:
	_subject.queue_free()


# ── Initial state ──────────────────────────────────────────────────────────────

func test_initial_hair_length_is_zero() -> void:
	assert_eq(_subject.hair_length, 0.0)


func test_initial_beard_length_is_zero() -> void:
	assert_eq(_subject.beard_length, 0.0)


func test_initial_dirt_level_is_zero() -> void:
	assert_eq(_subject.dirt_level, 0.0)


func test_initial_days_since_town_visit_is_zero() -> void:
	assert_eq(_subject.days_since_town_visit, 0)


func test_initial_hair_style_is_loose() -> void:
	assert_eq(_subject.hair_style, AppearanceComponent.HairStyle.LOOSE)


func test_initial_rugged_level_is_zero() -> void:
	assert_eq(_subject.get_rugged_level(), 0)


# ── Hair growth via day_passed ─────────────────────────────────────────────────

func test_day_passed_grows_hair() -> void:
	EventBus.day_passed.emit(1)
	assert_eq(_subject.hair_length, AppearanceComponent.HAIR_GROWTH_PER_DAY)


func test_hair_does_not_exceed_max() -> void:
	_subject.hair_length = AppearanceComponent.HAIR_MAX
	EventBus.day_passed.emit(1)
	assert_eq(_subject.hair_length, AppearanceComponent.HAIR_MAX)


func test_is_hair_long_false_below_threshold() -> void:
	_subject.hair_length = AppearanceComponent.HAIR_LONG_THRESHOLD - 1.0
	assert_false(_subject.is_hair_long())


func test_is_hair_long_true_at_threshold() -> void:
	_subject.hair_length = AppearanceComponent.HAIR_LONG_THRESHOLD
	assert_true(_subject.is_hair_long())


# ── Beard growth ───────────────────────────────────────────────────────────────

func test_day_passed_grows_beard_when_has_beard() -> void:
	_subject.has_beard = true
	EventBus.day_passed.emit(1)
	assert_eq(_subject.beard_length, AppearanceComponent.BEARD_GROWTH_PER_DAY)


func test_day_passed_does_not_grow_beard_when_no_beard() -> void:
	_subject.has_beard = false
	EventBus.day_passed.emit(1)
	assert_eq(_subject.beard_length, 0.0)


func test_beard_does_not_exceed_max() -> void:
	_subject.has_beard = true
	_subject.beard_length = AppearanceComponent.BEARD_MAX
	EventBus.day_passed.emit(1)
	assert_eq(_subject.beard_length, AppearanceComponent.BEARD_MAX)


# ── Dirt accumulation via hour_passed ─────────────────────────────────────────

func test_hour_passed_increases_dirt() -> void:
	EventBus.hour_passed.emit(1)
	assert_eq(_subject.dirt_level, AppearanceComponent.DIRT_GAIN_PER_HOUR)


func test_dirt_does_not_exceed_max() -> void:
	_subject.dirt_level = AppearanceComponent.DIRT_MAX
	EventBus.hour_passed.emit(1)
	assert_eq(_subject.dirt_level, AppearanceComponent.DIRT_MAX)


# ── bathe ──────────────────────────────────────────────────────────────────────

func test_bathe_resets_dirt_to_zero() -> void:
	_subject.dirt_level = 80.0
	_subject.bathe()
	assert_eq(_subject.dirt_level, 0.0)


func test_bathe_emits_appearance_changed() -> void:
	watch_signals(_subject)
	_subject.bathe()
	assert_signal_emitted(_subject, "appearance_changed")


func test_bathe_emits_eventbus_appearance_changed() -> void:
	watch_signals(EventBus)
	_subject.bathe()
	assert_signal_emitted(EventBus, "appearance_changed")


# ── visit_town ────────────────────────────────────────────────────────────────

func test_visit_town_resets_days_counter() -> void:
	_subject.days_since_town_visit = 50
	_subject.visit_town()
	assert_eq(_subject.days_since_town_visit, 0)


func test_visit_town_emits_appearance_changed() -> void:
	watch_signals(_subject)
	_subject.visit_town()
	assert_signal_emitted(_subject, "appearance_changed")


# ── get_rugged_level ──────────────────────────────────────────────────────────

func test_rugged_level_0_below_scruffy_threshold() -> void:
	_subject.days_since_town_visit = AppearanceComponent.SCRUFFY_THRESHOLD - 1
	assert_eq(_subject.get_rugged_level(), 0)


func test_rugged_level_1_at_scruffy_threshold() -> void:
	_subject.days_since_town_visit = AppearanceComponent.SCRUFFY_THRESHOLD
	assert_eq(_subject.get_rugged_level(), 1)


func test_rugged_level_2_at_rugged_threshold() -> void:
	_subject.days_since_town_visit = AppearanceComponent.RUGGED_THRESHOLD
	assert_eq(_subject.get_rugged_level(), 2)


func test_rugged_level_3_at_hermit_threshold() -> void:
	_subject.days_since_town_visit = AppearanceComponent.HERMIT_THRESHOLD
	assert_eq(_subject.get_rugged_level(), 3)


# ── set_hair_style ────────────────────────────────────────────────────────────

func test_set_hair_style_to_bun_ignored_when_hair_short() -> void:
	_subject.hair_length = 0.0
	_subject.set_hair_style(AppearanceComponent.HairStyle.BUN)
	assert_eq(_subject.hair_style, AppearanceComponent.HairStyle.LOOSE)


func test_set_hair_style_to_bun_succeeds_when_hair_long() -> void:
	_subject.hair_length = AppearanceComponent.HAIR_LONG_THRESHOLD
	_subject.set_hair_style(AppearanceComponent.HairStyle.BUN)
	assert_eq(_subject.hair_style, AppearanceComponent.HairStyle.BUN)


func test_set_hair_style_to_ponytail_succeeds_when_hair_long() -> void:
	_subject.hair_length = AppearanceComponent.HAIR_LONG_THRESHOLD
	_subject.set_hair_style(AppearanceComponent.HairStyle.PONYTAIL)
	assert_eq(_subject.hair_style, AppearanceComponent.HairStyle.PONYTAIL)


func test_set_hair_style_to_loose_always_succeeds() -> void:
	_subject.hair_length = 0.0
	_subject.hair_style = AppearanceComponent.HairStyle.BUN
	_subject.hair_length = AppearanceComponent.HAIR_LONG_THRESHOLD
	_subject.set_hair_style(AppearanceComponent.HairStyle.BUN)
	_subject.hair_length = 0.0
	_subject.set_hair_style(AppearanceComponent.HairStyle.LOOSE)
	assert_eq(_subject.hair_style, AppearanceComponent.HairStyle.LOOSE)


func test_set_hair_style_emits_appearance_changed_when_applied() -> void:
	_subject.hair_length = AppearanceComponent.HAIR_LONG_THRESHOLD
	watch_signals(_subject)
	_subject.set_hair_style(AppearanceComponent.HairStyle.BUN)
	assert_signal_emitted(_subject, "appearance_changed")


# ── Clothing durability ────────────────────────────────────────────────────────

func test_degrade_clothing_reduces_durability() -> void:
	_subject.degrade_clothing("torso", 20.0)
	assert_eq(_subject.get_clothing_durability("torso"),
		AppearanceComponent.CLOTHING_DURABILITY_MAX - 20.0)


func test_degrade_clothing_floors_at_zero() -> void:
	_subject.degrade_clothing("torso", 999.0)
	assert_eq(_subject.get_clothing_durability("torso"), 0.0)


func test_degrade_clothing_emits_appearance_changed() -> void:
	watch_signals(_subject)
	_subject.degrade_clothing("torso", 10.0)
	assert_signal_emitted(_subject, "appearance_changed")


func test_degrade_clothing_invalid_slot_leaves_others_unchanged() -> void:
	var before: float = _subject.get_clothing_durability("torso")
	_subject.degrade_clothing("invalid_slot", 30.0)
	assert_eq(_subject.get_clothing_durability("torso"), before)


func test_repair_clothing_restores_durability() -> void:
	_subject.degrade_clothing("legs", 50.0)
	_subject.repair_clothing("legs")
	assert_eq(_subject.get_clothing_durability("legs"),
		AppearanceComponent.CLOTHING_DURABILITY_MAX)


func test_repair_clothing_increments_patch_count() -> void:
	_subject.repair_clothing("head")
	_subject.repair_clothing("head")
	assert_eq(_subject.get_clothing_patch_count("head"), 2)


func test_repair_clothing_emits_appearance_changed() -> void:
	watch_signals(_subject)
	_subject.repair_clothing("feet")
	assert_signal_emitted(_subject, "appearance_changed")


func test_repair_clothing_invalid_slot_does_not_crash() -> void:
	_subject.repair_clothing("invalid_slot")
	assert_eq(_subject.get_clothing_patch_count("torso"), 0)


func test_clothing_degrades_each_day() -> void:
	var before: float = _subject.get_clothing_durability("torso")
	EventBus.day_passed.emit(1)
	assert_eq(_subject.get_clothing_durability("torso"),
		before - AppearanceComponent.CLOTHING_DEGRADE_PER_DAY)


# ── days_since_town_visit increments ──────────────────────────────────────────

func test_day_passed_increments_days_since_town_visit() -> void:
	EventBus.day_passed.emit(1)
	assert_eq(_subject.days_since_town_visit, 1)


# ── Serialise / deserialise ────────────────────────────────────────────────────

func test_serialise_round_trip_restores_hair_length() -> void:
	_subject.hair_length = 45.0
	var data: Dictionary = _subject.serialise()
	var other := AppearanceComponent.new()
	add_child(other)
	other.deserialise(data)
	assert_eq(other.hair_length, 45.0)
	other.queue_free()


func test_serialise_round_trip_restores_dirt_level() -> void:
	_subject.dirt_level = 33.0
	var data: Dictionary = _subject.serialise()
	var other := AppearanceComponent.new()
	add_child(other)
	other.deserialise(data)
	assert_eq(other.dirt_level, 33.0)
	other.queue_free()


func test_serialise_round_trip_restores_clothing_durability() -> void:
	_subject.degrade_clothing("head", 40.0)
	var data: Dictionary = _subject.serialise()
	var other := AppearanceComponent.new()
	add_child(other)
	other.deserialise(data)
	assert_eq(other.get_clothing_durability("head"),
		AppearanceComponent.CLOTHING_DURABILITY_MAX - 40.0)
	other.queue_free()


func test_serialise_round_trip_restores_patch_count() -> void:
	_subject.repair_clothing("legs")
	_subject.repair_clothing("legs")
	var data: Dictionary = _subject.serialise()
	var other := AppearanceComponent.new()
	add_child(other)
	other.deserialise(data)
	assert_eq(other.get_clothing_patch_count("legs"), 2)
	other.queue_free()


func test_serialise_round_trip_restores_hair_style() -> void:
	_subject.hair_length = AppearanceComponent.HAIR_LONG_THRESHOLD
	_subject.set_hair_style(AppearanceComponent.HairStyle.PONYTAIL)
	var data: Dictionary = _subject.serialise()
	var other := AppearanceComponent.new()
	add_child(other)
	other.deserialise(data)
	assert_eq(other.hair_style, AppearanceComponent.HairStyle.PONYTAIL)
	other.queue_free()
