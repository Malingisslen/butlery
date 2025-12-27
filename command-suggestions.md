# Command Suggestions - Butlery Project

## Del 1: Sammanfattning av analysen

### Projektets karaktär

**Butlery** är en mogen, produktionsklar Flutter-app för recepthantering med sociala funktioner och Firebase-backend. Projektet omfattar:
- 911 Dart-filer (~40 000 rader kod)
- MVVM + Repository-arkitektur med 7 DI-moduler
- 100+ testfiler med 67.4% kodtäckning
- 8 befintliga /commands (analyze, commit, branch, main, worktree, docs-update, test_architecture, test-generate)
- 7 specialistagenter (flutter-developer, testing-specialist, code-reviewer, etc.)

### Mönster från historiken

Din arbetshistorik visar tydliga mönster:
1. **Iterativt arbetsflöde** - "continue" för att gå vidare steg-för-steg (~190 instanser)
2. **Fasbaserad organisation** - Arbete strukturerat i numrerade faser
3. **Systematisk städning** - Hitta alla problem först, fixa metodiskt sedan
4. **Kvalitetsfokus** - Frekventa `flutter analyze`-körningar följda av åtgärder
5. **Dokumentationsdrift** - Identifiera när docs inte matchar kod
6. **Git-integration** - Commits och pushes som naturlig del av arbetsflödet

---

## Del 2: Förslag på /commands

### 1. `/cleanup`

**Beskrivning:** Identifiera och städa bort död kod, oanvända filer och duplicerad dokumentation.

**Motivering:** Din historik visar återkommande arbete med att:
- Skanna efter död kod och onödiga filer
- Konsolidera dokumentation (arkivera oanvända .md-filer)
- Ta bort duplikation systematiskt
- Radera migrationsfiler efter genomförande

Projektet har 33 intentionellt stora filer och en "cleanup mindset"-princip i CLAUDE.md. Ett dedikerat kommando effektiviserar detta återkommande arbete.

**Exempel på användning:**
```
/cleanup
/cleanup docs
/cleanup lib/services
```

**Föreslagen prompt:**
```markdown
---
description: Scan for dead code, unused files, and documentation drift
argument-hint: [optional: path or category to focus on]
---

Systematically scan for cleanup opportunities in this codebase. Focus on:

1. **Dead Code Analysis**
   - Unused imports and variables
   - Unreferenced functions and classes
   - Deprecated code still present

2. **File Hygiene**
   - Empty or near-empty files
   - Duplicate implementations
   - Orphaned test files (testing deleted code)

3. **Documentation Drift**
   - .md files describing removed features
   - README files for deleted directories
   - Outdated implementation plans
   - V1/V2 version files that should be consolidated

4. **Migration Cleanup**
   - Completed migration files still present
   - Debug/troubleshooting docs for resolved issues
   - Temporary files or experiments

If a path/category argument is provided, focus only on that area.

Create a structured report with:
- Total cleanup opportunities found
- Categorized list of items to remove
- Estimated impact (files/lines to remove)
- Recommended cleanup order

Ask: "Should I proceed with the cleanup? (all / category / skip)"
```

---

### 2. `/refactor`

**Beskrivning:** Analysera en fil/klass för refaktoreringsmöjligheter enligt projektets mönster.

**Motivering:**
- Projektet har en strikt 500-radersregel med facade pattern för större filer
- 33 filer är dokumenterat större än gränsen
- Din historik visar fokus på arkitekturförbättringar
- recipe_form_viewmodel.dart är markerat som "exemplary" för delegation till 6 managers

**Exempel på användning:**
```
/refactor lib/services/unified/unified_recipe_service.dart
/refactor lib/viewmodels/unified_shopping_viewmodel.dart
```

