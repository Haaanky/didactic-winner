@tool
extends VBoxContainer
## Editor dock for generating game assets via AI APIs and local AI servers.
##
## Cloud API endpoints (keep in sync with vendor/game-dev-tools/src/generate_asset.sh):
##   Sprite : POST https://api.openai.com/v1/images/generations          (OPENAI_API_KEY, tried first)
##          : POST https://router.huggingface.co/hf-inference/models/black-forest-labs/FLUX.1-schnell  (HUGGING_FACE)
##   SFX    : POST https://api.elevenlabs.io/v1/sound-generation
##   Music  : POST https://api.replicate.com/v1/predictions
##            GET  https://api.replicate.com/v1/predictions/{id}
##
## Local endpoints (keep in sync with vendor/game-dev-tools/src/generate_asset.sh):
##   Sprite : POST http://localhost:7860/sdapi/v1/txt2img  (AUTOMATIC1111)
##            Server: vendor/game-dev-tools/src/servers/local_sprite_server.py
##            Override with LOCAL_SPRITE_URL env var.
##            Auto-start with LOCAL_SPRITE_START_CMD env var.
##   SFX    : POST http://localhost:8080/generate/sfx  (AudioCraft wrapper)
##            Server: vendor/game-dev-tools/src/servers/local_audio_server.py
##            Override with LOCAL_SFX_URL env var.
##            Auto-start with LOCAL_SFX_START_CMD env var.
##   Music  : POST http://localhost:8080/generate/music  (MusicGen wrapper)
##            Server: vendor/game-dev-tools/src/servers/local_audio_server.py
##            Override with LOCAL_MUSIC_URL env var.
##            Auto-start with LOCAL_MUSIC_START_CMD env var.
##
## Backend selection is automatic: cloud is tried first. If cloud is
## unavailable (missing key or HTTP error), the local server is probed and
## started automatically if needed. Set FORCE_LOCAL_AI=1 to skip cloud.
## For the full fallback chain see docs/asset_generation_architecture.md.

enum AssetType { SPRITE, SFX, MUSIC }

const SPRITE_API_URL := "https://api.openai.com/v1/images/generations"
const HF_SPRITE_API_URL := "https://router.huggingface.co/hf-inference/models/black-forest-labs/FLUX.1-schnell"
const SFX_API_URL := "https://api.elevenlabs.io/v1/sound-generation"
const MUSIC_API_URL := "https://api.replicate.com/v1/predictions"

const LOCAL_SPRITE_API_URL := "http://localhost:7860/sdapi/v1/txt2img"
const LOCAL_SFX_API_URL := "http://localhost:8080/generate/sfx"
const LOCAL_MUSIC_API_URL := "http://localhost:8080/generate/music"

const OUTPUT_DIR := "res://assets/generated/"
const TIMEOUT_MSEC := 30000
const PROBE_TIMEOUT_MSEC := 2000
const SPIN_UP_TIMEOUT_MSEC := 30000
const SPIN_UP_POLL_SEC := 0.5
const MUSIC_POLL_INTERVAL_SEC := 3.0
const MUSIC_POLL_MAX_ATTEMPTS := 20
const SLUG_MAX_LENGTH := 32

const LOCAL_SPRITE_RESOLUTION := 256
const LOCAL_SPRITE_STEPS := 20
const LOCAL_SPRITE_CFG_SCALE := 7.0

