---
description: Commit, push, and hand off session to Claude Cloud for mobile continuation
argument-hint: [commit message or leave blank for auto-generated]
---

Hand off the current session to Claude Cloud so work can continue on mobile.

Commit message override: $ARGUMENTS

## Phase 1: Gather Context

### 1.1 Session Summary
Write a detailed summary of this session:
- What was the original task/goal?
- What approach was taken?
- Key decisions made and why
- Any blockers or concerns encountered

### 1.2 Files Changed
Run `git diff --stat` and `git status` to list:
- All modified files with brief description of changes
- Any new files created
- Any files deleted

### 1.3 Todo Status
Check the current todo list state:
- Which todos are completed?
- Which todos are still pending?
- Which todo was in progress?
- What's the logical next step?

## Phase 2: Quality Checks

### 2.1 Run Flutter Analyze
```bash
flutter analyze
```
- Note any errors, warnings, or infos
- Categorize: blocking vs non-blocking issues

### 2.2 Run Relevant Tests (if time permits)
If there are modified test files or testable changes:
```bash
flutter test test/unit/<relevant_path>
```
- Note pass/fail status
- If failures exist, note them for the handoff

## Phase 3: Commit and Push

### 3.1 Stage Changes
```bash
git add -A
```

### 3.2 Commit
Use provided message or generate one based on session summary.
Follow repository commit format:
```
<type>(<scope>): <description>

- Key change 1
- Key change 2

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

### 3.3 Push to Remote
```bash
git push
```
If no upstream, use `git push -u origin <branch>`.

## Phase 4: Create Cloud Handoff

### 4.1 Build Handoff Context
Create a comprehensive prompt for the cloud session that includes:

```
& Continue session: <brief task description>

## Context from previous session

### What was accomplished
<session summary from Phase 1.1>

### Files modified
<list from Phase 1.2>

### Current status
- Branch: <current branch>
- Last commit: <commit hash and message>
- Analyze status: <pass/fail with issue count>
- Test status: <pass/fail if run>

### Todo status
<from Phase 1.3>

### Next steps
<logical continuation based on todos and session context>

### Important notes
- <any blockers, decisions pending user input, or concerns>
- <architectural decisions that should be maintained>
- <files that should NOT be modified and why>

## Instructions
Continue working on the pending todos. Start by reading the relevant files to understand current state. Ask clarifying questions if the task is ambiguous.
```

### 4.2 Execute Handoff
Run the `&` command with the built context to send to Claude Cloud.

## Phase 5: Confirm Handoff

Output to user:
- Commit hash and message
- Remote push status
- Cloud session URL (from `&` output)
- `--teleport` command to resume locally later

Example output:
```
✅ Handoff complete!

📝 Committed: abc1234 - feat(tagging): improve threshold handling
🚀 Pushed to: origin/feature/tagging-improvements
☁️  Cloud session: https://claude.ai/code/session_xxx
📱 Monitor in Claude app → Code tab
💻 Resume locally: claude --teleport session_xxx
```