**Föreslagen prompt:**
```markdown
---
description: Analyze file for refactoring opportunities following project patterns
argument-hint: <file_path>
---

Analyze the specified file for refactoring opportunities following Butlery's established patterns.

## Analysis Checklist

1. **Line Count Check**
   - Current line count vs 500-line limit
   - Check if file is in ACCEPTED_LARGE_FILES.md (if so, note the documented reason)

2. **Pattern Compliance**
   - Does it follow MVVM + Repository pattern?
   - Is it using the correct mixins (ErrorHandlingMixin, AsyncOperationMixin, etc.)?
   - ServiceLocator.get<T>() usage (not sl<T>())
   - SerializationUtils for Firestore parsing

3. **Facade Pattern Opportunity**
   - Can responsibilities be delegated to focused managers?
   - Reference: recipe_form_viewmodel.dart delegates to 6 managers

4. **Deduplication**
   - Code that exists elsewhere in the codebase
   - Opportunities to use existing utilities

5. **Security & Validation**
   - PermissionValidationMixin on repositories
   - Proper data source usage (UserService vs PermissionService)

## Output

Create a structured refactoring plan with:
- Current issues found
- Recommended changes (ordered by priority)
- Files that would be created/modified
- Risk assessment

Ask: "Would you like me to proceed with Phase 1 of this refactoring?"
```

---

### 3. `/fixall`

**Beskrivning:** Kör analyze, skapa plan och fixa alla issues automatiskt.

**Motivering:** Din historik visar ett tydligt mönster:
1. Köra `flutter analyze`
2. Skapa en action plan
3. Säga "continue" för att fixa issue efter issue

Detta kommando kombinerar ditt befintliga `/analyze` med automatisk åtgärd, vilket sparar många "continue"-steg.

**Exempel på användning:**
```
/fixall
/fixall --errors-only
/fixall --dry-run
```

**Föreslagen prompt:**
```markdown
---
description: Run analyze and automatically fix all issues in priority order
argument-hint: [--errors-only | --dry-run]
---

Run Flutter analyze and systematically fix all issues found.

## Workflow

1. **Run Analysis**
   ```bash
   flutter analyze
   ```

2. **Prioritize Issues**
   - CRITICAL: Errors preventing compilation
   - HIGH: Warnings affecting functionality
   - MEDIUM: Code quality warnings
   - LOW: Info/style suggestions

3. **Fix Strategy**
   For each issue:
   - Identify root cause (not just symptom)
   - Apply fix following project patterns
   - Verify fix didn't introduce new issues
   - Move to next issue

4. **Verification**
   After all fixes:
   - Run `flutter analyze` again
   - Confirm zero issues (or document remaining intentional ones)

## Options
- `--errors-only`: Only fix errors, skip warnings/infos
- `--dry-run`: Report what would be fixed without making changes

## Progress Tracking
Use todo list to track:
- [ ] Total issues found: X
- [ ] Errors fixed: Y/Z
- [ ] Warnings fixed: Y/Z
- [ ] Verification passed

Continue fixing until all issues are resolved or ask for guidance on complex cases.
```

---

### 4. `/review`

**Beskrivning:** Kör en kvalitetsgenomgång av aktuella ändringar innan commit.

**Motivering:**
- Du har 7 specialistagenter men inget enkelt sätt att aktivera dem före commit
- Din historik visar att du ofta kör review-agenter efter kodändringar
- Projektet har strikta konventioner (500-radersregel, mixins, security validation)

**Exempel på användning:**
```
/review
/review --staged
/review lib/services/
```

**Föreslagen prompt:**
```markdown
---
description: Quality review of current changes before committing
argument-hint: [--staged | path]
---

Perform a comprehensive quality review of changes before committing.

## Review Checklist

### 1. Architecture Compliance
- [ ] MVVM + Repository pattern followed
- [ ] No files exceed 500 lines (check ACCEPTED_LARGE_FILES.md if they do)
- [ ] Correct mixin usage (ErrorHandlingMixin, AsyncOperationMixin, etc.)
- [ ] ServiceLocator.get<T>() used correctly

### 2. Security
- [ ] PermissionValidationMixin on new repository methods
- [ ] No direct FirebaseFirestore.instance usage
- [ ] Correct data source (UserService.currentUserProfile vs PermissionService.currentUser)

### 3. Code Quality
- [ ] SerializationUtils for all Firestore parsing
- [ ] No deprecated APIs (withOpacity → withValues)
- [ ] Comments explain WHY not WHAT
- [ ] No section dividers (// ===== SECTION =====)

### 4. Testing
- [ ] New code has corresponding tests
- [ ] Existing tests still pass

### 5. Documentation
- [ ] No unnecessary .md files created
- [ ] Existing docs updated if behavior changed

## Output

Provide:
- Summary of changes reviewed
- Issues found (categorized by severity)
- Recommended fixes
- Overall assessment: Ready to commit? (Yes/No/With fixes)

If issues found, ask: "Should I fix these issues before you commit?"
```

