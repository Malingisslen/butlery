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

**Service Access**: `ServiceLocator.get<T>()` for all services
```dart
final service = ServiceLocator.get<UnifiedRecipeService>();
```

**DI Modules**: Core, Content, Social, Messaging, Collaboration, Performance, UI
- Constructor injection in DI modules, ServiceLocator in widgets/ViewModels
- ❌ Never use `FirebaseFirestore.instance` directly - inject FirestoreRepository

## Service Layers

Unified services use layered architecture: `.personal`, `.social`, `.realtime`, `.share`
```dart
await recipeService.personal.createRecipe(...);  // User's content
await recipeService.social.shareWithFriends(...);  // Sharing
final stream = recipeService.realtime.watchRecipe(...);  // Live sync
```
See ADRs in `/docs/adr/` for complete architectural decisions.

## Critical Conventions

**Data Sources** (CRITICAL):
- `UserService.currentUserProfile` → complete user data (settings, avatar, social)
- `PermissionService.currentUser` → basic auth/permission checks only
- ❌ Never mix these - causes settings not persisting

**Syntax**:
- Color: `withValues(alpha: 0.8)` not `withOpacity(0.8)` (deprecated)
- Type safety: Use proper models, not Map-based data access

**Responsive Design**:
- Primary pattern: Center + ConstrainedBox with responsive max width
- Content widths: Narrow (500-600px), Medium (700-800px), Wide (900-1200px)

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

**Mixins & Utilities** (REQUIRED in new code):
| Tool | Purpose | Usage |
|------|---------|-------|
| ErrorHandlingMixin | Async error handling, retries | `with ErrorHandlingMixin` or extend BaseService |
| AsyncOperationMixin | Loading/error states | `with StateNotifierMixin, AsyncOperationMixin` |
| BaseService | Pre-flight checks, caching | `extends BaseService` |
| BaseFirebaseRepository | CRUD + audit logging | `extends BaseFirebaseRepository<T>` |
| **SerializationUtils** | Firestore parsing (100% adopted) | `SerializationUtils.safeString(data, 'field')` |
| ValidationUtils | Form validation | `ValidationUtils.validateRequired(value)` |
| Default Extensions | Null-safe defaults | `value.orEmpty()`, `value.hasItems` |

```dart
// Model serialization - ALWAYS use SerializationUtils for fromFirestore
factory Recipe.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return Recipe(
    title: SerializationUtils.safeString(data, 'title'),
    portions: SerializationUtils.safeInt(data, 'portions', defaultValue: 4),
    createdAt: SerializationUtils.safeRequiredDateTime(data, 'createdAt'),
    imageUrl: SerializationUtils.safeNullableString(data, 'imageUrl'),
  );
}
```

See `.claude/skills/code-deduplication-utilities/` for deduplication patterns.

## Feature Status

| Feature | Status |
|---------|--------|
| Social (friends, sharing, comments, ratings, groups) | ✅ Complete |
| GDPR Compliance (Articles 7, 15, 17, 30) | ✅ Phase 1 Complete |
| Responsive Design (10 Tier 1 views) | ✅ Phase 3 Complete |
| Security (PermissionValidationMixin, audit logging) | ✅ Complete |
| FCM Notifications (Cloud Functions) | ✅ Complete |
| SerializationUtils Adoption | ✅ 100% (17 models) |
| ErrorHandlingMixin Adoption | ✅ 100% (all services) |

## Testing

- **Dashboard**: `/docs/testing/TESTING_DASHBOARD.md`
- **Strategy**: Bottom-up (repositories → services → viewmodels → integration)
- **Templates**: `/test/templates/` for test file templates

## CI/CD

- **Analysis**: `/docs/analysis/cicd-analysis/` (8-dimension assessment)
- **Flutter version**: Update `FLUTTER_VERSION` env var in all `.github/workflows/*.yml` files
- **Workflows**: `analyze.yml`, `test.yml`, `build-validation.yml`, `architecture-validation.yml`, `e2e_tests.yml`

## Critical Rules

