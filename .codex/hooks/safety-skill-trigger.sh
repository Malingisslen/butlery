#!/usr/bin/env bash
# PostToolUse hook for Write|Edit: Triggers safety skill reminders
# based on the content of the .dart file that was just modified.

set -euo pipefail

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "python3")

INPUT=$(cat)

# Dispatcher fast path: post-edit-dispatch.sh already parsed the payload, so skip
# the interpreter spawn when it knows this is not a .dart file. The python guard
# below still runs on its own — this is a shortcut, not a replacement.
if [[ "${BUTLERY_HOOK_DISPATCH:-}" == "1" && "${BUTLERY_HOOK_FILE:-}" != *.dart ]]; then
  exit 0
fi

$PYTHON -c "
import json, sys, os

data = json.loads(sys.stdin.read())
file_path = (data.get('tool_input', {}).get('file_path', '')
             or data.get('tool_response', {}).get('filePath', ''))

if not file_path or not file_path.endswith('.dart'):
    sys.exit(0)

reminders = []

content = ''
try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        line_count = content.count('\n') + 1
except Exception:
    sys.exit(0)

# Data source enforcer
if 'UserService' in content or 'PermissionService' in content:
    reminders.append('SAFETY: This file uses UserService/PermissionService. Apply data-source-enforcer skill — never mix these data sources.')

# TriState validator
tri_signals = ['TriState', 'isGlutenFree', 'isDairyFree', 'tagResult',
               'allergenStatus', 'getAllergenStatus', 'isAllergenFree',
               'containsAllergen']
if any(s in content for s in tri_signals):
    reminders.append('SAFETY-CRITICAL: This file touches allergen/dietary TriState. Apply tri-state-validator skill — TriState must NEVER be treated as boolean.')

# Facade pattern detector
if line_count > 400:
    reminders.append(f'WARNING: File is {line_count} lines (limit: 500). Apply facade-pattern-detector skill — consider splitting.')

if not reminders:
    sys.exit(0)

print(json.dumps({'additionalContext': chr(10).join(reminders)}))
" <<< "$INPUT" 2>/dev/null || exit 0