@onready var _type_option: OptionButton = %TypeOption
@onready var _prompt_edit: TextEdit = %PromptEdit
@onready var _generate_button: Button = %GenerateButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_type_option.clear()
	_type_option.add_item("Sprite (PNG)", AssetType.SPRITE)
	_type_option.add_item("SFX (MP3)", AssetType.SFX)
	_type_option.add_item("Music (MP3)", AssetType.MUSIC)
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
			var ok := false
			if _get_env("FORCE_LOCAL_AI").is_empty():
				ok = await _try_generate_sprite_cloud(prompt_text)
				if not ok:
					ok = await _try_generate_sprite_hf(prompt_text)
			if not ok:
				await _ensure_local_and_generate_sprite(prompt_text)
		AssetType.SFX:
			var ok := false
			if _get_env("FORCE_LOCAL_AI").is_empty():
				ok = await _try_generate_sfx_cloud(prompt_text)
			if not ok:
				await _ensure_local_and_generate_sfx(prompt_text)
		AssetType.MUSIC:
			var ok := false
			if _get_env("FORCE_LOCAL_AI").is_empty():
				ok = await _try_generate_music_cloud(prompt_text)
			if not ok:
				await _ensure_local_and_generate_music(prompt_text)
	_generate_button.disabled = false


# ---------------------------------------------------------------------------
# Local server probe and auto-spin-up
# ---------------------------------------------------------------------------

func _resolve_local_url(env_key: String, default_url: String) -> String:
	var override := _get_env(env_key)
	return override if not override.is_empty() else default_url


func _local_reachable(url: String) -> bool:
	var parsed := _parse_url(url)
	var http := HTTPClient.new()
	if http.connect_to_host(parsed["host"], parsed["port"], parsed["tls"]) != OK:
		return false
	var deadline := Time.get_ticks_msec() + PROBE_TIMEOUT_MSEC
	while http.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		http.poll()
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return http.get_status() == HTTPClient.STATUS_CONNECTED


func _spin_up_server(start_cmd_env: String, probe_url: String) -> bool:
	var cmd := _get_env(start_cmd_env)
	if cmd.is_empty():
		push_warning("AIAssetDock: %s not set — cannot auto-start local server" % start_cmd_env)
		return false
	var parts := cmd.split(" ", false)
	if parts.is_empty():
		push_error("AIAssetDock: %s is empty — cannot auto-start local server" % start_cmd_env)
		return false
	var args := PackedStringArray()
	for i: int in range(1, parts.size()):
		args.append(parts[i])
	var pid := OS.create_process(parts[0], args)
	if pid < 0:
		push_error("AIAssetDock: failed to start local server — %s" % cmd)
		return false
	_set_status("Starting local server (waiting up to 30 s)...")
	var deadline := Time.get_ticks_msec() + SPIN_UP_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(SPIN_UP_POLL_SEC).timeout
		if await _local_reachable(probe_url):
			return true
	push_error("AIAssetDock: local server did not become reachable within %d ms — %s" % [SPIN_UP_TIMEOUT_MSEC, probe_url])
	return false


func _ensure_local_server(url_env: String, default_url: String, start_cmd_env: String) -> String:
	var url := _resolve_local_url(url_env, default_url)
	if await _local_reachable(url):
		return url
	if await _spin_up_server(start_cmd_env, url):
		return url
	push_error("AIAssetDock: local server unavailable and could not be started — %s" % url)
	_set_status("Error: local server unavailable. Set %s to auto-start." % start_cmd_env)
	return ""


# ---------------------------------------------------------------------------
# Sprite generation — Cloud (OpenAI DALL-E)
# ---------------------------------------------------------------------------

func _try_generate_sprite_cloud(prompt_text: String) -> bool:
	var api_key := _get_env("OPENAI_API_KEY")
	if api_key.is_empty():
		return false

	_set_status("Generating sprite via cloud (OpenAI)...")
	var body := {
		"model": "dall-e-3",
		"prompt": prompt_text,
		"n": 1,
		"size": "1024x1024",
		"response_format": "url",
	}

	var result := await fetch_async(
		SPRITE_API_URL,
		PackedStringArray(["Content-Type: application/json", "Authorization: Bearer %s" % api_key]),
		JSON.stringify(body),
	)
	if result.is_empty():
		return false

	var json: Dictionary = _parse_json(result["body"])
	if json.is_empty():
		return false

	if not json.has("data") or (json["data"] as Array).is_empty():
		return false

	var image_data: Dictionary = json["data"][0]
	var file_path := _build_output_path("sprite", prompt_text, "png")

	if image_data.has("b64_json"):
		var image_bytes := Marshalls.base64_to_raw(image_data["b64_json"])
		_save_bytes(file_path, image_bytes)
		return true
	elif image_data.has("url"):
		var download := await fetch_async(
			image_data["url"],
			PackedStringArray([]),
			"",
			HTTPClient.METHOD_GET,
		)
		if download.is_empty():
			return false
		_save_bytes(file_path, download["body_raw"])
		return true
	return false