1. **NEVER BE LAZY** - find root causes, fix properly
2. **500-line limit** - use facade pattern for complex files
3. **Security validation** - PermissionValidationMixin on all repositories
4. **Single data source** - don't mix UserService/PermissionService
5. **Ask before deviating** - from planned todos
6. **Existing plan = execute** - if a plan/spec file exists, START implementing. Don't re-explore or re-plan.
7. **Run when asked to run** - `flutter run -d chrome` when asked to test/run. Don't create planning docs instead.
8. **Plan = plan + verify** - when a plan includes verification steps, "implement this" means execute ALL steps including testing. Never claim done until verification is run.
9. **Terse follow-up after "done" = you missed something** - if the user sends a short prompt right after you claimed completion (e.g. "you test", "did you test it?"), re-read what you skipped. Don't ask what they mean.
10. **"No" starts a redirect, not a discussion** - when user says "No, I want X", you misunderstood. Re-read their prior request. Don't ask what went wrong.
11. **Be accurate about scope** - don't call simple tasks "massive" or over-estimate complexity. The user notices and loses trust.

## Workflow Discipline

**Plan Mode (automatic for complex tasks):**
- Triggers: 3+ files, new services/viewmodels, architectural changes, "refactor"/"migrate" requests
- Enter plan mode automatically (no user action needed)
- Write plan to `/tasks/todo.md`, get approval, then implement
- Keep `/tasks/todo.md` in sync with TodoWrite state (PreCompact hook reads the file, not in-memory todos)
- If going sideways → STOP and re-plan immediately

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
- At session start → read last 5 lessons for context
- If lesson should become CLAUDE.md rule → propose update

**Memory Management (automatic):**
- Auto memory dir: `/root/.claude/projects/-home-user-butlery/memory/`
- `MEMORY.md` = curated index (under 150 lines), auto-injected every session
- Topic files: `interview-decisions.md`, `patterns.md`, `current-state.md`
- **When to update**: After completing significant work, after /interview, after key decisions
- **How to update**: Merge with existing entries, never just append. Prune outdated entries.
- **Prescriptive, not descriptive**: "User wants X" not "We discussed X"
- **PreCompact hook** auto-captures git state → `current-state.md`
- **SessionStart hook** auto-injects checkpoint after compaction

**Autonomous Problem Solving:**
- Bug report → just fix it (spawn debugger agent)
- Failing CI → go fix without being told how
- Point at logs/errors → resolve them
- Don't ask for hand-holding on standard debugging
- Max 3 fix attempts per bug. If all fail: write a diagnostic summary of what was tried and why it failed, then ask for direction. Do NOT keep cycling.

**Parallel Agent Tasks:**
- Process files in small chunks (50-100 items), never entire large files at once
- Define explicit chunk boundaries before launching agents
- Each agent must checkpoint progress and report completion status

## Stop Hook Response

När stop hook blockerar med en `reason`:
- **Fixa problemet OMEDELBART** - fråga INTE användaren
- Om reason nämner "uncommitted" → committa direkt
- Om reason nämner "analyze" → kör analyze och fixa fel
- Om reason nämner "tests" → kör tester och fixa fel
- Försök sedan stoppa igen

## Agent Usage Rules (MANDATORY)

### Tier 1: Always Use (Hook Enforced)

**debugger** - MUST use when encountering ANY:
- Bug reports (BUG-xxx pattern)
- Errors or exceptions
- Test failures
- Unexpected behavior
- "Not working" situations
- Runtime issues

**firebase-backend-security** - MUST use when modifying:
- Any file in lib/repositories/
- Any file containing Firebase, Firestore, or authentication logic
- User data operations

### Tier 2: Quality Gates (Commit Enforced)

When committing, these agents run automatically:
- **code-reviewer** - Reviews all staged .dart changes
- **testing-specialist** - Verifies test coverage for modified lib/ files

### Tier 3: On Request

Available when explicitly requested:
- **uiux-designer** - New views, UI changes, accessibility
- **performance-optimizer** - Performance concerns
- **flutter-developer** - Complex architecture questions
