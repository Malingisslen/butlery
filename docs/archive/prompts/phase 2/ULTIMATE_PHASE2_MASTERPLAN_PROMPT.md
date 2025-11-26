# ULTIMATE PHASE 2: MASTER REMEDIATION PLAN PROMPT

## Mission

Analyze ALL Phase 1 investigation reports in `docs/ultimate/` and create a single, prioritized **Master Remediation Checklist** in `docs/ultimate/MASTERPLAN.md`.

This checklist is the **single source of truth** for all remediation work - one list, everything tracked in one place.

---

## Your Task

### Step 1: Read All Analysis Reports

**Location**: `docs/ultimate/*.md` (exclude subdirectories `/human` and `/prompts`)

Use `Glob` to find all reports, then `Read` each one:
```dart
Glob pattern: docs/ultimate/*.md
Exclude: docs/ultimate/human/*, docs/ultimate/prompts/*
```

**Extract from each report**:
- All findings and issues
- Severity (Critical/High/Medium/Low)
- Effort estimates (hours)
- File locations (file:line)
- Dependencies between issues

### Step 2: Prioritize Using This Framework

```
Priority Score = (Severity × Likelihood × Impact) + Dependency_Bonus - Effort_Penalty

Severity:     CRITICAL=10, HIGH=7, MEDIUM=4, LOW=1
Likelihood:   Certain=10, Likely=7, Possible=4, Unlikely=1
Impact:       All_users=10, Most=7, Some=4, Few=1
Dependencies: Blocks_5+=+20, Blocks_2-4=+10, Blocks_1=+5, None=0
Effort:       >3days=-10, 1-3days=-5, 3-8hrs=-3, 1-2hrs=-1
```

**Result**: Issues sorted by priority score (highest first)

### Step 3: Create ONE Master Checklist

**Output**: `docs/ultimate/MASTERPLAN.md`

