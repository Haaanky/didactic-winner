class_name PlayerController
extends CharacterBody2D

## Main player controller. Handles 8-directional movement, stamina, health, and interaction.
## Needs, inventory, and skill progression are delegated to child components.

signal health_changed(new_health: float)
signal interacted_with(target: Node)
signal player_died()

const _FOOTSTEP_SNOW: AudioStream = preload("res://assets/audio/footstep_snow.wav")

const MOVE_SPEED: float = 120.0
const RUN_SPEED: float = 200.0
const MAX_HEALTH: float = 100.0
const INTERACT_REACH: float = 40.0
const STAMINA_MAX: float = 100.0
const STAMINA_DRAIN_PER_SECOND: float = 20.0
const STAMINA_REGEN_PER_SECOND: float = 10.0
const ENCUMBRANCE_SPEED_PENALTY: float = 0.4
const HURT_FLASH_DURATION: float = 0.15
const DEATH_ANIM_DURATION: float = 0.8
const PROMPT_CHECK_INTERVAL: float = 0.1

@export var sprint_multiplier: float = 1.6
@export var needs: NeedsComponent
@export var inventory: InventoryComponent
@export var skills: SkillComponent
@export var appearance: AppearanceComponent
@export var sprite: AnimatedSprite2D
@export var footstep_player: AudioStreamPlayer2D

var health: float = MAX_HEALTH
var stamina: float = STAMINA_MAX
var _is_alive: bool = true
var _is_running: bool = false
var _last_direction: Vector2 = Vector2.DOWN
var _footstep_timer: float = 0.0
var _prompt_timer: float = 0.0
var _last_prompt: String = ""
var _hurt_tween: Tween

var interact_ray: RayCast2D
var camera: Camera2D


func _ready() -> void:
	interact_ray = get_node_or_null("InteractRay") as RayCast2D
	camera = get_node_or_null("Camera2D") as Camera2D
	add_to_group("player")
	SaveManager.register_player(self)
	GameManager.set_state(GameManager.GameState.PLAYING)
	if footstep_player != null:
		footstep_player.stream = _FOOTSTEP_SNOW
	_give_starting_items()


func _physics_process(delta: float) -> void:
	if not _is_alive:
		return
	_handle_movement(delta)
	_handle_stamina(delta)
	move_and_slide()
	_handle_footsteps(delta)
	_handle_interact_prompt(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_alive:
		return
	if event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("consume"):
		_try_consume()
	elif event.is_action_pressed("open_inventory"):
		EventBus.ui_screen_opened.emit("inventory")
	elif event.is_action_pressed("check_needs"):
		EventBus.ui_screen_opened.emit("needs_hud")
	elif event.is_action_pressed("open_journal"):
		EventBus.ui_screen_opened.emit("journal")
	elif event.is_action_pressed("pause"):
		var is_paused: bool = GameManager.current_state == GameManager.GameState.PAUSED
		EventBus.game_paused.emit(not is_paused)


func take_damage(amount: float) -> void:
	if not _is_alive:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health)
	EventBus.player_health_changed.emit(health)
	if health <= 0.0:
		_die()
		return
	_play_hurt_flash()


func heal(amount: float) -> void:
	if not _is_alive:
		return
	health = minf(MAX_HEALTH, health + amount)
	health_changed.emit(health)
	EventBus.player_health_changed.emit(health)


func serialise() -> Dictionary:
	return {
		"position": {"x": global_position.x, "y": global_position.y},
		"health": health,
		"stamina": stamina,
		"needs": needs.serialise() if needs != null else {},
		"inventory": inventory.serialise() if inventory != null else {},
		"skills": skills.serialise() if skills != null else {},
		"appearance": appearance.serialise() if appearance != null else {},
	}


func deserialise(data: Dictionary) -> void:
	var pos: Dictionary = data.get("position", {"x": 0.0, "y": 0.0})
	global_position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
	health = data.get("health", MAX_HEALTH)
	stamina = data.get("stamina", STAMINA_MAX)
	if needs != null:
		needs.deserialise(data.get("needs", {}))
	if inventory != null:
		inventory.deserialise(data.get("inventory", {}))
	if skills != null:
		skills.deserialise(data.get("skills", {}))
	if appearance != null:
		appearance.deserialise(data.get("appearance", {}))


func _give_starting_items() -> void:
	if inventory == null or not inventory.items.is_empty():
		return
	inventory.add_item("hand_axe", 1, ItemDatabase.get_weight("hand_axe"))
	inventory.add_item("hunting_knife", 1, ItemDatabase.get_weight("hunting_knife"))
	inventory.add_item("berries", 6, ItemDatabase.get_weight("berries"))
	inventory.add_item("dried_fish", 3, ItemDatabase.get_weight("dried_fish"))
	EventBus.journal_entry_added.emit(
		"You wake in the Alaskan wilderness. Survive 3 days. Chop trees [E], build fires, eat [F]."
	)


