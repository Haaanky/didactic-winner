class_name AppearanceComponent
extends Node

## Tracks the player's visual appearance over time.
## Hair and beard grow each in-game day; dirt accumulates each hour.
## Clothing durability degrades daily and can be repaired.
## Responds to: EventBus.day_passed, EventBus.hour_passed.

signal appearance_changed()

enum HairStyle { LOOSE, BUN, PONYTAIL }

## Days until hair is considered "long" — enables bun / ponytail styling.
const HAIR_LONG_THRESHOLD: float = 60.0
const HAIR_GROWTH_PER_DAY: float = 1.0
const HAIR_MAX: float = 120.0

## Days until beard is considered "full".
const BEARD_FULL_THRESHOLD: float = 30.0
const BEARD_GROWTH_PER_DAY: float = 1.0
const BEARD_MAX: float = 60.0

const DIRT_MAX: float = 100.0
const DIRT_GAIN_PER_HOUR: float = 0.5

const CLOTHING_DURABILITY_MAX: float = 100.0
const CLOTHING_DEGRADE_PER_DAY: float = 0.5

## Days without a town visit to reach each rugged level.
const SCRUFFY_THRESHOLD: int = 7
const RUGGED_THRESHOLD: int = 30
const HERMIT_THRESHOLD: int = 90

## Set false for characters without a beard (e.g. non-beard character creation).
@export var has_beard: bool = true

var hair_length: float = 0.0
var beard_length: float = 0.0
var dirt_level: float = 0.0
var days_since_town_visit: int = 0
var hair_style: HairStyle = HairStyle.LOOSE

var _clothing_durability: Dictionary = {
	"head": CLOTHING_DURABILITY_MAX,
	"torso": CLOTHING_DURABILITY_MAX,
	"legs": CLOTHING_DURABILITY_MAX,
	"feet": CLOTHING_DURABILITY_MAX,
}
var _clothing_patch_count: Dictionary = {
	"head": 0,
	"torso": 0,
	"legs": 0,
	"feet": 0,
}


func _ready() -> void:
	EventBus.day_passed.connect(_on_day_passed)
	EventBus.hour_passed.connect(_on_hour_passed)


## Resets dirt to zero (player bathed).
func bathe() -> void:
	dirt_level = 0.0
	EventBus.appearance_changed.emit()
	appearance_changed.emit()


## Resets the days-since-town-visit counter (player visited town).
func visit_town() -> void:
	days_since_town_visit = 0
	EventBus.appearance_changed.emit()
	appearance_changed.emit()


## Changes hair style. BUN / PONYTAIL require hair_length >= HAIR_LONG_THRESHOLD.
func set_hair_style(style: HairStyle) -> void:
	if style != HairStyle.LOOSE and not is_hair_long():
		return
	hair_style = style
	EventBus.appearance_changed.emit()
	appearance_changed.emit()


## Reduces clothing durability for [param slot] by [param amount].
## Valid slots: "head", "torso", "legs", "feet".
func degrade_clothing(slot: String, amount: float) -> void:
	if not _clothing_durability.has(slot):
		push_error("AppearanceComponent: unknown clothing slot — %s" % slot)
		return
	_clothing_durability[slot] = maxf(_clothing_durability[slot] - amount, 0.0)
	EventBus.appearance_changed.emit()
	appearance_changed.emit()


## Fully repairs clothing at [param slot] and records a patch.
## Valid slots: "head", "torso", "legs", "feet".
func repair_clothing(slot: String) -> void:
	if not _clothing_patch_count.has(slot):
		push_error("AppearanceComponent: unknown clothing slot — %s" % slot)
		return
	_clothing_durability[slot] = CLOTHING_DURABILITY_MAX
	_clothing_patch_count[slot] += 1
	EventBus.appearance_changed.emit()
	appearance_changed.emit()


func get_clothing_durability(slot: String) -> float:
	if not _clothing_durability.has(slot):
		push_error("AppearanceComponent: unknown clothing slot — %s" % slot)
		return 0.0
	return _clothing_durability[slot]


func get_clothing_patch_count(slot: String) -> int:
	if not _clothing_patch_count.has(slot):
		push_error("AppearanceComponent: unknown clothing slot — %s" % slot)
		return 0
	return _clothing_patch_count[slot]


func is_hair_long() -> bool:
	return hair_length >= HAIR_LONG_THRESHOLD


## Returns 0 (fresh), 1 (scruffy), 2 (rugged), or 3 (hermit).
func get_rugged_level() -> int:
	if days_since_town_visit >= HERMIT_THRESHOLD:
		return 3
	elif days_since_town_visit >= RUGGED_THRESHOLD:
		return 2
	elif days_since_town_visit >= SCRUFFY_THRESHOLD:
		return 1
	return 0


func serialise() -> Dictionary:
	return {
		"hair_length": hair_length,
		"beard_length": beard_length,
		"dirt_level": dirt_level,
		"days_since_town_visit": days_since_town_visit,
		"hair_style": hair_style as int,
		"clothing_durability": _clothing_durability.duplicate(),
		"clothing_patch_count": _clothing_patch_count.duplicate(),
	}


func deserialise(data: Dictionary) -> void:
	hair_length = data.get("hair_length", 0.0)
	beard_length = data.get("beard_length", 0.0)
	dirt_level = data.get("dirt_level", 0.0)
	days_since_town_visit = data.get("days_since_town_visit", 0)
	hair_style = (data.get("hair_style", HairStyle.LOOSE as int)) as HairStyle
	var saved_dur: Dictionary = data.get("clothing_durability", {})
	var saved_patches: Dictionary = data.get("clothing_patch_count", {})
	for slot: String in _clothing_durability.keys():
		if saved_dur.has(slot):
			_clothing_durability[slot] = saved_dur[slot]
		if saved_patches.has(slot):
			_clothing_patch_count[slot] = saved_patches[slot]
	appearance_changed.emit()


func _on_day_passed(_day: int) -> void:
	hair_length = minf(hair_length + HAIR_GROWTH_PER_DAY, HAIR_MAX)
	if has_beard:
		beard_length = minf(beard_length + BEARD_GROWTH_PER_DAY, BEARD_MAX)
	days_since_town_visit += 1
	for slot: String in _clothing_durability.keys():
		_clothing_durability[slot] = maxf(
			_clothing_durability[slot] - CLOTHING_DEGRADE_PER_DAY, 0.0
		)
	EventBus.appearance_changed.emit()
	appearance_changed.emit()


func _on_hour_passed(_hour: int) -> void:
	dirt_level = minf(dirt_level + DIRT_GAIN_PER_HOUR, DIRT_MAX)
