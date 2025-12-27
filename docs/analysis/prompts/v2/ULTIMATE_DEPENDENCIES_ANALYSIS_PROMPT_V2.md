# ULTIMATE BUTLERY DEPENDENCIES & SUPPLY CHAIN SECURITY ANALYSIS PROMPT - V2 (FOLLOW-UP SESSION)

**Copy and paste this entire prompt to Claude to trigger a follow-up dependency investigation that compares with your previous session's findings.**

---

## Mission: Follow-Up Dependency Analysis with Progress Tracking

Perform a comprehensive dependency and supply chain security analysis of the Butlery Flutter application AND compare your findings with the previous session's audit. This enables:

- **Vulnerability trending** - Are CVEs being addressed?
- **Version currency tracking** - Are packages being updated?
- **License compliance progress** - Legal risks resolved?
- **Dependency bloat reduction** - Unused packages removed?
- **Supply chain security improvement** - Trust score trajectory

This is a **comparative supply chain security audit** across 7 critical dimensions.

---

## 📁 FILE PATHS - CRITICAL

| Purpose | Path |
|---------|------|
| **V2 Output (Write First)** | `c:\Butlery\butlery\docs\analysis\outputs\v2\DEPENDENCY_SECURITY_FINDINGS_V2.md` |
| **V1 Input (Read After)** | `c:\Butlery\butlery\docs\analysis\outputs\DEPENDENCY_SECURITY_FINDINGS.md` |

---

## ⚠️ CRITICAL: FOUR-PHASE APPROACH

This analysis follows a **strict four-phase approach** to prevent bias:

### 🚨 ANTI-BIAS RULE - READ THIS FIRST 🚨

**DO NOT read the V1 findings file until AFTER you have completed Phase 1 and written your independent findings to the V2 output file.**

Reading V1 first would bias your dependency assessment. You must form your own conclusions independently before comparing.

---

### PHASE 1: INDEPENDENT INVESTIGATION & DOCUMENTATION

**🚫 ABSOLUTELY NO DEPENDENCY CHANGES ALLOWED**
**🚫 DO NOT READ V1 OUTPUT YET**

Your **ONLY** task is to:
1. **INVESTIGATE** - Scan all dependencies independently
2. **DOCUMENT** - Record every CVE and issue
3. **CATEGORIZE** - Classify by severity
4. **WRITE** - Save your complete findings to the V2 output file

**✅ COMPLETE PHASE 1 BY WRITING:**
Save your independent analysis to:
`c:\Butlery\butlery\docs\analysis\outputs\v2\DEPENDENCY_SECURITY_FINDINGS_V2.md`

---

### PHASE 2: READ V1 OUTPUT

**Only after Phase 1 is complete and V2 findings are written:**

1. **READ** the V1 findings from: `c:\Butlery\butlery\docs\analysis\outputs\DEPENDENCY_SECURITY_FINDINGS.md`
2. **NOTE** the previous session's date, scores, and CVE counts
3. **PREPARE** for comparative analysis

---

### PHASE 3: COMPARATIVE ANALYSIS

Now compare your independent findings with the V1 report:
1. **COMPARE** findings with V1 report
2. **IDENTIFY** resolved issues (in V1 but not in your V2 findings)
3. **DETECT** new issues (in your V2 findings but not in V1)
4. **TRACK** persistent issues (present in both V1 and V2)
5. **CALCULATE** security health delta
6. **UPDATE** your V2 output file with the comparison section

---

### PHASE 4: SMART UPGRADE PLAN

**Only after Phases 1-3 are complete**, create the upgrade plan.

---

## Analysis Framework: 7 Dependency Dimensions

### 1. VULNERABILITY SCANNING & CVE ANALYSIS (Weight: 25%)
Compare CVE status with previous session. Track vulnerability resolution.

### 2. VERSION CURRENCY & MAINTENANCE STATUS (Weight: 20%)
Compare version lag. Track package updates and maintenance status changes.

### 3. LICENSE COMPLIANCE & LEGAL RISK (Weight: 18%)
Compare license compliance. Track legal risk resolution.

### 4. DEPENDENCY BLOAT & BUNDLE SIZE IMPACT (Weight: 15%)
Compare unused dependencies. Track bundle size changes.

### 5. SECURITY PRACTICES & SUPPLY CHAIN INTEGRITY (Weight: 12%)
Compare publisher verification. Track trust score changes.