**Structure**:
```markdown
# BUTLERY MASTER REMEDIATION PLAN

**Generated**: [Date]
**Total Issues**: [X]
**Estimated Effort**: [Y hours] ([Z days])

---

## MASTER CHECKLIST

**Progress**: 0 / [X] complete (0%)

### PHASE 1: CRITICAL (P0) - [X hours]
*Must fix before production*

- [ ] **#001** [Short title] `[Report:Section]` **[X hrs]**
      → Files: file.dart:123
      → Fix: [What to do]
      → Impact: [Why critical]
      → Dependencies: [None or #XYZ must be done first]

- [ ] **#002** [Short title] `[Report:Section]` **[X hrs]**
      → Files: file.dart:456
      → Fix: [What to do]
      → Impact: [Why critical]
      → Dependencies: Blocks #005, #012

[... all P0 issues with checkboxes ...]

**Phase 1 Subtotal**: 0 / [X] complete (0%) - [Y hours]

---

### PHASE 2: HIGH PRIORITY (P1) - [X hours]
*Should fix soon*

- [ ] **#010** [Short title] `[Report:Section]` **[X hrs]**
      → Files: file.dart:789
      → Fix: [What to do]
      → Impact: [User impact]
      → Dependencies: Requires #002

[... all P1 issues with checkboxes ...]

**Phase 2 Subtotal**: 0 / [X] complete (0%) - [Y hours]

---

### PHASE 3: MEDIUM (P2) - [X hours]
*Quality improvements*

- [ ] **#030** [Short title] `[Report:Section]` **[X hrs]**
      → Files: file.dart:234
      → Fix: [What to do]
      → Impact: [Improvement]
      → Dependencies: None

[... all P2 issues with checkboxes ...]

**Phase 3 Subtotal**: 0 / [X] complete (0%) - [Y hours]

---

### PHASE 4: LOW PRIORITY (P3) - [X hours]
*Polish and optimization*

- [ ] **#050** [Short title] `[Report:Section]` **[X hrs]**
      → Files: file.dart:567
      → Fix: [What to do]
      → Impact: [Nice to have]
      → Dependencies: None

[... all P3 issues with checkboxes ...]

**Phase 4 Subtotal**: 0 / [X] complete (0%) - [Y hours]

---

## WORK LOG

**Update this section as you work - log completed items and issues**

### [Date] - Started Phase 1
- Working on: #001, #002, #003
- Status: In progress

### [Date] - Completed #001
- Issue: [Short title]
- Time taken: [X hours] (estimated: [Y hours])
- Notes: [Any learnings or challenges]
- Verified: [How you validated the fix]

### [Date] - Discovered New Issue
- New finding: [Description]
- Added as: #XXX in Phase [1/2/3/4]
- Effort: [X hours]

[... continue logging all work ...]

---

## CRITICAL DEPENDENCIES

**Issues that MUST be done before others**

**#002 → Blocks: #005, #012, #018**
- Offline-first architecture must be implemented before sync features

**#007 → Blocks: #015, #019**
- Security token migration must complete before auth flows

[... document all blocking dependencies ...]

---

## QUICK REFERENCE

### Reports Analyzed
1. CODE_QUALITY_ANALYSIS_REPORT.md - [X issues]
2. SECURITY_ANALYSIS_REPORT.md - [X issues]
3. PLATFORM_ANALYSIS_REPORT.md - [X issues]
[... list all reports ...]

### By Report Source
**SECURITY_ANALYSIS_REPORT.md**: Issues #001, #003, #007, #019
**PLATFORM_ANALYSIS_REPORT.md**: Issues #002, #008, #015, #023
[... map issues to source reports ...]

### By File
**lib/services/auth_service.dart**: Issues #001, #007, #012
**lib/viewmodels/recipe_form_viewmodel.dart**: Issues #005, #018
[... map issues to files ...]

---

## NOTES & DECISIONS

**Important decisions and context**

### Decision: Offline-First Approach
- **Date**: [Date]
- **Context**: Multiple edge case issues point to need for offline-first
- **Decision**: Implement offline-first architecture in Phase 1
- **Impact**: Affects issues #001, #002, #005, #012

### Risk: High-Risk Refactoring
- **Issue**: #002 Offline-first refactoring
- **Risk**: Could break existing Firestore operations
- **Mitigation**: Feature flag rollout, comprehensive testing
- **Rollback**: Revert commits [list commits when done]

[... document all important decisions ...]
```

---

## Issue Format

**Each issue follows this exact format**:

```markdown
- [ ] **#[NUMBER]** [One-line title] `[REPORT:Section]` **[X hrs]**
      → Files: [file.dart:line, file2.dart:line]
      → Fix: [Concise description of what to do]
      → Impact: [Why this matters / user impact]
      → Dependencies: [None | Requires #XYZ | Blocks #ABC]
```

**Example**:
```markdown
- [ ] **#001** Tokens stored in SharedPreferences unencrypted `SECURITY:M2` **2 hrs**
      → Files: lib/services/auth_service.dart:142
      → Fix: Migrate to flutter_secure_storage, revoke old tokens
      → Impact: Account compromise via local file access (CVSS 9.1)
      → Dependencies: Blocks #007 (token refresh)
```

---

## Prioritization Rules

1. **Phase 1 (P0 - Critical)**: Priority score >60
   - Security vulnerabilities (CRITICAL severity)
   - App store blockers
   - Data loss scenarios
   - Critical architecture violations

2. **Phase 2 (P1 - High)**: Priority score 30-60
   - Crashes and major bugs
   - Platform compliance issues
   - Performance problems
   - High-impact UX issues

3. **Phase 3 (P2 - Medium)**: Priority score 10-30
   - Code quality improvements
   - Optimization opportunities
   - Documentation issues
   - Medium-impact UX

4. **Phase 4 (P3 - Low)**: Priority score <10
   - Polish and nice-to-have
   - ASO optimization
   - Minor improvements

---

## Quality Checklist

