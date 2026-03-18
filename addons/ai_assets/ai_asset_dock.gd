@tool
extends VBoxContainer
## Editor dock for generating game assets via AI APIs.
##
## API endpoints (keep in sync with tools/generate_asset.sh):
##   Sprite : POST https://api.openai.com/v1/images/generations
##   SFX    : POST https://api.elevenlabs.io/v1/sound-generation
##   Music  : POST https://api.replicate.com/v1/predictions
##            GET  https://api.replicate.com/v1/predictions/{id}

enum AssetType { SPRITE, SFX, MUSIC }

const SPRITE_API_URL := "https://api.openai.com/v1/images/generations"
const SFX_API_URL := "https://api.elevenlabs.io/v1/sound-generation"
const MUSIC_API_URL := "https://api.replicate.com/v1/predictions"

const OUTPUT_DIR := "res://assets/generated/"
const TIMEOUT_SEC := 30.0
const MUSIC_POLL_INTERVAL_SEC := 3.0
const MUSIC_POLL_MAX_ATTEMPTS := 20

@onready var _type_option: OptionButton = %TypeOption
@onready var _prompt_edit: TextEdit = %PromptEdit
@onready var _generate_button: Button = %GenerateButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_type_option.clear()
	_type_option.add_item("Sprite (PNG)", AssetType.SPRITE)
	_type_option.add_item("SFX (WAV)", AssetType.SFX)
	_type_option.add_item("Music (OGG)", AssetType.MUSIC)
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
# Sprite generation (OpenAI DALL-E)
# ---------------------------------------------------------------------------

func _generate_sprite(prompt_text: String) -> void:
	var api_key := _get_env("OPENAI_API_KEY")
	if api_key.is_empty():
		_set_status("Error: OPENAI_API_KEY not set.")
		return

	var body := {
		"model": "dall-e-3",
		"prompt": prompt_text,
		"n": 1,
		"size": "1024x1024",
		"response_format": "b64_json",
	}

	var result := await _fetch_async(
		SPRITE_API_URL,
		["Content-Type: application/json", "Authorization: Bearer %s" % api_key],
		JSON.stringify(body),
	)
	if result.is_empty():
		return

	var json: Dictionary = _parse_json(result)
	if json.is_empty():
		return

	if not json.has("data") or (json["data"] as Array).is_empty():
		_set_status("Error: unexpected API response — no image data.")
		return

	var b64_string: String = json["data"][0]["b64_json"]
	var image_bytes := Marshalls.base64_to_raw(b64_string)
	var file_path := _build_output_path("sprite", prompt_text, "png")
	_save_bytes(file_path, image_bytes)


# ---------------------------------------------------------------------------
# SFX generation (ElevenLabs)
# ---------------------------------------------------------------------------

func _generate_sfx(prompt_text: String) -> void:
	var api_key := _get_env("ELEVENLABS_API_KEY")
	if api_key.is_empty():
		_set_status("Error: ELEVENLABS_API_KEY not set.")
		return

	var body := {
		"text": prompt_text,
		"duration_seconds": 5.0,
	}

	var result := await _fetch_async(
		SFX_API_URL,
		["Content-Type: application/json", "xi-api-key: %s" % api_key],
		JSON.stringify(body),
	)
	if result.is_empty():
		return

	# ElevenLabs returns raw audio bytes directly
	var file_path := _build_output_path("sfx", prompt_text, "wav")
	_save_bytes(file_path, result.to_utf8_buffer() if result is String else PackedByteArray())
	_set_status("Note: SFX saved. If the file is invalid, the API may have returned an error in JSON form.")


# ---------------------------------------------------------------------------
# Music generation (Suno via Replicate)
# ---------------------------------------------------------------------------