### 6. PLATFORM COMPATIBILITY & SUPPORT (Weight: 5%)
Compare SDK compatibility. Track platform support changes.

### 7. UPGRADE PATH & MIGRATION STRATEGY (Weight: 5%)
Compare upgrade complexity. Track migration progress.

---

## Output Format Required

### Executive Summary with Dependency Comparison

```
BUTLERY DEPENDENCY & SUPPLY CHAIN SECURITY - V2 FOLLOW-UP SESSION
===================================================================
Analysis Date: [Date]
Previous Analysis Date: [Date from previous report]
Days Since Last Analysis: [X days]
Total Dependencies: X direct, Y transitive (Z total)

DEPENDENCY HEALTH SCORE COMPARISON:
                              Previous    Current    Delta    Trend
──────────────────────────────────────────────────────────────────────
OVERALL HEALTH SCORE:         X/100       X/100      +/-X     ↑/↓/→
├─ Vulnerabilities (CVEs):    X/25        X/25       +/-X     ↑/↓/→
├─ Version Currency:          X/20        X/20       +/-X     ↑/↓/→
├─ License Compliance:        X/18        X/18       +/-X     ↑/↓/→
├─ Dependency Bloat:          X/15        X/15       +/-X     ↑/↓/→
├─ Security Practices:        X/12        X/12       +/-X     ↑/↓/→
├─ Platform Compatibility:    X/5         X/5        +/-X     ↑/↓/→
└─ Upgrade Path:              X/5         X/5        +/-X     ↑/↓/→

VULNERABILITY COMPARISON:
              Previous    Current    Patched    New    Net Change
────────────────────────────────────────────────────────────────────
CRITICAL:     X           X          X          X      +/-X
HIGH:         X           X          X          X      +/-X
MEDIUM:       X           X          X          X      +/-X
LOW:          X           X          X          X      +/-X

VERSION CURRENCY COMPARISON:
                      Previous    Current    Updated    Outdated    Net
──────────────────────────────────────────────────────────────────────────
Current (0-1 minor):  X           X          +X         -X          +/-X
Outdated (1-2 major): X           X          +X         -X          +/-X
Severely Outdated:    X           X          +X         -X          +/-X

SECURITY TRAJECTORY: [Strengthening | Stable | Weakening]
```

### Dependency Progress Report Section (NEW IN V2)

```markdown
## 📦 Dependency Progress Report: Changes Since Last Session

### ✅ RESOLVED DEPENDENCY ISSUES (X total)

Issues from the previous session that are now fixed:

#### CVEs Patched (X)
1. **[CVE-XXXX-XXXXX]** - [Package Name]
   - Previous Version: X.X.X (vulnerable)
   - Current Version: X.X.X (patched)
   - CVSS Score: X.X
   - Resolution: Package upgraded
   - Verified: ✅

#### Packages Updated (X)
1. **[Package Name]**
   - Previous Version: X.X.X (X major behind)
   - Current Version: X.X.X
   - Breaking Changes Handled: [Y/N]
   - Verified: ✅

#### Unused Dependencies Removed (X)
1. **[Package Name]**
   - Bundle Size Saved: X KB
   - Verified: ✅

---

### 🆕 NEW DEPENDENCY ISSUES (X total)

Issues not present in the previous session:

#### New CVEs (X)
1. **[CVE-XXXX-XXXXX]** - [Package Name] v[X.X.X]
   - CVSS Score: X.X (CRITICAL/HIGH/MEDIUM/LOW)
   - Disclosure Date: [Date]
   - Patch Available: [Y/N]
   - Affected Version Range: [X.X.X - Y.Y.Y]
   - Priority: CRITICAL

#### Newly Outdated Packages (X)
1. **[Package Name]**
   - Our Version: X.X.X
   - Latest Version: Y.Y.Y
   - Major Versions Behind: X
   - Reason: [Package released update since last audit]

---

### ⏳ PERSISTENT DEPENDENCY ISSUES (X total)

Issues still present from the previous session:

#### Persistent CVEs (X)
1. **[CVE-XXXX-XXXXX]** - [Package Name]
   - Days Unpatched: [X days]
   - CVSS Score: X.X
   - Reason Unresolved: [Breaking changes, no patch, etc.]
   - Risk Accumulation: [Increasing exposure]

#### Persistently Outdated (X)
1. **[Package Name]**
   - Days Behind: [X days]
   - Versions Behind: [X.X → Y.Y]
   - Reason: [Complex migration, etc.]

---

### 📊 Dependency Metrics Trending

| Metric | Previous | Current | Change | Status |
|--------|----------|---------|--------|--------|
| Total CVEs | X | X | -X | ↑/↓ |
| Packages with CVEs | X | X | -X | ↑/↓ |
| Average Version Lag | X.X | X.X | -X | ↑/↓ |
| Abandoned Packages | X | X | -X | ↑/↓ |
| Unused Dependencies | X | X | -X | ↑/↓ |
| Bundle Size (deps) | X MB | X MB | -X MB | ↑/↓ |

---

### 🎯 Recommendations Based on Progress

1. **Urgent Security:** [CVEs to patch immediately]
2. **Continue Momentum:** [Upgrade paths showing progress]
3. **Blocked Items:** [Upgrades needing resolution]
4. **Technical Debt:** [Packages needing attention]
```

