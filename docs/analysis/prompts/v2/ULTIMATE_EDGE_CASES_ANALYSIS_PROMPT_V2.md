# ULTIMATE EDGE CASES & CHAOS ENGINEERING ANALYSIS PROMPT - V2 (FOLLOW-UP SESSION)

**Copy and paste this entire prompt to Claude to trigger a follow-up edge case investigation that compares with your previous session's findings.**

---

## Mission: Follow-Up Chaos Engineering Analysis with Progress Tracking

Perform a comprehensive edge case and chaos engineering analysis of the Butlery Flutter application AND compare your findings with the previous session's audit. This enables:

- **Resilience trending** - Is the app becoming more robust?
- **Fix validation** - Were critical edge cases addressed?
- **Regression detection** - Any new fragility introduced?
- **Data loss prevention progress** - Critical scenarios resolved?
- **Chaos readiness trajectory** - Moving toward production-grade?

This is a **comparative resilience audit** across 8 dimensions of chaos readiness.

---

## 📁 FILE PATHS - CRITICAL

| Purpose | Path |
|---------|------|
| **V2 Output (Write First)** | `c:\Butlery\butlery\docs\analysis\outputs\v2\EDGE_CASES_FINDINGS_V2.md` |
| **V1 Input (Read After)** | `c:\Butlery\butlery\docs\analysis\outputs\EDGE_CASES_FINDINGS.md` |

---

## ⚠️ CRITICAL: FOUR-PHASE APPROACH

This analysis follows a **strict four-phase approach** to prevent bias:

### 🚨 ANTI-BIAS RULE - READ THIS FIRST 🚨

**DO NOT read the V1 findings file until AFTER you have completed Phase 1 and written your independent findings to the V2 output file.**

Reading V1 first would bias your resilience assessment. You must form your own conclusions independently before comparing.

---

### PHASE 1: INDEPENDENT INVESTIGATION & DOCUMENTATION

**🚫 ABSOLUTELY NO CODE CHANGES ALLOWED**
**🚫 DO NOT READ V1 OUTPUT YET**

Your **ONLY** task is to:
1. **INVESTIGATE** - Test edge cases independently
2. **DOCUMENT** - Record every finding with file:line references
3. **CATEGORIZE** - Classify by data loss risk
4. **WRITE** - Save your complete findings to the V2 output file

**✅ COMPLETE PHASE 1 BY WRITING:**
Save your independent analysis to:
`c:\Butlery\butlery\docs\analysis\outputs\v2\EDGE_CASES_FINDINGS_V2.md`

---

### PHASE 2: READ V1 OUTPUT

**Only after Phase 1 is complete and V2 findings are written:**

1. **READ** the V1 findings from: `c:\Butlery\butlery\docs\analysis\outputs\EDGE_CASES_FINDINGS.md`
2. **NOTE** the previous session's date, scores, and risk counts
3. **PREPARE** for comparative analysis

---

### PHASE 3: COMPARATIVE ANALYSIS

Now compare your independent findings with the V1 report:
1. **COMPARE** findings with V1 report
2. **IDENTIFY** resolved edge cases (in V1 but not in your V2 findings)
3. **DETECT** new vulnerabilities (in your V2 findings but not in V1)
4. **TRACK** persistent issues (present in both V1 and V2)
5. **CALCULATE** resilience delta for each dimension
6. **UPDATE** your V2 output file with the comparison section

---

### PHASE 4: SMART REMEDIATION PLAN

**Only after Phases 1-3 are complete**, create the hardening plan.

---

## Analysis Framework: 8 Dimensions

### Dimension 1: Network Failure Scenarios (25%)
Compare network resilience with previous session. Track offline mode improvements.

### Dimension 2: Resource Constraint Scenarios (18%)
Compare resource handling improvements. Track memory/storage optimizations.

### Dimension 3: Concurrent Access & Race Conditions (15%)
Compare concurrency safety. Track race condition fixes.

### Dimension 4: Time-Based Edge Cases (12%)
Compare timezone/DST handling improvements.

### Dimension 5: App Lifecycle & State Transitions (12%)
Compare lifecycle robustness. Track state preservation fixes.

### Dimension 6: Input Validation Extremes (10%)
Compare input validation coverage. Track boundary case fixes.

### Dimension 7: Data Integrity Under Chaos (5%)
Compare data integrity improvements. Track corruption detection.

### Dimension 8: User Behavior Edge Cases (3%)
Compare user behavior handling. Track rapid action fixes.

---

## Output Format Required

### Executive Summary with Resilience Comparison

```
BUTLERY EDGE CASES & CHAOS ENGINEERING - V2 FOLLOW-UP SESSION
==============================================================
Analysis Date: [Date]
Previous Analysis Date: [Date from previous report]
Days Since Last Analysis: [X days]

RESILIENCE SCORE COMPARISON:
                              Previous    Current    Delta    Trend
──────────────────────────────────────────────────────────────────────
OVERALL RESILIENCE SCORE:     X/100       X/100      +/-X     ↑/↓/→
├─ Network Failure:           X/25        X/25       +/-X     ↑/↓/→
├─ Resource Constraints:      X/18        X/18       +/-X     ↑/↓/→
├─ Concurrent Access:         X/15        X/15       +/-X     ↑/↓/→
├─ Time-Based:                X/12        X/12       +/-X     ↑/↓/→
├─ App Lifecycle:             X/12        X/12       +/-X     ↑/↓/→
├─ Input Validation:          X/10        X/10       +/-X     ↑/↓/→
├─ Data Integrity:            X/5         X/5        +/-X     ↑/↓/→
└─ User Behavior:             X/3         X/3        +/-X     ↑/↓/→

DATA LOSS RISK COMPARISON:
              Previous    Current    Fixed    New    Status
────────────────────────────────────────────────────────────
CRITICAL:     X           X          X        X      ↑/↓/→
HIGH:         X           X          X        X      ↑/↓/→
MEDIUM:       X           X          X        X      ↑/↓/→
LOW:          X           X          X        X      ↑/↓/→

CHAOS READINESS: [Production Ready | Improving | Needs Work | Fragile]
RESILIENCE TRAJECTORY: [Strengthening | Stable | Weakening]
```

