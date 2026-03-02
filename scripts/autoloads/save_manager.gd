class_name SaveManager
extends Node

## Serialises and deserialises the full game state to/from JSON.
## Three save slots supported.

const SAVE_DIR: String = "user://saves/"
const SAVE_VERSION: String = "1.0"
const MAX_SLOTS: int = 3

var _player_ref: Node = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func register_player(player: Node) -> void:
	_player_ref = player


func save(slot: int) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("SaveManager.save: slot out of range — %d (valid: 0–%d)" % [slot, MAX_SLOTS - 1])
		return
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"time": TimeManager.serialise(),
		"weather": WeatherManager.serialise(),
		"player": _serialise_player(),
	}
	var path: String = SAVE_DIR + "slot_%d.json" % slot
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open %s for writing" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	EventBus.game_saved.emit(slot)


func load_slot(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("SaveManager.load_slot: slot out of range — %d (valid: 0–%d)" % [slot, MAX_SLOTS - 1])
		return false
	var path: String = SAVE_DIR + "slot_%d.json" % slot
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager.load_slot: could not open %s for reading" % path)
		return false
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("SaveManager: corrupt save in slot %d" % slot)
		return false
	var data: Dictionary = parsed as Dictionary
	TimeManager.deserialise(data.get("time", {}))
	WeatherManager.deserialise(data.get("weather", {}))
	_deserialise_player(data.get("player", {}))
	EventBus.game_loaded.emit(slot)
	return true


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(SAVE_DIR + "slot_%d.json" % slot)


func _serialise_player() -> Dictionary:
	if _player_ref == null or not is_instance_valid(_player_ref):
		return {}
	if _player_ref.has_method("serialise"):
		return _player_ref.serialise()
	return {}


func _deserialise_player(data: Dictionary) -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
		return
	if _player_ref.has_method("deserialise"):
		_player_ref.deserialise(data)
