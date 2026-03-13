extends GutTest

## Tests for FishingSpot world object.

var _spot: FishingSpot
var _player: PlayerController


func before_each() -> void:
	_spot = FishingSpot.new()
	add_child(_spot)
	_player = PlayerController.new()
	add_child(_player)
	var inv: InventoryComponent = InventoryComponent.new()
	_player.inventory = inv
	_player.add_child(inv)
	var skills: SkillComponent = SkillComponent.new()
	_player.skills = skills
	_player.add_child(skills)
	await get_tree().process_frame


func after_each() -> void:
	_player.queue_free()
	_spot.queue_free()


func test_spot_starts_in_idle_state() -> void:
	assert_eq(_spot.fish_state, FishingSpot.FishState.IDLE)


func test_interact_from_idle_transitions_to_waiting() -> void:
	_spot.interact(_player)
	assert_eq(_spot.fish_state, FishingSpot.FishState.WAITING_FOR_BITE)


func test_interact_during_bite_catches_fish() -> void:
	_spot.fish_state = FishingSpot.FishState.BITING
	_spot._bite_countdown = 2.5
	_spot._fishing_player = _player
	_spot.interact(_player)
	assert_true(_player.inventory.has_item("raw_fish"))


func test_catch_transitions_to_cooldown() -> void:
	_spot.fish_state = FishingSpot.FishState.BITING
	_spot._bite_countdown = 2.5
	_spot._fishing_player = _player
	_spot.interact(_player)
	assert_eq(_spot.fish_state, FishingSpot.FishState.COOLDOWN)


func test_bite_countdown_expiry_triggers_escape() -> void:
	_spot.fish_state = FishingSpot.FishState.BITING
	_spot._bite_countdown = 0.01
	_spot._process(0.02)
	assert_eq(_spot.fish_state, FishingSpot.FishState.COOLDOWN)


func test_cooldown_expires_and_returns_to_idle() -> void:
	_spot.fish_state = FishingSpot.FishState.COOLDOWN
	_spot._cooldown_timer = 0.01
	_spot._process(0.02)
	assert_eq(_spot.fish_state, FishingSpot.FishState.IDLE)


func test_get_interact_prompt_changes_by_state() -> void:
	_spot.fish_state = FishingSpot.FishState.IDLE
	assert_string_contains(_spot.get_interact_prompt(_player), "Cast")

	_spot.fish_state = FishingSpot.FishState.WAITING_FOR_BITE
	assert_string_contains(_spot.get_interact_prompt(_player), "Waiting")

	_spot.fish_state = FishingSpot.FishState.BITING
	assert_string_contains(_spot.get_interact_prompt(_player), "PULL")


func test_fish_bite_signal_emitted_when_bite_triggers() -> void:
	var bite_count: int = 0
	EventBus.fish_bite.connect(func() -> void: bite_count += 1)
	_spot._trigger_bite()
	assert_eq(bite_count, 1)
	EventBus.fish_bite.disconnect_all()


func test_fish_caught_signal_emitted_on_successful_catch() -> void:
	var caught_id: String = ""
	EventBus.fish_caught.connect(func(id: String) -> void: caught_id = id)
	_spot.fish_state = FishingSpot.FishState.BITING
	_spot._bite_countdown = 2.5
	_spot._fishing_player = _player
	_spot.interact(_player)
	assert_eq(caught_id, "raw_fish")
	EventBus.fish_caught.disconnect_all()


func test_fish_missed_signal_emitted_on_escape() -> void:
	var missed: bool = false
	EventBus.fish_missed.connect(func() -> void: missed = true)
	_spot._fish_escaped()
	assert_true(missed)
	EventBus.fish_missed.disconnect_all()
