# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
Additional rules in `.claude/rules/` are auto-loaded.

## Commands
- **Analysis**: `flutter analyze`
- **Run**: `flutter run`
- **Tests**: `flutter test test/unit/file_test.dart`
- **Path rule**: Always use forward slashes in test paths

## Architecture

**Pattern**: MVVM + Repository (Views → ViewModels → Services → Repositories → Firebase)

See `.claude/rules/code-style.md` for file size limits, service access patterns, syntax, and commenting conventions.
See `.claude/rules/git-workflow.md` for git safety, pre-commit checks, and lefthook.
See `.claude/rules/workflow-discipline.md` for plan mode, verification, and self-improvement.
See `.claude/rules/ui-conventions.md` for responsive design and mockup comparison (scoped to views/widgets).

## Critical Conventions

**Data Sources** (CRITICAL — see `data-source-enforcer` skill):
- `userService.currentUserProfile` → complete user data (settings, avatar, social)
- `permissionService.currentUserId` → auth/permission checks only
- Never mix these — causes settings not persisting

## Infrastructure

New code must use project mixins and base classes. See `mixin-advisor` skill for the decision table.

## Critical Rules

1. **Find root causes** - prefer proper fixes over quick patches. If you can't find the root cause, say what you investigated and why you're stuck.
2. **500-line limit** - use facade pattern for complex files
3. **Security validation** - PermissionValidationMixin on all repositories
4. **Single data source** - don't mix UserService/PermissionService
5. **Ask before deviating** - from planned tasks
6. **Existing plan = execute** - if a plan/spec file exists, START implementing. Don't re-explore or re-plan.
7. **Run when asked to run** - `flutter run -d chrome` when asked to test/run. Don't create planning docs instead.
8. **Plan = plan + verify** - when a plan includes verification steps, "implement this" means execute ALL steps including testing. If a verification step fails or can't run, report what happened instead of claiming done.
9. **Terse follow-up after "done" = you missed something** - if the user sends a short prompt right after you claimed completion, re-read what you skipped. Don't ask what they mean.
10. **"No" starts a redirect, not a discussion** - when user says "No, I want X", you misunderstood. Re-read their prior request. Don't ask what went wrong.
11. **Be accurate about scope** - don't call simple tasks "massive" or over-estimate complexity.
12. **No retry loops on plan/review gates** - when exiting plan mode or completing a review gate, do it once. If the first attempt fails or is rejected, ask the user what they want instead of retrying the same action.
13. **Learn from corrections** - when the user corrects you ("no", "wrong", redirects, terse follow-up after "done"), IMMEDIATELY add an entry to `tasks/lessons.md` before doing anything else. Format: `### [Category] Title` + Date, Trigger, Rule, Example. Non-negotiable.

## Honesty Over Completion
- Saying "I don't know" or "this isn't working" is always acceptable
- A partial solution with clear docs of what's missing beats a complete solution that papers over problems
- If tests pass but you're not confident the fix is correct, say so
- Never claim "done" if you skipped verification steps — say which ones and why
- When stuck: describe what you tried, what failed, and where you'd look next

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
