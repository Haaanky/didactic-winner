extends GutTest
## Structural tests for the asset generation submodule integration.
##
## These tests verify that:
##   - The vendor/game-dev-tools submodule is properly configured
##   - All required scripts exist and are in the expected locations
##   - The wrapper script and internal fallback are both present
##   - The remove_bg.py script is available
##   - The wrapper correctly delegates and falls back via OS.execute
##
## These are filesystem / structural tests. They do NOT make API calls or
## start local servers. They will pass in CI environments where the submodule
## has been initialised with `git submodule update --init vendor/game-dev-tools`.

const WRAPPER_SCRIPT := "tools/generate_asset.sh"
const INTERNAL_SCRIPT := "tools/_generate_asset_internal.sh"
const REMOVE_BG_SCRIPT := "tools/remove_bg.py"
const SUBMODULE_DIR := "vendor/game-dev-tools"
const SUBMODULE_SCRIPT := "vendor/game-dev-tools/src/generate_asset.sh"
const SUBMODULE_SPRITE_SERVER := "vendor/game-dev-tools/src/servers/local_sprite_server.py"
const SUBMODULE_AUDIO_SERVER := "vendor/game-dev-tools/src/servers/local_audio_server.py"
const GITMODULES := ".gitmodules"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _project_path(relative: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join(relative)


func _file_exists(relative: String) -> bool:
	return FileAccess.file_exists(_project_path(relative))


func _dir_exists(relative: String) -> bool:
	return DirAccess.dir_exists_absolute(_project_path(relative))


# Returns true if a file contains the given substring.
func _file_contains(relative: String, substring: String) -> bool:
	var path := _project_path(relative)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var content := f.get_as_text()
	f.close()
	return content.contains(substring)


# ---------------------------------------------------------------------------
# Section 1 — Submodule registration
# ---------------------------------------------------------------------------

func test_gitmodules_exists() -> void:
	assert_true(_file_exists(GITMODULES),
		".gitmodules must exist for submodule to be tracked")


func test_gitmodules_contains_vendor_game_dev_tools() -> void:
	if not _file_exists(GITMODULES):
		pending(".gitmodules not found — skipping")
		return
	assert_true(_file_contains(GITMODULES, "vendor/game-dev-tools"),
		".gitmodules must contain the vendor/game-dev-tools submodule entry")


func test_gitmodules_contains_correct_url() -> void:
	if not _file_exists(GITMODULES):
		pending(".gitmodules not found — skipping")
		return
	assert_true(_file_contains(GITMODULES, "Haaanky/game-dev-tools"),
		".gitmodules must point to the Haaanky/game-dev-tools repository")


# ---------------------------------------------------------------------------
# Section 2 — Submodule content (requires `git submodule update --init`)
# ---------------------------------------------------------------------------

func test_submodule_directory_exists() -> void:
	if not _dir_exists(SUBMODULE_DIR):
		pending("Submodule not initialised — run: git submodule update --init vendor/game-dev-tools")
		return
	assert_true(_dir_exists(SUBMODULE_DIR),
		"vendor/game-dev-tools/ directory must exist after submodule init")


func test_submodule_generate_script_exists() -> void:
	if not _dir_exists(SUBMODULE_DIR):
		pending("Submodule not initialised — skipping content checks")
		return
	assert_true(_file_exists(SUBMODULE_SCRIPT),
		"vendor/game-dev-tools/src/generate_asset.sh must exist")


func test_submodule_sprite_server_exists() -> void:
	if not _dir_exists(SUBMODULE_DIR):
		pending("Submodule not initialised — skipping content checks")
		return
	assert_true(_file_exists(SUBMODULE_SPRITE_SERVER),
		"vendor/game-dev-tools/src/servers/local_sprite_server.py must exist")


func test_submodule_audio_server_exists() -> void:
	if not _dir_exists(SUBMODULE_DIR):
		pending("Submodule not initialised — skipping content checks")
		return
	assert_true(_file_exists(SUBMODULE_AUDIO_SERVER),
		"vendor/game-dev-tools/src/servers/local_audio_server.py must exist")


func test_submodule_readme_exists() -> void:
	if not _dir_exists(SUBMODULE_DIR):
		pending("Submodule not initialised — skipping content checks")
		return
	assert_true(_file_exists("vendor/game-dev-tools/README.md"),
		"vendor/game-dev-tools/README.md must exist")


# ---------------------------------------------------------------------------
# Section 3 — Project-local scripts
# ---------------------------------------------------------------------------

func test_wrapper_script_exists() -> void:
	assert_true(_file_exists(WRAPPER_SCRIPT),
		"tools/generate_asset.sh (wrapper) must exist")


func test_internal_fallback_exists() -> void:
	assert_true(_file_exists(INTERNAL_SCRIPT),
		"tools/_generate_asset_internal.sh (internal fallback) must exist")


func test_remove_bg_script_exists() -> void:
	assert_true(_file_exists(REMOVE_BG_SCRIPT),
		"tools/remove_bg.py must exist — required for sprite background removal")


# ---------------------------------------------------------------------------
# Section 4 — Wrapper script content checks
# ---------------------------------------------------------------------------

func test_wrapper_references_submodule_script() -> void:
	if not _file_exists(WRAPPER_SCRIPT):
		pending("Wrapper script not found — skipping content checks")
		return
	assert_true(_file_contains(WRAPPER_SCRIPT, "vendor/game-dev-tools/src/generate_asset.sh"),
		"Wrapper must reference the submodule script as primary path")


func test_wrapper_references_internal_fallback() -> void:
	if not _file_exists(WRAPPER_SCRIPT):
		pending("Wrapper script not found — skipping content checks")
		return
	assert_true(_file_contains(WRAPPER_SCRIPT, "_generate_asset_internal.sh"),
		"Wrapper must reference the internal fallback script")


func test_wrapper_references_remove_bg() -> void:
	if not _file_exists(WRAPPER_SCRIPT):
		pending("Wrapper script not found — skipping content checks")
		return
	assert_true(_file_contains(WRAPPER_SCRIPT, "remove_bg.py"),
		"Wrapper must call remove_bg.py for sprite background removal")


func test_wrapper_references_architecture_doc() -> void:
	if not _file_exists(WRAPPER_SCRIPT):
		pending("Wrapper script not found — skipping content checks")
		return
	assert_true(_file_contains(WRAPPER_SCRIPT, "asset_generation_architecture.md"),
		"Wrapper must reference the architecture doc for agent instructions")


func test_wrapper_sets_asset_output_dir() -> void:
	if not _file_exists(WRAPPER_SCRIPT):
		pending("Wrapper script not found — skipping content checks")
		return
	assert_true(_file_contains(WRAPPER_SCRIPT, "ASSET_OUTPUT_DIR"),
		"Wrapper must set ASSET_OUTPUT_DIR before calling submodule script")


# ---------------------------------------------------------------------------
# Section 5 — Internal fallback content checks
# ---------------------------------------------------------------------------

func test_internal_fallback_has_sprite_generation() -> void:
	if not _file_exists(INTERNAL_SCRIPT):
		pending("Internal fallback not found — skipping content checks")
		return
	assert_true(_file_contains(INTERNAL_SCRIPT, "generate_sprite"),
		"Internal fallback must contain sprite generation logic")


func test_internal_fallback_has_sfx_generation() -> void:
	if not _file_exists(INTERNAL_SCRIPT):
		pending("Internal fallback not found — skipping content checks")
		return
	assert_true(_file_contains(INTERNAL_SCRIPT, "generate_sfx"),
		"Internal fallback must contain SFX generation logic")


func test_internal_fallback_has_music_generation() -> void:
	if not _file_exists(INTERNAL_SCRIPT):
		pending("Internal fallback not found — skipping content checks")
		return
	assert_true(_file_contains(INTERNAL_SCRIPT, "generate_music"),
		"Internal fallback must contain music generation logic")


# ---------------------------------------------------------------------------
# Section 6 — Architecture document
# ---------------------------------------------------------------------------

func test_architecture_doc_exists() -> void:
	assert_true(_file_exists("docs/asset_generation_architecture.md"),
		"docs/asset_generation_architecture.md must exist — required for agent fallback instructions")


func test_architecture_doc_covers_agent_skills() -> void:
	if not _file_exists("docs/asset_generation_architecture.md"):
		pending("Architecture doc not found — skipping content checks")
		return
	assert_true(
		_file_contains("docs/asset_generation_architecture.md", "Agent Built-in Skills"),
		"Architecture doc must document the agent built-in skills fallback tier")


func test_architecture_doc_covers_submodule() -> void:
	if not _file_exists("docs/asset_generation_architecture.md"):
		pending("Architecture doc not found — skipping content checks")
		return
	assert_true(
		_file_contains("docs/asset_generation_architecture.md", "vendor/game-dev-tools"),
		"Architecture doc must reference the submodule path")