---

### 5. `/phase`

**Beskrivning:** Starta eller fortsätt ett fasbaserat arbete med automatisk tracking.

**Motivering:** Din historik visar stark preferens för fasbaserat arbete:
- "continue with phase 2"
- "proceed to phase 1"
- Arbete strukturerat i numrerade faser

Ett dedikerat kommando formaliserar detta mönster och ger bättre spårbarhet.

**Exempel på användning:**
```
/phase start "Implement dark mode" 4
/phase next
/phase status
```

**Föreslagen prompt:**
```markdown
---
description: Start or continue phase-based work with automatic tracking
argument-hint: <start "description" count | next | status>
---

Manage phase-based work for complex, multi-step tasks.

## Commands

### `/phase start "description" count`
Initialize a new phased project:
1. Create `/tasks/phase_[timestamp].md` with:
   - Project description
   - Phase breakdown (count phases)
   - Current status tracking
2. Set Phase 1 as in_progress
3. Ask for confirmation of phase plan before proceeding

### `/phase next`
Advance to the next phase:
1. Mark current phase as completed
2. Summarize what was accomplished
3. Set next phase as in_progress
4. Show next phase objectives
5. Begin work on next phase

### `/phase status`
Show current progress:
- Overall completion percentage
- Current phase and objectives
- Completed phases summary
- Remaining work overview

## Phase Template

```markdown
# [Project Name]
Started: [date]

## Phase Overview
- Phase 1: [description] ✓
- Phase 2: [description] ← Current
- Phase 3: [description]
- Phase 4: [description]

## Progress
- [x] Phase 1: [summary of completed work]
- [ ] Phase 2: [current objectives]

## Notes
[Any blockers, decisions, or context]
```

When user says "continue", automatically proceed with current phase work.
```

---

### 6. `/sync-docs`

**Beskrivning:** Identifiera dokumentation som inte längre matchar koden.

**Motivering:**
- Du har ett befintligt `/docs-update` men det uppdaterar docs baserat på ändringar
- Din historik visar fokus på att hitta "documentation drift"
- Projektet har minimal documentation philosophy men många docs från tidigare arbete
- CLAUDE.md säger: "Delete implementation plans once implemented"

**Exempel på användning:**
```
/sync-docs
/sync-docs docs/adr/
```

**Föreslagen prompt:**
```markdown
---
description: Identify documentation that no longer matches the code
argument-hint: [optional: docs folder to focus on]
---

Scan documentation for drift from actual implementation.

## Analysis Categories

### 1. Implementation Plans
- Plans marked as "complete" but file still exists
- Step-by-step guides for finished migrations
- Debug/troubleshooting docs for resolved issues

### 2. Architecture Docs
- ADRs that describe superseded decisions
- Architecture guides with outdated patterns
- README files describing removed features

### 3. API Documentation
- Function signatures that changed
- Removed endpoints still documented
- Parameter changes not reflected

### 4. Feature Documentation
- Features that were removed
- Functionality that changed significantly
- Integration docs for removed dependencies

## Output Format

```markdown
## Documentation Drift Report

### Files to Delete (X files)
- path/to/file.md - Reason: [implementation complete/feature removed/etc.]

### Files to Update (Y files)
- path/to/file.md
  - Section "X": describes removed feature
  - Section "Y": outdated pattern reference

### Files OK (Z files)
- path/to/file.md ✓
```

Ask: "Should I proceed with deletions and updates?"
```

---

### 7. `/quick`

**Beskrivning:** Snabb fix utan konversation - för små, tydliga uppgifter.

