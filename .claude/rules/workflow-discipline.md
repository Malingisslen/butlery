# Workflow Discipline

## Plan Mode (automatic for complex tasks)
- Triggers: 3+ files, new services/viewmodels, architectural changes, "refactor"/"migrate" requests
- Enter plan mode automatically (no user action needed)
- Write plan to `/tasks/todo.md`, get approval, then implement
- Task state persists on disk - PreCompact hook reads both Claude Code tasks and `/tasks/todo.md`
- If going sideways → STOP and re-plan immediately
- Before presenting plans, review against `.claude/plan-review-checklist.md`
- **Plain-language summary (MANDATORY):** Every plan MUST end with a section called "## What this means in plain language" that:
  - Explains what the user will notice changing (new button, different behavior, etc.)
  - Uses zero technical jargon — no "viewmodel", "repository", "mixin", "provider", "widget tree"
  - Summarizes the risk: what could break, and how easy it is to undo
  - Is max 5-8 bullet points, written as if explaining to a friend who doesn't code

## Fit Check (when 2+ approaches exist)
- Requirements as rows, approaches as columns
- Cells are strictly pass (Y) or fail (N) — no "maybe"
- Include ALL requirements, even ones that seem obvious
- Pick the approach with fewest fails; ties broken by simplicity

## Verification Before Done
- `flutter analyze` passes
- Relevant tests pass
- Diff behavior vs main if relevant
- Ask: "Would a staff engineer approve this — including approving 'I'm stuck' as an honest answer?"
- For layout/UI bugs: test the fix in Chrome before declaring done
- If first fix fails: STOP guessing. Find 3 similar working views, compare their layout pattern to the broken view, then fix based on the working pattern.

## Demand Diagnosis (Balanced)
- For non-trivial changes, before presenting: ask "is there a more elegant way to do this?"
- If a fix feels hacky, redo it: "Knowing everything I know now, implement the clean solution from scratch."
- **Balance clause (do not skip):** for simple, obvious, or one-line fixes, ship it — don't gold-plate. This rule serves quality on substantial work; on trivial work it would just fight rule #7 (don't over-estimate complexity) and "minimal impact".
- Trigger: applies when a change touches 3+ files, adds a service/viewmodel, or the first working version felt like a workaround. Skip otherwise.

## Self-Improvement Loop (automatic)
- After ANY user correction → add entry to `/tasks/lessons.md`
- Format: `### [Category] Title` + Date, Trigger, Rule, Example
- Categories: Architecture, Code Quality, Testing, Workflow, Firebase, UI/UX
- If lesson should become CLAUDE.md rule → propose update

## Memory Management
- Auto-memory is enabled — Claude manages MEMORY.md and topic files automatically
- `current-state.md` is managed by the PreCompact hook — do not overwrite it with auto-memory
- **Hooks** (fully automatic, no manual trigger):
  - PreCompact → captures git state + tasks → `current-state.md`
  - SessionStart (compact) → injects checkpoint as context after compaction
  - `/interview` → persists answers to `interview-decisions.md`

## Autonomous Problem Solving
- Bug report → just fix it (spawn debugger agent)
- Failing CI → go fix without being told how
- Point at logs/errors → resolve them
- Don't ask for hand-holding on standard debugging
- If stuck after multiple attempts: write a diagnostic summary of what was tried and why it failed, then ask for direction

## Parallel Agent Tasks
- Process files in small chunks (50-100 items), never entire large files at once
- Define explicit chunk boundaries before launching agents
- Each agent must checkpoint progress and report completion status
- When using parallel task agents for large plans, verify that agents are not overwriting each other's changes
- If the plan has 10+ items, process them sequentially or in small batches of 2-3 to avoid conflicts
