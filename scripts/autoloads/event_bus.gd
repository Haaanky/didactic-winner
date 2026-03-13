extends Node

## Global signal relay for decoupled systems.
## All cross-system events are emitted through here.

# ── Player ────────────────────────────────────────────────────────────────────
signal player_died()
signal player_health_changed(new_health: float)
signal player_respawned()
signal stamina_changed(new_stamina: float)
signal item_picked_up(item_id: String, quantity: int)
signal item_dropped(item_id: String, quantity: int)
signal item_consumed(item_id: String, food_value: float)

# ── Game state ────────────────────────────────────────────────────────────────
signal game_paused(is_paused: bool)
signal game_won(days_survived: int)

# ── Needs ─────────────────────────────────────────────────────────────────────
signal need_changed(need: String, value: float)
signal need_critical(need: String)
signal need_depleted(need: String)
signal health_changed(value: float)

# ── Skills ────────────────────────────────────────────────────────────────────
signal skill_xp_gained(skill: String, amount: float)
signal skill_leveled_up(skill: String, new_level: int)

# ── Time ──────────────────────────────────────────────────────────────────────
signal hour_passed(hour: int)
signal day_passed(day: int)
signal season_changed(season: int)

# ── Weather ───────────────────────────────────────────────────────────────────
signal weather_changed(weather_type: int)
signal temperature_changed(new_temp: float)

# ── Interaction ───────────────────────────────────────────────────────────────
signal interactable_focused(target: Node)
signal interactable_unfocused()
signal interaction_triggered(target: Node)
signal interact_prompt_changed(prompt: String)

# ── World ─────────────────────────────────────────────────────────────────────
signal campfire_lit(campfire: Node)
signal campfire_extinguished(campfire: Node)
signal tree_chopped(position: Vector2, logs_yielded: int)
signal berries_gathered(position: Vector2, count: int)
signal stone_mined(position: Vector2, count: int)

# ── Fishing ───────────────────────────────────────────────────────────────────
signal fish_bite()
signal fish_caught(item_id: String)
signal fish_missed()

# ── Crafting ──────────────────────────────────────────────────────────────────
signal crafting_opened(at_campfire: bool)
signal crafting_closed()
signal item_crafted(output_id: String)

# ── Save ──────────────────────────────────────────────────────────────────────
signal game_saved(slot: int)
signal game_loaded(slot: int)

# ── Appearance ────────────────────────────────────────────────────────────────
signal appearance_changed()

# ── UI ────────────────────────────────────────────────────────────────────────
signal journal_entry_added(entry: String)
signal ui_screen_opened(screen_name: String)
signal ui_screen_closed(screen_name: String)
