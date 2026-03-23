class_name NeedsComponent
extends Node

## Tracks the four survival needs: hunger, warmth, rest, morale.
## Health only drains when a need is fully depleted.
## Emits health_depleted when health reaches zero — PlayerController should connect to this.

signal health_depleted()

const BASE_DRAIN_PER_HOUR: Dictionary = {
	"hunger": 4.0,
	"warmth": 2.0,
	"rest": 3.0,
	"morale": 0.8,
}

const NEED_MAX: float = 100.0
const CRITICAL_THRESHOLD: float = 20.0
const HEALTH_DRAIN_PER_HOUR: float = 10.0

const TEMP_THRESHOLD_EXTREME: float = -15.0
const TEMP_THRESHOLD_COLD: float = -5.0
const TEMP_THRESHOLD_FREEZING: float = 0.0
const TEMP_THRESHOLD_WARM: float = 15.0
const WARMTH_MULTIPLIER_EXTREME: float = 4.0
const WARMTH_MULTIPLIER_COLD: float = 2.0
const WARMTH_MULTIPLIER_FREEZING: float = 1.5
const WARMTH_MULTIPLIER_WARM: float = 0.3

var needs: Dictionary = {
	"hunger": NEED_MAX,
	"warmth": NEED_MAX,
	"rest": NEED_MAX,
	"morale": NEED_MAX,
}
var health: float = NEED_MAX

var _warmth_multiplier: float = 1.0
var _morale_modifiers: float = 0.0
var _depleted_needs: Array[String] = []


func _ready() -> void:
	EventBus.hour_passed.connect(_on_hour_passed)
	EventBus.temperature_changed.connect(_on_temperature_changed)


func restore_need(need: String, amount: float) -> void:
	if not needs.has(need):
		return
	var was_depleted: bool = needs[need] <= 0.0
	needs[need] = minf(needs[need] + amount, NEED_MAX)
	EventBus.need_changed.emit(need, needs[need])
	if was_depleted and needs[need] > 0.0:
		_depleted_needs.erase(need)


func restore_health(amount: float) -> void:
	health = minf(health + amount, NEED_MAX)
	EventBus.health_changed.emit(health)


func add_morale_modifier(amount: float) -> void:
	_morale_modifiers += amount


func set_warmth_multiplier(multiplier: float) -> void:
	_warmth_multiplier = multiplier


func is_need_critical(need: String) -> bool:
	return needs.get(need, NEED_MAX) <= CRITICAL_THRESHOLD


func serialise() -> Dictionary:
	return {
		"needs": needs.duplicate(),
		"health": health,
		"warmth_multiplier": _warmth_multiplier,
	}


func deserialise(data: Dictionary) -> void:
	var saved_needs: Dictionary = data.get("needs", {})
	for key: String in needs.keys():
		if saved_needs.has(key):
			needs[key] = saved_needs[key]
	health = data.get("health", NEED_MAX)
	_warmth_multiplier = data.get("warmth_multiplier", 1.0)


func _drain_need(need: String, amount: float) -> void:
	needs[need] = maxf(needs[need] - amount, 0.0)
	EventBus.need_changed.emit(need, needs[need])
	if needs[need] <= CRITICAL_THRESHOLD and not _depleted_needs.has(need):
		EventBus.need_critical.emit(need)
	if needs[need] <= 0.0 and not _depleted_needs.has(need):
		_depleted_needs.append(need)
		EventBus.need_depleted.emit(need)


func _on_hour_passed(_hour: int) -> void:
	_drain_need("hunger", BASE_DRAIN_PER_HOUR["hunger"])
	var warmth_drain: float = BASE_DRAIN_PER_HOUR["warmth"] * _warmth_multiplier
	_drain_need("warmth", warmth_drain)
	_drain_need("rest", BASE_DRAIN_PER_HOUR["rest"])
	var morale_drain: float = BASE_DRAIN_PER_HOUR["morale"] - _morale_modifiers
	_drain_need("morale", maxf(morale_drain, 0.0))
	_morale_modifiers = 0.0

	if not _depleted_needs.is_empty():
		health = maxf(health - HEALTH_DRAIN_PER_HOUR * _depleted_needs.size(), 0.0)
		EventBus.health_changed.emit(health)
		if health <= 0.0:
			health_depleted.emit()


func _on_temperature_changed(temperature: float) -> void:
	if temperature <= TEMP_THRESHOLD_EXTREME:
		_warmth_multiplier = WARMTH_MULTIPLIER_EXTREME
	elif temperature <= TEMP_THRESHOLD_COLD:
		_warmth_multiplier = WARMTH_MULTIPLIER_COLD
	elif temperature <= TEMP_THRESHOLD_FREEZING:
		_warmth_multiplier = WARMTH_MULTIPLIER_FREEZING
	elif temperature >= TEMP_THRESHOLD_WARM:
		_warmth_multiplier = WARMTH_MULTIPLIER_WARM
	else:
		_warmth_multiplier = 1.0
