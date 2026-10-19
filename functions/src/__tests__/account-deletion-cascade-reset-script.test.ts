/**
 * BUT-1766 / BUT-1768: deletion cascade reset script scenarios, split out of
 * `account-deletion-cascade.test.ts` (BUT-2113). Shared fakes and seeds are
 * `_account-deletion-cascade-fake-firestore.ts` and `_account-deletion-cascade-test-seeds.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade-reset-script.test.ts
 */

import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import {
  check,
  finishSuite,
} from "./_account-deletion-cascade-test-seeds";

/**
 * BUT-1917: the DECLINE path names a recovery, and this pins the half of it
 * that is checkable here.
 *
 * `MAX_BLOCK_SWEEP_ROWS` says that above the cap the leg declines and a human
 * recovers by running `admin/reset-user-data.ts`. That script is list-driven —
 * it iterates `COLLECTIONS_TO_DELETE` — so membership in that list is
 * NECESSARY for the recovery to reach this collection. It was absent, and the claim had been inherited from
 * `MAX_ROSTER_SWEEP_ROWS`, where `conversations` IS listed.
 *
 * Membership is not SUFFICIENT, and this scenario does not claim it is. The
 * script also has to RUN, which it did not between 2026-03-19 and 2026-09-05
 * (BUT-2010).
 *
 * Asserted rather than written down, because prose is what let one docstring
 * borrow another's reasoning in the first place.
 */
async function scenario_resetScriptDeleteListNamesBlocks(): Promise<void> {
  // Imported, not parsed. The lists moved to their own side-effect-free module
  // in BUT-2028 precisely so this could stop reading source text — the old form
  // needed comment-stripping and an anchor on the list's last entry, and the
  // anchor carried a note telling the next person to move it when they append.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { COLLECTIONS_TO_DELETE } = require("../admin/reset-collection-lists");
  const names = (COLLECTIONS_TO_DELETE as { name: string }[]).map((t) => t.name);

  check(
    "the reset script's delete list is non-empty",
    names.length > 0,
    "COLLECTIONS_TO_DELETE imported as empty — the check below would pass " +
      "vacuously",
  );

  check(
    "the reset script's delete list names `blocks`",
    // The constant, not the literal "blocks": production reads the collection
    // through `Collections.blocks`, and a test restating the string would keep
    // passing if the two ever diverged.
    names.includes(Collections.blocks),
    "`MAX_BLOCK_SWEEP_ROWS` tells a human to recover by running " +
      "admin/reset-user-data.ts, but that script only deletes what " +
      "COLLECTIONS_TO_DELETE names, and it does not name this collection — so " +
      "the declined rows would survive a full reset",
  );
}

/**
 * BUT-2010: the reset script's two lists must not overlap.
 *
 * This is the invariant whose breach made the script do NOTHING for five and a
 * half months. `tag_configs` sat in both `COLLECTIONS_TO_DELETE` and
 * `COLLECTIONS_TO_KEEP`, so the script's own safety guard exited before Phase 1
 * on every run — correctly, since deleting seed data is exactly what that guard
 * exists to prevent.
 *
 * The guard was never the problem. Nothing NOTICED it was firing: the script is
 * run by hand, rarely, and an early `process.exit(1)` reads like a refusal
 * rather than a defect. Meanwhile `MAX_BLOCK_SWEEP_ROWS` named it as the
 * recovery for a declined Art. 17 erasure, which made a broken script into a
 * written promise.
 */
async function scenario_resetScriptListsDoNotOverlap(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const lists = require("../admin/reset-collection-lists");
  const toDelete = (lists.COLLECTIONS_TO_DELETE as { name: string }[]).map(
    (t) => t.name,
  );
  const toKeep = lists.COLLECTIONS_TO_KEEP as string[];

  // Both lists are imported, so a partially-read list is no longer a failure
  // mode and the last-entry anchors that guarded against one are gone with it.
  // What survives is an emptiness check: a disjointness filter over an empty
  // list passes while proving nothing, which is exactly what happened to the
  // text-parsing version of this scenario the moment the lists moved.
  check(
    "the reset script's lists are both non-empty",
    toDelete.length > 0 && toKeep.length > 0,
    `imported ${toDelete.length} delete and ${toKeep.length} keep entries — ` +
      "the disjointness check below would pass vacuously",
  );

  const overlap = toDelete.filter((name) => toKeep.includes(name));
  check(
    "the reset script's delete and keep lists are disjoint",
    overlap.length === 0,
    `${overlap.join(", ")} is in BOTH lists, so reset-user-data.ts exits at ` +
      "its overlap guard before Phase 1 and deletes nothing at all — which is " +
      "how it stayed inert from 2026-03-19 to 2026-09-05 while " +
      "MAX_BLOCK_SWEEP_ROWS named it as the recovery for a declined " +
      "Art. 17 erasure",
  );
}

