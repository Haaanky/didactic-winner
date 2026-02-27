class_name EventBus
extends Node

## Global signal relay — all cross-system communication goes through here.
## No node holds a direct reference to another node outside its own scene.

# ── Player ────────────────────────────────────────────────────────────────────
signal player_died()
signal player_health_changed(new_health: float)

# ── Game state ─────────────────────────────────────────────────────────────────
signal game_paused(is_paused: bool)

# ── Needs ──────────────────────────────────────────────────────────────────────
signal need_changed(need: String, value: float)
signal need_critical(need: String)
signal need_depleted(need: String)

# ── Time ───────────────────────────────────────────────────────────────────────
signal hour_passed(hour: int)
signal day_passed(day: int)
signal season_changed(season: int)

# ── Weather ────────────────────────────────────────────────────────────────────
signal weather_changed(weather_type: int)
signal temperature_changed(new_temp: float)

# ── Interaction ────────────────────────────────────────────────────────────────
signal interactable_focused(target: Node)
signal interactable_unfocused()
signal interaction_triggered(target: Node)
