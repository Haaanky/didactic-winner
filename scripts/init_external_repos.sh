#!/usr/bin/env bash
# init_external_repos.sh — Create GitHub repos from _staging/ and push content.
#
# Requirements:
#   - GITHUB_TOKEN env var with repo + administration write permissions, OR
#   - gh CLI authenticated via 'gh auth login'
#   - git, curl, jq
#
# Usage:
#   GITHUB_TOKEN=<token> ./scripts/init_external_repos.sh
#
# What it does:
#   1. Creates Haaanky/game-dev-tools (public) on GitHub
#   2. Creates Haaanky/godot-cicd (public) on GitHub
#   3. Pushes _staging/game-dev-tools/ content to the new repo
#   4. Pushes _staging/godot-cicd/ content to the new repo
#
# Safe to re-run: existing repos are not modified, only content is pushed.

set -euo pipefail

GITHUB_OWNER="Haaanky"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPOS=(
  "game-dev-tools:Generic AI asset generation tools for game and app development"
  "godot-cicd:Reusable GitHub Actions workflows for Godot 4 projects"
)

# ---- Auth detection ----

detect_auth() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo "token"
    return 0
  fi
  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    echo "gh"
    return 0
  fi
  echo "none"
}

AUTH_METHOD="$(detect_auth)"

if [[ "$AUTH_METHOD" == "none" ]]; then
  echo "ERROR: No GitHub authentication found." >&2
  echo "  Option A: export GITHUB_TOKEN=<your-fine-grained-pat>" >&2
  echo "  Option B: gh auth login" >&2
  exit 1
fi

echo "Auth method: $AUTH_METHOD"

# ---- Create repo ----

create_repo() {
  local repo_name="$1" description="$2"

  echo "Creating $GITHUB_OWNER/$repo_name..."

  if [[ "$AUTH_METHOD" == "gh" ]]; then
    if gh repo view "$GITHUB_OWNER/$repo_name" &>/dev/null 2>&1; then
      echo "  Repo already exists — skipping creation."
      return 0
    fi
    gh repo create "$GITHUB_OWNER/$repo_name" \
      --public \
      --description "$description" \
      --source /dev/null 2>/dev/null || true
    echo "  Created."
  else
    local response http_code
    response="$(curl -sS -w "\n%{http_code}" \
      -X POST "https://api.github.com/user/repos" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -d "$(jq -n \
        --arg name "$repo_name" \
        --arg desc "$description" \
        '{name: $name, description: $desc, private: false, auto_init: false}')")"
    http_code="$(echo "$response" | tail -n1)"
    response="$(echo "$response" | head -n -1)"

    if [[ "$http_code" == "201" ]]; then
      echo "  Created."
    elif [[ "$http_code" == "422" ]]; then
      echo "  Repo already exists — skipping creation."
    else
      echo "  ERROR: GitHub API returned HTTP $http_code" >&2
      echo "  Response: $(echo "$response" | head -c 200)" >&2
      return 1
    fi
  fi
}

# ---- Push staging content ----

push_staging() {
  local repo_name="$1"
  local staging_dir="$PROJECT_ROOT/_staging/$repo_name"

  if [[ ! -d "$staging_dir" ]]; then
    echo "ERROR: Staging directory not found: $staging_dir" >&2
    return 1
  fi

  echo "Pushing $staging_dir → $GITHUB_OWNER/$repo_name..."

  # Determine remote URL
  local remote_url
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    remote_url="https://${GITHUB_TOKEN}@github.com/${GITHUB_OWNER}/${repo_name}.git"
  else
    remote_url="https://github.com/${GITHUB_OWNER}/${repo_name}.git"
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  # Init a fresh git repo from staging content
  cp -r "$staging_dir/." "$tmp_dir/"
  cd "$tmp_dir"

  git init -b main
  git config user.name "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"
  git add -A
  git commit -m "Initial commit from didactic-winner staging"

  # Push — retry up to 4 times with exponential backoff on network errors
  local attempt=1 delay=2
  while [[ $attempt -le 4 ]]; do
    if git push -u "$remote_url" main --force 2>&1; then
      echo "  Pushed successfully."
      cd "$PROJECT_ROOT"
      return 0
    fi
    echo "  Push attempt $attempt failed — retrying in ${delay}s..." >&2
    sleep $delay
    delay=$((delay * 2))
    attempt=$((attempt + 1))
  done

  echo "  ERROR: All push attempts failed for $repo_name" >&2
  cd "$PROJECT_ROOT"
  return 1
}

# ---- Main ----

echo "=== Initialising external repos for $GITHUB_OWNER ==="
echo ""

for entry in "${REPOS[@]}"; do
  repo_name="${entry%%:*}"
  description="${entry#*:}"
  create_repo "$repo_name" "$description"
done

echo ""
echo "=== Pushing staging content ==="
echo ""

for entry in "${REPOS[@]}"; do
  repo_name="${entry%%:*}"
  push_staging "$repo_name"
done

echo ""
echo "=== Done ==="
echo ""
echo "Repos created:"
for entry in "${REPOS[@]}"; do
  repo_name="${entry%%:*}"
  echo "  https://github.com/$GITHUB_OWNER/$repo_name"
done
