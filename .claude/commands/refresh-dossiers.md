---
name: refresh-dossiers
description: Re-audit the role dossiers that went stale because code they own was edited. Reads the stale markers under docs/org/dossier-staleness/, re-reads the current code at each stale role's owned paths, updates that role's section in docs/architecture/ROLE_RESPONSIBILITY_MAP.md (Mandate / Evidence / Watch items) to match reality, then clears the markers. Interactive and $0 on Max. Pair to the dossier-freshness PostToolUse hook.
---

# /refresh-dossiers — keep role dossiers current with the code

The role map (`docs/architecture/ROLE_RESPONSIBILITY_MAP.md`) describes what each
of 28 roles owns and what it watches. When code a role owns changes, its dossier
can drift out of date. The `dossier-freshness-stamp.sh` PostToolUse hook flags the
affected role(s) by writing a marker under `docs/org/dossier-staleness/`. This skill
re-audits **only** the flagged roles and clears the flags. Runs **interactively**
(free on Max — never headless/metered). Design: `docs/architecture/ROLE_ORG_DESIGN.md`.

## Scope

- **No argument** → refresh every role with a marker in `docs/org/dossier-staleness/`.
- **A role name as argument** → refresh just that role (even if it has no marker).
- If there are no markers and no argument: report "all dossiers fresh" and stop.

## The loop

0. **Sync the path map.** Run `python tools/gen_role_paths.py` so
   `docs/org/role-paths.json` reflects the current map. (Cheap; harmless if unchanged.)
1. **Read markers.** List `docs/org/dossier-staleness/*.stale`. Each is JSON with the
   `role`, `stale_since`, and the `triggers` (the edited files that flagged it).
2. **Per stale role, re-audit against current code:**
   - Look up the role's owned globs in `docs/org/role-paths.json`.
   - Read the **trigger files** first (they're what changed), then spot-check the rest
     of the role's owned paths as needed.
   - Compare reality to the role's existing section in `ROLE_RESPONSIBILITY_MAP.md`:
     the **Mandate**, the prose, the **Watch items** (each has an _Evidence:_ path —
     verify the described behavior still exists), and the **Evidence** path list.
   - Update what drifted: stale descriptions, watch-items that were fixed or no longer
     apply, new files that should join the Evidence list, paths that moved. Keep the
     existing structure and tone. Line numbers are intentionally omitted from the map —
     don't add them. Don't invent issues; if nothing changed, the dossier may already
     be accurate (still clear the marker — the code was re-verified).
   - **Authority = flag-only.** This skill edits documentation, not app code. If the
     re-audit uncovers a real bug or security/privacy regression, do **not** fix it here
     — note it and file/raise it through the normal path (or, for legal/privacy, escalate
     to Malin), same as the world-watch loop.
3. **Clear the marker.** Delete `docs/org/dossier-staleness/<role-slug>.stale` once that
   role's section has been re-audited.
4. **Regenerate the path map** if you changed any role's Evidence paths:
   re-run `python tools/gen_role_paths.py`.
5. **Commit** `ROLE_RESPONSIBILITY_MAP.md`, the deleted markers, and (if changed)
   `role-paths.json`, with a terse message. Doc/.claude changes don't trip the `.dart`
   review gates.

## Output discipline

- Quiet when nothing drifted: "Re-audited N role(s); dossiers already accurate; markers cleared."
- When prose changed: one line per role — what drifted and what you updated.
- Cost guard: re-audit only the flagged roles, reading the trigger files first. Do **not**
  re-run the full 28-role multi-agent sweep — that's a deliberate, separate rebuild.

## Notes

- High-churn shared files (e.g. `lib/l10n/app_sv.arb`) flag several roles at once
  (UX Writer, Localization, Accessibility, Legal). That's expected; refresh them together.
- The markers are committed, so staleness persists across sessions until a refresh runs.
- This is the freshness-vs-code half of the role-org. The freshness-vs-world half is
  `/world-watch` (external sources). They're independent and both $0/interactive.
