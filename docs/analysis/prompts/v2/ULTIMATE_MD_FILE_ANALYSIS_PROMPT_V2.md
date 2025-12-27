# ULTIMATE MARKDOWN FILE ANALYSIS PROMPT - V2 (FOLLOW-UP SESSION)

**Copy and paste this entire prompt to Claude to trigger a follow-up markdown file investigation that compares with your previous session's findings.**

---

## Mission: Follow-Up Markdown File Analysis with Progress Tracking

Perform a **comprehensive, exhaustive analysis** of all `.md` documentation files in the Butlery codebase AND compare your findings with the previous session's audit. This is a **MAJOR analysis task** that will take significant time.

This enables:
- **Cleanup progress tracking** - Were unnecessary files deleted?
- **Staleness reduction** - Were outdated docs updated?
- **Redundancy elimination** - Were duplicates merged?
- **New bloat detection** - Any new unnecessary docs created?
- **Documentation health trajectory** - Is the doc set getting leaner?

---

## ⚠️ CRITICAL: ZERO ASSUMPTIONS POLICY

### 🚨 READ THIS BEFORE STARTING 🚨

**This analysis requires VERIFICATION, not assumption.**

You MUST:
- **READ every single .md file** - not skim, not sample, READ completely
- **VERIFY every claim** against the actual codebase
- **CHECK every file path** mentioned in documentation actually exists
- **CONFIRM every feature** mentioned as "implemented" exists in code
- **VALIDATE every code example** still compiles/works

You MUST NOT:
- ❌ Assume a file is current because it has a recent date
- ❌ Assume a feature exists because documentation says so
- ❌ Assume an implementation plan is complete without checking code
- ❌ Trust file names to indicate content
- ❌ Skip files because they "look fine"
- ❌ Make recommendations without evidence
- ❌ Assume V1 findings are still accurate (re-verify everything)

### Why This Matters

Documentation lies. Files claim features exist that don't. Plans say "complete" when code is missing. Dates say "updated" but content is stale. **Trust nothing. Verify everything.**

---

## ⏱️ TIME EXPECTATION

This is a **5-7 hour analysis task** for a codebase of this size (~100+ .md files).

| Phase | Time | Description |
|-------|------|-------------|
| Phase 1: File Discovery | 15 min | Find all .md files |
| **Phase 1: Complete File Reading** | **2-3 hours** | Read EVERY file completely |
| **Phase 1: Codebase Verification** | **1-2 hours** | Verify claims against actual code |
| Phase 1: Write V2 findings | 30 min | Document independent findings |
| Phase 2: Read V1 | 15 min | Review previous findings |
| Phase 3: Comparison | 30 min | Compare V2 vs V1 |
| Phase 4: Cleanup Plan | 30 min | Prioritize actions |

**Do not attempt to shortcut this process.**

---

## 📁 FILE PATHS - CRITICAL

| Purpose | Path |
|---------|------|
| **V2 Output (Write First)** | `c:\Butlery\butlery\docs\analysis\outputs\v2\MD_FILE_FINDINGS_V2.md` |
| **V1 Input (Read After)** | `c:\Butlery\butlery\docs\analysis\outputs\MD_FILE_FINDINGS.md` |

---

## ⚠️ CRITICAL: FOUR-PHASE APPROACH

### 🚨 ANTI-BIAS RULE - READ THIS FIRST 🚨

**DO NOT read the V1 findings file until AFTER you have completed Phase 1 and written your independent findings to the V2 output file.**

Reading V1 first would bias your assessment. You must form your own conclusions independently before comparing.

---

### PHASE 1: INDEPENDENT INVESTIGATION & DOCUMENTATION (3-5 HOURS)

**🚫 NO FILE DELETIONS OR EDITS ALLOWED**
**🚫 DO NOT READ V1 OUTPUT YET**

Your **ONLY** task is to:
1. **READ** - Read every .md file completely (not just headers)
2. **VERIFY** - Check every claim against the actual codebase
3. **DOCUMENT** - Record findings with evidence
4. **RECOMMEND** - Propose actions with justification
5. **WRITE** - Save your complete findings to the V2 output file

**DO NOT:**
- ❌ Delete ANY documentation files
- ❌ Edit or update ANY content
- ❌ Read the V1 findings file yet
- ❌ Make changes "while you're there"
- ❌ Skip verification steps

**✅ COMPLETE PHASE 1 BY WRITING:**
Save your independent analysis with full evidence to:
`c:\Butlery\butlery\docs\analysis\outputs\v2\MD_FILE_FINDINGS_V2.md`

---

### PHASE 2: READ V1 OUTPUT

**Only after Phase 1 is complete and V2 findings are written:**

1. **READ** the V1 findings from: `c:\Butlery\butlery\docs\analysis\outputs\MD_FILE_FINDINGS.md`
2. **NOTE** the previous session's date, file counts, and recommendations
3. **PREPARE** for comparative analysis

