extends GutTest

# Tests AudioManager constants, state management, and graceful null handling.
#
# Audio playback itself cannot be asserted in headless mode (no audio device),
# so tests focus on:
#   - Correct constant values
#   - set_indoors() state toggling and idempotency
#   - play_sfx / play_sfx_global null-guard paths
#   - Season track map coverage
#   - Unknown-season path emits no crash and leaves player silent


func after_each() -> void:
	# Reset indoors state so tests are isolated
	AudioManager._is_indoors = false


# ── Constants ─────────────────────────────────────────────────────────────────

func test_music_bus_name_is_correct() -> void:
	assert_eq(AudioManager.MUSIC_BUS, &"Music")


func test_sfx_bus_name_is_correct() -> void:
	assert_eq(AudioManager.SFX_BUS, &"SFX")


func test_crossfade_duration_is_positive() -> void:
	assert_gt(AudioManager.CROSSFADE_DURATION, 0.0)


func test_sfx_menu_click_path_has_wav_extension() -> void:
	assert_true(AudioManager.SFX_MENU_CLICK.ends_with(".wav"))


func test_sfx_footstep_snow_path_has_wav_extension() -> void:
	assert_true(AudioManager.SFX_FOOTSTEP_SNOW.ends_with(".wav"))


func test_sfx_footstep_grass_path_has_wav_extension() -> void:
	assert_true(AudioManager.SFX_FOOTSTEP_GRASS.ends_with(".wav"))


func test_indoor_track_path_has_wav_extension() -> void:
	assert_true(AudioManager.INDOOR_TRACK.ends_with(".wav"))


func test_blizzard_track_path_has_wav_extension() -> void:
	assert_true(AudioManager.BLIZZARD_TRACK.ends_with(".wav"))


# ── Season track map ──────────────────────────────────────────────────────────

func test_season_tracks_covers_spring() -> void:
	assert_true(AudioManager.SEASON_TRACKS.has(TimeManager.Season.SPRING))


func test_season_tracks_covers_summer() -> void:
	assert_true(AudioManager.SEASON_TRACKS.has(TimeManager.Season.SUMMER))


func test_season_tracks_covers_autumn() -> void:
	assert_true(AudioManager.SEASON_TRACKS.has(TimeManager.Season.AUTUMN))


func test_season_tracks_covers_winter() -> void:
	assert_true(AudioManager.SEASON_TRACKS.has(TimeManager.Season.WINTER))


func test_all_season_track_paths_have_wav_extension() -> void:
	for path: String in AudioManager.SEASON_TRACKS.values():
		assert_true(path.ends_with(".wav"), "Expected .wav extension for: %s" % path)


# ── set_indoors state ─────────────────────────────────────────────────────────

func test_set_indoors_true_sets_state() -> void:
	AudioManager.set_indoors(true)
	assert_true(AudioManager._is_indoors)


func test_set_indoors_false_sets_state() -> void:
	AudioManager._is_indoors = true
	AudioManager.set_indoors(false)
	assert_false(AudioManager._is_indoors)


func test_set_indoors_same_value_is_idempotent() -> void:
	# Calling with the current value must not alter state
	AudioManager._is_indoors = false
	AudioManager.set_indoors(false)
	assert_false(AudioManager._is_indoors)


# ── Null-guard: play_sfx_global ───────────────────────────────────────────────

func test_play_sfx_global_null_does_not_crash() -> void:
	# Must return early without adding a player node
	var child_count_before: int = AudioManager.get_child_count()
	AudioManager.play_sfx_global(null)
	assert_eq(AudioManager.get_child_count(), child_count_before)


# ── Null-guard: play_sfx ─────────────────────────────────────────────────────

func test_play_sfx_null_does_not_crash() -> void:
	var child_count_before: int = AudioManager.get_child_count()
	AudioManager.play_sfx(null)
	assert_eq(AudioManager.get_child_count(), child_count_before)


# ── Unknown season path (push_warning site) ───────────────────────────────────

func test_unknown_season_does_not_start_playback() -> void:
	# Season value -999 is not in SEASON_TRACKS; _play_contextual_music returns
	# early on the empty-string guard, leaving the active player silent.
	AudioManager._is_indoors = false
	AudioManager._on_season_changed(-999)
	assert_false(AudioManager._active_player.playing)