**Motivering:**
- Din historik visar många "continue" för att driva arbete framåt
- För små uppgifter är overhead för frågor och bekräftelser onödig
- Passar ditt direkta kommunikationsstil ("yes", "no", "1", "2")

**Exempel på användning:**
```
/quick fix the typo in RecipeCard
/quick add missing import in auth_service
/quick rename userId to currentUserId in shopping_viewmodel
```

**Föreslagen prompt:**
```markdown
---
description: Quick fix without conversation - for small, clear tasks
argument-hint: <brief description of the fix>
---

Execute a quick, small fix without asking questions.

## Guardrails

This command is ONLY for:
- Typo fixes
- Missing imports
- Simple renames
- Adding missing semicolons/brackets
- Small, obvious corrections

This command is NOT for:
- Changes affecting multiple files
- Logic changes
- Architectural decisions
- Anything requiring verification

## Workflow

1. Parse the task description
2. Locate the relevant file(s)
3. Make the fix
4. Run `flutter analyze` on changed files
5. Report: "Fixed [X] in [file]. Analyze: [pass/fail]"

If the task is too complex for /quick, respond:
"This task is too complex for /quick. Use a regular request instead."

No todo lists, no phases, no questions - just fix and report.
```

---

### 8. `/test-coverage`

**Beskrivning:** Analysera testtäckning för en specifik fil eller modul.

**Motivering:**
- Projektet har 67.4% kodtäckning och en testing dashboard
- Din historik visar fokus på systematisk testning
- Du har `/test-generate` för att skapa tester, men inget för att analysera vad som saknas

**Exempel på användning:**
```
/test-coverage lib/services/unified/unified_recipe_service.dart
/test-coverage lib/viewmodels/
```

**Föreslagen prompt:**
```markdown
---
description: Analyze test coverage for a specific file or module
argument-hint: <file_path or directory>
---

Analyze test coverage for the specified file or directory.

## Analysis Steps

1. **Find Source Files**
   - Identify all .dart files in scope
   - Exclude generated files, mocks, test files

2. **Find Corresponding Tests**
   - Match source files to test files
   - Check test/unit/, test/widget/, test/integration/

3. **Coverage Analysis**
   For each source file:
   - Has test file? (yes/no)
   - Test file line count vs source line count (coverage ratio)
   - Key methods/classes tested?
   - Permission validation tested? (for repositories)
   - Edge cases covered?

4. **Gap Identification**
   - Files with no tests
   - Files with minimal tests (<30% coverage)
   - Critical paths not tested
   - Missing permission validation tests

## Output Format

```markdown
## Test Coverage Report: [path]

### Summary
- Files analyzed: X
- Files with tests: Y (Z%)
- Estimated coverage: XX%

### Coverage by File
| File | Test File | Coverage | Priority |
|------|-----------|----------|----------|
| auth_service.dart | ✓ auth_service_test.dart | 85% | - |
| backup_service.dart | ✗ None | 0% | HIGH |

### Recommended Actions
1. [HIGH] Create tests for backup_service.dart
2. [MEDIUM] Expand tests for shopping_viewmodel.dart
```

Ask: "Should I generate tests for the highest-priority gaps using /test-generate?"
```

---

## Sammanfattning

| Kommando | Syfte | Baserat på |
|----------|-------|------------|
| `/cleanup` | Städa död kod och docs | Historik: systematisk städning |
| `/refactor` | Analysera refaktoreringsmöjligheter | Projekt: 500-radersregel, facade pattern |
| `/fixall` | Analyze + automatisk fix | Historik: analyze → continue → fix loop |
| `/review` | Kvalitetskontroll före commit | Projekt: strikta konventioner, 7 agenter |
| `/phase` | Fasbaserat arbete med tracking | Historik: "continue with phase 2" pattern |
| `/sync-docs` | Hitta dokumentationsdrift | Historik + Projekt: minimal docs philosophy |
| `/quick` | Snabba fixes utan frågor | Historik: direkt kommunikationsstil |
| `/test-coverage` | Analysera testtäckning | Projekt: 67.4% coverage, testing focus |

Dessa kommandon kompletterar dina befintliga 8 kommandon och adresserar specifika mönster i hur du arbetar med detta projekt.
