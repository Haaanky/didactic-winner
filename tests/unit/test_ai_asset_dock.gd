extends GutTest
## Unit tests for the AI Asset Generator dock.
##
## Tests cover the utility functions (slugify, build_output_path, JSON parsing,
## file saving) and the UI wiring.  Network calls are not exercised here because
## the real APIs require keys; instead we verify behaviour up to the HTTP
## boundary and the error-handling paths.

const DOCK_SCENE := preload("res://addons/ai_assets/ai_asset_dock.tscn")

var _dock: VBoxContainer


func before_each() -> void:
	_dock = DOCK_SCENE.instantiate()
	add_child(_dock)
	await get_tree().process_frame


func after_each() -> void:
	_dock.queue_free()


# ── slugify ──────────────────────────────────────────────────────────────────

func test_slugify_lowercases_and_replaces_spaces() -> void:
	var result: String = _dock._slugify("Hello World")
	assert_eq(result, "hello_world")


func test_slugify_strips_special_characters() -> void:
	var result: String = _dock._slugify("campfire!! @#in Alaska?")
	assert_eq(result, "campfire_in_alaska")


func test_slugify_collapses_multiple_underscores() -> void:
	var result: String = _dock._slugify("a---b___c   d")
	assert_eq(result, "a_b_c_d")


func test_slugify_trims_leading_trailing_underscores() -> void:
	var result: String = _dock._slugify("  --hello-- ")
	assert_eq(result, "hello")


func test_slugify_truncates_to_32_chars() -> void:
	var long_prompt := "a".repeat(60)
	var result: String = _dock._slugify(long_prompt)
	assert_true(result.length() <= 32, "slug length should be <= 32, got %d" % result.length())


func test_slugify_empty_string() -> void:
	var result: String = _dock._slugify("")
	assert_eq(result, "")


# ── build_output_path ────────────────────────────────────────────────────────

func test_build_output_path_format() -> void:
	var path: String = _dock._build_output_path("sprite", "test fire", "png")
	assert_true(path.begins_with("res://assets/generated/sprite_test_fire_"))
	assert_true(path.ends_with(".png"))


func test_build_output_path_music_ogg() -> void:
	var path: String = _dock._build_output_path("music", "guitar", "ogg")
	assert_true(path.begins_with("res://assets/generated/music_guitar_"))
	assert_true(path.ends_with(".ogg"))


# ── parse_json ───────────────────────────────────────────────────────────────

func test_parse_json_valid_dict() -> void:
	var result: Dictionary = _dock._parse_json('{"key": "value"}')
	assert_eq(result, {"key": "value"})


func test_parse_json_invalid_returns_empty() -> void:
	var result: Dictionary = _dock._parse_json("not json at all")
	assert_eq(result, {})
	assert_push_error_count(1)


func test_parse_json_array_returns_empty() -> void:
	var result: Dictionary = _dock._parse_json('[1, 2, 3]')
	assert_eq(result, {})


# ── save_bytes ───────────────────────────────────────────────────────────────

func test_save_bytes_creates_file() -> void:
	var test_path := "res://assets/generated/_test_save_bytes.txt"
	var data := "hello".to_utf8_buffer()
	_dock._save_bytes(test_path, data)

	assert_true(FileAccess.file_exists(test_path), "file should exist after save")

	var file := FileAccess.open(test_path, FileAccess.READ)
	var content := file.get_buffer(file.get_length())
	file.close()
	assert_eq(content, data)

	# Clean up
	DirAccess.remove_absolute(test_path)


func test_save_bytes_creates_output_directory() -> void:
	# Ensure dir exists (may already from previous runs)
	var dir := DirAccess.open("res://")
	if dir and dir.dir_exists("assets/generated"):
		pass  # already exists, that's fine
	var test_path := "res://assets/generated/_test_dir_create.txt"
	_dock._save_bytes(test_path, "x".to_utf8_buffer())
	assert_true(FileAccess.file_exists(test_path))
	DirAccess.remove_absolute(test_path)


# ── UI wiring ────────────────────────────────────────────────────────────────

func test_type_option_has_three_items() -> void:
	assert_eq(_dock._type_option.item_count, 3)


func test_type_option_sprite_is_first() -> void:
	assert_eq(_dock._type_option.get_item_text(0), "Sprite (PNG)")


func test_type_option_sfx_is_second() -> void:
	assert_eq(_dock._type_option.get_item_text(1), "SFX (MP3)")


func test_type_option_music_is_third() -> void:
	assert_eq(_dock._type_option.get_item_text(2), "Music (FLAC)")


func test_generate_button_exists() -> void:
	assert_not_null(_dock._generate_button)


func test_status_label_exists() -> void:
	assert_not_null(_dock._status_label)


func test_prompt_edit_exists() -> void:
	assert_not_null(_dock._prompt_edit)


# ── empty prompt guard ───────────────────────────────────────────────────────

func test_generate_with_empty_prompt_shows_error() -> void:
	_dock._prompt_edit.text = ""
	_dock._on_generate_pressed()
	assert_eq(_dock._status_label.text, "Enter a prompt first.")


func test_generate_with_whitespace_prompt_shows_error() -> void:
	_dock._prompt_edit.text = "   "
	_dock._on_generate_pressed()
	assert_eq(_dock._status_label.text, "Enter a prompt first.")


# ── API key guard (sprite) ───────────────────────────────────────────────────

func test_generate_sprite_without_key_shows_error() -> void:
	if not OS.get_environment("HUGGING_FACE").is_empty():
		pass_test("HUGGING_FACE is set — skipping missing-key test")
		return
	_dock._prompt_edit.text = "test sprite"
	_dock._type_option.select(0)
	_dock._on_generate_pressed()
	await get_tree().process_frame
	assert_string_contains(_dock._status_label.text, "HUGGING_FACE")
	assert_push_error_count(1)


# ── API key guard (music) ───────────────────────────────────────────────────

func test_generate_music_without_key_shows_error() -> void:
	if not OS.get_environment("HUGGING_FACE").is_empty():
		pass_test("HUGGING_FACE is set — skipping missing-key test")
		return
	_dock._prompt_edit.text = "test music"
	_dock._type_option.select(2)
	_dock._on_generate_pressed()
	await get_tree().process_frame
	assert_string_contains(_dock._status_label.text, "HUGGING_FACE")
	assert_push_error_count(1)


# ── set_status ───────────────────────────────────────────────────────────────

func test_set_status_updates_label() -> void:
	_dock._set_status("Hello test")
	assert_eq(_dock._status_label.text, "Hello test")
