/**
 * "Which collections does the database hold that no list decides?"
 *
 * BUT-2043. `admin/reset-user-data.ts` walks the real database, so it is the
 * only place in this repo that can answer that question. The coverage guard in
 * the account-cascade suite derives its universe from SOURCE — `firestore.rules`
 * plus a scan of `functions/src` — which cannot see a collection no code names
 * any more. That is exactly what BUT-2040 was: `users/{uid}/rateLimits`, a
 * spelling left behind by a rename, with no writer for a source scan to find
 * and 5 rows still on disk. A human reading a dry run's output found it.
 *
 * Pure and side-effect-free ON PURPOSE: `reset-user-data.ts` calls `main()` at
 * module scope, so anything written inside it cannot be imported by a test
 * without starting a destructive run. The caller does the I/O and passes the
 * names in; this decides what is unknown.
 *
 * REPORT ONLY. Nothing here may change what a run deletes, skips or keeps — a
 * reporting helper that steers a destructive script is a silent behaviour
 * change wearing a summary's clothes.
 */

import {
  COLLECTIONS_TO_DELETE,
  COLLECTIONS_TO_KEEP,
  COLLECTIONS_DELIBERATELY_UNTOUCHED,
  KNOWN_SUBCOLLECTION_NAMES,
} from "./reset-collection-lists";
import {
  USER_SUBCOLLECTIONS,
  TRIGGER_OWNED_SUBCOLLECTIONS,
} from "../account/account-deletion-cascade";

/** One subcollection name no list accounts for, and where the walk saw it. */
export interface UnknownSubcollection {
  name: string;
  /** Top-level targets under whose walk the name appeared. */
  underTargets: string[];
  /** Rows counted under that name, summed across those targets. */
  docs: number;
}

export interface UnknownCollectionsReport {
  /** Top-level collections present in the database and in none of the lists. */
  topLevel: string[];
  unknownSubcollections: UnknownSubcollection[];
}

/**
 * Every name the three lists decide, plus the names that ARE top-level
 * collections — a subcollection sharing a top-level collection's name is
 * accounted for by that entry.
 */
function decidedTopLevelNames(): Set<string> {
  return new Set<string>([
    ...COLLECTIONS_TO_DELETE.map((t) => t.name),
    ...COLLECTIONS_TO_KEEP,
    ...Object.keys(COLLECTIONS_DELIBERATELY_UNTOUCHED),
  ]);
}

/**
 * Names something in this repo accounts for as a SUBCOLLECTION.
 *
 * Four sources, and the last two are why this is not just the reset script's
 * own inventory. `CollectionTarget.subcollections` says in its own docstring
 * that it is a reader's aid rather than a verified list, and it is: measured
 * 2026-09-08, a check built on that inventory alone would report eight
 * subcollections the account cascade deletes correctly, among them
 * `onboarding` and `acquisition`. A report that fires on data the cascade
 * handles buries the one finding it exists to surface, so the cascade's own
 * lists are read here too.
 */
function decidedSubcollectionNames(): Set<string> {
  const names = new Set<string>(KNOWN_SUBCOLLECTION_NAMES);
  for (const target of COLLECTIONS_TO_DELETE) {
    for (const sub of target.subcollections ?? []) names.add(sub);
  }
  // The cascade's own two lists: what a single account's erasure actually
  // sweeps, and what `onUserDeleted` owns.
  for (const sub of USER_SUBCOLLECTIONS) names.add(sub);
  for (const sub of TRIGGER_OWNED_SUBCOLLECTIONS) names.add(sub);
  return names;
}

/**
 * The names a run cannot account for.
 *
 * `topLevelInDb` comes from a root `listCollections()`; `subCountsByTarget`
 * maps a top-level target to the subcollection ids its recursive walk saw at
 * any depth, which is what `deleteWithSubcollections` already returns.
 *
 * A `TRIGGER_OWNED_SUBCOLLECTIONS` name reaching this function is NOT filtered
 * as an oversight — it is accounted for, so it is not reported.
 */
export function findUnknownCollections(args: {
  topLevelInDb: readonly string[];
  subCountsByTarget: ReadonlyArray<{
    collection: string;
    subs: Readonly<Record<string, number>>;
  }>;
}): UnknownCollectionsReport {
  const decidedTop = decidedTopLevelNames();
  const decidedSub = decidedSubcollectionNames();

  const topLevel = [...args.topLevelInDb]
    .filter((name) => !decidedTop.has(name))
    .sort();

  const seen = new Map<string, { targets: Set<string>; docs: number }>();
  for (const result of args.subCountsByTarget) {
    for (const [name, count] of Object.entries(result.subs)) {
      if (decidedSub.has(name) || decidedTop.has(name)) continue;
      const entry = seen.get(name) ?? { targets: new Set<string>(), docs: 0 };
      entry.targets.add(result.collection);
      entry.docs += count;
      seen.set(name, entry);
    }
  }

  const unknownSubcollections = [...seen.entries()]
    .map(([name, entry]) => ({
      name,
      underTargets: [...entry.targets].sort(),
      docs: entry.docs,
    }))
    .sort((a, b) => a.name.localeCompare(b.name));

  return { topLevel, unknownSubcollections };
}

/**
 * The report as printed lines, including what it does NOT range over.
 *
 * The scope sentence ships with the report rather than living in a ticket: the
 * walk only descends into `COLLECTIONS_TO_DELETE`, so subcollections beneath a
 * kept or deliberately-untouched collection are never enumerated. A reader who
 * takes this for a full inventory of the database draws the wrong conclusion
 * from a clean result, which is the failure mode this whole ticket is about.
 */
export function formatUnknownCollections(
  report: UnknownCollectionsReport,
): string[] {
  const lines: string[] = [];
  if (report.topLevel.length === 0) {
    lines.push("  Top-level collections not in any list: none");
  } else {
    lines.push(
      "  Top-level collections NOT IN ANY LIST: " + report.topLevel.join(", "),
    );
  }

  if (report.unknownSubcollections.length === 0) {
    lines.push("  Subcollection names not accounted for: none");
  } else {
    lines.push("  Subcollection names NOT ACCOUNTED FOR:");
    for (const sub of report.unknownSubcollections) {
      lines.push(
        `    ${sub.name} (${sub.docs} docs, under ` +
          `${sub.underTargets.join(", ")})`,
      );
    }
  }

  lines.push(
    "  Scope: subcollections are only enumerated beneath the collections " +
      "this run deletes. Nothing beneath a kept or deliberately-untouched " +
      "collection is walked, so a clean result here is not a full inventory " +
      "of the database. A subcollection is also silenced by a TOP-LEVEL " +
      "collection of the same name, and by any name the account cascade " +
      "sweeps anywhere — both silence by NAME, so a genuinely new " +
      "subcollection reusing a known word is not reported.",
  );
  return lines;
}
