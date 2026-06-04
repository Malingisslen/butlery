#!/usr/bin/env bash
# BUT-488: compute the next version from conventional commits and (optionally)
# apply it to pubspec.yaml + CHANGELOG.md.
#
# Bump rules (highest match wins, scanning commits since the last v* tag):
#   - major  → any commit with `!:` in its type prefix, or `BREAKING CHANGE`
#              in the subject/body (e.g. `feat!:`, `refactor!:`).
#   - minor  → any `feat:` / `feat(scope):` commit.
#   - patch  → anything else (fix, refactor, chore, docs, ...).
# An explicit override (patch|minor|major) skips the scan.
#
# Usage:
#   tools/release/bump_version.sh [--dry-run] [--override <patch|minor|major>]
#
# --dry-run prints the computed bump, current→next version, and the CHANGELOG
# section that WOULD be written, then exits 0 without touching any file or
# requiring cider. Apply mode (no --dry-run) rewrites the pubspec `version:`
# line and prepends the section to CHANGELOG.md; the caller (CI) handles the
# git commit + tag + push.
set -euo pipefail

DRY_RUN=0
OVERRIDE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --override) OVERRIDE="${2:-}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -n "$OVERRIDE" ] && ! [[ "$OVERRIDE" =~ ^(patch|minor|major)$ ]]; then
  echo "::error::--override must be patch|minor|major (got '$OVERRIDE')" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PUBSPEC="$REPO_ROOT/pubspec.yaml"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"

# --- current version --------------------------------------------------------
CURRENT_LINE="$(grep -m1 '^version:' "$PUBSPEC")"
CURRENT_VERSION="${CURRENT_LINE#version: }"
CURRENT_VERSION="${CURRENT_VERSION// /}"
CORE="${CURRENT_VERSION%%+*}"          # 0.9.0
BUILD="${CURRENT_VERSION##*+}"         # 1
if [ "$BUILD" = "$CURRENT_VERSION" ]; then BUILD=0; fi   # no +build present
IFS='.' read -r MAJOR MINOR PATCH <<<"$CORE"

# --- commit range since last v* tag -----------------------------------------
LAST_TAG="$(git -C "$REPO_ROOT" tag --list 'v*' --sort=-version:refname | head -n1 || true)"
if [ -n "$LAST_TAG" ]; then
  RANGE="${LAST_TAG}..HEAD"
else
  RANGE="HEAD"   # no release tag yet → all of history
fi

# Subjects (one per line) and full log (for BREAKING CHANGE in bodies).
SUBJECTS="$(git -C "$REPO_ROOT" log "$RANGE" --no-merges --pretty=format:'%s' || true)"
BODIES="$(git -C "$REPO_ROOT" log "$RANGE" --no-merges --pretty=format:'%b' || true)"

# --- determine bump type ----------------------------------------------------
# NOTE: use here-strings, NOT `printf ... | grep -q`. `grep -q` exits on the
# first match and SIGPIPEs the upstream printf (exit 141); under `pipefail`
# that makes the whole pipeline non-zero EVEN ON A MATCH, silently demoting
# every bump to patch. `<<<` has no upstream process to break.
if [ -n "$OVERRIDE" ]; then
  BUMP="$OVERRIDE"
elif grep -qE '^[a-z]+(\([^)]*\))?!:' <<<"$SUBJECTS" \
     || grep -q 'BREAKING CHANGE' <<<"$BODIES"; then
  BUMP="major"
elif grep -qE '^feat(\([^)]*\))?:' <<<"$SUBJECTS"; then
  BUMP="minor"
else
  BUMP="patch"
fi

case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac
NEW_BUILD=$((BUILD + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}+${NEW_BUILD}"
NEW_CORE="${MAJOR}.${MINOR}.${PATCH}"

# --- build the changelog section (Keep a Changelog grouping) ----------------
# Date is passed by CI (RELEASE_DATE) so the script stays deterministic; falls
# back to `git log` of the newest commit when unset, never to a live clock.
RELEASE_DATE="${RELEASE_DATE:-$(git -C "$REPO_ROOT" log -1 --pretty=format:'%cs' 2>/dev/null || echo 'unreleased')}"

section_for() {
  # $1 = grep ERE for the conventional type prefix
  printf '%s\n' "$SUBJECTS" | grep -E "$1" | sed -E 's/^[a-z]+(\([^)]*\))?!?: //' | sed 's/^/- /' || true
}
ADDED="$(section_for '^feat(\([^)]*\))?!?:')"
FIXED="$(section_for '^fix(\([^)]*\))?!?:')"
CHANGED="$(section_for '^(refactor|perf|chore|build|ci|style|docs)(\([^)]*\))?!?:')"

SECTION="## [${NEW_CORE}] - ${RELEASE_DATE}"
[ -n "$ADDED" ]   && SECTION="${SECTION}"$'\n\n'"### Added"$'\n'"${ADDED}"
[ -n "$FIXED" ]   && SECTION="${SECTION}"$'\n\n'"### Fixed"$'\n'"${FIXED}"
[ -n "$CHANGED" ] && SECTION="${SECTION}"$'\n\n'"### Changed"$'\n'"${CHANGED}"

# --- output -----------------------------------------------------------------
echo "current_version=${CURRENT_VERSION}"
echo "bump=${BUMP}"
echo "new_version=${NEW_VERSION}"
echo "range=${RANGE}"
echo "--- CHANGELOG section ---"
printf '%s\n' "$SECTION"
echo "-------------------------"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "(dry-run: no files written)"
  # Expose to a GitHub step via $GITHUB_OUTPUT when present, even in dry-run.
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      echo "bump=${BUMP}"
      echo "new_version=${NEW_VERSION}"
    } >> "$GITHUB_OUTPUT"
  fi
  exit 0
fi

# --- apply ------------------------------------------------------------------
# Replace the single pubspec `version:` line. We already computed NEW_VERSION
# via semver math above, so no external version tool (cider et al.) is needed —
# one sed is the cheapest correct mechanism, and keeps this script + the release
# workflow dependency-free (pure bash + git + sed).
sed -i.bak -E "s/^version: .*/version: ${NEW_VERSION}/" "$PUBSPEC" && rm -f "${PUBSPEC}.bak"

# CHANGELOG: create with a Keep-a-Changelog header on first run, else prepend
# the new section directly under the header.
if [ ! -f "$CHANGELOG" ]; then
  {
    echo "# Changelog"
    echo
    echo "All notable changes to Butlery are documented here. Format follows"
    echo "[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions"
    echo "mirror pubspec.yaml and are bumped by tools/release/bump_version.sh (BUT-488)."
    echo
    printf '%s\n' "$SECTION"
  } > "$CHANGELOG"
else
  TMP="$(mktemp)"
  HEADER_END="$(grep -n -m1 '^## \[' "$CHANGELOG" | cut -d: -f1 || true)"
  if [ -n "$HEADER_END" ]; then
    head -n "$((HEADER_END - 1))" "$CHANGELOG" > "$TMP"
    printf '%s\n\n' "$SECTION" >> "$TMP"
    tail -n "+${HEADER_END}" "$CHANGELOG" >> "$TMP"
  else
    cat "$CHANGELOG" > "$TMP"
    printf '\n%s\n' "$SECTION" >> "$TMP"
  fi
  mv "$TMP" "$CHANGELOG"
fi

echo "Applied version ${NEW_VERSION} and updated CHANGELOG.md"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "bump=${BUMP}"
    echo "new_version=${NEW_VERSION}"
    echo "new_core=${NEW_CORE}"
  } >> "$GITHUB_OUTPUT"
fi
