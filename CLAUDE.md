# Claude Code Project Configuration

## Commands
- **Analysis**: `flutter analyze`
- **Run**: `flutter run`
- **Tests**: `flutter test test/unit/file_test.dart`
- **Path rule**: Always use forward slashes in test paths ✅

## Architecture

**Pattern**: MVVM + Repository (Views → ViewModels → Services → Repositories → Firebase)

**File Size**: 500 lines max. Use facade pattern for larger files.
- ✅ Exemplary: `recipe_form_viewmodel.dart` - delegates to 6 focused managers
- ⚠️ **33 files intentionally >500 lines** - see `/docs/architecture/ACCEPTED_LARGE_FILES.md` for list with reasons. Don't refactor these without reviewing the rationale first.

**Service Access**: `ServiceLocator.get<T>()` — constructor injection in DI modules, ServiceLocator in widgets/ViewModels
- ❌ Never use `FirebaseFirestore.instance` directly - inject FirestoreRepository
- Unified services use `.personal`, `.social`, `.realtime` modules (see `butlery-architecture` skill)

## Critical Conventions

**Data Sources** (CRITICAL — see `data-source-enforcer` skill):
- `userService.currentUserProfile` → complete user data (settings, avatar, social)
- `permissionService.currentUserId` → auth/permission checks only
- ❌ Never mix these — causes settings not persisting

**Syntax**:
- Color: `withValues(alpha: 0.8)` not `withOpacity(0.8)` (deprecated)
- Type safety: Use proper models, not Map-based data access

**Responsive Design**: Center + ConstrainedBox with responsive max width. See `responsive-layout-validator` skill for breakpoints and patterns.

**Commenting**:
- WHY not WHAT - code shows what, comments explain intent
- No doc comments on simple getters/private methods
- No section dividers (`// ===== SECTION =====`)
- All comments in English (UI strings stay Swedish)

**Documentation Files**: Prefer minimal documentation. Code should be self-documenting.
- Before creating any `.md` file, ask: Is this genuinely necessary? Could it go in an existing file?
- Prefer updating existing docs over creating new ones
- Avoid: README files for every directory, V1/V2 versions (update in place), analysis reports that won't be acted upon
- Cleanup mindset: Delete implementation plans once implemented, remove debug docs when resolved

**Git Safety**:
- NEVER run destructive git operations (checkout, reset, clean) with uncommitted changes
- Always run `git status` first; `git stash` if uncommitted work exists
- Ask user before any operation that could lose work

**Terse Prompt Signals** (user prompts are bimodal: detailed plans OR ultra-short commands):
| Signal | Meaning | Response |
|--------|---------|----------|
| `"continue"` | Resume at next step in current task | Don't ask "continue what?" - check plan/context and proceed |
| `"try it out"` / `"test it"` | Run the app and verify | Execute `flutter run -d chrome`, test, report result |
| Bare screenshot path | "Look at this" | Analyze proactively - describe what you see, don't ask what to look for |
| `"The issue remains"` | Previous fix failed | Try a DIFFERENT approach. Don't retry the same thing. |
| `"But..."` at start | Your previous claim was wrong | Stop and verify your claim before responding |
| `"are you really?"` | User doubts your statement | Actually verify (run command, check file) before confirming |
| `"what about X?"` | You missed/skipped something | Go check X immediately |
| `"Implement the following plan:"` | Complete spec, execute it | Don't ask clarifying questions. Parse and execute. |

**UI Mockup Comparison**:
- Be EXHAUSTIVE: check search box accents, avatar initials/images, icon colors, spacing, border radius, opacity, typography weight, and all small details
- List ALL differences, not just obvious ones
- Don't declare match until every element is verified

## Infrastructure

New code must use project mixins and base classes. See `mixin-advisor` skill for the decision table.

## Critical Rules

1. **NEVER BE LAZY** - find root causes, fix properly
2. **500-line limit** - use facade pattern for complex files
3. **Security validation** - PermissionValidationMixin on all repositories
4. **Single data source** - don't mix UserService/PermissionService
5. **Ask before deviating** - from planned tasks
6. **Existing plan = execute** - if a plan/spec file exists, START implementing. Don't re-explore or re-plan.
7. **Run when asked to run** - `flutter run -d chrome` when asked to test/run. Don't create planning docs instead.
8. **Plan = plan + verify** - when a plan includes verification steps, "implement this" means execute ALL steps including testing. Never claim done until verification is run.
9. **Terse follow-up after "done" = you missed something** - if the user sends a short prompt right after you claimed completion (e.g. "you test", "did you test it?"), re-read what you skipped. Don't ask what they mean.
10. **"No" starts a redirect, not a discussion** - when user says "No, I want X", you misunderstood. Re-read their prior request. Don't ask what went wrong.
11. **Be accurate about scope** - don't call simple tasks "massive" or over-estimate complexity. The user notices and loses trust.
12. **No retry loops on plan/review gates** - when exiting plan mode or completing a review gate, do it once. If the first attempt fails or is rejected, ask the user what they want instead of retrying the same action.

