# Sprint Backlog

## Sprint: iter-73 — BUT-1084 sanitizer-surprise note — 2026-05-25 (Mon)

Theme: Doc-only — append the BUT-1061 sanitizer-warning pattern to testing-specialist.knowledge.md so future test authors don't get caught by the post-BUT-1061 `issues[]` warning when their fixtures use raw `<script>`. P4 tech-debt.

### Step 0 — premise verification

- Knowledge file at `.claude/agents/testing-specialist.knowledge.md`, 2317 lines.
- Grep confirms no existing BUT-1061 / sanitizer entry. New append needed.
- Classification: **fits** — trivial append.

### Ship this sprint

- [ ] **A1. Append dated entry** to `.claude/agents/testing-specialist.knowledge.md` capturing the post-BUT-1061 sanitizer warning behavior. (BUT-1084)

### Acceptance

- [ ] File grows by ~10 lines; no edits to existing entries.
- [ ] No `dart analyze` needed (markdown only).

### Post-Sprint Steps

- [ ] Commit + push (no agent gates needed for .md-only commit)
- [ ] Close BUT-1084

---

## Archived iter-72 (commit `907268f0b`) — 2026-05-25 (Mon)

BUT-1089 P4 — hardened RealtimeMenuFactory.parseRepositoryData + parseJsonData (fromMap fail-loud sibling of BUT-1071). +120 / −27. 25/25 tests pass.
