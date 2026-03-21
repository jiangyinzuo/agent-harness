#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install_skills.sh <repo-url> [path1 path2 ...]
  install_skills.sh <repo-url> --branch <branch> [path1 path2 ...]

Description:
  Install skills from a git repository into:
    ./.claude/skills/

Modes:
  1) With repository paths:
       - Use sparse-checkout for the given repository-relative paths
       - Each path must be a directory containing SKILL.md
       - Install destination name = basename(path)

  2) Without repository paths:
       - Treat the repository root itself as a skill
       - Do NOT use sparse-checkout
       - Repository root must contain SKILL.md
       - Install destination name = repo name

Arguments:
  <repo-url>   Git repository URL
  <pathN>      Optional repository-relative skill directory path, such as:
               skill-creator
               skills/code-review
               some/nested/skill-dir

Options:
  --branch, -b <branch>   Clone a specific branch
  --help, -h              Show this help

Examples:
  # whole repo is a skill
  ./install_skills.sh https://github.com/example/my-skill

  # sparse checkout selected paths
  ./install_skills.sh https://github.com/anthropics/skills skill-creator
  ./install_skills.sh https://github.com/some/repo skills/foo skills/bar
EOF
}

log() {
  printf '[install_skills] %s\n' "$*"
}

err() {
  printf '[install_skills] ERROR: %s\n' "$*" >&2
}

repo_basename() {
  local url="$1"
  local base
  base="$(basename "$url")"
  base="${base%.git}"
  printf '%s\n' "$base"
}

copy_dir_without_git() {
  local src="$1"
  local dest="$2"

  rm -rf "$dest"
  mkdir -p "$dest"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a \
      --exclude '.git' \
      --exclude '.git/' \
      "$src"/ "$dest"/
  else
    (
      cd "$src"
      tar --exclude='.git' -cf - .
    ) | (
      mkdir -p "$dest"
      cd "$dest"
      tar -xf -
    )
  fi
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

REPO_URL="$1"
shift

BRANCH=""
PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch|-b)
      if [[ $# -lt 2 ]]; then
        err "--branch requires a value"
        exit 1
      fi
      BRANCH="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      PATHS+=("$1")
      shift
      ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  err "git not found"
  exit 1
fi

DEST_ROOT=".claude/skills"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/install-skills.XXXXXX")"
REPO_DIR="$TMP_DIR/repo"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$DEST_ROOT"

log "repo      : $REPO_URL"
[[ -n "$BRANCH" ]] && log "branch    : $BRANCH"
log "dest root : $DEST_ROOT"
log "tmp dir   : $TMP_DIR"

if [[ ${#PATHS[@]} -eq 0 ]]; then
  CLONE_ARGS=(clone --depth=1)
  if [[ -n "$BRANCH" ]]; then
    CLONE_ARGS+=(--branch "$BRANCH")
  fi
  CLONE_ARGS+=("$REPO_URL" "$REPO_DIR")

  log "cloning whole repository (no sparse checkout)"
  git "${CLONE_ARGS[@]}"

  if [[ ! -f "$REPO_DIR/SKILL.md" ]]; then
    err "repository root does not contain SKILL.md"
    exit 2
  fi

  NAME="$(repo_basename "$REPO_URL")"
  DEST="$DEST_ROOT/$NAME"

  log "installing repository root as skill -> $DEST"
  copy_dir_without_git "$REPO_DIR" "$DEST"

  if [[ ! -f "$DEST/SKILL.md" ]]; then
    err "install verification failed for repository root"
    exit 3
  fi

  log "done: installed=1 failed=0"
  exit 0
fi

CLONE_ARGS=(
  clone
  --depth=1
  --filter=blob:none
  --sparse
)

if [[ -n "$BRANCH" ]]; then
  CLONE_ARGS+=(--branch "$BRANCH")
fi

CLONE_ARGS+=("$REPO_URL" "$REPO_DIR")

log "cloning repository with sparse checkout enabled"
git "${CLONE_ARGS[@]}"

log "configuring sparse paths"
git -C "$REPO_DIR" sparse-checkout set "${PATHS[@]}"

INSTALLED=0
FAILED=0

for repo_path in "${PATHS[@]}"; do
  SRC="$REPO_DIR/$repo_path"
  NAME="$(basename "$repo_path")"
  DEST="$DEST_ROOT/$NAME"

  if [[ ! -d "$SRC" ]]; then
    err "path not found: $repo_path"
    FAILED=$((FAILED + 1))
    continue
  fi

  if [[ ! -f "$SRC/SKILL.md" ]]; then
    err "SKILL.md not found under: $repo_path"
    FAILED=$((FAILED + 1))
    continue
  fi

  log "installing '$repo_path' -> $DEST"
  copy_dir_without_git "$SRC" "$DEST"

  if [[ ! -f "$DEST/SKILL.md" ]]; then
    err "install verification failed for: $repo_path"
    FAILED=$((FAILED + 1))
    continue
  fi

  INSTALLED=$((INSTALLED + 1))
done

log "done: installed=$INSTALLED failed=$FAILED"

if [[ $INSTALLED -eq 0 ]]; then
  exit 2
fi

if [[ $FAILED -gt 0 ]]; then
  exit 3
fi
