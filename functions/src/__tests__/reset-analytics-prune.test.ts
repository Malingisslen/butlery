/**
 * BUT-2044 — `analytics` is kept by a reset, and the rows about individual
 * people under it are not.
 *
 * The measurement series (`analytics/{group}/daily/{date}`) survive a clean
 * slate; `feature_retention/users`, `retention/events`, `lapsed_users/events`,
 * `notifications/effectiveness` and `ingredients/learned_aliases` do not. The
 * allowlist decides by NAME, so the scan at the bottom is what stops a new
 * series from inheriting the exemption unread.
 */
import * as fs from "fs";
import * as path from "path";
import {
  countAnalyticsResidue,
  pruneAnalytics,
} from "../admin/reset-analytics-prune";
import {
  COLLECTIONS_TO_DELETE,
  COLLECTIONS_TO_KEEP,
  isKeptAnalyticsSeries,
} from "../admin/reset-collection-lists";

let passed = 0;
let failed = 0;
function check(name: string, cond: boolean, detail: string): void {
  if (cond) {
    passed++;
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}\n        ${detail}`);
  }
}

// --- A store that answers `listDocuments()` from stored paths --------------
//
// Derived from paths rather than hand-wired, so a parent that holds only
// subcollections — `analytics/notifications` is one in production — exists the
// way it does on disk. A stub returning `[]` there would make the walk look
// covered while never entering it.
class FakeStore {
  readonly docs = new Set<string>();
  /** Fields per path, for the parent documents the residue pass reads. */
  private readonly fields = new Map<string, Record<string, unknown>>();

  seed(...paths: string[]): void {
    for (const p of paths) this.docs.add(p);
  }

  seedFields(docPath: string, data: Record<string, unknown>): void {
    this.docs.add(docPath);
    this.fields.set(docPath, data);
  }

  /** Every path still stored under `prefix/`. */
  under(prefix: string): string[] {
    return [...this.docs].filter((p) => p.startsWith(`${prefix}/`));
  }

  /** Child segment names one level below `prefix`. */
  private childrenOf(prefix: string): string[] {
    const depth = prefix.split("/").length;
    const names = new Set<string>();
    for (const p of this.under(prefix)) {
      const parts = p.split("/");
      if (parts.length > depth) names.add(parts[depth]);
    }
    return [...names];
  }

  private docRef(docPath: string) {
    return {
      id: docPath.split("/").pop() as string,
      path: docPath,
      listCollections: async () =>
        this.childrenOf(docPath).map((name) => this.collectionRef(`${docPath}/${name}`)),
      // A parent that exists only through its children has no fields and, in
      // Firestore, does not exist as a document either.
      get: async () => ({
        exists: this.fields.has(docPath),
        data: () => this.fields.get(docPath),
      }),
    };
  }

  private collectionRef(colPath: string) {
    return {
      id: colPath.split("/").pop() as string,
      path: colPath,
      listDocuments: async () =>
        this.childrenOf(colPath).map((name) => this.docRef(`${colPath}/${name}`)),
    };
  }

  /** Enough of `admin.firestore.Firestore` for the walk. */
  asDb(): { collection: (name: string) => unknown } {
    return { collection: (name: string) => this.collectionRef(name) };
  }

  /** What the script's `deleteDocRecursive` does: the doc and everything under it. */
  deleteDeep(docPath: string): void {
    this.docs.delete(docPath);
    for (const p of this.under(docPath)) this.docs.delete(p);
  }
}

/* eslint-disable @typescript-eslint/no-explicit-any */
function dbOf(store: FakeStore): any {
  return store.asDb();
}

function seeded(): FakeStore {
  const store = new FakeStore();
  store.seed(
    // A parent with no fields of its own — it exists only through its children.
    "analytics/feature_retention/users/uidA_2026-09-01",
    "analytics/feature_retention/users/uidB_2026-09-01",
    "analytics/feature_retention/daily/2026-09-01",
    "analytics/feature_retention/daily/2026-09-02",
    "analytics/lapsed_users/events/evt1",
    "analytics/notifications/effectiveness/n1",
    "analytics/notifications/summary/2026-09-01",
  );
  // The job cursor: a real document with fields, beside its own subcollection.
  store.seedFields("analytics/lapsed_users", { lastRunAt: "2026-09-01" });
  return store;
}

async function run(): Promise<void> {
  console.log("BUT-2044 analytics prune\n");

  // --- The allowlist ------------------------------------------------------
  for (const parent of [
    "anomalies",
    "feature_retention",
    "feedback",
    "import_health",
    "ops",
    "parsing_corrections",
    "recipes",
    "duplicate_guard",
  ]) {
    check(
      `${parent}/daily is kept`,
      isKeptAnalyticsSeries(parent, "daily"),
      "a measurement series was about to be deleted by a reset",
    );
  }
  check(
    "notifications/summary is kept",
    isKeptAnalyticsSeries("notifications", "summary"),
    "the per-type notification rates carry no uid and are a dated series",
  );

  for (const [parent, sub] of [
    ["feature_retention", "users"],
    ["retention", "events"],
    ["lapsed_users", "events"],
    ["notifications", "effectiveness"],
    ["ingredients", "learned_aliases"],
    ["parsing", "corrections"],
    ["ingredients", "unmatched"],
  ]) {
    check(
      `${parent}/${sub} is deleted`,
      !isKeptAnalyticsSeries(parent, sub),
      "a reset would keep it; the five uid-carrying paths and the two " +
        "derived queues are what this change deletes",
    );
  }
  check(
    "a name nobody declared is deleted, not kept",
    !isKeptAnalyticsSeries("feature_retention", "collection_nobody_declared"),
    "the allowlist must close on the undeclared case — a delete-list would " +
      "keep tomorrow's per-person collection in silence",
  );

  // --- The lists ----------------------------------------------------------
  check(
    "analytics is preserved and no longer deleted whole",
    COLLECTIONS_TO_KEEP.includes("analytics") &&
      !COLLECTIONS_TO_DELETE.some((t) => t.name === "analytics"),
    `keep=${COLLECTIONS_TO_KEEP.includes("analytics")}, delete=${COLLECTIONS_TO_DELETE.some((t) => t.name === "analytics")}`,
  );

  // --- The walk -----------------------------------------------------------
  const store = seeded();
  const result = await pruneAnalytics(dbOf(store), {
    maybeRefreshKillSwitch: async () => {},
    deleteDocDeep: async (ref: any) => store.deleteDeep(ref.path),
  });

  check(
    "the per-person rows are gone",
    store.under("analytics/feature_retention/users").length === 0 &&
      store.under("analytics/lapsed_users/events").length === 0 &&
      store.under("analytics/notifications/effectiveness").length === 0,
    `left: ${JSON.stringify([...store.docs])}`,
  );
  check(
    "the series and the job cursor stand",
    store.under("analytics/feature_retention/daily").length === 2 &&
      store.under("analytics/notifications/summary").length === 1 &&
      store.docs.has("analytics/lapsed_users"),
    `left: ${JSON.stringify([...store.docs])}`,
  );
  check(
    "a parent that holds only subcollections is walked",
    result.deleted.some((e) => e.path === "analytics/notifications/effectiveness"),
    "analytics/notifications carries no fields of its own, so a walk built " +
      "on a query instead of listDocuments() never reaches it: " +
      JSON.stringify(result.deleted.map((e) => e.path)),
  );
  check(
    "the run can report what it removed and what it kept",
    result.deleted.length === 3 && result.kept.length === 2,
    `deleted=${JSON.stringify(result.deleted.map((e) => `${e.path}:${e.docs}`))} kept=${JSON.stringify(result.kept.map((e) => `${e.path}:${e.docs}`))}`,
  );

  // --- What a dry run looks like ------------------------------------------
  //
  // This module has no `dryRun` of its own: the run's flag lives in the
  // injected deleter, which is the script's `deleteDocRecursive`. A second
  // flag here would read as a control on a destructive helper while deciding
  // nothing. What is pinned is that a deleter which removes nothing still
  // yields the counts the dry run prints.
  const dry = new FakeStore();
  dry.seed(
    "analytics/feature_retention/users/uidA_2026-09-01",
    "analytics/feature_retention/daily/2026-09-01",
  );
  const dryResult = await pruneAnalytics(dbOf(dry), {
    maybeRefreshKillSwitch: async () => {},
    deleteDocDeep: async () => {},
  });
  check(
    "a deleter that removes nothing still produces the counts",
    dry.docs.size === 2 &&
      dryResult.deleted.length === 1 &&
      dryResult.deleted[0].docs === 1,
    `store=${JSON.stringify([...dry.docs])} result=${JSON.stringify(dryResult)}`,
  );

  // --- The residue counter -----------------------------------------------
  const leftover = new FakeStore();
  leftover.seed(
    "analytics/feature_retention/users/uidA_2026-09-01",
    "analytics/feature_retention/daily/2026-09-01",
  );
  leftover.seedFields("analytics/lapsed_users", { lastRunAt: "2026-09-01" });
  leftover.seedFields("analytics/retention", { userId: "uidA" });
  const residue = await countAnalyticsResidue(dbOf(leftover));
  check(
    "a surviving per-person row is residue",
    residue.subcollections.length === 1 &&
      residue.subcollections[0].path === "analytics/feature_retention/users",
    `reported: ${JSON.stringify(residue.subcollections)}`,
  );
  check(
    "a surviving series row is not",
    !residue.subcollections.some((e) => e.subId === "daily"),
    "the verification pass would report a kept series as residue and the " +
      "run could never answer CLEAN",
  );
  check(
    "a field on a PARENT document is residue too",
    residue.parentFields.length === 1 &&
      residue.parentFields[0].path === "analytics/retention" &&
      residue.parentFields[0].fields.join(",") === "userId",
    "the prune deletes subcollections, so a uid written onto a parent " +
      "survives it and nothing else in the run looks there: " +
      JSON.stringify(residue.parentFields),
  );
  check(
    "…and the job cursor is not",
    !residue.parentFields.some((e) => e.path === "analytics/lapsed_users"),
    "KEPT_PARENT_FIELDS exists so the one legitimate field does not make " +
      "every run answer NOT CLEAN",
  );

  // --- The writer scan ----------------------------------------------------
  //
  // The allowlist recognises a series by the NAME `daily`, so this is what
  // makes a new `daily` writer a decision rather than an inheritance. It must
  // see BOTH forms: the chain spelled out, and
  // `dailyDocRef(db, "<group>", date)` in analytics/daily-snapshots.ts.
  const reviewedDaily = new Set([
    "anomalies",
    "duplicate_guard",
    "feature_retention",
    "feedback",
    "import_health",
    "ops",
    "parsing_corrections",
    "recipes",
  ]);
  const scan = scanAnalyticsWriters(readFunctionsSources());
  check(
    "every analytics/<group>/daily writer is a reviewed series",
    [...scan.dailyGroups].every((g) => reviewedDaily.has(g)),
    `found: ${JSON.stringify([...scan.dailyGroups])}`,
  );
  check(
    "…and every reviewed series still has a writer",
    [...reviewedDaily].every((g) => scan.dailyGroups.has(g)),
    `missing: ${JSON.stringify([...reviewedDaily].filter((g) => !scan.dailyGroups.has(g)))} — ` +
      "a series that lost its writer means the list is describing code that " +
      "is gone, and the scan is then ranging over less than it claims",
  );
  check(
    "no dailyDocRef call passes a group the scan cannot resolve",
    scan.unresolved.length === 0,
    `unresolved: ${JSON.stringify(scan.unresolved)} — a variable group makes ` +
      "the series invisible to this scan, which would then pass while " +
      "ranging over fewer writers than it names",
  );
  // A chain whose parent is a variable names no series the scan can read, so
  // the files allowed to contain one are named. `daily-snapshots.ts` is the
  // helper itself, resolved through its call sites above; `detect-anomalies.ts`
  // READS the same shape back; `account-deletion-cascade.ts` DELETES through
  // it, looping `RETENTION_ANALYTICS_PARENTS`. A fourth file means a series
  // nobody reviewed.
  const reviewedVariableChains = [
    "daily-snapshots.ts",
    "detect-anomalies.ts",
    "account-deletion-cascade.ts",
  ];
  check(
    "no new file reaches analytics through a variable parent",
    [...scan.variableChainFiles].every((f) =>
      reviewedVariableChains.includes(f),
    ),
    `unreviewed: ${JSON.stringify(
      [...scan.variableChainFiles].filter(
        (f) => !reviewedVariableChains.includes(f),
      ),
    )}`,
  );
  check(
    "…and every reviewed variable-chain file still holds one",
    reviewedVariableChains.every((f) => scan.variableChainFiles.has(f)),
    `missing: ${JSON.stringify(
      reviewedVariableChains.filter((f) => !scan.variableChainFiles.has(f)),
    )} — an empty set satisfies the check above while guarding nothing`,
  );

  const synthetic = scanAnalyticsWriters([
    {
      file: "synthetic.ts",
      text: 'db.collection("analytics").doc("brand_new").collection("daily").doc(d)',
    },
  ]);
  check(
    "a new series is discovered rather than inherited",
    synthetic.dailyGroups.has("brand_new") &&
      !reviewedDaily.has("brand_new"),
    "the scan cannot see a literal chain, so it would pass on any new writer",
  );
  const syntheticHelper = scanAnalyticsWriters([
    { file: "synthetic.ts", text: 'dailyDocRef(db, "helper_series", dateStr)' },
  ]);
  check(
    "…including one written through the helper",
    syntheticHelper.dailyGroups.has("helper_series"),
    "a scan blind to it would range over the literal chains alone and still " +
      "look green",
  );

  // --- The call sites -----------------------------------------------------
  //
  // `reset-user-data.ts` calls `main()` at module scope, so it cannot be
  // imported. Anchored on code and asserted to appear exactly once each: an
  // anchor that matches twice is an anchor that stopped identifying anything.
  const script = fs.readFileSync(
    path.join(__dirname, "..", "admin", "reset-user-data.ts"),
    "utf8",
  );
  const anchors: [string, string][] = [
    ["the prune", "await pruneAnalytics(db, {"],
    // Including the line that makes the count MATTER. `verifyReset` cannot be
    // imported, and a residue row that is printed without setting `sawRows`
    // lets the run answer CLEAN over rows it just listed.
    ["the residue count", "await countAnalyticsResidue(db)"],
    [
      "surviving rows into the verdict",
      "for (const entry of residue.subcollections) {\n      sawRows = true;",
    ],
    [
      "a surviving parent field into the verdict",
      "for (const entry of residue.parentFields) {\n      sawRows = true;",
    ],
    // The DEEP deleter, not merely a deleter. This module takes it as an
    // argument, so a caller could hand it one that removes a document and
    // leaves its children — which `count()` reports as clean.
    [
      "the deep deleter",
      "deleteDocRecursive(docRef, {}, dryRun, maybeRefreshKillSwitch)",
    ],
  ];
  for (const [label, anchor] of anchors) {
    check(
      `reset-user-data.ts wires ${label} exactly once`,
      script.split(anchor).length === 2,
      `matched ${script.split(anchor).length - 1} times — the prune reaches ` +
        "the run only through this call, and nothing else in the repo can " +
        "observe whether it is there",
    );
  }

  console.log(
    `\nBUT-2044 analytics prune: ${passed}/${passed + failed} passing`,
  );
  if (failed > 0) process.exitCode = 1;
}

/** Every non-test TypeScript source under `functions/src`. */
function readFunctionsSources(): { file: string; text: string }[] {
  const root = path.join(__dirname, "..");
  const out: { file: string; text: string }[] = [];
  const walk = (dir: string): void => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === "__tests__" || entry.name === "node_modules") continue;
        walk(full);
      } else if (entry.name.endsWith(".ts")) {
        out.push({ file: full, text: fs.readFileSync(full, "utf8") });
      }
    }
  };
  walk(root);
  return out;
}

interface WriterScan {
  /** `{group}` for every `analytics/{group}/daily` writer found. */
  dailyGroups: Set<string>;
  /** `dailyDocRef` call sites whose group is not a string literal. */
  unresolved: string[];
  /**
   * Files where the chain itself takes a variable parent
   * (`.collection("analytics").doc(group)`). The scan cannot say which series
   * those touch, so they are listed by file and reviewed by name below.
   */
  variableChainFiles: Set<string>;
}

function scanAnalyticsWriters(
  sources: { file: string; text: string }[],
): WriterScan {
  const dailyGroups = new Set<string>();
  const unresolved: string[] = [];
  const variableChainFiles = new Set<string>();

  for (const { file, text } of sources) {
    // No `g` flag: `.test()` on a global regex advances `lastIndex`, so a
    // literal hoisted out of this loop would skip alternate files and the
    // guard would still read green.
    const variableChain =
      /\.collection\(\s*"analytics"\s*\)\s*\.doc\(\s*[A-Za-z_][A-Za-z0-9_.]*\s*\)/;
    if (variableChain.test(text)) variableChainFiles.add(path.basename(file));

    const chain =
      /\.collection\(\s*"analytics"\s*\)\s*\.doc\(\s*"([A-Za-z0-9_]+)"\s*\)\s*\.collection\(\s*"([A-Za-z0-9_]+)"\s*\)/g;
    let match: RegExpExecArray | null;
    while ((match = chain.exec(text)) !== null) {
      if (match[2] === "daily") dailyGroups.add(match[1]);
    }

    const helper = /dailyDocRef\(\s*[A-Za-z0-9_.()]+\s*,\s*([^,]+),/g;
    while ((match = helper.exec(text)) !== null) {
      const group = match[1].trim();
      const literal = /^"([A-Za-z0-9_]+)"$/.exec(group);
      if (literal) dailyGroups.add(literal[1]);
      else unresolved.push(`${path.basename(file)}: dailyDocRef(…, ${group})`);
    }
  }

  return { dailyGroups, unresolved, variableChainFiles };
}

void run();