---

## Phase Deliverables Checklist

### Phase 1: Independent Investigation (Write V2 First)
- [ ] Complete dependency inventory
- [ ] Vulnerability scan with CVEs
- [ ] Version currency assessment
- [ ] License compliance matrix
- [ ] **WRITE to V2 output file BEFORE reading V1**

### Phase 2: Read V1 Output
- [ ] Read V1 findings from: `docs/analysis/outputs/DEPENDENCY_SECURITY_FINDINGS.md`
- [ ] Note previous session date and CVE counts

### Phase 3: Comparative Analysis
- [ ] Dependency health score comparison
- [ ] CVEs patched/new/persistent
- [ ] Packages updated/outdated since last session
- [ ] Unused dependencies added/removed
- [ ] License risk changes
- [ ] Supply chain trust score changes
- [ ] Recommendations based on progress
- [ ] **UPDATE V2 output file with comparison section**

### Phase 4: Upgrade Plan
- [ ] Prioritized upgrades
- [ ] CVE remediation roadmap

---

## Success Criteria

**This follow-up dependency analysis is complete when:**

1. ✅ Current state fully investigated INDEPENDENTLY (all 7 dimensions)
2. ✅ **V2 findings written BEFORE reading V1**
3. ✅ V1 findings read AFTER V2 was written
4. ✅ Complete comparison performed
5. ✅ CVE status tracked (patched/new/persistent)
6. ✅ Version currency changes measured
7. ✅ License compliance progress tracked
8. ✅ Bundle size changes calculated
9. ✅ Supply chain security trajectory determined
10. ✅ Recommendations prioritized by security risk
11. ✅ **ZERO dependency changes made**

---

## 🚀 BEGIN FOLLOW-UP DEPENDENCY ANALYSIS NOW

**CRITICAL WORKFLOW:**
```
┌─────────────────────────────────────────────────────────────┐
│  PHASE 1: Investigate dependencies INDEPENDENTLY            │
│           ↓                                                  │
│           Write findings to outputs/v2/DEPENDENCY_SEC...    │
│           ↓                                                  │
│  PHASE 2: NOW read outputs/DEPENDENCY_SECURITY_... (V1)     │
│           ↓                                                  │
│  PHASE 3: Compare V2 vs V1, update V2 with comparison       │
│           ↓                                                  │
│  PHASE 4: Create upgrade plan                               │
└─────────────────────────────────────────────────────────────┘
```

**CRITICAL REMINDERS:**
- 🚫 **DO NOT READ V1 UNTIL PHASE 2** - Prevents bias
- 🚫 **NO DEPENDENCY CHANGES** - Investigation and comparison ONLY
- 📝 Write V2 findings first: `docs/analysis/outputs/v2/DEPENDENCY_SECURITY_FINDINGS_V2.md`
- 📖 Read V1 after: `docs/analysis/outputs/DEPENDENCY_SECURITY_FINDINGS.md`
- 🔒 Focus on CVE resolution tracking
- ✅ Complete all 4 phases in order

**Your Mission:**
Execute comprehensive INDEPENDENT dependency investigation first, write your findings to V2 output, THEN read V1 and compare. Track CVE resolution toward zero-vulnerability dependency excellence.

**This analysis ensures unbiased continuous dependency security improvement.**
