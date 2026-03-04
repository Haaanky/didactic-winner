class_name NeedsComponent
extends Node

## Tracks the four survival needs: hunger, warmth, rest, morale.
## When a need is fully depleted, health damage is delegated to the parent PlayerController.

const BASE_DRAIN_PER_HOUR: Dictionary = {
	"hunger": 4.0,
	"warmth": 2.0,
	"rest": 1.0,
	"morale": 0.5,
}

const NEED_MAX: float = 100.0
const CRITICAL_THRESHOLD: float = 20.0
const HEALTH_DRAIN_PER_HOUR: float = 10.0

var needs: Dictionary = {
	"hunger": NEED_MAX,
	"warmth": NEED_MAX,
	"rest": NEED_MAX,
	"morale": NEED_MAX,
}

var _warmth_multiplier: float = 1.0
var _morale_modifiers: float = 0.0
var _depleted_needs: Array[String] = []
var _player_controller: PlayerController = null


func _ready() -> void:
	_player_controller = get_parent() as PlayerController
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


func add_morale_modifier(amount: float) -> void:
	_morale_modifiers += amount


func set_warmth_multiplier(multiplier: float) -> void:
	_warmth_multiplier = multiplier


func is_need_critical(need: String) -> bool:
	return needs.get(need, NEED_MAX) <= CRITICAL_THRESHOLD


func serialise() -> Dictionary:
	return {
		"needs": needs.duplicate(),
		"warmth_multiplier": _warmth_multiplier,
	}


func deserialise(data: Dictionary) -> void:
	var saved_needs: Dictionary = data.get("needs", {})
	for key: String in needs.keys():
		if saved_needs.has(key):
			needs[key] = saved_needs[key]
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
		var drain_amount: float = HEALTH_DRAIN_PER_HOUR * _depleted_needs.size()
		if _player_controller != null and is_instance_valid(_player_controller):
			_player_controller.take_damage(drain_amount)


func _on_temperature_changed(temperature: float) -> void:
	if temperature <= -15.0:
		_warmth_multiplier = 4.0
	elif temperature <= -5.0:
		_warmth_multiplier = 2.0
	elif temperature <= 0.0:
		_warmth_multiplier = 1.5
	elif temperature >= 15.0:
		_warmth_multiplier = 0.3
	else:
		_warmth_multiplier = 1.0
