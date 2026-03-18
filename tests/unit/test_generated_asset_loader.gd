extends GutTest
## Tests for GeneratedAssetLoader — scanning, categorisation, and sprite/music access.

const LoaderScript := preload("res://scripts/autoloads/generated_asset_loader.gd")

var _loader: Node
var _test_files: Array[String] = []

const GEN_DIR := "res://assets/generated/"


func before_each() -> void:
	# Ensure directory exists
	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists("assets/generated"):
		dir.make_dir_recursive("assets/generated")
	_loader = LoaderScript.new()
	add_child(_loader)


func after_each() -> void:
	# Clean up any test files we created
	for path: String in _test_files:
		DirAccess.remove_absolute(path)
	_test_files.clear()
	_loader.queue_free()


func _create_test_file(file_name: String, content: String = "x") -> String:
	var path := GEN_DIR + file_name
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
	_test_files.append(path)
	return path


# ── scan / categorise ────────────────────────────────────────────────────────

func test_scan_finds_sprite_files() -> void:
	_create_test_file("sprite_campfire_test_9999999.png")
	_loader.rescan()
	assert_true(_loader._sprite_cache.has("campfire_test"))


func test_scan_finds_music_files() -> void:
	_create_test_file("music_guitar_9999999.ogg")
	_loader.rescan()
	var tracks: Array[String] = _loader.get_music_tracks()
	assert_eq(tracks.size(), 1)
	assert_string_contains(tracks[0], "music_guitar")


func test_scan_finds_sfx_files() -> void:
	_create_test_file("sfx_boom_9999999.wav")
	_loader.rescan()
	var paths: Array[String] = _loader.get_sfx_paths()
	assert_eq(paths.size(), 1)
	assert_string_contains(paths[0], "sfx_boom")


func test_scan_ignores_unrelated_files() -> void:
	_create_test_file("random_notes.txt")
	_loader.rescan()
	assert_eq(_loader._sprite_cache.size(), 0)
	assert_eq(_loader.get_music_tracks().size(), 0)
	assert_eq(_loader.get_sfx_paths().size(), 0)


# ── _extract_key ─────────────────────────────────────────────────────────────

func test_extract_key_strips_prefix_suffix_timestamp() -> void:
	var key: String = _loader._extract_key("sprite_campfire_1234567890.png", "sprite_", ".png")
	assert_eq(key, "campfire")


func test_extract_key_multi_word_slug() -> void:
	var key: String = _loader._extract_key("sprite_alaska_forest_1234567890.png", "sprite_", ".png")
	assert_eq(key, "alaska_forest")


# ── get_sprite ───────────────────────────────────────────────────────────────

func test_get_sprite_returns_null_when_no_match() -> void:
	_loader.rescan()
	var result: Texture2D = _loader.get_sprite("nonexistent")
	assert_null(result)


# ── get_music_tracks ─────────────────────────────────────────────────────────

func test_get_music_tracks_empty_when_no_files() -> void:
	_loader.rescan()
	assert_eq(_loader.get_music_tracks().size(), 0)


# ── apply_sprite_to_node ────────────────────────────────────────────────────

func test_apply_sprite_returns_false_when_no_asset() -> void:
	_loader.rescan()
	var sprite := Sprite2D.new()
	add_child(sprite)
	var applied: bool = _loader.apply_sprite_to_node("nonexistent", sprite)
	assert_false(applied)
	sprite.queue_free()


# ── rescan ───────────────────────────────────────────────────────────────────

func test_rescan_picks_up_new_files() -> void:
	_loader.rescan()
	assert_eq(_loader.get_music_tracks().size(), 0)
	_create_test_file("music_new_track_9999999.ogg")
	_loader.rescan()
	assert_eq(_loader.get_music_tracks().size(), 1)


# ── play_generated_music (no crash) ─────────────────────────────────────────

func test_play_generated_music_with_no_tracks_does_not_crash() -> void:
	_loader.rescan()
	_loader.play_generated_music()
	pass_test("no crash")
