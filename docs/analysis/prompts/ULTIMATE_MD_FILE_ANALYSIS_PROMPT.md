# ULTIMATE MARKDOWN FILE ANALYSIS PROMPT

## Mission

Perform a **comprehensive, exhaustive analysis** of all `.md` documentation files in the Butlery codebase. This is a **MAJOR analysis task** that will take significant time. Do not rush. Do not cut corners.

**Goal**: Achieve a lean, maintainable documentation set where every file serves a clear purpose.

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

### Why This Matters

Documentation lies. Files claim features exist that don't. Plans say "complete" when code is missing. Dates say "updated" but content is stale. **Trust nothing. Verify everything.**

---

## ⏱️ TIME EXPECTATION

This is a **4-6 hour analysis task** for a codebase of this size (~100+ .md files).

| Phase | Time | Description |
|-------|------|-------------|
| File Discovery | 15 min | Find all .md files |
| **Complete File Reading** | **2-3 hours** | Read EVERY file completely |
| **Codebase Verification** | **1-2 hours** | Verify claims against actual code |
| Cross-Reference Analysis | 30 min | Check links and references |
| Report Generation | 30 min | Compile findings |

**Do not attempt to shortcut this process.**

---

## ⚠️ CRITICAL: TWO-PHASE APPROACH

### PHASE 1: INVESTIGATION & DOCUMENTATION

**🚫 NO FILE DELETIONS OR EDITS ALLOWED**

Your **ONLY** task is to:
1. **READ** - Read every .md file completely (not just headers)
2. **VERIFY** - Check every claim against the actual codebase
3. **DOCUMENT** - Record findings with evidence
4. **RECOMMEND** - Propose actions with justification

**DO NOT:**
- ❌ Delete ANY documentation files
- ❌ Edit or update ANY content
- ❌ Create consolidation merges
- ❌ Rename or move files
- ❌ Make changes "while you're there"

**Your output is a COMPREHENSIVE FINDINGS REPORT with EVIDENCE** - nothing else.

### PHASE 2: CLEANUP EXECUTION (After Approval)

Only after findings are reviewed and approved:
1. Execute deletions for unnecessary files
2. Merge redundant content
3. Update stale references
4. Reorganize misplaced files

---

## Verification Requirements

### For EVERY .md File

```
□ Read the COMPLETE file content (all lines, not samples)
□ Understand the file's stated purpose
□ Check if the purpose is still relevant
□ Verify any file paths mentioned exist
□ Verify any code examples are accurate
□ Check if referenced features exist in codebase
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
□ Verify directory structure matches
□ Check if services/classes exist
□ Validate patterns are actually used
□ Cross-reference with actual code organization
```

---

## Analysis Framework: 5 Dimensions

### Dimension 1: Necessity Analysis (30%)

**Question**: Does this file need to exist?

**VERIFICATION REQUIRED:**

1. **Implementation Plans**
   - Read the entire plan
   - List every file/component it says to create
   - Use `ls` and `glob` to check if each exists
   - Provide evidence: "Plan says create X.dart → File exists at lib/X.dart (5,234 bytes)"

2. **Success Reports**
   - Read what it claims was implemented
   - Verify the implementation exists
   - If implementation exists, report is obsolete

3. **Feature Documentation**
   - Identify what feature it documents
   - Search codebase for that feature
   - If feature doesn't exist, doc is orphaned

### Dimension 2: Staleness Detection (25%)

**Question**: Is this documentation accurate and current?

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

3. **Architecture Claims**
   - Verify directory structure
   - Check service registrations
   - Validate patterns in use

### Dimension 3: Redundancy Analysis (20%)

**Question**: Does this duplicate information elsewhere?

**VERIFICATION REQUIRED:**

1. **Similar Files**
   - Read BOTH files completely
   - Calculate actual overlap percentage
   - Don't assume based on names

2. **Spec vs Architecture Docs**
   - Read the spec completely
   - Read the architecture doc completely
   - Determine if content is truly duplicated

### Dimension 4: Orphaned Documentation (15%)

**Question**: Does this document something that still exists?

**VERIFICATION REQUIRED:**

1. **Feature Documentation**
   - Identify the documented feature
   - Search codebase: `grep`, `glob`
   - Verify feature exists in code

2. **API Documentation**
   - Check if endpoints/methods exist
   - Verify in actual source files

### Dimension 5: Structure & Organization (10%)

**Question**: Is this file in the right place with the right name?

**VERIFICATION REQUIRED:**

1. **File Content vs Name**
   - Read file content
   - Compare to filename
   - Note mismatches (e.g., DEBUG_PLAN.md contains "Test Plan")

2. **Location Appropriateness**
   - Check if file belongs in its directory
   - Note files in unusual locations (e.g., README in lib/)

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

## Investigation Process

### Step 1: Catalog All Files (15 min)
```bash
find . -name "*.md" -type f | grep -v node_modules | grep -v build | sort
```

### Step 2: Read and Classify Each File (2-3 HOURS)

**🚨 THIS IS THE MOST IMPORTANT STEP 🚨**

For EACH file:
1. **Read the ENTIRE file** - use `Read` tool, read all content
2. **Understand the purpose** - what is this file trying to do?
3. **Identify claims** - what does it say exists/works/is implemented?
4. **Prepare verification** - what needs to be checked?

**DO NOT SKIP FILES. DO NOT SKIM. READ COMPLETELY.**

### Step 3: Verify Against Codebase (1-2 HOURS)

For EACH claim in documentation:
1. Use `ls`, `glob`, `grep` to check if it's true
2. Document the verification result
3. Note file paths and sizes as evidence

### Step 4: Cross-Reference (30 min)
- Find which files reference each other
- Check if referenced files exist
- Identify broken links

### Step 5: Generate Report (30 min)
- Compile findings WITH EVIDENCE
- Calculate scores
- Prioritize recommendations

---

## Output Format

### Required Sections

1. **Executive Summary** - Overall health score
2. **Files to DELETE** - With evidence for each
3. **Files to RENAME** - With justification
4. **Files to UPDATE** - With specific issues
5. **Files to KEEP** - Brief confirmation
6. **Complete File Inventory** - Every file listed

### Evidence Requirements

Every DELETE/UPDATE recommendation must include:
- What the documentation claims
- What you verified in the codebase
- Specific file paths checked
- Your conclusion with reasoning

---

## 🚀 BEGIN ANALYSIS NOW

**CRITICAL REMINDERS:**

1. ⏱️ **This takes 4-6 hours** - Don't rush
2. 📖 **Read EVERY file completely** - No skimming
3. ✅ **Verify EVERY claim** - Check the codebase
4. 📋 **Document EVIDENCE** - Paths, sizes, existence
5. 🚫 **NO assumptions** - Trust nothing, verify everything
6. 🚫 **NO file changes** - Investigation only

**Output Location:** `docs/analysis/outputs/MD_FILE_FINDINGS.md`

**Your Mission:**
Create a complete, verified inventory of all .md files with:
- Every file read completely
- Every claim verified against codebase
- Evidence documented for all recommendations
- Accurate assessment based on reality, not documentation claims

**This codebase deserves accurate analysis** - not assumptions.
