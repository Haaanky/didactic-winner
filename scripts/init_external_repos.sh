#!/usr/bin/env bash
# init_external_repos.sh — Create GitHub repos from _staging/ and push content.
#
# Uses GitHub Contents API to upload files one by one — works on empty repos
# without requiring git or commit signing.
#
# Requirements:
#   - GITHUB_TOKEN env var with repo + administration write permissions
#   - curl, jq, find, base64
#
# Usage:
#   GITHUB_TOKEN=<token> ./scripts/init_external_repos.sh

set -euo pipefail

GITHUB_OWNER="Haaanky"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
API="https://api.github.com"

REPOS=(
  "game-dev-tools:Generic AI asset generation tools for game and app development"
  "godot-cicd:Reusable GitHub Actions workflows for Godot 4 projects"
)

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: GITHUB_TOKEN not set." >&2
  exit 1
fi

api() {
  local method="$1" path="$2" data="${3:-}"
  if [[ -n "$data" ]]; then
    curl -sS -w "\n%{http_code}" \
      -X "$method" "$API$path" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -d "$data"
  else
    curl -sS -w "\n%{http_code}" \
      -X "$method" "$API$path" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28"
  fi
}

# ---- Create repo (delete + recreate if already empty) ----

ensure_repo() {
  local repo_name="$1" description="$2"
  echo "Ensuring $GITHUB_OWNER/$repo_name exists..."

  # Check if repo exists
  local check_code
  check_code="$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "$API/repos/$GITHUB_OWNER/$repo_name")"

  if [[ "$check_code" == "200" ]]; then
    echo "  Exists — will overwrite content."
  else
    echo "  Creating..."
    local resp
    resp="$(api POST /user/repos "$(jq -n \
      --arg name "$repo_name" \
      --arg desc "$description" \
      '{name: $name, description: $desc, private: false, auto_init: false}')")"
    local code
    code="$(echo "$resp" | tail -n1)"
    [[ "$code" == "201" ]] || { echo "  ERROR: HTTP $code"; echo "$resp" | head -n -1; return 1; }
    echo "  Created."
  fi
}

# ---- Upload one file via Contents API ----

upload_file() {
  local repo_name="$1" abs_path="$2" rel_path="$3"
  local content_b64
  content_b64="$(base64 -w 0 "$abs_path")"

  # Check if file already exists (need its SHA to update)
  local existing_sha=""
  local check_resp
  check_resp="$(curl -sS -o /tmp/_ga_check -w "%{http_code}" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$API/repos/$GITHUB_OWNER/$repo_name/contents/$rel_path")"

  if [[ "$check_resp" == "200" ]]; then
    existing_sha="$(jq -r '.sha' /tmp/_ga_check)"
  fi

  # Build payload
  local payload
  if [[ -n "$existing_sha" ]]; then
    payload="$(jq -n \
      --arg msg "Add $rel_path" \
      --arg content "$content_b64" \
      --arg sha "$existing_sha" \
      '{message: $msg, content: $content, sha: $sha}')"
  else
    payload="$(jq -n \
      --arg msg "Add $rel_path" \
      --arg content "$content_b64" \
      '{message: $msg, content: $content}')"
  fi

  local resp code
  resp="$(curl -sS -w "\n%{http_code}" \
    -X PUT "$API/repos/$GITHUB_OWNER/$repo_name/contents/$rel_path" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -d "$payload")"
  code="$(echo "$resp" | tail -n1)"

  if [[ "$code" == "200" || "$code" == "201" ]]; then
    echo "  OK  $rel_path"
  else
    echo "  FAIL $rel_path (HTTP $code)" >&2
    echo "$resp" | head -n -1 | jq -r '.message // .' >&2
    return 1
  fi
}

# ---- Push all files from staging dir ----

push_staging() {
  local repo_name="$1"
  local staging_dir="$PROJECT_ROOT/_staging/$repo_name"

  if [[ ! -d "$staging_dir" ]]; then
    echo "ERROR: Staging directory not found: $staging_dir" >&2
    return 1
  fi

  echo "Uploading $staging_dir → github.com/$GITHUB_OWNER/$repo_name"

  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$staging_dir" -type f -print0 | sort -z)

  for abs_path in "${files[@]}"; do
    local rel_path="${abs_path#$staging_dir/}"
    upload_file "$repo_name" "$abs_path" "$rel_path"
  done

  echo "  Done: https://github.com/$GITHUB_OWNER/$repo_name"
}

# ---- Main ----

echo "=== Initialising external repos for $GITHUB_OWNER ==="
echo ""

for entry in "${REPOS[@]}"; do
  repo_name="${entry%%:*}"
  description="${entry#*:}"
  ensure_repo "$repo_name" "$description"
done

echo ""
echo "=== Uploading content ==="
echo ""

for entry in "${REPOS[@]}"; do
  repo_name="${entry%%:*}"
  push_staging "$repo_name"
  echo ""
done

echo "=== Done ==="
echo ""
for entry in "${REPOS[@]}"; do
  repo_name="${entry%%:*}"
  echo "  https://github.com/$GITHUB_OWNER/$repo_name"
done
