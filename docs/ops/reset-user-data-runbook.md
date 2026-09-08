# Reset-user-data runbook (BUT-2028)

`functions/src/admin/reset-user-data.ts` wipes user data from the **production**
project (`admin-init.ts` hardcodes it — there is no environment switch). This
runbook covers the one thing about it that can go wrong quietly: the kill switch.

## TL;DR

- Preview: `cd functions && npm run reset-user-data:dry-run`. Changes nothing,
  sets no flag, prints no verdict.
- A live run asks you to type a phrase in full before it deletes anything. That
  prompt is the last human step. A test holds one shortcut shut: no script in
  `functions/package.json` may carry the phrase. A shell pipe still satisfies
  the prompt and no test holds that, so do not build one.
- A live run **suppresses `onUserDeleted`** for its duration by writing
  `system/__reset_in_progress`, and clears it in a `finally`.
- If the run ends and that document still exists, **report anonymisation and
  between-user cleanup are off for every real account deletion** until it goes.

## The kill switch

| | |
|---|---|
| Path | `system/__reset_in_progress` |
| Set by | `setResetKillSwitch` in `functions/src/shared/reset-kill-switch.ts` |
| Read by | `onUserDeleted`, uncached, once per account deletion — and by Phase 4 |
| Cleared by | the reset script's `finally`, or by hand |
| Expiry | 90 minutes from the last time the run stamped it. The run re-stamps it as it works. See `EXPIRED before the run ended` below. |

It lives in `system`, beside `system/config` (the LLM kill switch, BUT-439), and
**not** in `site_configs`, which every signed-in user can read and which
`log-parse-event.ts` writes at runtime. The `__` prefix keeps it from being
mistaken for a domain key such as `config` or `llmLimits`.

Expiry is enforced by the **reader**, not by a Firestore TTL policy. A TTL policy
is configured per collection, so arming one on `system` would point it at
`system/config` and delete the LLM kill switch on schedule.

### If the flag is stuck

Symptom: any of these.

- The run printed `FAILED TO CLEAR THE KILL SWITCH`.
- Phase 4 reported `system/__reset_in_progress: still present`.
- `onUserDeleted` is logging `SKIPPED — reset kill switch is set` in Cloud Logging.
- **You interrupted the run** (Ctrl-C, or the terminal closed). The script tries
  to clear the flag on interrupt, but if it was killed outright it cannot.

Fix: **delete the document** `system/__reset_in_progress` in the Firebase console.

**One exception.** If Phase 4 printed `belongs to run …, not this one`, another
reset is running right now and the flag is protecting *it*. Leave it alone until
that run finishes.

Otherwise that is the whole remedy. If nobody does, the expiry above makes the trigger
resume on its own — but the accounts deleted while it was set do not get a second
attempt, and nothing re-runs their cleanup.

`git revert` does not help here: the flag is a Firestore document, and the gate
sits in a **deployed** function — removing the suppression needs a deploy, not a
reverted commit.

## Reading the verdict

Phase 4 counts what is left and never deletes. Exit codes:

| Code | Verdict | Means |
|---|---|---|
| 0 | `CLEAN` | every probe answered, and answered zero |
| 1 | `NOT CLEAN` | rows remain, or the kill switch is still set |
| 2 | `INDETERMINATE` | a probe could not answer, or a phase had a soft failure |

`2` is not a softer `1` — it means the script could not tell.

**Neither code means "run it again."** Re-running is another full destructive
wipe, and the commonest cause of a `1` is a kill switch left standing, which is
fixed by deleting one document. Read the printed lines: they name the fault.

A third line to know: `EXPIRED before the run ended`. That means the suppression
lapsed while the wipe was still going, so the cleanup trigger was live during
part of Phase 2. Treat that run as raced.

**A clean verdict is not a guarantee of completion.** `onUserDeleted` is a gen1
Auth trigger with no bounded delivery time and no `retry`, so an event may still
arrive after Phase 4 — or may have been dropped entirely. A second sweep can prove
residue exists; nothing can prove it is finished.

## The unknown-collection report, and the pre-launch dry run (BUT-2043)

Every run prints **Unknown collections (report only, nothing was skipped)** after
the summary. Two questions, both answered from what the run actually saw in the
database rather than from what the code says:

- top-level collections present in the database and in none of the three lists;
- subcollection names the walk met that no inventory, no `KNOWN_SUBCOLLECTION_NAMES`
  entry and neither of the account cascade's own two lists accounts for.

**Why it exists.** BUT-2040 was `users/{uid}/rateLimits`, a spelling left behind by
a rename, with 5 rows still on disk. No source-scanning guard could find it — a
dead spelling has no writer to scan for — and the coverage guard in the cascade
suite derives its universe from source. It was found because a person read a dry
run's output closely. This report is that reading, done by the tool.

**The report never changes what a run does.** If it throws, it says so and the
run's verdict is unaffected.

**Its scope is narrower than it looks, and it prints that itself:** subcollections
are only enumerated beneath the collections the run DELETES. Nothing beneath a
kept or deliberately-untouched collection is walked, so "none" here is not a
clean bill of health for the whole database.

### Run the dry run before launch

```
cd functions
npm run reset-user-data:dry-run
```

Read the unknown-collection section. Anything it names is either a collection
that needs a decision (add it to one of the three lists) or an orphan like
BUT-2040's.

**Before launch, not on a schedule.** A recurring routine fails this repo's own
four-box test: it does not repeat weekly, it needs credentials and a person to
read the output, and "done" is not objective. It belongs on the path to going
live, when the population stops being test accounts. **Tracked as BUT-2045.**

The first run of this report, 2026-09-08, named collections no list decided,
including personal data no erasure path reached (BUT-2044). Read the output on
every run.

Two steps this leaves for a person, neither of which the report performs:

- `npx ts-node src/admin/migrate-friend-categories.ts` (dry run) and then
  `--live` moves any `users/{uid}/friendCategories` row onto the live spelling.
  Until it runs, such a row is deleted by the cascade rather than exported —
  see the BUT-2044 entries in `docs/architecture/ACCEPTED_DEVIATIONS.md`.
- Anything the report names is either a collection needing a decision (into one
  of the three lists) or an orphan of a rename. Neither closes itself.

## Before a live run

- The weekly scheduled jobs (`reconcileBlockMirrors`, `cleanup-old-notifications`,
  `purge-dormant-family-data`, and others) delete and write in the same
  collections, unaware a reset is running. Whether to pause Cloud Scheduler for
  the run is **open and undecided — BUT-2036**. Until it is decided, this is
  something to weigh yourself before starting a live run; nothing in the script
  handles it.
- The run writes its own record to Cloud Storage at `ops/resets/<runId>.json`
  **before** Phase 1, because every Firestore audit collection it could write to
  is in its own delete list. A file there with no matching verdict in the console
  output means a run started and did not finish.
