---
name: world-watch
description: Run the role-org horizon-scanning loop — poll each due role's authoritative external sources (law, app-store policy, CVEs, vendor changes), diff against the stored snapshot, impact-check deltas against the role's dossier, and route material findings to Linear per the role's authority. Interactive and $0 on Max. MVP covers Legal, Release/App-Store Compliance, and Security.
---

# /world-watch — horizon scanning for the role-org

Keeps the high-stakes roles current with the outside world despite the model's
knowledge cutoff. Runs **interactively** (free on Max — never headless/metered).
State of record: `docs/org/world-watch/state.json`. Design: `docs/architecture/ROLE_ORG_DESIGN.md`.

## Scope

- **No argument** → scan every role whose scan is **due** (`now - lastScan >= cadence`).
- **A role name as argument** → scan just that role, due or not (manual/on-demand).
- MVP roles: **Security Architect** (weekly, auto-ticket), **Release / App-Store
  Compliance Manager** (weekly, auto-ticket), **Legal Counsel** (monthly, escalate-human).

## The loop (per due role)

1. **Read** `docs/org/world-watch/state.json` for the role's `sources`, `watch_signals`,
   `authority`, and prior `snapshot`.
2. **Cheap poll.** `WebFetch` each source — prefer the RSS/Atom/`/whats-new`/`/release`
   endpoints already in the allowlist (they're the change-monitoring surfaces). Tolerate a
   blocked/403 fetch gracefully; note it, don't fail the run.
3. **Diff vs snapshot.** Compare what you see now to `snapshot[url]`. Emit **only deltas**
   (new advisory, new policy line, new guidance, version bump). First run has an empty
   snapshot — record current state as the baseline and only ticket a delta if it's clearly
   already actionable.
4. **Impact-check.** A delta matters only if it plausibly touches Butlery. Cross-reference
   the role's owned paths + watch-items in `docs/architecture/ROLE_RESPONSIBILITY_MAP.md`
   (e.g. a CVE only matters if the package is in `pubspec.lock`/`functions/package-lock.json`).
   Drop deltas with no plausible impact.
5. **Route by `authority`:**
   - `auto-ticket` (Security, Release) → create a **Linear** issue via the Linear MCP tools.
     Title = the change; body = what changed, **the source URL + a quoted snippet**, the
     concrete Butlery impact, and a suggested action. Label by role area.
   - `escalate-human` (Legal) → create a Linear issue **labelled for Malin's review**
     (do not assert a legal conclusion — present the change + source + why it may matter).
   - Never assert law/policy without a citation. Never auto-*act*; only flag/ticket/escalate.
   - **Fallback when Linear issue-creation tools are absent** (some sessions only expose the
     Linear status-update tools): do NOT fail. Emit the finding as a **ready-to-paste ticket
     draft** in chat (title + body) and offer to file it as a GitHub issue in
     `malingisslen/butlery` instead. Still update state so the finding isn't lost.
6. **Update state.** Write the new `snapshot` and set `lastScan` to today (ISO date) for
   each scanned role — **even if nothing was found** (so it doesn't re-fire). Commit
   `docs/org/world-watch/state.json` with a terse message.

## Output discipline

- Silent when nothing material is found (just update state + commit).
- When something is found: a one-line summary per finding with its Linear link. No essays.
- Cost guard: this is cheap by design — poll, diff, ticket. Do **not** launch deep multi-agent
  research unless a delta is genuinely ambiguous and high-stakes.

## Adding roles later

Append a role block to `state.json` (copy its `cadence`/`authority`/`sources` from the role's
World-watch entry in `ROLE_RESPONSIBILITY_MAP.md`). The due-check hook and this loop pick it up
automatically.
