#!/usr/bin/env bash
# BUT-771: assert every CI workflow's `node-version:` matches the Node version
# declared in `functions/package.json` `engines.node`. Run from repo root:
#
#   bash tools/check_node_version_consistency.sh
#
# Exits non-zero on drift so CI fails loud rather than silently testing under
# a Node version different from the one Cloud Functions actually run on.
#
# Tolerated patterns:
#   - `node-version: "22"` / `node-version: '22'` / `node-version: 22`
#   - `node-version: ${{ env.NODE_VERSION }}` (env var resolved separately;
#     the env: NODE_VERSION value must match)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="${REPO_ROOT}/functions/package.json"
WORKFLOW_DIR="${REPO_ROOT}/.github/workflows"

if [[ ! -f "${PKG}" ]]; then
  echo "::error::functions/package.json not found at ${PKG}" >&2
  exit 2
fi

# Pull the engines.node value. node 22 → "22"; "22.x" → "22.x". We strip the
# major-only when comparing because workflows commonly pin to the major.
ENGINES_NODE="$(node -p "require('${PKG}').engines && require('${PKG}').engines.node || ''" 2>/dev/null || true)"
if [[ -z "${ENGINES_NODE}" ]]; then
  # Fallback to a grep-based extraction so the script also works without Node
  # available (e.g. on a stripped-down runner).
  ENGINES_NODE="$(grep -E '"node"\s*:\s*"' "${PKG}" | head -1 | sed -E 's/.*"node"\s*:\s*"([^"]+)".*/\1/')"
fi
if [[ -z "${ENGINES_NODE}" ]]; then
  echo "::error::Could not read engines.node from ${PKG}" >&2
  exit 2
fi

# Normalize: keep only the major version digits. "22" / "22.x" / ">=22" → "22".
EXPECTED_MAJOR="$(echo "${ENGINES_NODE}" | grep -oE '[0-9]+' | head -1)"
if [[ -z "${EXPECTED_MAJOR}" ]]; then
  echo "::error::engines.node='${ENGINES_NODE}' has no numeric component" >&2
  exit 2
fi
echo "engines.node major: ${EXPECTED_MAJOR}"

drift=0
shopt -s nullglob
for wf in "${WORKFLOW_DIR}"/*.yml "${WORKFLOW_DIR}"/*.yaml; do
  # Inline literal node-version pins.
  while IFS= read -r line; do
    # line ex: '          node-version: "20"'
    actual="$(echo "${line}" | sed -E 's/.*node-version:[[:space:]]*//; s/[\x27\x22]//g; s/[[:space:]]*$//')"
    # Skip env-var indirections — those are validated below.
    if [[ "${actual}" == \$\{\{* ]]; then
      continue
    fi
    actual_major="$(echo "${actual}" | grep -oE '[0-9]+' | head -1)"
    if [[ -z "${actual_major}" ]]; then
      continue
    fi
    if [[ "${actual_major}" != "${EXPECTED_MAJOR}" ]]; then
      echo "::error file=${wf}::node-version pinned to ${actual} but functions/package.json engines.node major is ${EXPECTED_MAJOR}"
      drift=1
    fi
  done < <(grep -nE '^[[:space:]]*node-version:' "${wf}" || true)

  # Env-var indirections: when `node-version: ${{ env.NODE_VERSION }}` is used,
  # validate the env: NODE_VERSION value declared in the same workflow.
  if grep -qE 'node-version:[[:space:]]*\$\{\{\s*env\.NODE_VERSION\s*\}\}' "${wf}"; then
    env_val="$(grep -E '^[[:space:]]*NODE_VERSION:' "${wf}" | head -1 | sed -E 's/.*NODE_VERSION:[[:space:]]*//; s/[\x27\x22]//g; s/[[:space:]]*$//')"
    env_major="$(echo "${env_val}" | grep -oE '[0-9]+' | head -1)"
    if [[ -z "${env_major}" ]]; then
      echo "::error file=${wf}::node-version uses \${{ env.NODE_VERSION }} but env.NODE_VERSION is not declared in this workflow"
      drift=1
    elif [[ "${env_major}" != "${EXPECTED_MAJOR}" ]]; then
      echo "::error file=${wf}::env.NODE_VERSION='${env_val}' but functions/package.json engines.node major is ${EXPECTED_MAJOR}"
      drift=1
    fi
  fi
done

if [[ "${drift}" -ne 0 ]]; then
  echo "::error::Node version drift detected. Bring all workflows in line with functions/package.json engines.node, or update engines.node deliberately."
  exit 1
fi

echo "All workflow node-version pins match engines.node major ${EXPECTED_MAJOR}."
