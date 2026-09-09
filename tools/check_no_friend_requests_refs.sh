#!/usr/bin/env bash
# BUT-772: ensure functions/src/ never re-introduces the legacy
# `friend_requests` collection name in active code. The Firestore collection
# was renamed `friend_requests` -> `social_requests` in BUT-761; clients + rules
# migrated. Cloud-Functions code was migrated in BUT-772. Reintroducing the
# old name silently zero-results notification + cleanup jobs.
#
# Comment-only mentions (// , * , #) are allowed so historical breadcrumbs
# don't trip the guard.
#
# BUT-2044 added the one legitimate class of ACTIVE reference: code that exists
# solely to ERASE rows left under the dead spelling. That is the opposite of
# what this guard protects against — it reads the old name precisely because
# nothing writes it any more. Such a line is permitted only when BOTH locks
# open: the file is named in ALLOWED_FILES below, and the line contains the
# marker `LEGACY-SWEEP-OK`. A new reader or writer of the
# dead spelling anywhere else still fails, and adding a marker is a deliberate
# edit to a line a reviewer sees.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNCTIONS_DIR="$ROOT_DIR/functions/src"

if [[ ! -d "$FUNCTIONS_DIR" ]]; then
  echo "::error::functions/src not found at $FUNCTIONS_DIR" >&2
  exit 2
fi

# Erasure-only sites, relative to functions/src/. A marker on a line in any
# other file is ignored and still fails the guard.
ALLOWED_FILES=(
  # The per-account sweep's constant (BUT-2044) — read by cleanupSocialRequests.
  "cleanup/on-user-deleted.ts"
  # The whole-collection reset list (BUT-2044) — names the collection to wipe.
  "admin/reset-collection-lists.ts"
  # Tests that prove the two sweeps above actually reach the dead spelling.
  "__tests__/legacy-friend-requests.test.ts"
  "__tests__/on-user-deleted.integration.test.ts"
)

# Match the legacy literal in active code only:
#   - 'friend_requests' / "friend_requests"  (string literal)
#   - .friendRequests                         (property access)
#   - friendRequests:                         (object key)
# Ignore lines that begin with a comment marker (`//`, ` * `, `#`).
PATTERN="('friend_requests'|\"friend_requests\"|\.friendRequests\b|^[[:space:]]*friendRequests:)"

# grep -E exits 0 on hit, 1 on no-hit. Pipe through a comment-stripping
# filter so historical breadcrumbs (`// renamed from friend_requests in
# BUT-761`) don't trip the guard. The whole pipeline is wrapped in `if`
# so a no-hit (exit 1) doesn't tank set -e.
HITS=$(
  grep -REn --include='*.ts' --include='*.js' \
       --exclude-dir=node_modules --exclude-dir=lib \
       -E "$PATTERN" "$FUNCTIONS_DIR" 2>/dev/null \
    | grep -vE "^[^:]+:[0-9]+:[[:space:]]*(//|\*)" \
    || true
)

# Drop the erasure-only lines: allowlisted file AND an explicit marker.
REMAINING=""
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  file="${hit%%:*}"
  rel="${file#"$FUNCTIONS_DIR/"}"
  allowed=0
  for a in "${ALLOWED_FILES[@]}"; do
    if [[ "$rel" == "$a" && "$hit" == *"LEGACY-SWEEP-OK"* ]]; then
      allowed=1
      break
    fi
  done
  if [[ $allowed -eq 0 ]]; then
    REMAINING+="$hit"$'\n'
  fi
done <<< "$HITS"

REMAINING="$(printf '%s' "$REMAINING" | sed '/^$/d')"

if [[ -n "$REMAINING" ]]; then
  echo "::error::Legacy 'friend_requests' / 'friendRequests' references found in functions/src/" >&2
  echo "Use 'social_requests' / 'Collections.socialRequests' instead. See BUT-772 / BUT-761." >&2
  echo "An ERASURE-only reference (BUT-2044) needs both an ALLOWED_FILES entry in" >&2
  echo "tools/check_no_friend_requests_refs.sh and a 'LEGACY-SWEEP-OK' marker on the line." >&2
  echo >&2
  echo "$REMAINING" >&2
  exit 1
fi

echo "OK: no active-code friend_requests / friendRequests refs in functions/src/"