func _generate_music(prompt_text: String) -> void:
	var api_key := _get_env("REPLICATE_API_TOKEN")
	if api_key.is_empty():
		_set_status("Error: REPLICATE_API_TOKEN not set.")
		return

	var body := {
		"version": "7a76a8258b23fae65c5a22debb8841d1d7e816b75c2f24218cd2bd8573787906",
		"input": {
			"prompt": prompt_text,
			"model_version": "chirp-v3-5",
			"duration": 30,
		},
	}

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key,
	]

	var result := await _fetch_async(MUSIC_API_URL, headers, JSON.stringify(body))
	if result.is_empty():
		return

	var json: Dictionary = _parse_json(result)
	if json.is_empty():
		return

	if not json.has("urls") or not (json["urls"] as Dictionary).has("get"):
		_set_status("Error: unexpected Replicate response — no poll URL.")
		return

	var poll_url: String = json["urls"]["get"]
	_set_status("Music generation started. Polling for result...")

	var audio_url := await _poll_replicate(poll_url, headers)
	if audio_url.is_empty():
		return

	# Download the audio file from the output URL
	var audio_result := await _fetch_async(audio_url, [], "")
	if audio_result.is_empty():
		return

	var file_path := _build_output_path("music", prompt_text, "ogg")
	_save_bytes(file_path, audio_result.to_utf8_buffer() if audio_result is String else PackedByteArray())


func _poll_replicate(poll_url: String, headers: Array) -> String:
	for i: int in range(MUSIC_POLL_MAX_ATTEMPTS):
		await get_tree().create_timer(MUSIC_POLL_INTERVAL_SEC).timeout
		_set_status("Polling attempt %d / %d..." % [i + 1, MUSIC_POLL_MAX_ATTEMPTS])

		var result := await _fetch_async(poll_url, headers, "", HTTPClient.METHOD_GET)
		if result.is_empty():
			return ""

		var json: Dictionary = _parse_json(result)
		if json.is_empty():
			return ""

		var status: String = json.get("status", "")
		if status == "succeeded":
			var output = json.get("output", null)
			if output is String:
				return output
			if output is Array and not (output as Array).is_empty():
				return output[0]
			_set_status("Error: succeeded but no output URL found.")
			return ""
		elif status == "failed" or status == "canceled":
			_set_status("Error: Replicate prediction %s." % status)
			return ""

	_set_status("Error: music generation timed out after polling.")
	return ""


# ---------------------------------------------------------------------------
# HTTP helper — frame-polling async fetch with timeout
# ---------------------------------------------------------------------------

func _fetch_async(
	url: String,
	headers: Array,
	body: String,
	method: int = HTTPClient.METHOD_POST,
) -> String:
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = TIMEOUT_SEC

	var error: int
	if body.is_empty() and method == HTTPClient.METHOD_GET:
		error = http.request(url, PackedStringArray(headers), method)
	else:
		error = http.request(url, PackedStringArray(headers), method, body)

	if error != OK:
		push_error("AIAssetDock: HTTPRequest.request() failed — error code %d" % error)
		_set_status("Error: HTTP request failed (code %d)." % error)
		http.queue_free()
		return ""

	var response: Array = await http.request_completed
	http.queue_free()

	var result_code: int = response[0]
	var http_code: int = response[1]
	var response_body: PackedByteArray = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		push_error("AIAssetDock: request to %s failed — result code %d" % [url, result_code])
		_set_status("Error: request failed (result %d)." % result_code)
		return ""

	if http_code < 200 or http_code >= 300:
		var error_text := response_body.get_string_from_utf8()
		push_error("AIAssetDock: HTTP %d from %s — %s" % [http_code, url, error_text])
		_set_status("Error: HTTP %d — %s" % [http_code, error_text.left(200)])
		return ""

	return response_body.get_string_from_utf8()


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

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
	# Replace non-alphanumeric characters with underscores
	var result := ""
	for c: String in slug:
		if c >= "a" and c <= "z" or c >= "0" and c <= "9":
			result += c
		elif result.length() > 0 and not result.ends_with("_"):
			result += "_"
	# Trim trailing underscore and limit length
	result = result.trim_suffix("_")
	if result.length() > 40:
		result = result.left(40).trim_suffix("_")
	return result


func _build_output_path(type_prefix: String, prompt_text: String, extension: String) -> String:
	var slug := _slugify(prompt_text)
	var timestamp := int(Time.get_unix_time_from_system())
	return "%s%s_%s_%d.%s" % [OUTPUT_DIR, type_prefix, slug, timestamp, extension]


func _save_bytes(file_path: String, data: PackedByteArray) -> void:
	# Ensure the output directory exists
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
	# Trigger reimport so the asset appears in the FileSystem dock
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()


func _set_status(text: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = text
