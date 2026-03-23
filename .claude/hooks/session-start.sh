#!/bin/bash
# Session start hook — installs all dependencies needed for cloud Claude Code sessions.
# Only runs in remote (cloud) environments; exits immediately on local machines.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

echo "=== Session setup: installing dependencies ==="

# ── 1. Node / Playwright ──────────────────────────────────────────────────────
echo "[1/4] npm install"
npm install

echo "[2/4] Playwright browsers (chromium)"
npx playwright install --with-deps chromium

# ── 2. Godot 4 ───────────────────────────────────────────────────────────────
GODOT_VERSION="4.4.1"

if ! command -v godot &>/dev/null; then
  echo "[3/4] Installing Godot $GODOT_VERSION"
  wget -q \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    -O /tmp/godot.zip
  unzip -q /tmp/godot.zip -d /tmp/godot_extract
  install -m 755 \
    "/tmp/godot_extract/Godot_v${GODOT_VERSION}-stable_linux.x86_64" \
    /usr/local/bin/godot
  rm -rf /tmp/godot_extract /tmp/godot.zip
  echo "    Godot $GODOT_VERSION installed at $(command -v godot)"
else
  echo "[3/4] Godot already installed: $(godot --version 2>&1 | head -1)"
fi

# Import the project so class names and resources are registered.
# Required before GUT tests can resolve class_name symbols.
echo "    Importing Godot project (registers class names for GUT)..."
timeout 120 godot --headless --import 2>/dev/null || true

# ── 3. CLI tools ──────────────────────────────────────────────────────────────
echo "[4/4] Checking CLI tools (curl, jq)"
missing=""
command -v curl &>/dev/null || missing="$missing curl"
command -v jq   &>/dev/null || missing="$missing jq"

if [ -n "$missing" ]; then
  echo "    Installing:$missing"
  apt-get install -y -qq $missing
else
  echo "    curl and jq already present"
fi

echo "=== Session setup complete ==="