Before finalizing `MASTERPLAN.md`:

- [ ] All `*.md` files in `docs/ultimate/` read (excluding subdirectories)
- [ ] All issues extracted with severity, effort, files
- [ ] All issues prioritized using scoring framework
- [ ] All issues have unique #NUMBER identifiers
- [ ] All dependencies documented (what blocks what)
- [ ] ONE master checklist (no scattered checklists)
- [ ] File locations included for each issue
- [ ] Effort estimates for each issue
- [ ] Work log section ready for updates
- [ ] Production readiness criteria defined

---

## Example Output Structure

```markdown
# BUTLERY MASTER REMEDIATION PLAN

**Generated**: 2025-11-07
**Total Issues**: 147
**Estimated Effort**: 284 hours (35 days)

## MASTER CHECKLIST

**Progress**: 0 / 147 complete (0%)

### PHASE 1: CRITICAL (P0) - 42 hours
*Must fix before production*

- [ ] **#001** Tokens in SharedPreferences unencrypted `SECURITY:M2` **2 hrs**
      → Files: lib/services/auth_service.dart:142
      → Fix: Migrate to flutter_secure_storage
      → Impact: Account compromise (CVSS 9.1)
      → Dependencies: Blocks #007

- [ ] **#002** Network loss during save causes data loss `EDGE_CASES:1.1` **12 hrs**
      → Files: lib/services/recipe_service.dart:89, lib/viewmodels/recipe_form_viewmodel.dart:234
      → Fix: Implement offline-first with sync queue
      → Impact: Users lose recipe creation work
      → Dependencies: Blocks #005, #012, #018

- [ ] **#003** Missing privacy policy URL `PLATFORM:5.1` **2 hrs**
      → Files: Info.plist, AndroidManifest.xml, app metadata
      → Fix: Create policy, add URL to metadata
      → Impact: App Store submission blocker
      → Dependencies: None

[... 15 total P0 issues ...]

**Phase 1 Subtotal**: 0 / 15 complete (0%) - 42 hours

### PHASE 2: HIGH PRIORITY (P1) - 86 hours
*Should fix soon*

- [ ] **#016** iOS HIG compliance 70% (target 90%) `PLATFORM:1` **6 hrs**
      → Files: Multiple views (see PLATFORM report Section 1)
      → Fix: Implement platform-adaptive widgets
      → Impact: App Store rejection risk
      → Dependencies: None

[... 35 total P1 issues ...]

**Phase 2 Subtotal**: 0 / 35 complete (0%) - 86 hours

### PHASE 3: MEDIUM (P2) - 112 hours

[... 53 total P2 issues ...]

**Phase 3 Subtotal**: 0 / 53 complete (0%) - 112 hours

### PHASE 4: LOW PRIORITY (P3) - 44 hours

[... 44 total P3 issues ...]

**Phase 4 Subtotal**: 0 / 44 complete (0%) - 44 hours
```

---

## Critical Guidelines

### Keep It Simple
- **ONE checklist** with ALL items
- **Sequential numbering** (#001, #002, #003...)
- **Phase grouping** (P0, P1, P2, P3)
- **No duplicate checklists** anywhere

### Make It Trackable
- Each issue has ONE checkbox
- Check off as you complete
- Update progress percentages
- Log completed items in WORK LOG

### Make It Maintainable
- Add new issues with next #NUMBER
- Update effort based on actual time
- Document decisions in NOTES
- Keep WORK LOG current

---

## Ready to Create Master Plan

**Execute these steps**:

1. `Glob` pattern `docs/ultimate/*.md` to find all reports
2. `Read` each report file
3. Extract all issues with severity, effort, files
4. Score and prioritize each issue
5. Assign sequential #NUMBERS
6. Create ONE master checklist in phases
7. Write to `docs/ultimate/MASTERPLAN.md`

**Output**: A single, comprehensive, trackable master remediation checklist.

🚀 **BEGIN MASTER PLAN CREATION NOW**
