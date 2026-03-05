#!/usr/bin/env bash
# PreToolUse Bash firewall: blocks destructive commands not caught by the deny list.
# Provides clear error messages so Claude can adjust its approach.

set -euo pipefail

# Cross-platform Python detection
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "python3")

# Read tool input from stdin and extract the command
INPUT=$(cat)
COMMAND=$($PYTHON -c "
import json, sys
data = json.loads(sys.stdin.read())
print(data.get('tool_input', {}).get('command', ''))
" <<< "$INPUT" 2>/dev/null || echo "")

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Check against dangerous patterns
BLOCKED=""

# git clean with force flag
if echo "$COMMAND" | grep -qE 'git\s+clean\s+.*-[a-zA-Z]*f'; then
  BLOCKED="git clean -f deletes untracked files permanently"
fi

# git checkout . or git checkout -- . (discard all changes)
if echo "$COMMAND" | grep -qE 'git\s+checkout\s+(--\s+)?\.'; then
  BLOCKED="git checkout . discards all unstaged changes"
fi

# git restore . (discard all changes)
if echo "$COMMAND" | grep -qE 'git\s+restore\s+\.'; then
  BLOCKED="git restore . discards all unstaged changes"
fi

# git reset --hard (destroys uncommitted work)
if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
  BLOCKED="git reset --hard destroys all uncommitted work"
fi

# rm -rf on home, root, or current directory
if echo "$COMMAND" | grep -qE 'rm\s+-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*\s+(~/|/\s|/\*|\./\s|\.\*)'; then
  BLOCKED="rm -rf on home/root/current directory"
fi

# Force push to any branch (not just main/master which deny list catches)
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*(-f|--force)\b'; then
  BLOCKED="git push --force can overwrite remote history"
fi

if [ -n "$BLOCKED" ]; then
  echo "{\"decision\":\"block\",\"reason\":\"SAFETY: $BLOCKED. Run git status first and ask the user before proceeding.\"}"
  exit 0
fi

exit 0
