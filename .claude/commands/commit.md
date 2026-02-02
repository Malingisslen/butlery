---
description: Commit all changes made during the session
argument-hint: (no arguments required)
---

Commit all changes made during this session to git with an appropriate commit message.

Follow the established commit message format used in this repository and include:
- Clear description of what was accomplished
- List of key changes or improvements
- Proper categorization (feat:, fix:, refactor:, etc.)
- Generated with Claude Code footer

## Pre-Commit Lesson Check

If `/tasks/lessons.md` exists:
1. Review last 5 entries
2. Verify none were violated in staged changes
3. If a lesson was specifically followed, note in commit message

## Pre-Commit Quality Gates (MANDATORY)

Before creating any commit, you MUST run these agents:

### 1. code-reviewer Agent
Spawn the `code-reviewer` agent to review all staged .dart files:
- Architecture compliance (MVVM, mixins, ServiceLocator)
- Security patterns (PermissionValidationMixin, no direct Firebase)
- Code quality (SerializationUtils, no deprecated APIs)
- Comment quality (WHY not WHAT)

### 2. testing-specialist Agent (if lib/ modified)
If ANY lib/ files are staged, spawn the `testing-specialist` agent:
- Verify tests exist for modified ViewModels/Services
- Check test coverage isn't reduced
- Ensure critical tests aren't skipped

### 3. Gate Logic
- If code-reviewer finds BLOCKING issues → fix before commit
- If testing-specialist finds coverage gaps → add tests before commit
- Only proceed to git commit after agents approve

## Git Workflow

After quality gates pass, use the standard git workflow:
1. Stage all changes with `git add .`
2. Create a descriptive commit message
3. Commit the changes
4. Confirm the commit was successful