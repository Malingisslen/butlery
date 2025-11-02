#!/bin/bash
# Enhanced Skill Activation Hook - Auto-activate relevant skills based on user prompt and file context
# Hook Type: UserPromptSubmit (non-blocking)
# Purpose: Analyze prompt and recent file changes to inject relevant skill context

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the user prompt from stdin or argument
USER_PROMPT="${1:-$(cat)}"

# Paths (convert to Windows format for Python on Windows)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$CLAUDE_DIR/skills"
SKILL_RULES="$CLAUDE_DIR/skill-rules.json"

# Convert /c/ paths to C:/ for Python on Windows
if [[ "$SKILL_RULES" == /[a-z]/* ]]; then
  SKILL_RULES_WIN=$(echo "$SKILL_RULES" | sed 's|^/\([a-z]\)/|\U\1:/|')
else
  SKILL_RULES_WIN="$SKILL_RULES"
fi

# Check if skill rules exist
if [ ! -f "$SKILL_RULES" ]; then
  echo -e "${YELLOW}⚠ Skill rules not found at $SKILL_RULES${NC}" >&2
  exit 0
fi

# Detect Python command (cross-platform)
PYTHON_CMD=""
if command -v python3 &> /dev/null; then
  PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
  PYTHON_CMD="python"
elif command -v py &> /dev/null; then
  PYTHON_CMD="py"
else
  # Try Windows py launcher through cmd.exe
  if cmd.exe /c "py --version" &> /dev/null; then
    PYTHON_CMD="cmd.exe /c py"
  fi
fi

if [ -z "$PYTHON_CMD" ]; then
  echo -e "${YELLOW}⚠ Python not found - skill activation disabled${NC}" >&2
  exit 0
fi

# Get recently modified files (from git if in a repo)
MODIFIED_FILES=""
if git rev-parse --git-dir > /dev/null 2>&1; then
  MODIFIED_FILES=$(git diff --name-only HEAD 2>/dev/null || echo "")
fi

# Use Python to parse skill-rules.json and match skills
ACTIVATED_SKILLS=$($PYTHON_CMD - <<EOF
import json
import re
import sys

# Load skill rules
try:
    with open("$SKILL_RULES_WIN", "r", encoding="utf-8") as f:
        skill_rules = json.load(f)
except Exception as e:
    print(f"Error loading skill rules: {e}", file=sys.stderr)
    sys.exit(0)

# User prompt and modified files
user_prompt = """$USER_PROMPT"""
modified_files = """$MODIFIED_FILES"""

prompt_lower = user_prompt.lower()
activated = []

# Check each skill
for skill_name, rules in skill_rules.items():
    skill_matched = False
    match_reasons = []

    # Priority for ordering
    priority = rules.get("priority", "medium")
    priority_weight = {"critical": 3, "high": 2, "medium": 1}.get(priority, 1)

    # Check prompt triggers
    if "promptTriggers" in rules:
        # Check keywords
        if "keywords" in rules["promptTriggers"]:
            for keyword in rules["promptTriggers"]["keywords"]:
                if keyword.lower() in prompt_lower:
                    skill_matched = True
                    match_reasons.append(f"keyword:{keyword}")
                    break

        # Check intent patterns
        if not skill_matched and "intentPatterns" in rules["promptTriggers"]:
            for pattern in rules["promptTriggers"]["intentPatterns"]:
                try:
                    if re.search(pattern, prompt_lower):
                        skill_matched = True
                        match_reasons.append(f"intent:{pattern}")
                        break
                except re.error:
                    pass

    # Check file triggers (if files were modified)
    if not skill_matched and modified_files and "fileTriggers" in rules:
        if "pathPatterns" in rules["fileTriggers"]:
            for path_pattern in rules["fileTriggers"]["pathPatterns"]:
                # Convert glob pattern to regex
                regex_pattern = path_pattern.replace("**", ".*").replace("*", "[^/]*").replace("?", ".")
                for file_path in modified_files.split("\n"):
                    if file_path and re.match(regex_pattern, file_path):
                        skill_matched = True
                        match_reasons.append(f"file:{file_path}")
                        break
                if skill_matched:
                    break

    if skill_matched:
        activated.append({
            "name": skill_name,
            "priority": priority,
            "priority_weight": priority_weight,
            "reasons": match_reasons,
            "enforcement": rules.get("enforcement", "suggest")
        })

# Sort by priority (critical first)
activated.sort(key=lambda x: (-x["priority_weight"], x["name"]))

# Output as JSON for bash to parse
import json
print(json.dumps(activated))
EOF
)

# Parse Python output
if [ -z "$ACTIVATED_SKILLS" ] || [ "$ACTIVATED_SKILLS" = "[]" ]; then
  echo -e "${CYAN}ℹ No skills activated for this prompt${NC}" >&2
  exit 0
fi

# Parse activated skills and output skill activation message for Claude
echo "" >&2
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}" >&2
echo -e "${GREEN}📚 SKILL ACTIVATION DETECTED${NC}" >&2
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}" >&2
echo "" >&2

# Count skills
SKILL_COUNT=$(echo "$ACTIVATED_SKILLS" | $PYTHON_CMD -c "import sys, json; print(len(json.load(sys.stdin)))")

echo -e "${CYAN}Found ${SKILL_COUNT} relevant skill(s) for this request:${NC}" >&2
echo "" >&2

# Output to Claude (stdout - this becomes part of the conversation)
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 SKILL ACTIVATION - Butlery Architecture Patterns"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "The following Butlery architecture skills are relevant to this request:"
echo ""

# Parse and display each skill with Python (UTF-8 safe)
$PYTHON_CMD - <<EOF
import json
import sys
import io

# Force UTF-8 output (Windows compatibility)
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

activated = json.loads('''$ACTIVATED_SKILLS''')

for idx, skill in enumerate(activated, 1):
    name = skill["name"]
    priority = skill["priority"]
    enforcement = skill["enforcement"]
    reasons = skill["reasons"][:2]  # Show first 2 reasons

    # Priority markers (ASCII-safe for Windows)
    priority_marker = {"critical": "[!]", "high": "[*]", "medium": "[-]"}.get(priority, "[ ]")

    # Enforcement text
    enforcement_text = {"enforce": "REQUIRED", "suggest": "RECOMMENDED"}.get(enforcement, "OPTIONAL")

    print(f"{idx}. {priority_marker} **{name}** [{priority.upper()} - {enforcement_text}]")
    print(f"   Location: .claude/skills/{name}/SKILL.md")

    if reasons:
        reason_text = ", ".join(reasons)
        print(f"   Matched: {reason_text}")

    print()
EOF

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📖 INSTRUCTIONS:"
echo ""
echo "Before responding, please READ the above skill files to ensure your answer"
echo "follows Butlery's established architecture patterns and best practices."
echo ""
echo "Use the patterns, examples, and guidelines from these skills in your response."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Also output to stderr for user visibility
echo -e "${GREEN}✓ Skills activated and injected into conversation context${NC}" >&2
echo "" >&2

# Show skill list in stderr
$PYTHON_CMD - >&2 <<EOF
import json
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
activated = json.loads('''$ACTIVATED_SKILLS''')
for skill in activated:
    print(f"  - {skill['name']} ({skill['priority']})")
EOF

echo "" >&2
echo -e "${CYAN}Tip: Claude will now read these skills before responding${NC}" >&2
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}" >&2
echo "" >&2

# Exit with 0 (non-blocking)
exit 0
