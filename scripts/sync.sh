#!/usr/bin/env bash
# Agent Skills Junction - Multi-Harness Sync Engine (Linux / macOS)
# Consolidates AI Agent skills into a Single Source of Truth (~/.agents/skills)
# and creates atomic symlinks for all target agent harnesses.

set -euo pipefail

SSOT="${HOME}/.agents/skills"
CONFIG_FILE="$(dirname "$0")/../config/harnesses.json"

echo "================================================================"
echo "          Agent Skills Junction - Sync Engine (POSIX)           "
echo "================================================================"
echo "Central SSOT: ${SSOT}"

mkdir -p "${SSOT}"

# Default fallback targets
TARGETS=(
  "${HOME}/.pi/agent/skills"
  "${HOME}/.codex/skills"
  "${HOME}/.gemini/config/skills"
  "${HOME}/.gemini/antigravity-cli/skills"
  "${HOME}/.claude/skills"
  "${HOME}/.continue/skills"
  "${HOME}/.openhands/skills"
  "${HOME}/.cursor/skills"
)

# Load targets dynamically from harnesses.json if jq or python3 is available
if [ -f "${CONFIG_FILE}" ]; then
  if command -v jq >/dev/null 2>&1; then
    PARSED=$(jq -r '.targets[] | select(.enabled == true) | .path_posix' "${CONFIG_FILE}" 2>/dev/null || true)
    if [ -n "${PARSED}" ]; then
      TARGETS=()
      while IFS= read -r line; do
        TARGETS+=("${line/#\~/$HOME}")
      done <<< "${PARSED}"
    fi
  elif command -v python3 >/dev/null 2>&1; then
    PARSED=$(python3 -c "import json, sys; [print(t['path_posix']) for t in json.load(open('${CONFIG_FILE}'))['targets'] if t.get('enabled')]" 2>/dev/null || true)
    if [ -n "${PARSED}" ]; then
      TARGETS=()
      while IFS= read -r line; do
        TARGETS+=("${line/#\~/$HOME}")
      done <<< "${PARSED}"
    fi
  fi
fi

for target in "${TARGETS[@]}"; do
  echo "Processing target: ${target}"
  mkdir -p "$(dirname "${target}")"

  if [ -L "${target}" ]; then
    echo "  -> [OK] Already a symlink: ${target}"
  elif [ -d "${target}" ]; then
    echo "  -> [MERGE] Physical folder found. Merging unique skills into SSOT..."
    mkdir -p "${SSOT}"
    cp -rn "${target}/"* "${SSOT}/" 2>/dev/null || true
    bak="${target}.bak_$(date +%Y%m%d%H%M%S)"
    mv "${target}" "${bak}"
    echo "  -> [BACKUP] Safely preserved original folder as: ${bak}"
    ln -sfn "${SSOT}" "${target}"
    echo "  -> [SUCCESS] Symlink created: ${target} -> ${SSOT}"
  else
    ln -sfn "${SSOT}" "${target}"
    echo "  -> [SUCCESS] Symlink created: ${target} -> ${SSOT}"
  fi
done

echo "================================================================"
echo "All target harnesses successfully symlinked to SSOT!"
echo "================================================================"
