extends Node

## Routes all game audio through music and SFX buses.
## Gameplay scripts must never call AudioStreamPlayer.play() directly.

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"

const SEASON_TRACKS: Dictionary = {
	TimeManager.Season.SPRING: "res://assets/audio/spring_day.wav",
	TimeManager.Season.SUMMER: "res://assets/audio/summer_day.wav",
	TimeManager.Season.AUTUMN: "res://assets/audio/autumn_day.wav",
	TimeManager.Season.WINTER: "res://assets/audio/winter_outdoor.wav",
}
const INDOOR_TRACK: String = "res://assets/audio/cabin_interior.wav"
const BLIZZARD_TRACK: String = "res://assets/audio/blizzard.wav"

const SFX_MENU_CLICK: String = "res://assets/audio/menu_click.wav"
const SFX_FOOTSTEP_SNOW: String = "res://assets/audio/footstep_snow.wav"
const SFX_FOOTSTEP_GRASS: String = "res://assets/audio/footstep_grass.wav"

const CROSSFADE_DURATION: float = 2.0

var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _inactive_player: AudioStreamPlayer
var _is_indoors: bool = false
var _crossfade_tween: Tween


func _ready() -> void:
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = MUSIC_BUS
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = MUSIC_BUS
	add_child(_music_player_b)

	_active_player = _music_player_a
	_inactive_player = _music_player_b
	EventBus.season_changed.connect(_on_season_changed)
	EventBus.weather_changed.connect(_on_weather_changed)


func play_sfx(stream: AudioStream, position: Vector2 = Vector2.ZERO) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	player.stream = stream
	player.bus = SFX_BUS
	player.position = position
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func play_sfx_global(stream: AudioStream) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SFX_BUS
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func set_indoors(indoors: bool) -> void:
	if _is_indoors == indoors:
		return
	_is_indoors = indoors
	_play_contextual_music()


func set_music_volume(volume_db: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, volume_db)


func set_sfx_volume(volume_db: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(SFX_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, volume_db)


func mute_music(muted: bool) -> void:
	var bus_index: int = AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, muted)


func mute_sfx(muted: bool) -> void:
	var bus_index: int = AudioServer.get_bus_index(SFX_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, muted)


func _play_contextual_music() -> void:
	var track_path: String = ""
	if _is_indoors:
		track_path = INDOOR_TRACK
	elif WeatherManager.current_weather == WeatherManager.WeatherType.BLIZZARD:
		track_path = BLIZZARD_TRACK
	else:
		track_path = SEASON_TRACKS.get(TimeManager.current_season, "")

	if track_path.is_empty():
		return
	if not ResourceLoader.exists(track_path):
		push_warning("AudioManager: music track not found — %s" % track_path)
		return

	var stream: AudioStream = load(track_path)
	_crossfade_to(stream)


const _VOLUME_SILENT_DB: float = -80.0

func _crossfade_to(stream: AudioStream) -> void:
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	_inactive_player.stream = stream
	_inactive_player.volume_db = _VOLUME_SILENT_DB
	_inactive_player.play()
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)
	_crossfade_tween.tween_property(_active_player, "volume_db", _VOLUME_SILENT_DB, CROSSFADE_DURATION)
	_crossfade_tween.tween_property(_inactive_player, "volume_db", 0.0, CROSSFADE_DURATION)
	_crossfade_tween.set_parallel(false)
	_crossfade_tween.tween_callback(_swap_players)


func _swap_players() -> void:
	_active_player.stop()
	var temp: AudioStreamPlayer = _active_player
	_active_player = _inactive_player
	_inactive_player = temp


func _on_season_changed(_season: int) -> void:
	if not _is_indoors:
		_play_contextual_music()


func _on_weather_changed(_weather: int) -> void:
	if not _is_indoors:
		_play_contextual_music()
