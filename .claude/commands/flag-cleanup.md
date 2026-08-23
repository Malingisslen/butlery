---
name: flag-cleanup
description: Audit Firebase Remote Config feature flags for orphans. Diffs flag keys defined in lib/services/feature_flags/feature_flag_service.dart and call sites in lib/ against the live Remote Config template (via Firebase MCP). Reports flags-in-code-but-not-in-remote (crash-on-lookup risk), flags-in-remote-but-not-in-code (orphan debt), and flags older than N months (cleanup candidates).
disable-model-invocation: true
---

# /flag-cleanup — Remote Config feature-flag audit

## Why this is user-only

It's a diagnostic. Don't run autonomously — flag debt accumulates slowly
and the audit is a deliberate cleanup ritual, usually quarterly.

## What it produces

A markdown report at `tasks/flag-audit-<YYYY-MM-DD>.md` with three sections:

1. **Critical — flags read in code but missing from remote** — these will
   silently return defaults forever. Either add to remote or remove the
   read.
2. **Cleanup candidates — flags in remote but no longer read in code** —
   orphans. Safe to delete.
3. **Stale flags — in both, but no value change in N+ months** — likely
   permanent decisions; flatten to code constant.

## Workflow

### 1. Enumerate code-side flags

The single source of truth in `lib/` is
`lib/services/feature_flags/feature_flag_service.dart`. Grep:

- The `_defaults` map for declared flag keys.
- All call sites: `_remoteConfig.getBool('FLAG_KEY')`, `getInt`, `getString`,
  `getDouble`. Use a project-wide grep:

  ```bash
  grep -rn "_remoteConfig\.\(get[BISD][a-z]*\)\(['\"]\([^'\"]*\)['\"]\)" lib/ --include="*.dart"
  ```

  Plus any `FirebaseRemoteConfig.instance.get*` calls (e.g. in `llm_service.dart`).

### 2. Pull live remote template

Via Firebase MCP (already connected):
- List Remote Config parameters and their last-update timestamps.

### 3. Diff

| Set | Action |
|---|---|
| In code, not in remote | **Critical** — crashes-on-lookup risk |
| In remote, not in code | **Cleanup** — safe to delete from remote |
| In both | Keep, but mark "stale" if last-modified > 6 months |

### 4. Write report

Use this template (Swedish headings, since the project's UI is Swedish —
report keeps the same convention for consistency):

```markdown
# Feature flag audit — <YYYY-MM-DD>

## Kritiskt — flaggor i kod, saknas i remote (N st)

- `FLAG_KEY_NAME` — read in `path/to/file.dart:LINE` — never has a
  remote value, always returns the default.
- ...

## Städkandidater — flaggor i remote, ej i kod (N st)

- `OLD_FLAG_KEY` — last modified YYYY-MM-DD, no call site found.
- ...

## Inaktiva flaggor — i båda men oförändrade > 6 månader (N st)

- `MATURE_FLAG` — last value change YYYY-MM-DD. Consider flattening to a
  code constant if this is a permanent decision.
- ...

## Sammanfattning

- N flaggor totalt
- M kritiska
- O städkandidater
- P inaktiva
```

### 5. Attach next-actions

For each Critical entry: propose the smallest fix (add to remote OR remove
the read). Don't apply automatically — surface to the user.

For each Cleanup entry: provide the Firebase Console URL or the CLI command
to delete:

```bash
firebase remoteconfig:get --output current.json
# manually edit, then:
firebase deploy --only remoteconfig
```

## Failure modes

- **Firebase MCP unavailable** — fall back to reading the most recent
  exported `remoteconfig.json` if one exists in the repo. Otherwise stop
  and report the limitation.
- **Dynamic flag keys** — if a `getBool()` call uses a non-string-literal
  argument (e.g. a constant), surface that file/line as "could not
  statically resolve flag key — manual review needed."

## What NOT to do

- Do not delete flags from remote autonomously. Surface for the user.
- Do not "rationalize" the audit by removing entries that look harmless.
  The whole point is the full picture.
- Do not run more often than quarterly without reason — flag churn is
  natural, and the report has signal-to-noise issues if it runs weekly.