# ---------------------------------------------------------------------------
# Sprite generation — Cloud (HuggingFace FLUX.1-schnell)
# ---------------------------------------------------------------------------

func _try_generate_sprite_hf(prompt_text: String) -> bool:
	var api_key := _get_env("HUGGING_FACE")
	if api_key.is_empty():
		return false

	_set_status("Generating sprite via cloud (HuggingFace FLUX.1-schnell)...")
	var body := {"inputs": prompt_text}

	var result := await fetch_async(
		HF_SPRITE_API_URL,
		PackedStringArray([
			"Content-Type: application/json",
			"Authorization: Bearer %s" % api_key,
		]),
		JSON.stringify(body),
	)
	if result.is_empty():
		return false

	var file_path := _build_output_path("sprite", prompt_text, "jpg")
	_save_bytes(file_path, result["body_raw"])
	return true


# ---------------------------------------------------------------------------
# Sprite generation — Local (AUTOMATIC1111 Stable Diffusion WebUI)
# ---------------------------------------------------------------------------

func _ensure_local_and_generate_sprite(prompt_text: String) -> void:
	var url := await _ensure_local_server("LOCAL_SPRITE_URL", LOCAL_SPRITE_API_URL, "LOCAL_SPRITE_START_CMD")
	if url.is_empty():
		return
	_set_status("Generating sprite via local server...")
	var body := {
		"prompt": prompt_text,
		"width": LOCAL_SPRITE_RESOLUTION,
		"height": LOCAL_SPRITE_RESOLUTION,
		"steps": LOCAL_SPRITE_STEPS,
		"cfg_scale": LOCAL_SPRITE_CFG_SCALE,
	}

	var result := await fetch_async(
		url,
		PackedStringArray(["Content-Type: application/json"]),
		JSON.stringify(body),
	)
	if result.is_empty():
		return

	var json: Dictionary = _parse_json(result["body"])
	if json.is_empty():
		return

	if not json.has("images") or (json["images"] as Array).is_empty():
		push_error("AIAssetDock: local sprite API returned no images — %s" % result["body"].left(200))
		_set_status("Error: no images in local API response.")
		return

	var b64: String = json["images"][0]
	var image_bytes := Marshalls.base64_to_raw(b64)
	var file_path := _build_output_path("sprite", prompt_text, "png")
	_save_bytes(file_path, image_bytes)


# ---------------------------------------------------------------------------
# SFX generation — Cloud (ElevenLabs)
# ---------------------------------------------------------------------------

func _try_generate_sfx_cloud(prompt_text: String) -> bool:
	var api_key := _get_env("ELEVENLABS_API_KEY")
	if api_key.is_empty():
		return false

	_set_status("Generating SFX via cloud (ElevenLabs)...")
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
		return false

	var file_path := _build_output_path("sfx", prompt_text, "mp3")
	_save_bytes(file_path, result["body_raw"])
	return true


# ---------------------------------------------------------------------------
# SFX generation — Local (AudioCraft wrapper)
# ---------------------------------------------------------------------------

func _ensure_local_and_generate_sfx(prompt_text: String) -> void:
	var url := await _ensure_local_server("LOCAL_SFX_URL", LOCAL_SFX_API_URL, "LOCAL_SFX_START_CMD")
	if url.is_empty():
		return
	_set_status("Generating SFX via local server...")
	var body := {
		"text": prompt_text,
		"duration": 5,
	}

	var result := await fetch_async(
		url,
		PackedStringArray(["Content-Type: application/json"]),
		JSON.stringify(body),
	)
	if result.is_empty():
		return

	var file_path := _build_output_path("sfx", prompt_text, "wav")
	_save_bytes(file_path, result["body_raw"])


