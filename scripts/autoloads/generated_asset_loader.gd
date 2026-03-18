extends Node

## Scans assets/generated/ for AI-generated assets and makes them available
## to the game.  Sprites can be applied to world objects; music tracks can be
## queued through AudioManager.
##
## Usage:
##   GeneratedAssetLoader.get_sprite("campfire")  -> Texture2D or null
##   GeneratedAssetLoader.get_music_tracks()       -> Array[String]
##   GeneratedAssetLoader.play_generated_music()   -> plays first available track

const GENERATED_DIR := "res://assets/generated/"
const SPRITE_PREFIX := "sprite_"
const MUSIC_PREFIX := "music_"
const SFX_PREFIX := "sfx_"

var _sprite_cache: Dictionary = {}
var _music_paths: Array[String] = []
var _sfx_paths: Array[String] = []


func _ready() -> void:
	_scan_generated_assets()


func _scan_generated_assets() -> void:
	_sprite_cache.clear()
	_music_paths.clear()
	_sfx_paths.clear()

	if not DirAccess.dir_exists_absolute(GENERATED_DIR):
		return

	var dir := DirAccess.open(GENERATED_DIR)
	if dir == null:
		push_warning("GeneratedAssetLoader: could not open %s" % GENERATED_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			_categorise_file(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _categorise_file(file_name: String) -> void:
	var full_path := GENERATED_DIR + file_name
	if file_name.begins_with(SPRITE_PREFIX) and file_name.ends_with(".png"):
		var key := _extract_key(file_name, SPRITE_PREFIX, ".png")
		_sprite_cache[key] = full_path
	elif file_name.begins_with(MUSIC_PREFIX) and file_name.ends_with(".ogg"):
		_music_paths.append(full_path)
	elif file_name.begins_with(SFX_PREFIX) and file_name.ends_with(".wav"):
		_sfx_paths.append(full_path)


func _extract_key(file_name: String, prefix: String, suffix: String) -> String:
	var stripped := file_name.trim_prefix(prefix).trim_suffix(suffix)
	# Remove the trailing _timestamp portion
	var last_underscore := stripped.rfind("_")
	if last_underscore > 0:
		stripped = stripped.left(last_underscore)
	return stripped


## Returns a loaded Texture2D for a generated sprite whose slug contains [keyword],
## or null if none found.
func get_sprite(keyword: String) -> Texture2D:
	for key: String in _sprite_cache:
		if key.contains(keyword):
			var path: String = _sprite_cache[key]
			if ResourceLoader.exists(path):
				return load(path) as Texture2D
			push_error("GeneratedAssetLoader: sprite file missing — %s" % path)
			return null
	return null


## Returns all discovered generated music track paths.
func get_music_tracks() -> Array[String]:
	return _music_paths


## Returns all discovered generated SFX paths.
func get_sfx_paths() -> Array[String]:
	return _sfx_paths


## Plays the first available generated music track through AudioManager.
func play_generated_music() -> void:
	if _music_paths.is_empty():
		push_warning("GeneratedAssetLoader: no generated music tracks found")
		return
	var track_path: String = _music_paths[0]
	if not ResourceLoader.exists(track_path):
		push_error("GeneratedAssetLoader: music file missing — %s" % track_path)
		return
	var stream: AudioStream = load(track_path)
	AudioManager.play_sfx_global(stream)


## Applies a generated sprite texture to a Sprite2D node, if a matching
## generated asset exists.  Returns true if applied, false if no asset found.
func apply_sprite_to_node(keyword: String, target: Sprite2D) -> bool:
	var tex := get_sprite(keyword)
	if tex == null:
		return false
	target.texture = tex
	return true


## Re-scans the generated directory.  Call after generating new assets at runtime.
func rescan() -> void:
	_scan_generated_assets()
