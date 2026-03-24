class_name InventoryComponent
extends Node

## Weight-based inventory system.
## Items are tracked by item_id with quantity and weight per unit.

signal inventory_changed()
signal weight_limit_reached()

const MAX_WEIGHT: float = 30.0
const _PICKUP_SFX: AudioStream = preload("res://assets/audio/item_pickup.wav")

var items: Dictionary = {}
var total_weight: float = 0.0


func add_item(item_id: String, quantity: int, weight_per_unit: float) -> bool:
	var added_weight: float = quantity * weight_per_unit
	if total_weight + added_weight > MAX_WEIGHT:
		weight_limit_reached.emit()
		return false
	if items.has(item_id):
		items[item_id]["quantity"] += quantity
	else:
		items[item_id] = {
			"quantity": quantity,
			"weight_per_unit": weight_per_unit,
		}
	total_weight += added_weight
	AudioManager.play_sfx_global(_PICKUP_SFX)
	EventBus.item_picked_up.emit(item_id, quantity)
	inventory_changed.emit()
	return true


func remove_item(item_id: String, quantity: int) -> bool:
	if not items.has(item_id):
		return false
	if items[item_id]["quantity"] < quantity:
		return false
	var weight_removed: float = quantity * items[item_id]["weight_per_unit"]
	items[item_id]["quantity"] -= quantity
	if items[item_id]["quantity"] <= 0:
		items.erase(item_id)
	total_weight -= weight_removed
	EventBus.item_dropped.emit(item_id, quantity)
	inventory_changed.emit()
	return true


func has_item(item_id: String, quantity: int = 1) -> bool:
	if not items.has(item_id):
		return false
	return items[item_id]["quantity"] >= quantity


func get_quantity(item_id: String) -> int:
	if not items.has(item_id):
		return 0
	return items[item_id]["quantity"]


func get_weight_ratio() -> float:
	return total_weight / MAX_WEIGHT


func serialise() -> Dictionary:
	return {
		"items": items.duplicate(true),
		"total_weight": total_weight,
	}


func deserialise(data: Dictionary) -> void:
	items = data.get("items", {})
	total_weight = data.get("total_weight", 0.0)
	inventory_changed.emit()
