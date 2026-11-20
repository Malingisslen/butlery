"""Parse Claude Code hook stdin JSON, handling Windows backslash corruption.

Windows paths (e.g. with backslashes) contain unescaped backslashes that
break json.loads(). This module provides safe extraction of fields.

Usage from bash:
  SESSION_ID=$(echo "$INPUT" | py -3 .claude/hooks/parse_hook_json.py session_id)
  FILE_PATH=$(echo "$INPUT" | py -3 .claude/hooks/parse_hook_json.py tool_input.file_path)
"""
import json
import re
import sys


def extract_field(raw, field_path):
    """Extract a field from JSON with regex fallback for corrupted input."""
    # Try normal JSON parse first
    try:
        data = json.loads(raw)
        obj = data
        for key in field_path.split('.'):
            if isinstance(obj, dict):
                obj = obj.get(key, '')
            else:
                return ''
        return obj if isinstance(obj, str) else ''
    except (json.JSONDecodeError, ValueError):
        pass

    # Fallback: regex extraction for simple string fields
    # Only works for top-level or one-level nested keys
    parts = field_path.split('.')
    if len(parts) == 1:
        m = re.search(r'"' + re.escape(parts[0]) + r'"\s*:\s*"([^"]*)"', raw)
        return m.group(1) if m else ''
    elif len(parts) == 2:
        # Find the outer object, then the inner key
        # e.g., "tool_input":{"file_path":"..."}
        pattern = r'"' + re.escape(parts[0]) + r'"\s*:\s*\{[^}]*"' + re.escape(parts[1]) + r'"\s*:\s*"([^"]*)"'
        m = re.search(pattern, raw)
        return m.group(1) if m else ''

    return ''


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('')
        sys.exit(0)

    raw = sys.stdin.read()
    fields = sys.argv[1:]

    # Output each requested field on its own line
    for field in fields:
        print(extract_field(raw, field))