func _handle_movement(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_is_running = Input.is_action_pressed("sprint") and stamina > 0.0
	if direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		_play_idle_animation()
		return
	_last_direction = direction
	if interact_ray != null:
		interact_ray.target_position = direction.normalized() * INTERACT_REACH
	var speed: float = _calculate_speed()
	velocity = direction * speed
	_play_walk_animation(direction)


func _handle_stamina(delta: float) -> void:
	var old_stamina: float = stamina
	if velocity != Vector2.ZERO and _is_running:
		stamina = maxf(stamina - STAMINA_DRAIN_PER_SECOND * delta, 0.0)
		if stamina <= 0.0:
			_is_running = false
	elif velocity == Vector2.ZERO:
		stamina = minf(stamina + STAMINA_REGEN_PER_SECOND * delta, STAMINA_MAX)
	if stamina != old_stamina:
		EventBus.stamina_changed.emit(stamina)


func _handle_footsteps(delta: float) -> void:
	if velocity == Vector2.ZERO:
		_footstep_timer = 0.0
		return
	var interval: float = 0.45 if not _is_running else 0.3
	_footstep_timer += delta
	if _footstep_timer >= interval:
		_footstep_timer = 0.0
		_play_footstep()


func _handle_interact_prompt(delta: float) -> void:
	if interact_ray == null:
		return
	_prompt_timer += delta
	if _prompt_timer < PROMPT_CHECK_INTERVAL:
		return
	_prompt_timer = 0.0
	var prompt: String = ""
	if interact_ray.is_colliding():
		var target: Object = interact_ray.get_collider()
		if target is Node:
			var parent: Node = (target as Node).get_parent()
			if is_instance_valid(parent) and parent.has_method("get_interact_prompt"):
				prompt = parent.get_interact_prompt(self)
			elif (target as Node).has_method("get_interact_prompt"):
				prompt = (target as Node).get_interact_prompt(self)
	if prompt != _last_prompt:
		_last_prompt = prompt
		EventBus.interact_prompt_changed.emit(prompt)


func _calculate_speed() -> float:
	var encumbrance_ratio: float = 0.0
	if inventory != null:
		encumbrance_ratio = inventory.get_weight_ratio()
	var base: float = RUN_SPEED * sprint_multiplier if _is_running else MOVE_SPEED
	return base * (1.0 - encumbrance_ratio * ENCUMBRANCE_SPEED_PENALTY)


func _try_interact() -> void:
	if interact_ray == null or not interact_ray.is_colliding():
		return
	var target: Object = interact_ray.get_collider()
	if not (target is Node):
		return
	interacted_with.emit(target as Node)
	EventBus.interaction_triggered.emit(target as Node)
	var node: Node = target as Node
	var parent: Node = node.get_parent()
	if is_instance_valid(parent) and parent.has_method("interact"):
		parent.interact(self)
	elif node.has_method("interact"):
		node.interact(self)


func _try_consume() -> void:
	if inventory == null or needs == null:
		return
	var best_id: String = _find_best_food()
	if best_id.is_empty():
		EventBus.journal_entry_added.emit("No food to eat. Gather berries or catch fish.")
		return
	var food_value: float = ItemDatabase.get_food_value(best_id)
	var warmth_value: float = ItemDatabase.get_warmth_value(best_id)
	inventory.remove_item(best_id, 1)
	needs.restore_need("hunger", food_value)
	if warmth_value > 0.0:
		needs.restore_need("warmth", warmth_value)
	var name_str: String = ItemDatabase.get_display_name(best_id)
	EventBus.journal_entry_added.emit("Ate %s." % name_str)
	EventBus.item_consumed.emit(best_id, food_value)


func _find_best_food() -> String:
	if inventory == null:
		return ""
	var best_id: String = ""
	var best_value: float = 0.0
	for item_id: String in inventory.items.keys():
		if not ItemDatabase.is_food(item_id):
			continue
		var val: float = ItemDatabase.get_food_value(item_id)
		if val > best_value:
			best_value = val
			best_id = item_id
	return best_id


func _play_walk_animation(direction: Vector2) -> void:
	if sprite == null:
		return
	var animation: StringName
	if abs(direction.x) > abs(direction.y):
		animation = &"run_side" if _is_running else &"walk_side"
		sprite.flip_h = direction.x < 0.0
	elif direction.y < 0.0:
		animation = &"run_up" if _is_running else &"walk_up"
	else:
		animation = &"run_down" if _is_running else &"walk_down"
	if sprite.animation != animation:
		sprite.play(animation)


func _play_idle_animation() -> void:
	if sprite == null:
		return
	var animation: StringName
	if abs(_last_direction.x) > abs(_last_direction.y):
		animation = &"idle_side"
		sprite.flip_h = _last_direction.x < 0.0
	elif _last_direction.y < 0.0:
		animation = &"idle_up"
	else:
		animation = &"idle_down"
	if sprite.animation != animation:
		sprite.play(animation)


func _play_footstep() -> void:
	if footstep_player == null:
		return
	footstep_player.play()


func _play_hurt_flash() -> void:
	if sprite == null:
		return
	if is_instance_valid(_hurt_tween):
		_hurt_tween.kill()
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(sprite, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.0)
	_hurt_tween.tween_property(sprite, "modulate", Color.WHITE, HURT_FLASH_DURATION)


func _play_death_animation() -> void:
	if sprite == null:
		return
	if is_instance_valid(_hurt_tween):
		_hurt_tween.kill()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.0, 0.0, 0.0), DEATH_ANIM_DURATION)
	tween.tween_property(sprite, "scale", Vector2.ZERO, DEATH_ANIM_DURATION)


func _die() -> void:
	_is_alive = false
	_play_death_animation()
	player_died.emit()
	EventBus.player_died.emit()
