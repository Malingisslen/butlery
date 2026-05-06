#!/usr/bin/env bash
# PreToolUse Bash hook — block git commits that contain real secrets.
#
# Scans the staged diff for known secret shapes:
#   - Google / Firebase API keys (AIza...)
#   - OpenAI keys (sk-...)
#   - Anthropic keys (sk-ant-...)
#   - Stripe live keys (sk_live_..., pk_live_..., rk_live_...)
#   - AWS access keys (AKIA...)
#   - JWT bearer tokens (eyJ...)
#   - Generic high-entropy assignments to *_API_KEY / *_SECRET / *_TOKEN /
#     *_PASSWORD that aren't placeholder values
#
# Hard-blocks (exit 2) on match. PreToolUse exit 2 cancels the tool call
# AND surfaces stderr to the model — so Claude sees why and can fix the
# commit (e.g. unstage the leaking file) instead of retrying blindly.
#
# Why hard-block instead of soft warn: a leaked Vertex / Firebase key on
# this project means uncapped billing exposure on a solo-dev account.

set -euo pipefail

JSON=$(cat)

# Only act on Bash tool calls (PreToolUse Bash matcher should already filter,
# but defensive)
COMMAND=$(printf '%s' "$JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print(d.get('tool_input',{}).get('command',''))
" 2>/dev/null || true)

[[ -z "${COMMAND:-}" ]] && exit 0

# Only intercept git-commit calls (not log, not status, not diff)
case "$COMMAND" in
  *"git commit"*) : ;;
  *) exit 0 ;;
esac

# Need to be inside a git repo
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Get staged diff. -U0 = no context lines (cuts noise), -- excludes pathspec.
DIFF=$(git diff --cached -U0 2>/dev/null || true)
[[ -z "$DIFF" ]] && exit 0

# Filter: only added lines (start with '+', not '+++'). Strip the leading '+'.
ADDED=$(printf '%s\n' "$DIFF" | grep -E '^\+[^+]' | sed 's/^+//' || true)
[[ -z "$ADDED" ]] && exit 0

# Patterns. Each is "name|regex".
PATTERNS=(
  "Google/Firebase API key|AIza[0-9A-Za-z_-]{35}"
  "OpenAI key|sk-[A-Za-z0-9]{20,}"
  "Anthropic key|sk-ant-[A-Za-z0-9_-]{20,}"
  "Stripe live secret|sk_live_[A-Za-z0-9]{24,}"
  "Stripe live publishable|pk_live_[A-Za-z0-9]{24,}"
  "Stripe live restricted|rk_live_[A-Za-z0-9]{24,}"
  "AWS access key id|AKIA[0-9A-Z]{16}"
  "Slack token|xox[abprs]-[A-Za-z0-9-]{10,}"
  "GitHub PAT (classic)|ghp_[A-Za-z0-9]{30,}"
  "GitHub PAT (fine-grained)|github_pat_[A-Za-z0-9_]{40,}"
  "JWT bearer token|eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}"
  "Private key block|-----BEGIN ((RSA|EC|OPENSSH|PGP) )?PRIVATE KEY-----"
)

# Placeholder values to ignore (template / example markers)
PLACEHOLDER_RX='YOUR_|EXAMPLE_|REPLACE_ME|XXXX|placeholder|dummy|FAKE_|test_key|sample-|<.*>|TEST_'

VIOLATIONS=()

for p in "${PATTERNS[@]}"; do
  NAME="${p%%|*}"
  RX="${p#*|}"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Skip if the matched line is clearly a placeholder
    if printf '%s' "$line" | grep -qE "$PLACEHOLDER_RX"; then
      continue
    fi
    VIOLATIONS+=("$NAME: $(printf '%s' "$line" | head -c 120)")
  done < <(printf '%s\n' "$ADDED" | grep -EI "$RX" 2>/dev/null || true)
done

# Generic high-entropy assignments to known sensitive var names.
# Catches Vertex, custom APIs, anything not on the explicit list above.
while IFS= read -r line; do
  # Strip variable name + operator to inspect the value.
  VALUE=$(printf '%s' "$line" | sed -E 's/^[^=:]*[=:]\s*//; s/^[\x27"]//; s/[\x27"]\s*[;,]?\s*$//')
  # Skip placeholders
  printf '%s' "$VALUE" | grep -qE "$PLACEHOLDER_RX" && continue
  # Skip empty / very short
  [[ ${#VALUE} -lt 20 ]] && continue
  # Require some entropy: at least one digit AND one letter, mostly base64-ish chars
  if printf '%s' "$VALUE" | grep -qE '^[A-Za-z0-9+/=_.-]{20,}$' \
     && printf '%s' "$VALUE" | grep -qE '[0-9]' \
     && printf '%s' "$VALUE" | grep -qE '[A-Za-z]'; then
    VIOLATIONS+=("Sensitive assignment: $(printf '%s' "$line" | head -c 120)")
  fi
done < <(printf '%s\n' "$ADDED" | grep -EI '(API_KEY|APIKEY|SECRET|TOKEN|PASSWORD|PRIVATE_KEY)\s*[=:]' || true)

if [[ ${#VIOLATIONS[@]} -eq 0 ]]; then
  exit 0
fi

# Block. Exit 2 = PreToolUse blocking exit; stderr is shown to Claude.
{
  echo "🛑 secret-scan-precommit BLOCKED the commit — staged diff appears to contain secrets:"
  echo ""
  for v in "${VIOLATIONS[@]}"; do
    echo "   • $v"
  done
  echo ""
  echo "Next steps:"
  echo "  1. Identify which file is leaking: git diff --cached --name-only"
  echo "  2. If a real secret got staged: git restore --staged <file> AND rotate the key."
  echo "  3. If it's a false positive (test fixture, mock, README example):"
  echo "     replace the value with a placeholder containing 'YOUR_', 'EXAMPLE_',"
  echo "     'TEST_', 'FAKE_', '<placeholder>', 'dummy', or 'XXXX'."
  echo "  4. If you genuinely need to commit this (rare): run the commit"
  echo "     manually outside Claude's Bash tool."
} >&2
exit 2
