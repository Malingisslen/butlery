---
name: optimize-triggers
description: Analyze skill triggers and optimize if needed (autonomous decision-making)
---

# Skill Trigger Analysis & Optimization

**Autonomous workflow**: This command analyzes the skill trigger system and decides whether optimization is needed.

## Your Task

### Phase 1: Analysis

1. **Run Analysis Tools**:
   ```bash
   python .claude/tools/analyze_skill_triggers.py
   python .claude/tools/calculate_trigger_precision.py
   ```

2. **Review Generated Reports**:
   - Read the latest reports in `.claude/analysis/`
   - Extract key metrics:
     - Number of keyword collisions
     - Number of high-risk generic keywords
     - Over-trigger rate (% of prompts with 4+ skills)
     - Keyword vs Intent pattern ratio
     - Unused skills

### Phase 2: Decision Criteria

**Optimization is NEEDED if ANY of these conditions are met:**

| Condition | Threshold | Action Required |
|-----------|-----------|-----------------|
| Keyword collisions | ≥ 1 | Resolve collisions |
| High-risk generic keywords | ≥ 3 | Replace with multi-word terms |
| Over-trigger rate | ≥ 10% | Tighten triggers |
| Keyword dominance | ≥ 95% | Add intent patterns |
| Unused skills | ≥ 2 | Review trigger relevance |

**Optimization is NOT NEEDED if ALL of these are true:**
- Zero keyword collisions
- < 3 high-risk generic keywords
- Over-trigger rate < 10%
- Keyword ratio < 95%
- ≤ 1 unused skill

### Phase 3A: If Optimization Needed

1. **Create Optimization Plan**:
   - List specific issues found
   - Propose fixes for each issue
   - Estimate impact

2. **Present Plan to User**:
   ```
   ## Issues Found
   - [X] keyword collisions
   - [X] high-risk generic keywords
   - Over-trigger rate: X%

   ## Proposed Optimizations
   1. [Specific fix 1]
   2. [Specific fix 2]
   ...

   Do you want me to apply these optimizations? (yes/no)
   ```

3. **If User Approves**:
   - Update `.claude/skill-rules.json`
   - Validate JSON syntax
   - Create detailed optimization report
   - Save in `.claude/analysis/SKILL_TRIGGER_OPTIMIZATION_REPORT_[timestamp].md`

4. **If User Declines**:
   - Save analysis report only
   - Exit with recommendations for manual review

### Phase 3B: If Optimization NOT Needed

**Report Status**:
```
✅ Skill Trigger System: Healthy

Metrics:
- Keyword collisions: 0
- Generic keywords: [X] (target: <3)
- Over-trigger rate: [X]% (target: <10%)
- Intent pattern usage: [X]% (target: >5%)

No optimization needed at this time.

Next recommended analysis: [1 month from now]
```

## Critical Rules

**NEVER** modify `.claude/skill-rules.json` without explicit user approval
**ALWAYS** validate JSON after modifications
**ALWAYS** create a detailed report of what was changed
**ALWAYS** follow the methodology in `.claude/SKILL_TRIGGER_ANALYSIS_GUIDE.md`

## Decision Framework

Use this logic to autonomously decide:

```python
if (collisions > 0 or
    high_risk_keywords >= 3 or
    over_trigger_rate >= 10 or
    keyword_ratio >= 95):
    # Optimization needed
    present_plan_and_ask_for_approval()
else:
    # System is healthy
    report_status_and_exit()
```

## Success Criteria

After optimization (if performed):
- ✅ Zero keyword collisions
- ✅ Zero high-risk generic keywords
- ✅ Over-trigger rate < 10%
- ✅ Intent patterns > 5% of matches
- ✅ All JSON valid
- ✅ Detailed report generated

---

**Remember**: Be autonomous in analysis and decision-making, but ALWAYS ask before making changes to `.claude/skill-rules.json`.
