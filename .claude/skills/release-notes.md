---
name: release-notes
description: Generate Swedish-first release notes from Linear issues + git history since the last tag. Pulls Linear via MCP, cross-references BUT-XXX commit prefixes in git log, groups by Linear label (Feature / Fix / Improvement / Internal), and produces a markdown changelog ready to paste into the App Store / Play Store / GitHub release.
disable-model-invocation: true
---

# /release-notes — Generate Swedish-first release notes

## Why this is user-only

Release notes are a deliberate publishing act. Claude shouldn't infer "we
should generate release notes now" from context — only when you say so.

## What this produces

A markdown file at `docs/releases/<version>.md` with two sections:

1. **Swedish (user-facing)** — for App Store / Play Store / in-app changelog.
   Friendly tone, no internal jargon, no Linear IDs.
2. **English (internal)** — for GitHub release notes / changelog. Includes
   BUT-XXX references and grouped by Linear label.

## Args

- `<version>` (optional) — the version being released, e.g. `1.4.0`. If
  omitted, parses from `pubspec.yaml`.
- `<since>` (optional) — git ref to diff from. If omitted, uses the most
  recent `git tag` matching `v*`. Falls back to the last 30 commits if no
  tag exists.

## Workflow

1. **Resolve range**:
   - `SINCE=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || echo "HEAD~30")`
   - `UNTIL=HEAD`
2. **Pull commits**:
   - `git log "$SINCE..$UNTIL" --pretty=format:'%H|%s|%an|%ai'`
   - Extract any BUT-XXX prefixes from each subject.
3. **Pull Linear issues** for each BUT-XXX via `mcp__linear__get_issue`.
   Skip silently if Linear MCP is offline — fall back to commit subjects.
4. **Group by Linear label** (in order): Feature → Fix → Improvement → Internal.
   - "Internal" includes refactors, CI changes, test-only commits — drop
     these from the Swedish section, keep them in the English section.
5. **Translate or extract Swedish summary**:
   - If a Linear issue has a `swedish_summary` custom field or a "Swedish
     description" block in its body, use that verbatim.
   - Otherwise, generate a one-line Swedish summary from the issue title +
     description. Keep tone friendly, action-oriented (per the
     uiux-designer microcopy rules — see its knowledge file).
6. **Write to** `docs/releases/<version>.md` with this template:

   ```markdown
   # Butlery <version>

   *<RELEASE_DATE>*

   ## Vad är nytt? 🎉

   ### Nytt
   - <swedish summary of feature 1>
   - <swedish summary of feature 2>

   ### Förbättringar
   - <swedish summary of improvement 1>

   ### Buggfixar
   - <swedish summary of fix 1>

   ---

   <details>
   <summary>Internal changelog (English)</summary>

   ## Features
   - **BUT-XXX** Title (commit `abc1234`) — Linear issue summary
   - ...

   ## Fixes
   - ...

   ## Improvements
   - ...

   ## Internal
   - <commits without Linear IDs, refactors, CI tweaks>

   </details>
   ```

7. **Open** the file path in stdout so the user can paste/edit.

## Constraints

- **Never** include Linear IDs (`BUT-XXX`) in the Swedish section. Users
  don't care.
- **Never** include emoji-only commits or dependency bumps in the Swedish
  section. They land in "Internal" only.
- Group order: Feature first, then Fix, then Improvement, then Internal.
  This matches what users care about most.
- File is markdown; do NOT pre-translate to App Store ASCII-only — that
  conversion is a separate step done at upload time.

## Failure modes

- **Linear MCP offline** — fall back to commit subjects, mark each entry
  with `(linear unreachable)` in the internal section so the user knows
  to enrich manually.
- **No previous tag** — falls back to last 30 commits; warn in stdout.
- **No BUT-XXX in any commit** — generate purely from commit subjects;
  the Swedish section will be sparser but still works.

## After generation

- The user reviews + edits the Swedish section.
- Commit: `chore: release notes for v<version>`.
- Tag: `git tag -a v<version> -m "v<version>"`.
- Paste Swedish section into App Store Connect / Play Console.
