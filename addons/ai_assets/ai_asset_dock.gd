@tool
extends VBoxContainer
## Editor dock for generating game assets via AI APIs.
##
## API endpoints (keep in sync with tools/generate_asset.sh):
##   Sprite : POST https://router.huggingface.co/hf-inference/models/stabilityai/stable-diffusion-xl-base-1.0
##   SFX    : POST https://api.elevenlabs.io/v1/sound-generation
##   Music  : POST https://router.huggingface.co/hf-inference/models/facebook/musicgen-small

enum AssetType { SPRITE, SFX, MUSIC }

const SPRITE_API_URL := "https://router.huggingface.co/hf-inference/models/stabilityai/stable-diffusion-xl-base-1.0"
const SFX_API_URL := "https://api.elevenlabs.io/v1/sound-generation"
const MUSIC_API_URL := "https://router.huggingface.co/hf-inference/models/facebook/musicgen-small"

const OUTPUT_DIR := "res://assets/generated/"
const TIMEOUT_MSEC := 30000
const MUSIC_TIMEOUT_MSEC := 120000
const SLUG_MAX_LENGTH := 32

@onready var _type_option: OptionButton = %TypeOption
@onready var _prompt_edit: TextEdit = %PromptEdit
@onready var _generate_button: Button = %GenerateButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_type_option.clear()
	_type_option.add_item("Sprite (PNG)", AssetType.SPRITE)
	_type_option.add_item("SFX (MP3)", AssetType.SFX)
	_type_option.add_item("Music (FLAC)", AssetType.MUSIC)
	_generate_button.pressed.connect(_on_generate_pressed)


func _on_generate_pressed() -> void:
	var prompt_text := _prompt_edit.text.strip_edges()
	if prompt_text.is_empty():
		_set_status("Enter a prompt first.")
		return
	var asset_type: AssetType = _type_option.get_selected_id() as AssetType
	_generate_button.disabled = true
	_set_status("Generating...")
	match asset_type:
		AssetType.SPRITE:
			await _generate_sprite(prompt_text)
		AssetType.SFX:
			await _generate_sfx(prompt_text)
		AssetType.MUSIC:
			await _generate_music(prompt_text)
	_generate_button.disabled = false


# ---------------------------------------------------------------------------
# Sprite generation (HuggingFace Stable Diffusion XL)
# ---------------------------------------------------------------------------

func _generate_sprite(prompt_text: String) -> void:
	var api_key := _get_env("HUGGING_FACE")
	if api_key.is_empty():
		push_error("AIAssetDock: HUGGING_FACE environment variable not set")
		_set_status("Error: HUGGING_FACE not set.")
		return

	var result := await fetch_async(
		SPRITE_API_URL,
		PackedStringArray(["Content-Type: application/json", "Authorization: Bearer %s" % api_key]),
		JSON.stringify({"inputs": prompt_text}),
	)
	if result.is_empty():
		return

	var file_path := _build_output_path("sprite", prompt_text, "png")
	_save_bytes(file_path, result["body_raw"])


# ---------------------------------------------------------------------------
# SFX generation (ElevenLabs)
# ---------------------------------------------------------------------------

func _generate_sfx(prompt_text: String) -> void:
	var api_key := _get_env("ELEVENLABS_API_KEY")
	if api_key.is_empty():
		push_error("AIAssetDock: ELEVENLABS_API_KEY environment variable not set")
		_set_status("Error: ELEVENLABS_API_KEY not set.")
		return

	var body := {
		"text": prompt_text,
		"duration_seconds": null,
		"prompt_influence": 0.3,
	}

	var result := await fetch_async(
		SFX_API_URL,
		PackedStringArray(["Content-Type: application/json", "xi-api-key: %s" % api_key]),
		JSON.stringify(body),
	)
	if result.is_empty():
		return

	var file_path := _build_output_path("sfx", prompt_text, "mp3")
	_save_bytes(file_path, result["body_raw"])


# ---------------------------------------------------------------------------
# Music generation (HuggingFace MusicGen)
# ---------------------------------------------------------------------------

func _generate_music(prompt_text: String) -> void:
	var api_key := _get_env("HUGGING_FACE")
	if api_key.is_empty():
		push_error("AIAssetDock: HUGGING_FACE environment variable not set")
		_set_status("Error: HUGGING_FACE not set.")
		return

	_set_status("Generating music — this may take up to a minute...")
	var result := await fetch_async(
		MUSIC_API_URL,
		PackedStringArray(["Content-Type: application/json", "Authorization: Bearer %s" % api_key]),
		JSON.stringify({"inputs": prompt_text}),
		HTTPClient.METHOD_POST,
		MUSIC_TIMEOUT_MSEC,
	)
	if result.is_empty():
		return

	var file_path := _build_output_path("music", prompt_text, "flac")
	_save_bytes(file_path, result["body_raw"])