/**
 * BUT-2028: the reset kill switch, exercised rather than described.
 *
 * `admin/reset-user-data.ts` deletes every Auth user in Phase 1, which fires
 * `onUserDeleted` into collections Phase 2 is concurrently deleting. The switch
 * suppresses the trigger for the run.
 *
 * A flag that sticks ON silently stops report anonymisation and between-user
 * cleanup on every REAL account deletion, so the self-healing half is what
 * these checks are mostly about. Its own local fake, not `FakeFirestore`: the
 * shared one has no top-level `doc(path)`.
 */
async function scenario_resetKillSwitchSelfHeals(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const ks = require("../shared/reset-kill-switch");

  /** Minimal `db.doc(path)` store — get, set, delete, nothing else. */
  function makeStore() {
    const docs = new Map<string, Record<string, unknown>>();
    const deleted: string[] = [];
    const db = {
      // `clearResetKillSwitch` compares the stored run id inside a
      // transaction, so the store has to offer one. Modelled, not stubbed to
      // pass through: a transaction whose `get` returned nothing would make
      // the compare succeed vacuously.
      async runTransaction<T>(
        handler: (tx: {
          get(ref: { path: string }): Promise<{
            exists: boolean;
            data(): Record<string, unknown> | undefined;
          }>;
          delete(ref: { path: string }): void;
        }) => Promise<T>,
      ): Promise<T> {
        return handler({
          get: async (ref) => ({
            exists: docs.has(ref.path),
            data: () => docs.get(ref.path),
          }),
          delete: (ref) => {
            deleted.push(ref.path);
            docs.delete(ref.path);
          },
        });
      },
      doc(path: string) {
        return {
          path,
          get: async () => ({
            exists: docs.has(path),
            data: () => docs.get(path),
          }),
          set: async (
            data: Record<string, unknown>,
            options?: { merge?: boolean },
          ) => {
            // `{merge: true}` is MODELLED rather than ignored. A fake that
            // always replaced could not tell a merging `set` from a replacing
            // one, so the no-merge check below would pass against the very
            // change it exists to catch.
            docs.set(
              path,
              options?.merge ? { ...(docs.get(path) ?? {}), ...data } : data,
            );
          },
          delete: async () => {
            deleted.push(path);
            docs.delete(path);
          },
        };
      },
    };
    return { db: db as unknown as admin.firestore.Firestore, docs, deleted };
  }

  const path = ks.RESET_KILL_SWITCH_PATH as string;

  // 1. No document at all — the normal state, and it must read as OFF.
  {
    const { db } = makeStore();
    const state = await ks.readResetKillSwitch(db);
    check(
      "an absent kill switch reads as inactive",
      state.active === false && state.expired === false,
      `absent flag read as ${JSON.stringify(state)}`,
    );
  }

  // 2. Set and unexpired — the only state that suppresses the trigger. claim-lint:ok moved unchanged, BUT-2113
  {
    const { db, docs } = makeStore();
    await ks.setResetKillSwitch(db, "run-1");
    const state = await ks.readResetKillSwitch(db);
    check(
      "a freshly set kill switch reads as active",
      state.active === true && state.runId === "run-1",
      `set flag read as ${JSON.stringify(state)}; stored ` +
        JSON.stringify(docs.get(path)),
    );
  }

  // 3. Expired — the self-healing half. This is what stands between an
  // abandoned run and a permanently suppressed cleanup trigger, and it is
  // enforced by the READER: a Firestore TTL policy is configured per
  // collection, so arming one on `system` would point it at `system/config`,
  // the LLM kill switch, and delete that on schedule.
  {
    const { db } = makeStore();
    await ks.setResetKillSwitch(db, "run-2", -1); // expired one minute ago
    const state = await ks.readResetKillSwitch(db);
    check(
      "an expired kill switch reads as inactive",
      state.active === false && state.expired === true,
      `expired flag read as ${JSON.stringify(state)} — the trigger would stay ` +
        "suppressed after the run that set it has ended",
    );
  }

  // 4. A document with no usable expiry. Deliberately treated as EXPIRED
  // rather than as active: failing closed here would let one malformed write
  // disable the cleanup trigger with nothing to notice, since the run that
  // wrote it has ended and the verification phase only inspects its own run.
  {
    const { db } = makeStore();
    await ks.setResetKillSwitch(db, "run-3");
    const store = db as unknown as { doc(p: string): { set(d: unknown): Promise<void> } };
    await store.doc(path).set({ active: true, runId: "run-3" });
    const state = await ks.readResetKillSwitch(db);
    check(
      "a kill switch with no expiry reads as inactive, not as active forever",
      state.active === false && state.expired === true,
      `expiry-less flag read as ${JSON.stringify(state)}`,
    );
  }

  // 5. `set` must not merge. A merge would inherit `active`, `runId` and
  // `expiresAt` from an abandoned earlier run, so a half-written flag could
  // survive into a run that believes it wrote its own.
  {
    const { db, docs } = makeStore();
    const store = db as unknown as { doc(p: string): { set(d: unknown): Promise<void> } };
    await store.doc(path).set({ leftover: "from an older run", active: false });
    await ks.setResetKillSwitch(db, "run-4");
    check(
      "setting the kill switch replaces the document rather than merging",
      docs.get(path)?.leftover === undefined,
      `an older run's field survived: ${JSON.stringify(docs.get(path))}`,
    );
  }

  // 6b. `exists` is what the verification phase asks. The predicate it
  // replaced — active || expired || runId — answers FALSE for a document with
  // a future expiry, `active: false` and no run id, which is exactly the
  // "tidy record" shape that deleting-rather-than-flagging exists to forbid.
  {
    const { db } = makeStore();
    const store = db as unknown as { doc(p: string): { set(d: unknown): Promise<void> } };
    await store.doc(path).set({
      active: false,
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 3_600_000),
    });
    const state = await ks.readResetKillSwitch(db);
    check(
      "a leftover kill-switch document is reported even when it is inert",
      state.exists === true &&
        state.active === false &&
        state.expired === false &&
        state.runId === undefined,
      `inert leftover read as ${JSON.stringify(state)} — the verification ` +
        "phase would call the run clean with a document still standing",
    );
  }

  // 6c. A read that THROWS. The contract matters because the trigger's call
  // sits above its own try: `readResetKillSwitch` propagates, so the caller
  // must fail open itself or a transient Firestore error costs that account
  // its whole cascade, on a gen1 trigger that drops the event.
  {
    const db = {
      doc: () => ({
        get: async () => {
          throw Object.assign(new Error("unavailable"), { code: 14 });
        },
      }),
    } as unknown as admin.firestore.Firestore;
    let threw = false;
    try {
      await ks.readResetKillSwitch(db);
    } catch {
      threw = true;
    }
    check(
      "a failed kill-switch read propagates rather than reading as active",
      threw,
      "readResetKillSwitch swallowed a read failure — a caller cannot tell " +
        "`no flag` from `could not ask`, and the safe answer differs",
    );
  }

  // 6d. Clearing compares the run id. Two overlapping runs are implausible
  // behind the confirmation gate; the failure if they happen is the one this
  // module exists to prevent, so the compare is cheap insurance.
  {
    const { db, docs } = makeStore();
    await ks.setResetKillSwitch(db, "run-A");
    const cleared = await ks.clearResetKillSwitch(db, "run-B");
    check(
      "clearing with a different run id leaves another run's flag standing",
      cleared === false && docs.has(path),
      `clear returned ${cleared}; document still stored: ${docs.has(path)}`,
    );
    const clearedOwn = await ks.clearResetKillSwitch(db, "run-A");
    check(
      "clearing with the matching run id removes the flag",
      clearedOwn === true && !docs.has(path),
      `clear returned ${clearedOwn}; document still stored: ${docs.has(path)}`,
    );
  }

  // 6. Clearing DELETES. Setting `active: false` instead would make a leftover
  // document sometimes a tidy record and sometimes a fault; the verification
  // phase asks whether it is gone, which needs one right answer.
  {
    const { db, docs, deleted } = makeStore();
    await ks.setResetKillSwitch(db, "run-5");
    await ks.clearResetKillSwitch(db);
    check(
      "clearing the kill switch deletes the document",
      deleted.includes(path) && !docs.has(path),
      `after clear: deleted=${JSON.stringify(deleted)}, still stored=` +
        `${docs.has(path)}`,
    );
  }
}

