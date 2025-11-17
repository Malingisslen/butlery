#!/bin/bash
# Trigger Precision Calculator
# Calculates effectiveness metrics for skill triggers

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
REPORT_FILE="$OUTPUT_DIR/trigger_precision_metrics_$TIMESTAMP.md"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     TRIGGER PRECISION CALCULATOR${NC}"
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

echo -e "${BLUE}Analyzing ${#LOG_FILES[@]} log file(s)...${NC}"
echo ""

# Initialize report
cat > "$REPORT_FILE" <<EOF
# Trigger Precision Metrics Report

**Generated**: $(date +"%Y-%m-%d %H:%M:%S")
**Log Files**: ${#LOG_FILES[@]} files
**Analysis Tool**: calculate_trigger_precision.sh

---

EOF

# Get totals
TOTAL_PROMPTS=$(cat $LOG_DIR/*.jsonl | wc -l)
TOTAL_ACTIVATIONS=$(cat $LOG_DIR/*.jsonl | jq -r '.activatedSkills[]?.skillName' 2>/dev/null | wc -l)
PROMPTS_WITH_ACTIVATIONS=$(cat $LOG_DIR/*.jsonl | jq -r 'select(.activatedSkills | length > 0) | .timestamp' 2>/dev/null | wc -l)
PROMPTS_WITHOUT_ACTIVATIONS=$((TOTAL_PROMPTS - PROMPTS_WITH_ACTIVATIONS))

cat >> "$REPORT_FILE" <<EOF
## Overall Metrics

| Metric | Value |
|--------|-------|
| Total Prompts | $TOTAL_PROMPTS |
| Total Activations | $TOTAL_ACTIVATIONS |
| Prompts with Skills | $PROMPTS_WITH_ACTIVATIONS |
| Prompts without Skills | $PROMPTS_WITHOUT_ACTIVATIONS |
| Average Skills per Prompt | $(printf "%.2f" $(echo "scale=2; $TOTAL_ACTIVATIONS / $TOTAL_PROMPTS" | bc)) |
| Activation Rate | $(printf "%.1f" $(echo "scale=1; $PROMPTS_WITH_ACTIVATIONS * 100 / $TOTAL_PROMPTS" | bc))% |

---

EOF

# Metric 1: Keyword Effectiveness
echo -e "${YELLOW}[1/5] Calculating keyword effectiveness...${NC}"

cat >> "$REPORT_FILE" <<EOF
## 1. Keyword Effectiveness

Top 20 most effective keywords (by activation count):

| Keyword | Skill | Activations | Match Type |
|---------|-------|-------------|------------|
EOF

# Extract all keyword matches with counts
cat $LOG_DIR/*.jsonl | jq -r '.activatedSkills[] | "\(.skillName)|\(.matchReason[]? | select(.type == "keyword") | .pattern)"' 2>/dev/null | \
    grep -v "null" | sort | uniq -c | sort -rn | head -n 20 | \
    awk '{print "| `" $3 "` | " $2 " | " $1 " | keyword |"}' >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo -e "${GREEN}✓ Keyword effectiveness calculated${NC}"

# Metric 2: Intent Pattern Effectiveness
echo -e "${YELLOW}[2/5] Calculating intent pattern effectiveness...${NC}"

cat >> "$REPORT_FILE" <<EOF
---

## 2. Intent Pattern Effectiveness

Top 20 most effective intent patterns (by activation count):

| Pattern | Skill | Activations | Match Type |
|---------|-------|-------------|------------|
EOF

# Extract all intent pattern matches with counts
cat $LOG_DIR/*.jsonl | jq -r '.activatedSkills[] | "\(.skillName)|\(.matchReason[]? | select(.type == "intent") | .pattern)"' 2>/dev/null | \
    grep -v "null" | sort | uniq -c | sort -rn | head -n 20 | \
    awk -F'|' '{print "| `" $2 "` | " $1 " | " substr($0, 1, index($0, "|")-1) " | intent |"}' | \
    sed 's/  */ /g' >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo -e "${GREEN}✓ Intent pattern effectiveness calculated${NC}"

# Metric 3: Per-Skill Performance
echo -e "${YELLOW}[3/5] Calculating per-skill performance metrics...${NC}"

cat >> "$REPORT_FILE" <<EOF
---

## 3. Per-Skill Performance

Detailed metrics for each skill:

| Skill | Total Activations | Keyword Matches | Intent Matches | Avg Triggers/Prompt |
|-------|-------------------|-----------------|----------------|---------------------|
EOF

# All known skills
ALL_SKILLS="butlery-architecture code-deduplication-utilities dependency-injection-patterns firebase-repository-patterns flutter-widget-guidelines gdpr-compliance navigation-routing offline-first-patterns performance-optimization realtime-collaboration skill-developer state-management-patterns testing-patterns"

for skill in $ALL_SKILLS; do
    TOTAL=$(cat $LOG_DIR/*.jsonl | jq -r ".activatedSkills[]? | select(.skillName == \"$skill\") | .skillName" 2>/dev/null | wc -l)

    if [ "$TOTAL" -gt 0 ]; then
        KEYWORD_COUNT=$(cat $LOG_DIR/*.jsonl | jq -r ".activatedSkills[]? | select(.skillName == \"$skill\") | .matchReason[]? | select(.type == \"keyword\") | .pattern" 2>/dev/null | wc -l)
        INTENT_COUNT=$(cat $LOG_DIR/*.jsonl | jq -r ".activatedSkills[]? | select(.skillName == \"$skill\") | .matchReason[]? | select(.type == \"intent\") | .pattern" 2>/dev/null | wc -l)
        AVG=$(printf "%.2f" $(echo "scale=2; $TOTAL / $TOTAL_PROMPTS" | bc))

        echo "| \`$skill\` | $TOTAL | $KEYWORD_COUNT | $INTENT_COUNT | $AVG |" >> "$REPORT_FILE"
    else
        echo "| \`$skill\` | 0 | 0 | 0 | 0.00 |" >> "$REPORT_FILE"
    fi
done

echo "" >> "$REPORT_FILE"
echo -e "${GREEN}✓ Per-skill performance calculated${NC}"

# Metric 4: Match Type Distribution
echo -e "${YELLOW}[4/5] Analyzing match type distribution...${NC}"

KEYWORD_MATCHES=$(cat $LOG_DIR/*.jsonl | jq -r '.activatedSkills[]? | .matchReason[]? | select(.type == "keyword") | .pattern' 2>/dev/null | wc -l)
INTENT_MATCHES=$(cat $LOG_DIR/*.jsonl | jq -r '.activatedSkills[]? | .matchReason[]? | select(.type == "intent") | .pattern' 2>/dev/null | wc -l)
TOTAL_MATCHES=$((KEYWORD_MATCHES + INTENT_MATCHES))

KEYWORD_PCT=0
INTENT_PCT=0
if [ "$TOTAL_MATCHES" -gt 0 ]; then
    KEYWORD_PCT=$(printf "%.1f" $(echo "scale=1; $KEYWORD_MATCHES * 100 / $TOTAL_MATCHES" | bc))
    INTENT_PCT=$(printf "%.1f" $(echo "scale=1; $INTENT_MATCHES * 100 / $TOTAL_MATCHES" | bc))
fi

cat >> "$REPORT_FILE" <<EOF
---

## 4. Match Type Distribution

| Match Type | Count | Percentage |
|------------|-------|------------|
| Keyword Matches | $KEYWORD_MATCHES | $KEYWORD_PCT% |
| Intent Pattern Matches | $INTENT_MATCHES | $INTENT_PCT% |
| **Total** | **$TOTAL_MATCHES** | **100%** |

**Insight**: $([ $KEYWORD_MATCHES -gt $INTENT_MATCHES ] && echo "Keywords are triggering more than intent patterns" || echo "Intent patterns are triggering more than keywords")

EOF

echo -e "${GREEN}✓ Match type distribution calculated${NC}"

# Metric 5: Activation Distribution
echo -e "${YELLOW}[5/5] Calculating activation distribution...${NC}"

PROMPTS_0_SKILLS=$(cat $LOG_DIR/*.jsonl | jq -r 'select(.activatedSkills | length == 0) | .timestamp' 2>/dev/null | wc -l)
PROMPTS_1_SKILL=$(cat $LOG_DIR/*.jsonl | jq -r 'select(.activatedSkills | length == 1) | .timestamp' 2>/dev/null | wc -l)
PROMPTS_2_SKILLS=$(cat $LOG_DIR/*.jsonl | jq -r 'select(.activatedSkills | length == 2) | .timestamp' 2>/dev/null | wc -l)
PROMPTS_3_SKILLS=$(cat $LOG_DIR/*.jsonl | jq -r 'select(.activatedSkills | length == 3) | .timestamp' 2>/dev/null | wc -l)
PROMPTS_4PLUS_SKILLS=$(cat $LOG_DIR/*.jsonl | jq -r 'select(.activatedSkills | length >= 4) | .timestamp' 2>/dev/null | wc -l)

PCT_0=$(printf "%.1f" $(echo "scale=1; $PROMPTS_0_SKILLS * 100 / $TOTAL_PROMPTS" | bc))
PCT_1=$(printf "%.1f" $(echo "scale=1; $PROMPTS_1_SKILL * 100 / $TOTAL_PROMPTS" | bc))
PCT_2=$(printf "%.1f" $(echo "scale=1; $PROMPTS_2_SKILLS * 100 / $TOTAL_PROMPTS" | bc))
PCT_3=$(printf "%.1f" $(echo "scale=1; $PROMPTS_3_SKILLS * 100 / $TOTAL_PROMPTS" | bc))
PCT_4PLUS=$(printf "%.1f" $(echo "scale=1; $PROMPTS_4PLUS_SKILLS * 100 / $TOTAL_PROMPTS" | bc))

cat >> "$REPORT_FILE" <<EOF
---

## 5. Activation Distribution

How many skills activate per prompt:

| Skills Activated | Prompt Count | Percentage | Status |
|------------------|--------------|------------|--------|
| 0 skills | $PROMPTS_0_SKILLS | $PCT_0% | ⚪ No match |
| 1 skill | $PROMPTS_1_SKILL | $PCT_1% | ✅ Ideal |
| 2 skills | $PROMPTS_2_SKILLS | $PCT_2% | ✅ Good |
| 3 skills | $PROMPTS_3_SKILLS | $PCT_3% | ⚠️ Moderate |
| 4+ skills | $PROMPTS_4PLUS_SKILLS | $PCT_4PLUS% | ❌ Over-triggering |

**Quality Score**: $([ $PROMPTS_4PLUS_SKILLS -gt $((TOTAL_PROMPTS / 10)) ] && echo "⚠️ Needs improvement (too many over-triggers)" || echo "✅ Good (low over-triggering rate)")

EOF

echo -e "${GREEN}✓ Activation distribution calculated${NC}"

# Summary and Recommendations
cat >> "$REPORT_FILE" <<EOF
---

## Summary & Recommendations

### Key Findings

1. **Overall Activation Rate**: $PROMPTS_WITH_ACTIVATIONS/$TOTAL_PROMPTS prompts triggered at least one skill ($(printf "%.1f" $(echo "scale=1; $PROMPTS_WITH_ACTIVATIONS * 100 / $TOTAL_PROMPTS" | bc))%)
2. **Match Type Balance**: Keywords ($KEYWORD_PCT%) vs Intent Patterns ($INTENT_PCT%)
3. **Over-Triggering**: $PROMPTS_4PLUS_SKILLS prompts activated 4+ skills ($PCT_4PLUS%)

### Recommendations

EOF

# Generate recommendations based on metrics
if [ "$PROMPTS_4PLUS_SKILLS" -gt "$((TOTAL_PROMPTS / 10))" ]; then
    echo "- ⚠️ **High Priority**: Reduce over-triggering by tightening generic keywords" >> "$REPORT_FILE"
fi

if [ "$KEYWORD_MATCHES" -gt "$((INTENT_MATCHES * 2))" ]; then
    echo "- ⚠️ **Consider**: Keywords dominating - may need more intent patterns for context" >> "$REPORT_FILE"
fi

if [ "$PROMPTS_0_SKILLS" -gt "$((TOTAL_PROMPTS / 3))" ]; then
    echo "- ℹ️ **Note**: High no-match rate - consider adding more triggers or accept as normal" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" <<EOF

### Target Metrics (Industry Best Practices)

- ✅ **Activation Rate**: 60-80% (current: $(printf "%.1f" $(echo "scale=1; $PROMPTS_WITH_ACTIVATIONS * 100 / $TOTAL_PROMPTS" | bc))%)
- ✅ **Avg Skills/Prompt**: 1-3 (current: $(printf "%.2f" $(echo "scale=2; $TOTAL_ACTIVATIONS / $TOTAL_PROMPTS" | bc)))
- ✅ **Over-Trigger Rate**: <10% (current: $PCT_4PLUS%)

---

**Next Steps**: Use these metrics to prioritize optimization efforts in \`.claude/skill-rules.json\`

EOF

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Precision calculation complete!${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Report saved to: ${MAGENTA}$REPORT_FILE${NC}"
echo ""