### Resilience Progress Report Section (NEW IN V2)

```markdown
## 🛡️ Resilience Progress Report: Changes Since Last Session

### ✅ RESOLVED EDGE CASES (X total)

Edge cases from the previous session that are now handled:

#### Critical Data Loss Scenarios Fixed (X)
1. **[Scenario Title]** - Previously at [Code Location]
   - Previous Risk: CRITICAL (data loss)
   - Resolution: [How it was fixed]
   - Test Coverage: [Test added? Y/N]
   - Verified: ✅

#### Network Resilience Improvements (X)
1. **[Scenario]**
   - Previous Behavior: [Description]
   - Current Behavior: [Description]
   - Improvement: [Specific change]

---

### 🆕 NEW EDGE CASES (X total)

Edge cases not present in the previous session:

#### New Critical Risks (X)
1. **[Edge Case Title]** - [Code Location]
   - Risk: CRITICAL
   - Scenario: [Description]
   - Likely Cause: [New feature, refactoring, etc.]
   - Data Loss Risk: [Assessment]

---

### ⏳ PERSISTENT EDGE CASES (X total)

Edge cases still unhandled from the previous session:

#### Persistent Critical Risks (X)
1. **[Edge Case Title]**
   - Days Unaddressed: [X days]
   - Data Loss Exposure: [X user-days of risk]
   - Reason Unresolved: [If known]
   - Risk Escalation: [Has risk increased?]

---

### 📊 Resilience Metrics Trending

| Scenario Category | Previous Pass % | Current Pass % | Change |
|-------------------|-----------------|----------------|--------|
| Network Loss During Save | X% | X% | +/-X% |
| Offline Mode | X% | X% | +/-X% |
| Multi-Device Sync | X% | X% | +/-X% |
| App Termination | X% | X% | +/-X% |
| Input Boundaries | X% | X% | +/-X% |

---

### 🎯 Recommendations Based on Progress

1. **Data Loss Prevention:** [Priority items]
2. **Network Resilience:** [Remaining work]
3. **User Experience:** [Edge cases affecting UX]
4. **Low-Hanging Fruit:** [Easy fixes remaining]
```

---

## Phase Deliverables Checklist

### Phase 1: Independent Investigation (Write V2 First)
- [ ] Network failure scenario testing
- [ ] Resource constraint assessment
- [ ] Concurrent access evaluation
- [ ] Lifecycle transition testing
- [ ] **WRITE to V2 output file BEFORE reading V1**

### Phase 2: Read V1 Output
- [ ] Read V1 findings from: `docs/analysis/outputs/EDGE_CASES_FINDINGS.md`
- [ ] Note previous session date and risk counts

### Phase 3: Comparative Analysis
- [ ] Resilience score comparison
- [ ] Data loss scenarios resolved/new/persistent
- [ ] Network resilience improvements
- [ ] Concurrency safety progress
- [ ] Input validation coverage changes
- [ ] Recommendations based on progress
- [ ] **UPDATE V2 output file with comparison section**

### Phase 4: Remediation Plan
- [ ] Prioritized edge case fixes
- [ ] Data loss prevention roadmap

---

## Success Criteria

**This follow-up edge case analysis is complete when:**

1. ✅ Current state fully investigated INDEPENDENTLY (all 8 dimensions)
2. ✅ **V2 findings written BEFORE reading V1**
3. ✅ V1 findings read AFTER V2 was written
4. ✅ Complete comparison performed
5. ✅ Data loss scenarios tracked and compared
6. ✅ Resolved edge cases verified
7. ✅ New vulnerabilities flagged
8. ✅ Persistent issues tracked with exposure time
9. ✅ Resilience trajectory determined
10. ✅ Recommendations prioritized by data loss risk
11. ✅ **ZERO code changes made**

---

## 🚀 BEGIN FOLLOW-UP EDGE CASE ANALYSIS NOW

**CRITICAL WORKFLOW:**
```
┌─────────────────────────────────────────────────────────────┐
│  PHASE 1: Investigate edge cases INDEPENDENTLY              │
│           ↓                                                  │
│           Write findings to outputs/v2/EDGE_CASES_...       │
│           ↓                                                  │
│  PHASE 2: NOW read outputs/EDGE_CASES_FINDINGS.md (V1)      │
│           ↓                                                  │
│  PHASE 3: Compare V2 vs V1, update V2 with comparison       │
│           ↓                                                  │
│  PHASE 4: Create remediation plan                           │
└─────────────────────────────────────────────────────────────┘
```

**CRITICAL REMINDERS:**
- 🚫 **DO NOT READ V1 UNTIL PHASE 2** - Prevents bias
- 🚫 **NO CODE CHANGES** - Investigation and comparison ONLY
- 📝 Write V2 findings first: `docs/analysis/outputs/v2/EDGE_CASES_FINDINGS_V2.md`
- 📖 Read V1 after: `docs/analysis/outputs/EDGE_CASES_FINDINGS.md`
- 🛡️ Focus on data loss prevention progress
- ✅ Complete all 4 phases in order

**Your Mission:**
Execute comprehensive INDEPENDENT chaos engineering investigation first, write your findings to V2 output, THEN read V1 and compare. Track data loss risk reduction toward production-grade robustness.

**This analysis ensures unbiased continuous resilience improvement.**