---

### PHASE 3: COMPARATIVE ANALYSIS

Now compare your independent findings with the V1 report:
1. **COMPARE** findings with V1 report
2. **IDENTIFY** cleanup completed (files deleted, merged, updated)
3. **DETECT** new issues (new unnecessary docs, new staleness)
4. **TRACK** persistent issues (still present from V1)
5. **CALCULATE** documentation health delta
6. **UPDATE** your V2 output file with the comparison section

---

### PHASE 4: SMART CLEANUP PLAN

**Only after Phases 1-3 are complete**, create the cleanup plan:
1. **PRIORITIZE** by impact and effort
2. **GROUP** related cleanup tasks
3. **SEQUENCE** for efficient execution

---

## Verification Requirements

### For EVERY .md File

```
□ Read the COMPLETE file content (all lines, not samples)
□ Understand the file's stated purpose
□ Check if the purpose is still relevant
□ Verify any file paths mentioned exist (use ls, glob)
□ Verify any code examples are accurate (check actual code)
□ Check if referenced features exist in codebase (use grep)
□ Determine if file is actively useful or obsolete
□ Document verification evidence in findings
```

### For Implementation Plans

```
□ Read the plan completely
□ List each component the plan says to create
□ Check if each component exists in the codebase (use ls, glob, grep)
□ Note file paths and sizes as evidence
□ Determine: COMPLETE (all exist), PARTIAL (some exist), NOT STARTED
□ If COMPLETE → recommend DELETE with evidence
```

### For Feature Documentation

```
□ Read the feature description
□ Search codebase for the feature (grep, glob)
□ Verify the documented behavior matches code
□ Check if APIs/methods still exist
□ Note specific file paths as evidence
```

### For Architecture Documentation

```
□ Read the architecture claims
□ Verify directory structure matches (use ls)
□ Check if services/classes exist (use glob)
□ Validate patterns are actually used (use grep)
□ Cross-reference with actual code organization
```

---

## Required Evidence Format

Every finding MUST include evidence:

### Good Finding (With Evidence)
```markdown
#### docs/import_system_plan.md (2,619 lines)
**Status:** COMPLETE - DELETE

**Verification:**
Plan says to create:
- GlobalRecipeCache → VERIFIED: lib/services/import/cache/global_recipe_cache.dart exists
- YouTubeTranscriptService → VERIFIED: lib/services/import/youtube/youtube_transcript_service.dart (12,269 bytes)
- LlmTier → VERIFIED: lib/services/parsing/tiers/llm_tier.dart (8,317 bytes)

All 5 planned components verified to exist. Plan is complete.
```

### Bad Finding (No Evidence)
```markdown
#### docs/import_system_plan.md
**Status:** DELETE

Looks like the import system is implemented.
```

**The second example is UNACCEPTABLE. Every recommendation needs verification.**

---

## Analysis Framework: 5 Dimensions

### Dimension 1: Necessity Analysis (Weight: 30%)

**VERIFICATION REQUIRED for each file:**

1. **Implementation Plans**
   - Read the entire plan
   - List every file/component it says to create
   - Use `ls` and `glob` to check if each exists
   - Provide evidence: "Plan says create X.dart → File exists at lib/X.dart (5,234 bytes)"

2. **Success Reports**
   - Read what it claims was implemented
   - Verify the implementation exists in code
   - If implementation exists, report is obsolete

### Dimension 2: Staleness Detection (Weight: 25%)

**VERIFICATION REQUIRED:**

1. **Code Path References**
   ```
   For EACH file path in documentation:
   □ Run: ls <path> or glob for the path
   □ Document: "docs/X.md references lib/Y.dart → EXISTS/MISSING"
   ```

2. **Code Examples**
   - Check if class/method names exist
   - Verify API signatures match
   - Note any discrepancies

### Dimension 3: Redundancy Analysis (Weight: 20%)

**VERIFICATION REQUIRED:**

1. **Similar Files**
   - Read BOTH files completely
   - Calculate actual overlap percentage
   - Don't assume based on names

### Dimension 4: Orphaned Documentation (Weight: 15%)

**VERIFICATION REQUIRED:**

1. **Feature Documentation**
   - Identify the documented feature
   - Search codebase: `grep`, `glob`
   - Verify feature exists in code

### Dimension 5: Structure & Organization (Weight: 10%)

**VERIFICATION REQUIRED:**

1. **File Content vs Name**
   - Read file content
   - Compare to filename
   - Note mismatches

---

## Output Format Required

### Executive Summary with Comparison

