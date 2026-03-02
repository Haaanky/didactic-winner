extends Node

## Global signal relay for decoupled systems.
## All cross-system events are emitted through here.

# ── Player ────────────────────────────────────────────────────────────────────
signal player_died()
signal player_health_changed(new_health: float)
signal player_respawned()
signal item_picked_up(item_id: String, quantity: int)
signal item_dropped(item_id: String, quantity: int)

# ── Game state ────────────────────────────────────────────────────────────────
signal game_paused(is_paused: bool)

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

# ── World ─────────────────────────────────────────────────────────────────────
signal campfire_lit(campfire: Node)
signal campfire_extinguished(campfire: Node)
signal tree_chopped(position: Vector2, logs_yielded: int)

# ── Save ──────────────────────────────────────────────────────────────────────
signal game_saved(slot: int)
signal game_loaded(slot: int)

# ── Appearance ────────────────────────────────────────────────────────────────
signal appearance_changed()

# ── UI ────────────────────────────────────────────────────────────────────────
signal journal_entry_added(entry: String)
signal ui_screen_opened(screen_name: String)
signal ui_screen_closed(screen_name: String)