## Pre-Commit Checks

After making code changes, always run `dart analyze --fatal-infos` before committing. Fix any errors before staging.

## Git Workflow

Git pre-commit hooks (lefthook) exist in this project and may reformat files. After the first commit attempt, if it fails due to formatting, re-stage all changed files and commit again with the same message. Do not panic or start over.

Another Claude Code session may be running in parallel in a worktree or on a different branch. If `git status` shows unexpected changes or merge conflicts you didn't create, **stop and ask the user** — do not reset, clean, or force-push. The other session's work is just as important.

## Workflow Discipline

**Plan Mode (automatic for complex tasks):**
- Triggers: 3+ files, new services/viewmodels, architectural changes, "refactor"/"migrate" requests
- Enter plan mode automatically (no user action needed)
- Write plan to `/tasks/todo.md`, get approval, then implement
- Task state persists on disk - PreCompact hook reads both Claude Code tasks and `/tasks/todo.md`
- If going sideways → STOP and re-plan immediately
- Before presenting plans, review against `.claude/plan-review-checklist.md`

**Fit Check (when 2+ approaches exist):**
- Requirements as rows, approaches as columns
- Cells are strictly pass (Y) or fail (N) — no "maybe"
- Include ALL requirements, even ones that seem obvious
- Pick the approach with fewest fails; ties broken by simplicity

**Verification Before Done:**
- `flutter analyze` passes
- Relevant tests pass
- Diff behavior vs main if relevant
- Ask: "Would a staff engineer approve this?"
- For layout/UI bugs: test the fix in Chrome before declaring done. Never assume from static analysis alone.
- If first fix fails: STOP guessing. Find 3 similar working views, compare their layout pattern to the broken view, then fix based on the working pattern.

**Self-Improvement Loop (automatic):**
- After ANY user correction → add entry to `/tasks/lessons.md`
- Format: `### [Category] Title` + Date, Trigger, Rule, Example
- Categories: Architecture, Code Quality, Testing, Workflow, Firebase, UI/UX
- If lesson should become CLAUDE.md rule → propose update

**Memory Management:**
- Auto-memory is enabled — Claude manages MEMORY.md and topic files automatically
- `current-state.md` is managed by the PreCompact hook — do not overwrite it with auto-memory
- **Hooks** (fully automatic, no manual trigger):
  - PreCompact → captures git state + tasks → `current-state.md`
  - SessionStart (compact) → injects checkpoint as context after compaction
  - `/interview` → persists answers to `interview-decisions.md`

**Autonomous Problem Solving:**
- Bug report → just fix it (spawn debugger agent)
- Failing CI → go fix without being told how
- Point at logs/errors → resolve them
- Don't ask for hand-holding on standard debugging
- If stuck after multiple attempts: write a diagnostic summary of what was tried and why it failed, then ask for direction. Don't keep cycling.

**Parallel Agent Tasks:**
- Process files in small chunks (50-100 items), never entire large files at once
- Define explicit chunk boundaries before launching agents
- Each agent must checkpoint progress and report completion status
- When using parallel task agents for large plans, verify that agents are not overwriting each other's changes. After all agents complete, diff the working tree to confirm no regressions
- If the plan has 10+ items, process them sequentially or in small batches of 2-3 to avoid conflicts

## Stop Hook Response

När stop hook blockerar med en `reason`:
- **Fixa problemet OMEDELBART** - fråga INTE användaren
- Om reason nämner "uncommitted" → committa direkt
- Om reason nämner "analyze" → kör analyze och fixa fel
- Om reason nämner "tests" → kör tester och fixa fel
- Försök sedan stoppa igen

## Agent Usage Rules

### Tier 1: Strongly Recommended

**debugger** - Use when encountering: bug reports, errors/exceptions, test failures, unexpected behavior, runtime issues.

**firebase-backend-security** - Use when modifying: files in lib/repositories/, Firebase/Firestore/auth logic, user data operations.

### Tier 2: Quality Gates (Commit Enforced)

When committing, these agents run automatically:
- **code-reviewer** - Reviews all staged .dart changes
- **testing-specialist** - Verifies test coverage for modified lib/ files

### Tier 3: On Request

Available when explicitly requested:
- **uiux-designer** - New views, UI changes, accessibility
- **performance-optimizer** - Performance concerns
- **flutter-developer** - Complex architecture questions
