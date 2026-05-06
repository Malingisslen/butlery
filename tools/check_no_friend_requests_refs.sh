#!/usr/bin/env bash
# BUT-772: ensure functions/src/ never re-introduces the legacy
# `friend_requests` collection name in active code. The Firestore collection
# was renamed `friend_requests` -> `social_requests` in BUT-761; clients + rules
# migrated. Cloud-Functions code was migrated in BUT-772. Reintroducing the
# old name silently zero-results notification + cleanup jobs.
#
# Comment-only mentions (// , * , #) are allowed so historical breadcrumbs
# don't trip the guard.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNCTIONS_DIR="$ROOT_DIR/functions/src"

if [[ ! -d "$FUNCTIONS_DIR" ]]; then
  echo "::error::functions/src not found at $FUNCTIONS_DIR" >&2
  exit 2
fi

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

if [[ -n "$HITS" ]]; then
  echo "::error::Legacy 'friend_requests' / 'friendRequests' references found in functions/src/" >&2
  echo "Use 'social_requests' / 'Collections.socialRequests' instead. See BUT-772 / BUT-761." >&2
  echo >&2
  echo "$HITS" >&2
  exit 1
fi

echo "OK: no active-code friend_requests / friendRequests refs in functions/src/"
