class_name Campfire
extends Node2D

## Placeable campfire. Emits warmth in an area.
## Must be fuelled with logs to remain lit.
## When lit, player can interact to open the campfire crafting/cooking screen.

signal lit()
signal extinguished()

const WARMTH_RADIUS: float = 96.0
const FUEL_BURN_PER_HOUR: float = 1.0
const WARMTH_MULTIPLIER_NEAR_FIRE: float = 0.05
const LOG_ITEM_ID: StringName = &"log"

@export var flame_sprite: AnimatedSprite2D
@export var warmth_area: Area2D
@export var light_occluder: Light2D

var is_lit: bool = false
var fuel_logs: int = 0


func _ready() -> void:
	EventBus.hour_passed.connect(_on_hour_passed)
	if warmth_area != null:
		warmth_area.body_entered.connect(_on_body_entered)
		warmth_area.body_exited.connect(_on_body_exited)
	_update_visuals()


func interact(player: PlayerController) -> void:
	if not is_lit:
		_try_light(player)
	else:
		_handle_lit_interaction(player)


func get_interact_prompt(player: PlayerController) -> String:
	if not is_lit:
		if player.inventory != null and player.inventory.has_item(LOG_ITEM_ID, 2):
			return "[E] Light Campfire (needs 2 logs)"
		return "Campfire (need 2 logs to light)"
	return "[E] Cook / Add Fuel"


func add_fuel(logs: int) -> void:
	fuel_logs += logs


func _try_light(player: PlayerController) -> void:
	if player.inventory == null:
		return
	if not player.inventory.has_item(LOG_ITEM_ID, 2):
		EventBus.journal_entry_added.emit("Need at least 2 logs to start a fire. Chop a tree [E].")
		return
	player.inventory.remove_item(LOG_ITEM_ID, 2)
	fuel_logs += 2
	is_lit = true
	_update_visuals()
	lit.emit()
	EventBus.campfire_lit.emit(self)
	EventBus.journal_entry_added.emit("Campfire lit! Stay warm. Cook food here with [E].")


func _handle_lit_interaction(player: PlayerController) -> void:
	if player.inventory != null and player.inventory.has_item(LOG_ITEM_ID):
		player.inventory.remove_item(LOG_ITEM_ID, 1)
		fuel_logs += 1
		EventBus.journal_entry_added.emit("Added a log to the fire (fuel: %d hrs)." % fuel_logs)
	EventBus.crafting_opened.emit(true)


func _extinguish() -> void:
	is_lit = false
	_update_visuals()
	extinguished.emit()
	EventBus.campfire_extinguished.emit(self)


func _update_visuals() -> void:
	if flame_sprite != null:
		flame_sprite.visible = is_lit
		if is_lit:
			if fuel_logs >= 2:
				flame_sprite.play(&"flickering")
			else:
				flame_sprite.play(&"embers")
		else:
			flame_sprite.stop()
	if light_occluder != null:
		light_occluder.visible = is_lit


func _on_hour_passed(_hour: int) -> void:
	if not is_lit:
		return
	fuel_logs -= 1
	if fuel_logs <= 0:
		fuel_logs = 0
		_extinguish()
		return
	_update_visuals()


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController and is_lit:
		(body as PlayerController).needs.set_warmth_multiplier(WARMTH_MULTIPLIER_NEAR_FIRE)


func _on_body_exited(body: Node2D) -> void:
	if body is PlayerController:
		(body as PlayerController).needs.set_warmth_multiplier(1.0)