```
BUTLERY MARKDOWN FILE ANALYSIS - V2 FOLLOW-UP SESSION
======================================================
Analysis Date: [Date]
Previous Analysis Date: [Date from V1]
Days Since Last Analysis: [X days]
Verification Method: All claims verified against actual codebase

FILE COUNT COMPARISON:
                              Previous    Current    Delta    Trend
──────────────────────────────────────────────────────────────────────
TOTAL .md FILES:              X           X          +/-X     ↑/↓/→
├─ docs/                      X           X          +/-X     ↑/↓/→
├─ docs/analysis/prompts/     X           X          +/-X     ↑/↓/→
├─ docs/analysis/prompts/v2/  X           X          +/-X     ↑/↓/→
├─ .claude/                   X           X          +/-X     ↑/↓/→
├─ test/                      X           X          +/-X     ↑/↓/→
├─ lib/                       X           X          +/-X     ↑/↓/→
└─ root/                      X           X          +/-X     ↑/↓/→

DOCUMENTATION HEALTH SCORE:
                              Previous    Current    Delta    Trend
──────────────────────────────────────────────────────────────────────
OVERALL SCORE:                X/100       X/100      +/-X     ↑/↓/→
├─ Necessity:                 X/30        X/30       +/-X     ↑/↓/→
├─ Freshness:                 X/25        X/25       +/-X     ↑/↓/→
├─ Uniqueness:                X/20        X/20       +/-X     ↑/↓/→
├─ Relevance:                 X/15        X/15       +/-X     ↑/↓/→
└─ Organization:              X/10        X/10       +/-X     ↑/↓/→

DOCUMENTATION TRAJECTORY: [Significantly Leaner | Leaner | Stable | Growing]
```

### Progress Report Section

```markdown
## 📁 Documentation Cleanup Progress Report

### ✅ CLEANUP COMPLETED SINCE LAST SESSION (X actions)

**Verified by checking file existence:**

#### Files Deleted (X files)
| File | Previous Location | V1 Recommendation | Verified Deleted |
|------|-------------------|-------------------|------------------|
| IMPLEMENTATION_PLAN.md | docs/parser/ | DELETE | ✅ File not found |

#### Files Renamed (X files)
| Old Name | New Name | Verified |
|----------|----------|----------|
| DEBUG_PLAN.md | TEST_PLAN.md | ✅ Confirmed via ls |

---

### 🆕 NEW DOCUMENTATION ISSUES (X total)

Issues not present in the previous session (verified against codebase):

#### New Unnecessary Files (X)
| File | Why Unnecessary | Evidence |
|------|-----------------|----------|
| NEW_PLAN.md | Implementation complete | lib/feature/ exists with all components |

---

### ⏳ PERSISTENT ISSUES (X total)

Issues still present from the previous session (re-verified):

#### Still Unnecessary (X files)
| File | V1 Recommendation | Current Status | Evidence |
|------|-------------------|----------------|----------|
| OLD_PLAN.md | DELETE | Still exists | Still no action taken |
```

---

## Success Criteria

**This follow-up analysis is complete when:**

1. ✅ **Every .md file read completely** - No skimming
2. ✅ **Every claim verified against codebase** - With evidence
3. ✅ V2 findings written BEFORE reading V1
4. ✅ V1 findings read AFTER V2 was written
5. ✅ Complete comparison performed
6. ✅ Cleanup progress verified (check if files deleted/renamed)
7. ✅ New issues flagged with evidence
8. ✅ Persistent issues re-verified
9. ✅ Documentation health trajectory determined
10. ✅ Recommendations prioritized with evidence
11. ✅ **ZERO file changes made** - Investigation only

---

## 🚀 BEGIN FOLLOW-UP ANALYSIS NOW

**CRITICAL WORKFLOW:**
```
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 1: Read EVERY .md file completely (2-3 hours)                │
│           Verify EVERY claim against codebase (1-2 hours)           │
│           ↓                                                          │
│           Write findings WITH EVIDENCE to outputs/v2/MD_FILE_...    │
│           ↓                                                          │
│  PHASE 2: NOW read outputs/MD_FILE_FINDINGS.md (V1)                 │
│           ↓                                                          │
│  PHASE 3: Compare V2 vs V1, update V2 with comparison               │
│           ↓                                                          │
│  PHASE 4: Create cleanup plan                                        │
└─────────────────────────────────────────────────────────────────────┘
```

**CRITICAL REMINDERS:**

1. ⏱️ **This takes 5-7 hours** - Don't rush
2. 📖 **Read EVERY file completely** - No skimming
3. ✅ **Verify EVERY claim** - Check the codebase with ls, glob, grep
4. 📋 **Document EVIDENCE** - Paths, sizes, existence
5. 🚫 **NO assumptions** - Trust nothing, verify everything
6. 🚫 **DO NOT READ V1 UNTIL PHASE 2** - Prevents bias
7. 🚫 **NO FILE CHANGES** - Investigation and comparison ONLY

**Your Mission:**
Execute comprehensive INDEPENDENT markdown file investigation first. READ every file. VERIFY every claim. Write your findings WITH EVIDENCE to V2 output. THEN read V1 and compare. Track cleanup progress, detect new bloat, and document health trajectory.

**This analysis ensures continuous documentation hygiene improvement through rigorous verification.**
