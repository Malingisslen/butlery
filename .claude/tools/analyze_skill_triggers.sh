#!/bin/bash
# Skill Trigger Analysis Tool
# Analyzes prompt logs to identify false positives, collisions, and unused skills

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
LOG_DIR=".claude/cache/prompt-logs"
OUTPUT_DIR=".claude/analysis"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
REPORT_FILE="$OUTPUT_DIR/skill_trigger_analysis_$TIMESTAMP.md"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     SKILL TRIGGER ANALYSIS TOOL${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed. Please install jq to run this script.${NC}"
    exit 1
fi

# Check if log directory exists
if [ ! -d "$LOG_DIR" ]; then
    echo -e "${RED}Error: Log directory not found: $LOG_DIR${NC}"
    exit 1
fi

# Count log files
LOG_FILES=($LOG_DIR/*.jsonl)
if [ ${#LOG_FILES[@]} -eq 0 ]; then
    echo -e "${RED}Error: No .jsonl files found in $LOG_DIR${NC}"
    exit 1
fi

echo -e "${BLUE}Found ${#LOG_FILES[@]} log file(s)${NC}"
echo ""

# Initialize report
cat > "$REPORT_FILE" <<EOF
# Skill Trigger Analysis Report

**Generated**: $(date +"%Y-%m-%d %H:%M:%S")
**Log Files**: ${#LOG_FILES[@]} files
**Analysis Tool**: analyze_skill_triggers.sh

---

EOF

# Analysis 1: Activation Count Per Skill
echo -e "${YELLOW}[1/6] Counting activations per skill...${NC}"

cat >> "$REPORT_FILE" <<EOF
## 1. Skill Activation Summary

EOF

# Combine all logs and count activations
cat $LOG_DIR/*.jsonl | jq -r '.activatedSkills[]?.skillName' 2>/dev/null | \
    sort | uniq -c | sort -rn | \
    awk '{print "| " $2 " | " $1 " |"}' > /tmp/skill_counts.txt

# Add table header
echo "| Skill Name | Activation Count |" >> "$REPORT_FILE"
echo "|------------|------------------|" >> "$REPORT_FILE"
cat /tmp/skill_counts.txt >> "$REPORT_FILE"

# Get total count
TOTAL_ACTIVATIONS=$(cat $LOG_DIR/*.jsonl | jq -r '.activatedSkills[]?.skillName' 2>/dev/null | wc -l)
TOTAL_PROMPTS=$(cat $LOG_DIR/*.jsonl | wc -l)

cat >> "$REPORT_FILE" <<EOF

**Total Activations**: $TOTAL_ACTIVATIONS
**Total Prompts**: $TOTAL_PROMPTS
**Average Activations per Prompt**: $(echo "scale=2; $TOTAL_ACTIVATIONS / $TOTAL_PROMPTS" | bc)

EOF

echo -e "${GREEN}✓ Activation counts calculated${NC}"

# Analysis 2: Keyword Collision Detection
echo -e "${YELLOW}[2/6] Detecting keyword collisions...${NC}"

cat >> "$REPORT_FILE" <<EOF
---

## 2. Keyword Collision Analysis

Keywords that appear in multiple skills:

EOF

# Extract all keywords from each skill
declare -A KEYWORD_SKILLS

cat $LOG_DIR/*.jsonl | jq -r '.activatedSkills[] | "\(.skillName)|\(.matchReason[]?.pattern)"' 2>/dev/null | \
    grep -v "null" | while IFS='|' read skill keyword; do
    echo "$keyword|$skill"
done | sort | uniq > /tmp/keyword_skill_map.txt

# Find keywords used by multiple skills
cat /tmp/keyword_skill_map.txt | cut -d'|' -f1 | sort | uniq -d > /tmp/collision_keywords.txt

if [ -s /tmp/collision_keywords.txt ]; then
    while read keyword; do
        SKILLS=$(grep "^$keyword|" /tmp/keyword_skill_map.txt | cut -d'|' -f2 | sort | uniq | tr '\n' ', ' | sed 's/,$//')
        COUNT=$(grep "^$keyword|" /tmp/keyword_skill_map.txt | cut -d'|' -f2 | sort | uniq | wc -l)
        echo "| \`$keyword\` | $COUNT | $SKILLS |" >> "$REPORT_FILE"
    done < /tmp/collision_keywords.txt

    echo "" >> "$REPORT_FILE"
    COLLISION_COUNT=$(wc -l < /tmp/collision_keywords.txt)
    echo -e "${RED}⚠ Found $COLLISION_COUNT keyword collisions${NC}"
else
    echo "No keyword collisions detected." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo -e "${GREEN}✓ No collisions found${NC}"
fi

# Analysis 3: Generic Single-Word Keyword Detection
echo -e "${YELLOW}[3/6] Identifying generic single-word keywords...${NC}"

cat >> "$REPORT_FILE" <<EOF
---

## 3. Generic Single-Word Keywords

Single-word keywords that may cause false positives:

| Keyword | Skill | Activation Count | Risk Level |
|---------|-------|------------------|------------|
EOF

# Extract all single-word keywords (no spaces)
cat $LOG_DIR/*.jsonl | jq -r '.activatedSkills[] | "\(.skillName)|\(.matchReason[]? | select(.type == "keyword") | .pattern)"' 2>/dev/null | \
    grep -v "null" | grep -v " " | while IFS='|' read skill keyword; do
    COUNT=$(cat $LOG_DIR/*.jsonl | jq -r ".activatedSkills[] | select(.skillName == \"$skill\") | .matchReason[]? | select(.pattern == \"$keyword\") | .pattern" 2>/dev/null | wc -l)

    # Determine risk level based on keyword genericness
    RISK="LOW"
    case "$keyword" in
        test|check|data|save|remove|show|display|loading|ensure|verify|investigate|fetch|retrieve|service|repository)
            RISK="HIGH"
            ;;
        create|update|delete|get|set|add|list)
            RISK="MEDIUM"
            ;;
    esac

    echo "| \`$keyword\` | $skill | $COUNT | $RISK |"
done | sort -t'|' -k4 -r >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo -e "${GREEN}✓ Generic keywords identified${NC}"

# Analysis 4: Unused Skills
echo -e "${YELLOW}[4/6] Finding unused skills...${NC}"

cat >> "$REPORT_FILE" <<EOF
---

## 4. Unused Skills

Skills that never activated in the logs:

EOF

# All known skills (from the research)
ALL_SKILLS="butlery-architecture code-deduplication-utilities dependency-injection-patterns firebase-repository-patterns flutter-widget-guidelines gdpr-compliance navigation-routing offline-first-patterns performance-optimization realtime-collaboration skill-developer state-management-patterns testing-patterns"

UNUSED_FOUND=false
for skill in $ALL_SKILLS; do
    COUNT=$(cat $LOG_DIR/*.jsonl | jq -r ".activatedSkills[]? | select(.skillName == \"$skill\") | .skillName" 2>/dev/null | wc -l)
    if [ "$COUNT" -eq 0 ]; then
        echo "- \`$skill\` (0 activations)" >> "$REPORT_FILE"
        UNUSED_FOUND=true
    fi
done

if [ "$UNUSED_FOUND" = false ]; then
    echo "All skills have been activated at least once." >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo -e "${GREEN}✓ Unused skills identified${NC}"

# Analysis 5: Over-Triggering Prompts
echo -e "${YELLOW}[5/6] Finding prompts that triggered 3+ skills...${NC}"

cat >> "$REPORT_FILE" <<EOF
---

## 5. Over-Triggering Prompts

Prompts that activated 3 or more skills (potential false positives):

EOF

cat $LOG_DIR/*.jsonl | jq -r 'select(.activatedSkills | length >= 3) | "**Prompt**: \"\(.prompt.text)\"\n- **Skills**: \(.activatedSkills | map(.skillName) | join(", "))\n- **Count**: \(.activatedSkills | length)\n"' 2>/dev/null >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo -e "${GREEN}✓ Over-triggering prompts identified${NC}"

# Analysis 6: False Positive Candidates
echo -e "${YELLOW}[6/6] Extracting false positive candidates...${NC}"

cat >> "$REPORT_FILE" <<EOF
---

## 6. False Positive Candidates

Prompts where generic keywords matched (sample of 20):

EOF

# Sample prompts that matched generic keywords
GENERIC_KEYWORDS="test|check|data|save|remove|show|display|loading"

cat $LOG_DIR/*.jsonl | jq -r --arg keywords "$GENERIC_KEYWORDS" \
    'select(.activatedSkills[]?.matchReason[]? | select(.type == "keyword") | .pattern | test($keywords)) |
     "**Prompt**: \"\(.prompt.text)\"\n- **Matched Keyword**: \(.activatedSkills[0].matchReason[0].pattern)\n- **Skill**: \(.activatedSkills[0].skillName)\n"' 2>/dev/null | \
    head -n 60 >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo -e "${GREEN}✓ False positive candidates extracted${NC}"

# Summary
cat >> "$REPORT_FILE" <<EOF
---

## Summary

- **Total Prompts Analyzed**: $TOTAL_PROMPTS
- **Total Skill Activations**: $TOTAL_ACTIVATIONS
- **Average Skills per Prompt**: $(echo "scale=2; $TOTAL_ACTIVATIONS / $TOTAL_PROMPTS" | bc)

### Recommendations

1. **Resolve Keyword Collisions**: Review Section 2 for keywords appearing in multiple skills
2. **Replace Generic Keywords**: Review Section 3 for high-risk single-word triggers
3. **Investigate Unused Skills**: Review Section 4 for skills that may need better triggers or removal
4. **Fix Over-Triggering**: Review Section 5 for prompts activating too many skills
5. **Validate False Positives**: Review Section 6 for potentially irrelevant activations

---

**Next Steps**: Use this report to optimize \`.claude/skill-rules.json\`

EOF

# Cleanup
rm -f /tmp/skill_counts.txt /tmp/keyword_skill_map.txt /tmp/collision_keywords.txt

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Analysis complete!${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Report saved to: ${MAGENTA}$REPORT_FILE${NC}"
echo ""
