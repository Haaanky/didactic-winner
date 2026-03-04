extends GutTest

# Tests SaveManager slot validation, file I/O, and signal emission.
# Tests that write real files clean up after themselves in after_each.

const _SaveManagerScript := preload("res://scripts/autoloads/save_manager.gd")
const TEST_SLOT: int = 0

var _sm: Node


func before_each() -> void:
	_sm = _SaveManagerScript.new()
	add_child(_sm)


func after_each() -> void:
	var path: String = "user://saves/slot_%d.json" % TEST_SLOT
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_sm.queue_free()


# ── slot validation ───────────────────────────────────────────────────────────

func test_save_with_negative_slot_logs_error() -> void:
	assert_error_emitted(func(): _sm.save(-1))


func test_save_with_out_of_range_slot_logs_error() -> void:
	assert_error_emitted(func(): _sm.save(_sm.MAX_SLOTS))


func test_load_slot_with_negative_slot_logs_error() -> void:
	assert_error_emitted(func(): _sm.load_slot(-1))


func test_load_slot_with_out_of_range_slot_logs_error() -> void:
	assert_error_emitted(func(): _sm.load_slot(_sm.MAX_SLOTS))


func test_load_slot_with_invalid_slot_returns_false() -> void:
	assert_false(_sm.load_slot(_sm.MAX_SLOTS))


# ── slot_exists ───────────────────────────────────────────────────────────────

func test_slot_exists_returns_false_for_new_slot() -> void:
	assert_false(_sm.slot_exists(TEST_SLOT))


# ── save and load ─────────────────────────────────────────────────────────────

func test_save_creates_file() -> void:
	_sm.save(TEST_SLOT)
	assert_true(FileAccess.file_exists("user://saves/slot_%d.json" % TEST_SLOT))


func test_save_emits_game_saved() -> void:
	watch_signals(EventBus)
	_sm.save(TEST_SLOT)
	assert_signal_emitted_with_parameters(EventBus, "game_saved", [TEST_SLOT])


func test_slot_exists_true_after_save() -> void:
	_sm.save(TEST_SLOT)
	assert_true(_sm.slot_exists(TEST_SLOT))


func test_load_slot_returns_false_when_file_absent() -> void:
	assert_false(_sm.load_slot(TEST_SLOT))


func test_load_slot_returns_true_after_save() -> void:
	_sm.save(TEST_SLOT)
	assert_true(_sm.load_slot(TEST_SLOT))


func test_load_slot_emits_game_loaded() -> void:
	_sm.save(TEST_SLOT)
	watch_signals(EventBus)
	_sm.load_slot(TEST_SLOT)
	assert_signal_emitted_with_parameters(EventBus, "game_loaded", [TEST_SLOT])


# ── corrupt save ──────────────────────────────────────────────────────────────

func test_load_slot_returns_false_on_corrupt_json() -> void:
	var path: String = "user://saves/slot_%d.json" % TEST_SLOT
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not valid json {{{{")
	file.close()
	assert_false(_sm.load_slot(TEST_SLOT))


func test_load_slot_logs_error_on_corrupt_json() -> void:
	var path: String = "user://saves/slot_%d.json" % TEST_SLOT
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not valid json {{{{")
	file.close()
	assert_error_emitted(func(): _sm.load_slot(TEST_SLOT))


# ── player registration ───────────────────────────────────────────────────────

func test_register_player_sets_player_ref() -> void:
	var dummy := Node.new()
	_sm.register_player(dummy)
	assert_eq(_sm._player_ref, dummy)
	dummy.queue_free()


func test_serialise_player_returns_empty_dict_when_no_player() -> void:
	var result: Dictionary = _sm._serialise_player()
	assert_eq(result.size(), 0)