/**
 * BUT-2028: the switch is wired into the two places that must honour it.
 *
 * Source checks, and they prove REFERENCE and ORDER, not effect — the trigger
 * is a `v1.auth.user().onDelete()` wrapper with a module-scope `db`, so there
 * is no seam to inject a store through. Each check below is written to fail on
 * the specific way its half stops working, and each was mutation-probed.
 */
async function scenario_resetKillSwitchIsWiredIn(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const ks = require("../shared/reset-kill-switch");

  const functionsSrc = path.join(__dirname, "..");
  /** Comment lines dropped: commenting a guard out is the cheapest disarm. */
  const readCode = (rel: string): string =>
    (fs.readFileSync(path.join(functionsSrc, rel), "utf8") as string)
      .split("\n")
      .filter((line: string) => !line.trim().startsWith("//"))
      .join("\n");

  // --- The document id cannot collide with a domain key -------------------
  const docId = ks.RESET_KILL_SWITCH_DOC_ID as string;
  check(
    "the kill switch's document id cannot be mistaken for a domain key",
    docId.startsWith("__"),
    `the flag lives at ${ks.RESET_KILL_SWITCH_PATH} — every other document in ` +
      "`system` is a domain key (config, llmLimits, prompts), and a name that " +
      "looks like one invites a future writer to merge the flag into a config " +
      "document, or a config write to clear the flag",
  );

  // Measured against the repo rather than asserted: every OTHER `system/…`
  // document path written anywhere in functions/src.
  const otherSystemDocs = new Set<string>();
  (function walk(dir: string) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory()) {
        if (entry.name === "__tests__") continue;
        walk(path.join(dir, entry.name));
      } else if (entry.name.endsWith(".ts")) {
        const source: string = fs.readFileSync(path.join(dir, entry.name), "utf8");
        // Every `system/…` literal written OUTSIDE the kill-switch module.
        // Excluding the flag's own id here instead would make the check
        // unable to see a collision at all: pointing the flag at
        // `system/config` would simply stop adding `config` to the set.
        if (path.join(dir, entry.name).endsWith("reset-kill-switch.ts")) continue;
        for (const m of source.matchAll(/"system\/([A-Za-z0-9_]+)"/g)) {
          otherSystemDocs.add(m[1]);
        }
      }
    }
  })(functionsSrc);
  check(
    "the kill switch does not share its document with any other system flag",
    otherSystemDocs.size > 0 && !otherSystemDocs.has(docId),
    `other system/ documents found: ${[...otherSystemDocs].join(", ") || "none"}` +
      " — none found at all means this check stopped measuring anything",
  );

  // --- onUserDeleted honours it, before doing any work --------------------
  const trigger = readCode("cleanup/on-user-deleted.ts");
  const handlerAt = trigger.indexOf(".onDelete(async (user)");
  const readAt = trigger.indexOf("readResetKillSwitch(", handlerAt);
  const cleanupAt = trigger.indexOf("cleanupUserSocialData(", handlerAt);
  check(
    "onUserDeleted reads the kill switch before it cleans anything up",
    handlerAt >= 0 && readAt > handlerAt && cleanupAt > readAt,
    `in the handler: read at ${readAt}, cleanupUserSocialData at ` +
      `${cleanupAt} — the trigger would write into collections Phase 2 is ` +
      "concurrently deleting",
  );
  check(
    "onUserDeleted RETURNS when the kill switch is set",
    // Presence of the read proves nothing on its own: logging the flag and
    // carrying on is the shape that reads as guarded and is not.
    /killSwitch\.active\)?\s*\{[\s\S]{0,600}?\breturn;/.test(
      trigger.slice(readAt),
    ),
    "the kill-switch branch in onUserDeleted does not return — it would log " +
      "the suppression and then do the work anyway",
  );

  check(
    "onUserDeleted's kill-switch read fails OPEN",
    // The read is the only I/O above the handler's own `try`, and a gen1 Auth claim-lint:ok moved unchanged, BUT-2113
    // trigger has no `failurePolicy` — an uncaught throw here DROPS the event,
    // so a transient Firestore error would cost that account its entire
    // cascade with nothing to retry it. The default must also be inactive: a
    // catch that left the flag active would suppress the cascade instead.
    /try\s*\{[\s\S]{0,200}?readResetKillSwitch\(db\);[\s\S]{0,400}?\}\s*catch/.test(
      trigger,
    ) && /killSwitch:\s*ResetKillSwitchState\s*=\s*\{[\s\S]{0,120}?active:\s*false/.test(
      trigger,
    ),
    "the kill-switch read in onUserDeleted is unguarded, or its fallback is " +
      "not inactive — either way a read failure decides the fate of an " +
      "account's whole cascade",
  );

  // --- The script sets it, and clears it in a `finally` -------------------
  const script = readCode("admin/reset-user-data.ts");
  const mainAt = script.indexOf("async function main()");
  const main = mainAt >= 0 ? script.slice(mainAt) : "";
  const setAt = main.indexOf("setResetKillSwitch(");
  const phasesAt = main.indexOf("runPhases(");
  check(
    "the reset script sets the kill switch before it reaches the phases",
    setAt >= 0 && phasesAt > setAt,
    `in main(): set at ${setAt}, first runPhases call at ${phasesAt}`,
  );
  check(
    "the reset script clears the kill switch in a `finally`",
    // The whole self-healing story rests on this: a `catch`, or a clear placed
    // after the phases, leaves the trigger suppressed whenever a phase throws.
    /\}\s*finally\s*\{[\s\S]{0,800}?clearResetKillSwitch\(/.test(main),
    "clearResetKillSwitch is not reached from a `finally` — an exception in " +
      "any phase would leave the cleanup trigger suppressed until the flag " +
      "expires",
  );

  // --- The verification phase counts, and never deletes -------------------
  const verifyAt = script.indexOf("async function verifyReset(");
  const verifyEnd = script.indexOf("\nasync function main()", verifyAt);
  const verifyBody = verifyAt >= 0 ? script.slice(verifyAt, verifyEnd) : "";
  check(
    "the verification pass counts and deletes nothing",
    verifyBody.length > 0 &&
      verifyBody.includes(".count()") &&
      !verifyBody.includes(".delete(") &&
      !verifyBody.includes("deleteCollection(") &&
      !verifyBody.includes("deleteWithSubcollections("),
    "verifyReset writes as well as reads — a pass that quietly re-deletes " +
      "reports CLEAN about a state it produced itself",
  );
  check(
    "the run re-stamps the kill switch while the phases are running",
    // The expiry bounds the RUN, not just an abandoned one. A Phase 2 that
    // outlives it disarms its own suppression mid-wipe, and nothing on screen
    // says so — the trigger simply starts writing again.
    // Inside the per-DOCUMENT walk, not merely present in the file and not
    // merely between collections. Nearly all of a real wipe's wall time is
    // inside two entries (`users`, `conversations`), so a refresh that fires
    // only between collections never runs during either of them — the version
    // that expires mid-wipe. Both deep functions are named, because either one
    // losing the call reopens the gap on its own.
    /async function deleteWithSubcollections\([\s\S]{0,900}?await maybeRefreshKillSwitch\(\);/.test(
      script,
    ) &&
      /async function deleteDocRecursive\([\s\S]{0,900}?await maybeRefreshKillSwitch\(\);/.test(
        script,
      ) &&
      script.includes("KILL_SWITCH_REFRESH_INTERVAL_MS"),
    "the kill-switch refresh does not reach the per-document walk, so a long " +
      "collection expires the run's own suppression while it is still deleting",
  );
  check(
    "the verification pass looks for orphaned parents, not only documents",
    // `count()` answers over DOCUMENTS. A parent deleted while its
    // subcollections survive is not one, so a count reports zero over exactly
    // the residue this ticket is about — a late trigger write beneath a parent
    // Phase 2 already removed.
    verifyBody.includes("listDocuments()"),
    "verifyReset counts documents only, so a deleted parent still holding " +
      "subcollection rows reports as clean",
  );
  check(
    "a failed storage prefix does not abandon the ones after it",
    // One try around the whole loop meant a failure on `users/` silently
    // skipped `shared/` and `feedback/`, and the recorded message named no
    // prefix — so the operator could not tell which files were left.
    /for \(const prefix of STORAGE_PREFIXES_TO_DELETE\) \{\s*try \{/.test(
      script,
    ) && script.includes("Storage prefix ${prefix} not cleaned"),
    "the storage phase wraps its whole loop, so one failing prefix abandons " +
      "the rest without naming which",
  );
  check(
    "the verification pass asks whether the kill switch is gone",
    // `state.exists`, not a derived question. `active || expired || runId`
    // answers false for a document with a future expiry, `active: false` and
    // no run id — the "tidy record" shape that deleting-rather-than-flagging
    // exists to forbid, pinned in the sibling scenario.
    verifyBody.includes("readResetKillSwitch(") &&
      verifyBody.includes("state.exists"),
    "verifyReset does not ask whether the flag document is GONE, so a run " +
      "that failed to clear it can still report a clean verdict while the " +
      "cleanup trigger stays suppressed for every real account deletion",
  );
  check(
    "the verification pass names a flag that belongs to another run",
    // Its own check, not a third conjunct above: the runbook quotes this
    // string verbatim, and its remedy is the OPPOSITE of the runbook's
    // default ("delete the document"). Folded into the check above, a break
    // here would report itself as the `state.exists` failure and send the
    // reader to the wrong line.
    verifyBody.includes("belongs to run"),
    "verifyReset does not distinguish another run's flag, so Phase 4 prints " +
      "`still present` and the runbook tells the operator to delete a " +
      "document that is protecting a live sibling run",
  );
  // The RULE, exercised. It lives in its own side-effect-free module for
  // exactly this reason: a source check for the string "indeterminate"
  // survives collapsing the three answers into two, because the constant map
  // still spells the word — guarded-looking and worth nothing.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const verdictModule = require("../admin/reset-verdict");
  const verdictFor = verdictModule.verdictFor as (
    sawRows: boolean,
    sawUnanswerable: boolean,
  ) => string;
  const exitCodes = verdictModule.EXIT_CODE_BY_VERDICT as Record<string, number>;
  check(
    "the verdict keeps `not clean` and `could not tell` apart",
    verdictFor(false, false) === "clean" &&
      verdictFor(true, false) === "not-clean" &&
      verdictFor(false, true) === "indeterminate",
    "a binary verdict reports a run that could not answer the same as a run " +
      `that answered zero (got ${verdictFor(false, false)}, ` +
      `${verdictFor(true, false)}, ${verdictFor(false, true)})`,
  );
  check(
    "rows found outrank a probe that could not answer",
    // Both true at once is the interesting case: a measurement beats an
    // absence of one, so the operator is told what IS there rather than that
    // something is unknown.
    verdictFor(true, true) === "not-clean",
    `both signals set produced ${verdictFor(true, true)}`,
  );
  check(
    "each verdict carries a distinct exit code, and clean is 0",
    exitCodes["clean"] === 0 &&
      new Set(Object.values(exitCodes)).size === 3 &&
      Object.keys(exitCodes).length === 3,
    `exit codes: ${JSON.stringify(exitCodes)} — a shared code makes two ` +
      "different instructions to the operator indistinguishable to a caller",
  );
  check(
    "the reset script's exit code comes from the verdict",
    script.includes("process.exitCode = EXIT_CODE_BY_VERDICT") &&
      script.includes("verdictFor("),
    "the reset script computes a verdict and does not let it reach the exit " +
      "code, so a caller cannot tell a clean run from a failed one",
  );
}

/**
 * BUT-2028: a live run requires the confirmation phrase, typed by a human.
 *
 * This replaces the temporary BUT-2028 refusal, lifted 2026-09-06 — the
 * decision and what it rested on are in `ACCEPTED_DEVIATIONS.md`, not here,
 * because a docstring cannot hold a provenance claim. What survives is the
 * property that made that scenario worth having, and it is not the refusal: it
 * is that a gate meant as the last human step must not be satisfiable without
 * the human.
 *
 * That is what BUT-2010 taught. The overlap guard protected this script for
 * five and a half months while nothing watched whether it could still fire — a
 * guard that runs and cannot fail reads exactly like one that passes. An npm
 * script piping the phrase in would leave this gate running and prove nothing.
 *
 * Source parsing, so this proves REFERENCE and ORDER rather than effect:
 * `main()` takes no injectable stream, so the prompt cannot be driven from a
 * test. The one check here that measures a real effect is the last — that no
 * npm script bakes the phrase in — and it reads `package.json`.
 */
async function scenario_resetScriptRequiresTheConfirmationPhrase(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  const scriptPath = path.join(__dirname, "..", "admin", "reset-user-data.ts");
  // Comment lines are dropped first, for the same reason the sibling scenario
  // drops them: commenting the guard out is the cheapest way to disarm it, and
  // over raw source every check below would stay green above a dead `if`. The
  // 200-char `!dryRun` lookback is the other reason — a future comment carrying
  // that token would satisfy it.
  const source = (fs.readFileSync(scriptPath, "utf8") as string)
    .split("\n")
    .filter((line: string) => !line.trim().startsWith("//"))
    .join("\n");

  // The phrase is READ from the script, never restated here: matching a
  // literal means a reword leaves this searching for a string nothing uses,
  // green while an npm script bakes in the new one. Same reason the sibling
  // scenario matches `Collections.blocks` rather than "blocks".
  // Anchored on the DECLARATION line, because the `//`-stripper above leaves
  // `/** */` blocks intact and the phrase's own JSDoc sits directly above it.
  // An unanchored match takes the first occurrence, so a future edit quoting
  // the phrase in that comment would win — and after a later reword the
  // npm-script check would hunt the OLD phrase, green, while a script baked in
  // the new one. That is the failure this scenario exists to prevent.
  const phraseMatch = source.match(/^const CONFIRMATION_PHRASE = "([^"]+)"/m);
  check(
    "the confirmation phrase is readable from the script",
    phraseMatch !== null,
    "CONFIRMATION_PHRASE's declaration was not found, so neither the gate " +
      "checks nor the npm-script check below know what to look for",
  );
  if (phraseMatch === null) return;
  const phrase = phraseMatch[1];

  // Scoped to `main()`'s body. `runPhases` is DECLARED above `main`, so file
  // order stopped meaning execution order — a check reading the whole source
  // would compare the gate against a function definition rather than against
  // the call that reaches it.
  const mainAt = source.indexOf("async function main()");
  const mainBody = mainAt >= 0 ? source.slice(mainAt) : "";
  const promptAt = mainBody.indexOf("promptUser(");
  const phasesCalledAt = mainBody.indexOf("runPhases(");
  check(
    "main() asks for the confirmation phrase before it reaches the phases",
    mainAt >= 0 &&
      promptAt >= 0 &&
      phasesCalledAt >= 0 &&
      phasesCalledAt > promptAt,
    `in main(): prompt at ${promptAt}, first runPhases call at ` +
      `${phasesCalledAt} — the gate would ask after Phase 1 has already ` +
      "deleted every Auth user",
  );

  const gate = mainBody.slice(promptAt, phasesCalledAt);
  check(
    "the confirmation gate is conditional on a live run",
    // Leans on the check above: with the prompt deleted `promptAt` is -1, the
    // lookback spans nearly the whole body and this passes vacuously. It is
    // not dormant, because that same state reddens the order check above and
    // the exit check below — but on its own it proves nothing there.
    promptAt >= 0 &&
      mainBody.slice(Math.max(0, promptAt - 400), promptAt).includes("!dryRun"),
    "the confirmation prompt is not guarded by `!dryRun`, so --dry-run would " +
      "block on a prompt — and inspecting the script is what --dry-run is for",
  );
  check(
    "a wrong phrase EXITS rather than only printing",
    // Presence and position prove a reference, never an EFFECT: swap the exit
    // for a `console.log` and every check above stays green while the script
    // prints "Aborted." and wipes production anyway.
    gate.includes("process.exit(0)") &&
      gate.includes(`!== CONFIRMATION_PHRASE`),
    "main() does not compare the answer to CONFIRMATION_PHRASE and exit — a " +
      "wrong answer would fall through into Phase 1",
  );

  // The blind spot the OVERLAP guard had, kept closed. That guard ran for five
  // and a half months while nothing watched whether it could still fire; an
  // npm script piping the phrase in leaves this gate intact and permanently
  // satisfied, which is the same shape.
  const pkg = fs.readFileSync(
    path.join(__dirname, "..", "..", "package.json"),
    "utf8",
  ) as string;
  const scripts = JSON.parse(pkg).scripts as Record<string, string>;
  const baked = Object.entries(scripts)
    .filter(([, cmd]) => cmd.includes("reset-user-data"))
    .filter(([, cmd]) => cmd.includes(phrase))
    .map(([name]) => name);
  check(
    "no npm script types the confirmation phrase for the operator",
    baked.length === 0,
    `${baked.join(", ")} carries the confirmation phrase, so the gate is ` +
      "satisfied before the operator sees it — it still runs and still proves " +
      "nothing, which is exactly how the overlap guard went unnoticed",
  );
}

/**
 * BUT-2036: the scheduler pause is wired into main(), in both directions.
 *
 * Source checks, like their two siblings above, and for the same reason:
 * `main()` runs at module scope and takes nothing injectable, so ORDER and
 * REFERENCE are what a test can reach here. What the pause itself decides is
 * proven against a fake in `reset-scheduler-pause.test.ts`; this is the wiring
 * that file cannot see, and it is the half that dies quietly — a resume
 * dropped from the `finally` leaves the project's scheduled work switched off
 * with nothing on screen to say so.
 */
async function scenario_resetScriptPausesAndResumesScheduler(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  const scriptPath = path.join(__dirname, "..", "admin", "reset-user-data.ts");
  // Comments dropped for the reason the sibling scenarios drop them:
  // commenting a call out is the cheapest way to disarm it.
  const source = (fs.readFileSync(scriptPath, "utf8") as string)
    .split("\n")
    .filter((line: string) => !line.trim().startsWith("//"))
    .join("\n");

  const mainAt = source.indexOf("async function main()");
  const mainBody = mainAt >= 0 ? source.slice(mainAt) : "";
  const pauseAt = mainBody.indexOf("pauseJobs(");
  const phasesCalledAt = mainBody.indexOf("runPhases(");
  check(
    "main() pauses the scheduled jobs before it reaches the phases",
    mainAt >= 0 && pauseAt >= 0 && phasesCalledAt > pauseAt,
    `in main(): pauseJobs at ${pauseAt}, first runPhases call at ` +
      `${phasesCalledAt} — a pause after Phase 1 leaves the jobs writing ` +
      "into the collections Phase 2 is deleting",
  );

  // The refusal is what makes the pause a control rather than an attempt, and
  // it has to land while nothing has been deleted.
  //
  // Scoped to the refusal branch alone, not to everything before the phases:
  // the kill-switch guard below it resumes and exits too, so a window holding
  // both is satisfied by either — and the check would then stay green on the
  // very edit it names.
  const refusalAt = mainBody.indexOf("paused.failed.length > 0");
  // Ends at the kill-switch guard, which is the next thing that resumes and
  // exits — so the window holds the refusal branch alone. Anchored on code
  // rather than on the console copy between them: a reworded message would
  // empty the window and redden these checks against production.
  const afterRefusalAt = mainBody.indexOf("setResetKillSwitch(db, runId)");
  const refusalBranch =
    refusalAt >= 0 && afterRefusalAt > refusalAt
      ? mainBody.slice(refusalAt, afterRefusalAt)
      : "";
  check(
    "a pause that did not fully succeed stops the run",
    refusalAt >= 0 && refusalBranch.includes("process.exit(1)"),
    "main() does not exit on a failed pause, so a run that could not " +
      "protect the wipe would carry on and wipe anyway",
  );
  check(
    "and what it did manage to pause is put back before it exits",
    refusalBranch.includes("resumeJobs("),
    "the refusal path does not resume — it would leave the project's " +
      "scheduled work switched off by a run that deleted nothing",
  );

  // The window between the first pause and the `try` is outside `finally`,
  // and it is not empty: the kill switch is set in it. Both checks below are
  // about that window, and each names a different way out of it.
  const signalRegisteredAt = mainBody.indexOf('process.on("SIGINT"');
  // The FIRST occurrence is the one in the live-run block; the refresher
  // defined below it calls the same function.
  const killSwitchSetAt = mainBody.indexOf("setResetKillSwitch(db, runId)");
  check(
    "the signal handlers are registered before the first job is paused",
    signalRegisteredAt >= 0 && pauseAt > signalRegisteredAt,
    `in main(): process.on at ${signalRegisteredAt}, pauseJobs at ` +
      `${pauseAt} — a Ctrl-C between the first pause and the try block would ` +
      "hit Node's default handler and leave the schedule off",
  );
  const killSwitchWindow =
    killSwitchSetAt >= 0 && phasesCalledAt > killSwitchSetAt
      ? mainBody.slice(killSwitchSetAt, phasesCalledAt)
      : "";
  check(
    "a kill switch that cannot be set resumes the jobs rather than throwing " +
      "past every release path",
    killSwitchWindow.includes("resumeJobs(") &&
      killSwitchWindow.includes("process.exit(1)"),
    "setResetKillSwitch is not guarded — it runs after the jobs are paused " +
      "and before the try, so a throw there reaches main().catch and no " +
      "resume ever runs",
  );

  // Both release paths. They are textually separate and each dies alone: the
  // `finally` covers a crash or a clean end, the signal handler covers Ctrl-C,
  // which bypasses `finally` entirely.
  const finallyAt = mainBody.indexOf("} finally {");
  const verificationAt = mainBody.indexOf("Phase 4: verification");
  const finallyBlock =
    finallyAt >= 0 && verificationAt > finallyAt
      ? mainBody.slice(finallyAt, verificationAt)
      : "";
  check(
    "the finally that clears the kill switch also resumes the jobs",
    finallyBlock.includes("resumeJobs("),
    "the release block does not resume the scheduled jobs, so any run that " +
      "ends — cleanly or by throwing — leaves them paused",
  );

  const signalAt = mainBody.indexOf("const onSignal =");
  // Ends at the live-run block that follows the handler, not at `finally`:
  // the handler is DEFINED above the pause, so a window reaching `finally`
  // spans the pause block's own two resumes and is satisfied by either.
  const afterSignalAt = mainBody.indexOf("if (!dryRun) {", signalAt);
  const signalBlock =
    signalAt >= 0 && afterSignalAt > signalAt
      ? mainBody.slice(signalAt, afterSignalAt)
      : "";
  check(
    "Ctrl-C resumes them too",
    signalBlock.includes("resumeJobs("),
    "the signal handler does not resume the scheduled jobs — signals bypass " +
      "`finally`, so an interrupted wipe would leave the schedule off with " +
      "no verification pass to report it",
  );

  // The verification phase must ASK rather than believe the resume step.
  check(
    "the verification phase re-reads the jobs' state",
    source.includes("findStillPausedJobs("),
    "nothing re-reads Cloud Scheduler, so a resume call that answered " +
      "without doing anything would be reported as success",
  );
}

async function main(): Promise<void> {
  await scenario_resetScriptDeleteListNamesBlocks();
  await scenario_resetScriptListsDoNotOverlap();
  await scenario_resetScriptRequiresTheConfirmationPhrase();
  await scenario_resetKillSwitchSelfHeals();
  await scenario_resetKillSwitchIsWiredIn();
  await scenario_resetScriptPausesAndResumesScheduler();

  finishSuite("BUT-1766/BUT-1768 deletion cascade reset script");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