# ---------------------------------------------------------------------------
# Music generation — Cloud (Suno via Replicate)
# ---------------------------------------------------------------------------

func _try_generate_music_cloud(prompt_text: String) -> bool:
	var api_key := _get_env("REPLICATE_API_TOKEN")
	if api_key.is_empty():
		return false

	_set_status("Generating music via cloud (Replicate)...")
	var body := {
		"version": "7a76a8258b23fae65c5a22debb8841d1d7e816b75c2f24218cd2bd8573787906",
		"input": {
			"prompt": prompt_text,
			"model_version": "chirp-v3-5",
			"duration": 30,
		},
	}

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key,
	])

	var result := await fetch_async(MUSIC_API_URL, headers, JSON.stringify(body))
	if result.is_empty():
		return false

	var json: Dictionary = _parse_json(result["body"])
	if json.is_empty():
		return false

	if not json.has("urls") or not (json["urls"] as Dictionary).has("get"):
		return false

	var poll_url: String = json["urls"]["get"]
	_set_status("Music generation started. Polling for result...")

	var audio_url := await _poll_replicate(poll_url, headers)
	if audio_url.is_empty():
		return false

	var audio_result := await fetch_async(audio_url, PackedStringArray([]), "", HTTPClient.METHOD_GET)
	if audio_result.is_empty():
		return false

	var file_path := _build_output_path("music", prompt_text, "mp3")
	_save_bytes(file_path, audio_result["body_raw"])
	return true


# ---------------------------------------------------------------------------
# Music generation — Local (MusicGen via AudioCraft wrapper)
# ---------------------------------------------------------------------------

func _ensure_local_and_generate_music(prompt_text: String) -> void:
	var url := await _ensure_local_server("LOCAL_MUSIC_URL", LOCAL_MUSIC_API_URL, "LOCAL_MUSIC_START_CMD")
	if url.is_empty():
		return
	_set_status("Generating music via local server...")
	var body := {
		"text": prompt_text,
		"duration": 30,
	}

	var result := await fetch_async(
		url,
		PackedStringArray(["Content-Type: application/json"]),
		JSON.stringify(body),
	)
	if result.is_empty():
		return

	var file_path := _build_output_path("music", prompt_text, "wav")
	_save_bytes(file_path, result["body_raw"])


func _poll_replicate(poll_url: String, headers: PackedStringArray) -> String:
	for i: int in range(MUSIC_POLL_MAX_ATTEMPTS):
		await get_tree().create_timer(MUSIC_POLL_INTERVAL_SEC).timeout
		_set_status("Polling attempt %d / %d..." % [i + 1, MUSIC_POLL_MAX_ATTEMPTS])

		var result := await fetch_async(poll_url, headers, "", HTTPClient.METHOD_GET)
		if result.is_empty():
			return ""

		var json: Dictionary = _parse_json(result["body"])
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

func fetch_async(
	url: String,
	headers: PackedStringArray,
	body: String,
	method: int = HTTPClient.METHOD_POST,
) -> Dictionary:
	var http := HTTPClient.new()
	var parsed := _parse_url(url)

	var err := http.connect_to_host(parsed["host"], parsed["port"], parsed["tls"])
	if err != OK:
		push_error("AIAssetDock: connect_to_host failed — error code %d" % err)
		_set_status("Error: could not connect (code %d)." % err)
		return {}

	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC

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
	var use_tls := url.begins_with("https://")
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
	var port := 443 if use_tls else 80
	var colon_idx := host.find(":")
	if colon_idx >= 0:
		port = host.substr(colon_idx + 1).to_int()
		host = host.left(colon_idx)
	var tls_options: TLSOptions = TLSOptions.client() if use_tls else null
	return {"host": host, "port": port, "path": path, "tls": tls_options}


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