# ---------------------------------------------------------------------------
# HTTP helper — frame-polling async fetch with timeout
# ---------------------------------------------------------------------------

func fetch_async(
	url: String,
	headers: PackedStringArray,
	body: String,
	method: int = HTTPClient.METHOD_POST,
	timeout_msec: int = TIMEOUT_MSEC,
) -> Dictionary:
	var http := HTTPClient.new()
	var parsed := _parse_url(url)

	var err := http.connect_to_host(parsed["host"], parsed["port"], parsed["tls"])
	if err != OK:
		push_error("AIAssetDock: connect_to_host failed — error code %d" % err)
		_set_status("Error: could not connect (code %d)." % err)
		return {}

	var deadline := Time.get_ticks_msec() + timeout_msec

	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		if Time.get_ticks_msec() > deadline:
			push_error("AIAssetDock: connection to %s timed out" % url)
			_set_status("Error: connection timed out.")
			return {}
		await get_tree().process_frame

	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		push_error("AIAssetDock: could not connect to %s — status %d" % [url, http.get_status()])
		_set_status("Error: connection failed (status %d)." % http.get_status())
		return {}

	if body.is_empty() and method == HTTPClient.METHOD_GET:
		err = http.request(method, parsed["path"], headers)
	else:
		err = http.request(method, parsed["path"], headers, body)

	if err != OK:
		push_error("AIAssetDock: HTTPClient.request() failed — error code %d" % err)
		_set_status("Error: HTTP request failed (code %d)." % err)
		return {}

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		if Time.get_ticks_msec() > deadline:
			push_error("AIAssetDock: request to %s timed out" % url)
			_set_status("Error: request timed out.")
			return {}
		await get_tree().process_frame

	if not http.has_response():
		push_error("AIAssetDock: no response from %s" % url)
		_set_status("Error: no response from server.")
		return {}

	var status_code := http.get_response_code()
	var response_body := PackedByteArray()

	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.size() > 0:
			response_body.append_array(chunk)
		if Time.get_ticks_msec() > deadline:
			push_error("AIAssetDock: reading body from %s timed out" % url)
			_set_status("Error: response body timed out.")
			return {}
		await get_tree().process_frame

	if status_code < 200 or status_code >= 300:
		var error_text := response_body.get_string_from_utf8()
		push_error("AIAssetDock: HTTP %d from %s — %s" % [status_code, url, error_text])
		_set_status("Error: HTTP %d — %s" % [status_code, error_text.left(200)])
		return {}

	return {
		"status_code": status_code,
		"body": response_body.get_string_from_utf8(),
		"body_raw": response_body,
	}


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

func _parse_url(url: String) -> Dictionary:
	var tls := url.begins_with("https://")
	var stripped := url.replace("https://", "").replace("http://", "")
	var slash_idx := stripped.find("/")
	var host: String
	var path: String
	if slash_idx >= 0:
		host = stripped.left(slash_idx)
		path = stripped.substr(slash_idx)
	else:
		host = stripped
		path = "/"
	var port := 443 if tls else 80
	var colon_idx := host.find(":")
	if colon_idx >= 0:
		port = host.substr(colon_idx + 1).to_int()
		host = host.left(colon_idx)
	return {"host": host, "port": port, "path": path, "tls": tls}


func _get_env(key: String) -> String:
	return OS.get_environment(key)


func _parse_json(text: String) -> Dictionary:
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("AIAssetDock: JSON parse error — %s" % json.get_error_message())
		_set_status("Error: invalid JSON response.")
		return {}
	if json.data is Dictionary:
		return json.data
	_set_status("Error: expected JSON object, got %s." % typeof(json.data))
	return {}


func _slugify(text: String) -> String:
	var slug := text.to_lower().strip_edges()
	var result := ""
	for c: String in slug:
		if c >= "a" and c <= "z" or c >= "0" and c <= "9":
			result += c
		elif result.length() > 0 and not result.ends_with("_"):
			result += "_"
	result = result.trim_suffix("_")
	if result.length() > SLUG_MAX_LENGTH:
		result = result.left(SLUG_MAX_LENGTH).trim_suffix("_")
	return result


func _build_output_path(type_prefix: String, prompt_text: String, extension: String) -> String:
	var slug := _slugify(prompt_text)
	var timestamp := int(Time.get_unix_time_from_system())
	return "%s%s_%s_%d.%s" % [OUTPUT_DIR, type_prefix, slug, timestamp, extension]


func _save_bytes(file_path: String, data: PackedByteArray) -> void:
	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists("assets/generated"):
		dir.make_dir_recursive("assets/generated")

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("AIAssetDock: could not write to %s — %s" % [file_path, FileAccess.get_open_error()])
		_set_status("Error: could not save file.")
		return
	file.store_buffer(data)
	file.close()
	_set_status("Saved: %s" % file_path)
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()


func _set_status(text: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = text
