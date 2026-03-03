extends GutTest

# Tests for HUD scene and hud.gd.
# The HUD has no interactive elements, so coverage focuses on signal-driven
# state changes: need bars, critical icon visibility, health, and season label.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _hud: HUD


func before_each() -> void:
	_hud = HUD_SCENE.instantiate() as HUD
	add_child(_hud)
	await get_tree().process_frame


func after_each() -> void:
	_hud.queue_free()


# ── Node wiring ───────────────────────────────────────────────────────────────

func test_all_exported_nodes_are_wired() -> void:
	assert_not_null(_hud.health_bar)
	assert_not_null(_hud.health_label)
	assert_not_null(_hud.needs_panel)
	assert_not_null(_hud.hunger_bar)
	assert_not_null(_hud.warmth_bar)
	assert_not_null(_hud.rest_bar)
	assert_not_null(_hud.morale_bar)
	assert_not_null(_hud.critical_icons)
	assert_not_null(_hud.hunger_critical_icon)
	assert_not_null(_hud.warmth_critical_icon)
	assert_not_null(_hud.rest_critical_icon)
	assert_not_null(_hud.morale_critical_icon)
	assert_not_null(_hud.season_day_label)


# ── Initial state ─────────────────────────────────────────────────────────────

func test_needs_panel_hidden_by_default() -> void:
	assert_false(_hud.needs_panel.visible)


func test_critical_icons_hidden_by_default() -> void:
	assert_false(_hud.hunger_critical_icon.visible)
	assert_false(_hud.warmth_critical_icon.visible)
	assert_false(_hud.rest_critical_icon.visible)
	assert_false(_hud.morale_critical_icon.visible)


func test_health_bar_starts_at_max() -> void:
	assert_eq(_hud.health_bar.value, HUD.HEALTH_MAX)


# ── Health updates ────────────────────────────────────────────────────────────

func test_player_health_changed_updates_health_bar() -> void:
	EventBus.player_health_changed.emit(75.0)
	assert_eq(_hud.health_bar.value, 75.0)


func test_player_health_changed_updates_health_label() -> void:
	EventBus.player_health_changed.emit(42.0)
	assert_eq(_hud.health_label.text, "Health: 42")


# ── Needs bar updates ─────────────────────────────────────────────────────────

func test_need_changed_hunger_updates_hunger_bar() -> void:
	EventBus.need_changed.emit("hunger", 60.0)
	assert_eq(_hud.hunger_bar.value, 60.0)


func test_need_changed_warmth_updates_warmth_bar() -> void:
	EventBus.need_changed.emit("warmth", 45.0)
	assert_eq(_hud.warmth_bar.value, 45.0)


func test_need_changed_rest_updates_rest_bar() -> void:
	EventBus.need_changed.emit("rest", 80.0)
	assert_eq(_hud.rest_bar.value, 80.0)


func test_need_changed_morale_updates_morale_bar() -> void:
	EventBus.need_changed.emit("morale", 55.0)
	assert_eq(_hud.morale_bar.value, 55.0)


# ── Critical icon visibility ──────────────────────────────────────────────────

func test_hunger_critical_icon_shown_when_below_threshold() -> void:
	EventBus.need_changed.emit("hunger", HUD.CRITICAL_THRESHOLD - 1.0)
	assert_true(_hud.hunger_critical_icon.visible)


func test_hunger_critical_icon_hidden_when_above_threshold() -> void:
	EventBus.need_changed.emit("hunger", HUD.CRITICAL_THRESHOLD + 1.0)
	assert_false(_hud.hunger_critical_icon.visible)


func test_warmth_critical_icon_shown_when_below_threshold() -> void:
	EventBus.need_changed.emit("warmth", HUD.CRITICAL_THRESHOLD - 1.0)
	assert_true(_hud.warmth_critical_icon.visible)


func test_warmth_critical_icon_hidden_when_above_threshold() -> void:
	EventBus.need_changed.emit("warmth", HUD.CRITICAL_THRESHOLD + 1.0)
	assert_false(_hud.warmth_critical_icon.visible)


func test_rest_critical_icon_shown_when_below_threshold() -> void:
	EventBus.need_changed.emit("rest", HUD.CRITICAL_THRESHOLD - 1.0)
	assert_true(_hud.rest_critical_icon.visible)


func test_rest_critical_icon_hidden_when_above_threshold() -> void:
	EventBus.need_changed.emit("rest", HUD.CRITICAL_THRESHOLD + 1.0)
	assert_false(_hud.rest_critical_icon.visible)


func test_morale_critical_icon_shown_when_below_threshold() -> void:
	EventBus.need_changed.emit("morale", HUD.CRITICAL_THRESHOLD - 1.0)
	assert_true(_hud.morale_critical_icon.visible)


func test_morale_critical_icon_hidden_when_above_threshold() -> void:
	EventBus.need_changed.emit("morale", HUD.CRITICAL_THRESHOLD + 1.0)
	assert_false(_hud.morale_critical_icon.visible)


# ── Needs panel visibility ────────────────────────────────────────────────────

func test_ui_screen_opened_needs_hud_shows_needs_panel() -> void:
	EventBus.ui_screen_opened.emit("needs_hud")
	assert_true(_hud.needs_panel.visible)


func test_needs_panel_hides_after_display_duration() -> void:
	EventBus.ui_screen_opened.emit("needs_hud")
	# Drive _process forward past DISPLAY_DURATION (4 s) in 20 ms steps.
	for _i in range(210):
		_hud._process(0.02)
	assert_false(_hud.needs_panel.visible)


func test_needs_panel_not_shown_for_unrelated_screen() -> void:
	EventBus.ui_screen_opened.emit("pause_menu")
	assert_false(_hud.needs_panel.visible)


# ── Season label ──────────────────────────────────────────────────────────────

func test_hour_passed_updates_season_day_label() -> void:
	EventBus.hour_passed.emit(1)
	assert_false(_hud.season_day_label.text.is_empty())
