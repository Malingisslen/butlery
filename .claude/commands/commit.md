---
description: Commit all changes made during the session
argument-hint: (no arguments required)
---

Commit all changes made during this session to git with an appropriate commit message.

## Workflow

1. Run `git status` and `git diff --staged` (stage with `git add` if needed)
2. Run `dart analyze` on changed .dart files — fix any issues before proceeding
3. **Quality gate — code review:**
   - Invoke the `code-reviewer` agent on all staged .dart files
   - If the agent finds **Critical** or **High** issues: fix them before proceeding
   - **Medium** and **Low** findings: note in commit body but don't block
4. **Quality gate — test coverage:**
   - Invoke the `testing-specialist` agent on all staged lib/ .dart files
   - The agent checks for corresponding test files and runs them
   - If tests fail: fix before proceeding
   - If no test file exists for a modified file: note the gap in commit body (don't block)
5. Create a conventional commit message:
   - Prefix: `feat:`, `fix:`, `refactor:`, `chore:`, `test:`, `docs:`
   - Subject: clear, concise description of what was accomplished
   - Body (always include for non-trivial changes):
     - *Why* this change was made — the problem or need it addresses
     - Design decisions and trade-offs considered
     - Invariants that must be preserved (e.g. "X must always be called before Y")
     - List key changes if multi-file
   - If review/test findings were noted, include: `Review notes: ...`
   - `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` footer
6. Commit the changes
7. If pre-commit hook fails: fix the issue, re-stage, create a NEW commit (never amend)
8. Confirm success with `git status`
8.5. **CI monitoring (if pushed):** If `git push` was executed during this flow, start a CI watcher:
   - Use Monitor tool: command `bash .claude/hooks/monitors/ci-watcher.sh $(git rev-parse HEAD)`, persistent: false, timeout_ms: 900000, description: "CI status for <short-sha>"
   - Continue with remaining steps — do not wait for CI
9. After successful commit, check `tasks/todo.md`:
   - If a task matches what was just committed, check it off (`[ ]` → `[x]`)
   - Report sprint progress: "Sprint: X/Y tasks done"
   - If all tasks are checked: "Sprint complete — run `/triage plan` for next sprint"
10. **Linear ticket update:**
    - Scan the commit message for BUT-XXX patterns
    - For each ticket reference where the corresponding todo.md task is now checked off:
      - Call `list_issue_statuses` to resolve "Done" state UUID
      - Call `get_issue` with BUT-XXX to get the Linear UUID
      - Call `save_issue` with id: <uuid>, stateId: <Done-uuid>
      - Call `save_comment` with: "Fixed in commit [7-char short hash]. Changes: [first line of commit body or subject]"
      - Report: "Closed BUT-XXX in Linear"
    - If Linear MCP is not connected, skip silently (morning brief catches stragglers)
