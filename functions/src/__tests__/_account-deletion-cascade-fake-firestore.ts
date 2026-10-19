/**
 * In-memory Firestore double for the account-deletion cascade suites
 * (`account-deletion-cascade*.test.ts`). Moved out of the single cascade test
 * file unchanged so every area suite can share it.
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-cascade" });
}

/** Marker standing in for `FieldValue.arrayRemove` (real SDK unavailable). */
const ARRAY_REMOVE_MARKER = Symbol("arrayRemove");
interface ArrayRemoveOp {
  [ARRAY_REMOVE_MARKER]: true;
  values: unknown[];
}
function isArrayRemoveOp(v: unknown): v is ArrayRemoveOp {
  return (
    typeof v === "object" &&
    v !== null &&
    (v as ArrayRemoveOp)[ARRAY_REMOVE_MARKER] === true
  );
}
(
  admin.firestore.FieldValue as unknown as {
    arrayRemove: (...values: unknown[]) => ArrayRemoveOp;
  }
).arrayRemove = (...values: unknown[]) => ({
  [ARRAY_REMOVE_MARKER]: true,
  values,
});

/** Marker standing in for `FieldValue.delete()`. */
const DELETE_MARKER = Symbol("fieldDelete");
interface DeleteOp {
  [DELETE_MARKER]: true;
}
function isDeleteOp(v: unknown): v is DeleteOp {
  return (
    typeof v === "object" && v !== null && (v as DeleteOp)[DELETE_MARKER] === true
  );
}
(
  admin.firestore.FieldValue as unknown as { delete: () => DeleteOp }
).delete = () => ({ [DELETE_MARKER]: true });

/**
 * Marker standing in for `FieldValue.increment()` (BUT-2112). Without it the
 * real SDK's opaque sentinel would be stored in place of a number.
 */
const INCREMENT_MARKER = Symbol("increment");
interface IncrementOp {
  [INCREMENT_MARKER]: true;
  by: number;
}
function isIncrementOp(v: unknown): v is IncrementOp {
  return (
    typeof v === "object" &&
    v !== null &&
    (v as IncrementOp)[INCREMENT_MARKER] === true
  );
}
(
  admin.firestore.FieldValue as unknown as {
    increment: (by: number) => IncrementOp;
  }
).increment = (by: number) => ({ [INCREMENT_MARKER]: true, by });

export type DocData = Record<string, unknown>;

/** Write `value` at a dotted field path, cloning each map on the way down. */
function applyFieldPath(
  target: Record<string, unknown>,
  segments: string[],
  value: unknown,
): void {
  const [head, ...rest] = segments;
  if (rest.length === 0) {
    if (isDeleteOp(value)) {
      delete target[head];
    } else if (isArrayRemoveOp(value)) {
      // BUT-2115: `reactions.<key>` is an arrayRemove at a dotted path; storing
      // the marker would read as the other reactors' uids being wiped.
      const cur = Array.isArray(target[head]) ? (target[head] as unknown[]) : [];
      target[head] = cur.filter((item) => !value.values.includes(item));
    } else {
      target[head] = value;
    }
    return;
  }
  // BUT-2272: deleting a key under a map that is not there changes nothing in
  // Firestore. Building the missing map here would leave an empty one behind.
  if (
    isDeleteOp(value) &&
    (typeof target[head] !== "object" || target[head] === null)
  ) {
    return;
  }
  const child =
    typeof target[head] === "object" && target[head] !== null
      ? { ...(target[head] as Record<string, unknown>) }
      : {};
  applyFieldPath(child, rest, value);
  target[head] = child;
}

/**
 * BUT-1716: the collection a document sits in, and the document that owns that
 * collection — `doc.ref.parent.parent` in the real SDK.
 *
 * `removeFromSharedContent` resolves a `members/{uid}` row back to its
 * `shared_content` parent that way, and scopes on `parent.parent.id` because a
 * collection-GROUP read also returns `members` rows nested under other
 * collections. Without this the production line throws a TypeError, which under
 * this file's single bottom-level catch reads as a shrunken suite rather than a
 * failure — and the path-scoping assertion could not be written at all.
 */
interface FakeCollectionRef {
  /** The collection segment, e.g. `members`. */
  id: string;
  /** The document that owns it, or null for a top-level collection. */
  parent: FakeRef | null;
}

interface FakeRef {
  path: string;
  /**
   * BUT-1716: the document id. Real `DocumentReference`s carry it, this stub did
   * not, and the gap was invisible in the usual direction: production code that
   * reads `ref.id` got `undefined` here and simply took the other branch. The
   * owned-share SKIP in `scrubSharedContentItemAttribution` is keyed on it, so
   * without this the suite graded a skip that never happened.
   */
  id: string;
  parent: FakeCollectionRef;
  /** BUT-2046: a document read by id, for the moderation-record probe leg. */
  get(): Promise<{ exists: boolean; data(): DocData | undefined }>;
  delete(): Promise<void>;
  update(data: DocData): Promise<void>;
  collection(name: string): FakeSubcollection;
  /**
   * BUT-1957: `probeResidualData` stopped naming the `users/{uid}` subcollections
   * it probes and now ENUMERATES them. Without this method the enumeration lands
   * in the probe's own outer catch, which fails CLOSED — every clean fixture in
   * this file then reports `residual_data_detected`, and the six scenarios that
   * assert a clean store go red for a reason that has nothing to do with what
   * they test. Modelled, not stubbed to `[]`: a stub returning nothing would make
   * every assertion about the enumeration pass vacuously.
   */
  listCollections(): Promise<FakeSubcollectionRef[]>;
}

/** What `listCollections()` hands back: a subcollection handle that knows its id. */
interface FakeSubcollectionRef extends FakeSubcollection {
  id: string;
}

interface FakeQuerySnapshot {
  empty: boolean;
  size: number;
  docs: { ref: FakeRef; id: string; data: () => DocData }[];
}

interface FakeSubcollection {
  get(): Promise<FakeQuerySnapshot>;
  doc(id: string): FakeRef;
  /**
   * BUT-1789: a FILTERED read of a subcollection. The top-level `collection()`
   * matcher below cannot serve this — it only ever considers 2-segment paths,
   * so `analytics/feature_retention/users` (a 3-segment prefix) is invisible to
   * it, which is precisely the shape of collection the cascade had never swept.
   */
  where(
    field: string | admin.firestore.FieldPath,
    op: string,
    value: unknown,
  ): {
    get(): Promise<FakeQuerySnapshot>;
    count(): { get(): Promise<{ data(): { count: number } }> };
  };
  /** BUT-1822: needed by `probeResidualData`'s own subcollection legs. */
  count(): { get(): Promise<{ data(): { count: number } }> };
  /** BUT-2046: the cap-and-decline read on a subcollection. */
  limit(max: number): { get(): Promise<FakeQuerySnapshot> };
  listDocuments(): Promise<FakeRef[]>;
}

export class FakeFirestore {
  private docs = new Map<string, DocData>();
  /**
   * Every path a batch WROTE to. The fake's applyUpdate returns silently on a
   * missing doc, where a real `batch.update` throws grpc 5 and poison-pills the
   * whole chunk — so "was it written before it was deleted?" is invisible
   * unless the writes are recorded.
   */
  readonly updatedPaths: string[] = [];
  /**
   * Path -> grpc code that `ref.update()` should reject with. Empty by default,
   * so every existing scenario is untouched. See the seam in `makeRef`.
   */
  readonly updateFailures = new Map<string, number>();
  /**
   * Path -> grpc code that a BATCH commit touching that path should reject
   * with. Separate from `updateFailures` because the two write shapes reach
   * different code: `commitInChunks` batches, and its strict/swallow posture is
   * only observable through this one.
   */
  readonly batchFailures = new Map<string, number>();
  /**
   * Every path deleted, in order. BUT-1822 turns on an ORDERING invariant —
   * roster rows before the conversation document — and "both are gone at the
   * end" is exactly the assertion that cannot tell the fixed code from the
   * broken code.
   */
  readonly deletedPaths: string[] = [];
  /**
   * Paths whose `ref.get()` rejects. The reporter legs read each linked
   * `reports/{id}` one document at a time, and their fail-closed branch (keep
   * the row, report the step incomplete) is unreachable without this.
   */
  readonly readFailures = new Set<string>();

  private autoIdCounter = 0;

  /** Stands in for Firestore's generated document id. */
  private mintId(): string {
    this.autoIdCounter += 1;
    return `auto-${this.autoIdCounter}`;
  }

  set(path: string, data: DocData): void {
    this.docs.set(path, data);
  }

  get(path: string): DocData | undefined {
    return this.docs.get(path);
  }

  has(path: string): boolean {
    return this.docs.has(path);
  }

  /** Every stored path under `<collection>/`, top level only. */
  idsIn(collection: string): string[] {
    const out: string[] = [];
    for (const path of this.docs.keys()) {
      const segments = path.split("/");
      if (segments.length === 2 && segments[0] === collection) {
        out.push(segments[1]);
      }
    }
    return out.sort();
  }

  /** Every stored path directly under `<prefix>/` (one more segment). */
  pathsUnder(prefix: string): string[] {
    const depth = prefix.split("/").length + 1;
    const out: string[] = [];
    for (const path of this.docs.keys()) {
      if (!path.startsWith(`${prefix}/`)) continue;
      if (path.split("/").length === depth) out.push(path);
    }
    return out.sort();
  }

  private makeRef(path: string): FakeRef {
    const segments = path.split("/");
    const parentDocPath = segments.slice(0, -2).join("/");
    return {
      path,
      id: segments[segments.length - 1],
      parent: {
        id: segments[segments.length - 2],
        parent: parentDocPath === "" ? null : this.makeRef(parentDocPath),
      },
      // BUT-2046: `probeResidualData` reads the `user_moderation/{uid}` PARENT
      // by id, so the stub needs the one verb a document reference is normally
      // asked for. Without it the probe's own catch fires and every scenario
      // that asserts a CLEAN store reports `residual_data_detected` — a fail
      // shaped exactly like the leg working.
      get: async () => {
        if (this.readFailures.has(path)) {
          throw Object.assign(new Error(`injected read failure on ${path}`), {
            code: 14,
          });
        }
        const data = this.docs.get(path);
        return { exists: data !== undefined, data: () => data };
      },
      delete: async () => {
        this.deletedPaths.push(path);
        this.docs.delete(path);
      },
      update: async (data: DocData) => {
        // BUT-1801: the failure seam. Real Firestore REJECTS `update()` on a
        // missing document with grpc code 5 (NOT_FOUND); this stub silently
        // resolved, because `applyUpdate` returns on a missing doc. That made
        // the poll-creator scrub's code-5 tolerance unstageable — inverting the
        // predicate to tolerate everything EXCEPT code 5 left the whole suite
        // green, so the branch was dead weight to the tests that were meant to
        // hold it. Tests opt in by path; nothing else changes behaviour.
        //
        // Reaches `ref.update()` ONLY. A `batch().update` does not go through
        // `makeRef`, so an injection aimed at a `commitInChunks` path would pass
        // vacuously — check which write shape the code under test uses before
        // trusting a green result from this seam.
        const injected = this.updateFailures.get(path);
        if (injected !== undefined) {
          throw Object.assign(new Error(`injected update failure on ${path}`), {
            code: injected,
          });
        }
        this.applyUpdate(path, data);
      },
      // Subcollections are real in Firestore and NOT deleted with their parent
      // — the whole point of the orphan findings this suite now covers. The
      // stub models them as deeper slash-separated keys.
      //
      // Derived from the stored paths, exactly like `listDocuments` below and
      // for the same reason: a real `listCollections()` answers from what the
      // database HOLDS, so a subcollection whose parent document is gone is
      // still listed. Returning only names the test remembered to register
      // would make the enumeration a mirror of the fixture's intent instead of
      // of its contents.
      listCollections: async (): Promise<FakeSubcollectionRef[]> => {
        const prefix = `${path}/`;
        const names = new Set<string>();
        for (const p of this.docs.keys()) {
          if (!p.startsWith(prefix)) continue;
          const rest = p.slice(prefix.length).split("/");
          if (rest.length >= 2) names.add(rest[0]);
        }
        return [...names].sort().map((name) =>
          Object.assign(this.makeRef(path).collection(name), { id: name }),
        );
      },
      collection: (name: string): FakeSubcollection => {
        const snapshotOf = (paths: string[]): FakeQuerySnapshot =>
          this.snapshotOfPaths(paths);
        const filtered = (
          field: string | admin.firestore.FieldPath,
          op: string,
          value: unknown,
        ) =>
          this.pathsUnder(`${path}/${name}`).filter((p) => {
            // `readField`, not a literal key lookup: Firestore resolves a dotted
            // `where()` field as a PATH into nested maps, and a stub that
            // disagreed would report a dotted subcollection query as matching
            // nothing while claiming to pass. The top-level matcher has always
            // done this; extending `count()` here without it would put the trap
            // on a second path.
            const fieldVal = FakeFirestore.readField(
              this.docs.get(p) as DocData,
              field,
            );
            if (op === "==") return fieldVal === value;
            if (op === "array-contains") {
              return Array.isArray(fieldVal) && fieldVal.includes(value);
            }
            return false;
          });
        return {
          get: async () => snapshotOf(this.pathsUnder(`${path}/${name}`)),
          doc: (id: string) => this.makeRef(`${path}/${name}/${id}`),
          // BUT-2046: an UNFILTERED-but-limited subcollection read, which
          // `deleteModerationRecord` uses to tell a plausible row count from a
          // seeded one and DECLINE rather than truncate. The top-level matcher
          // and the collection-group one already had this; without it here the
          // deleter throws a TypeError that says nothing about the logic under
          // test — and because `main()` awaits the scenarios with one catch at
          // the bottom, that throw takes every scenario after it down too.
          limit: (max: number) => ({
            get: async () =>
              snapshotOf(this.pathsUnder(`${path}/${name}`).slice(0, max)),
          }),
          count: () => ({
            get: async () => {
              const size = this.pathsUnder(`${path}/${name}`).length;
              return { data: () => ({ count: size }) };
            },
          }),
          // Derived from DEEPER paths, not from stored documents: the one state
          // `listDocuments()` exists to surface is a MISSING parent that still
          // owns a subcollection, and a stub that mapped stored docs could never
          // represent it.
          listDocuments: async () => {
            const prefix = `${path}/${name}`;
            const depth = prefix.split("/").length + 1;
            const ids = new Set<string>();
            for (const p of this.docs.keys()) {
              if (!p.startsWith(`${prefix}/`)) continue;
              ids.add(p.split("/").slice(0, depth).join("/"));
            }
            return [...ids].sort().map((p) => this.makeRef(p));
          },
          where: (
            field: string | admin.firestore.FieldPath,
            op: string,
            value: unknown,
          ) => ({
            get: async () => snapshotOf(filtered(field, op, value)),
            count: () => ({
              get: async () => {
                const size = filtered(field, op, value).length;
                return { data: () => ({ count: size }) };
              },
            }),
          }),
        };
      },
    };
  }

  /** `applyUpdate` for the `FieldPath` form: a missing doc is not written. */
  private applyFieldPairs(path: string, pairs: [string[], unknown][]): void {
    const existing = this.docs.get(path);
    if (!existing) return;
    const next = { ...existing };
    for (const [segments, value] of pairs) {
      applyFieldPath(next, segments, value);
    }
    this.docs.set(path, next);
  }

  private applyUpdate(path: string, data: DocData): void {
    const existing = this.docs.get(path);
    if (!existing) return;
    const next = { ...existing };
    for (const [k, v] of Object.entries(data)) {
      // Dotted keys are Firestore FIELD PATHS, not literal key names — the
      // whole point of `participantDisplayNames.<uid>`. A stub that stored them
      // literally would report every map-key removal as passing.
      if (k.includes(".")) {
        applyFieldPath(next, k.split("."), v);
        continue;
      }
      if (isArrayRemoveOp(v)) {
        const cur = Array.isArray(next[k]) ? (next[k] as unknown[]) : [];
        next[k] = cur.filter((item) => !v.values.includes(item));
      } else if (isDeleteOp(v)) {
        delete next[k];
      } else if (isIncrementOp(v)) {
        next[k] = (typeof next[k] === "number" ? (next[k] as number) : 0) + v.by;
      } else {
        next[k] = v;
      }
    }
    this.docs.set(path, next);
  }

  /**
   * Firestore resolves a dotted `where()` field as a PATH into nested maps —
   * `metadata.subjectUserId` is not a key called "metadata.subjectUserId". A
   * stub that looked up the literal key would report the BUT-1788 system-message
   * sweep as matching nothing while claiming to pass.
   */
  /** A `FieldPath` is not a dotted string; its parts are its `.segments`. */
  private static readField(
    data: DocData,
    field: string | admin.firestore.FieldPath,
  ): unknown {
    const segments =
      field instanceof admin.firestore.FieldPath
        ? (field as unknown as { segments: string[] }).segments
        : field.split(".");
    let cursor: unknown = data;
    for (const segment of segments) {
      if (cursor === null || typeof cursor !== "object") return undefined;
      cursor = (cursor as Record<string, unknown>)[segment];
    }
    return cursor;
  }

  collection(name: string): unknown {
    const matching = (
      field: string | admin.firestore.FieldPath,
      op: string,
      value: unknown,
    ) => {
      const matches: { path: string; data: DocData }[] = [];
      for (const [path, data] of this.docs) {
        const segments = path.split("/");
        if (segments.length !== 2 || segments[0] !== name) continue;
        const fieldVal = FakeFirestore.readField(data, field);
        if (op === "==" && fieldVal === value) {
          matches.push({ path, data });
        } else if (op === "!=" && fieldVal !== value && fieldVal !== undefined) {
          // Firestore's `!=` excludes documents where the field is ABSENT. A
          // stub that returned them would report the shared-list member-key
          // probe as matching every document in the collection.
          matches.push({ path, data });
        } else if (
          op === "array-contains" &&
          Array.isArray(fieldVal) &&
          fieldVal.includes(value)
        ) {
          matches.push({ path, data });
        } else if (op === "in" && Array.isArray(value)) {
          // BUT-2046 follow-up. `hasOpenModerationCase` filters
          // `status in ['new','in_review','actioned']`, and without this branch
          // the stub matched NOTHING — so every hold scenario would have read
          // "no open case" and passed vacuously while asserting the opposite.
          if ((value as unknown[]).includes(fieldVal)) {
            matches.push({ path, data });
          }
        } else if (op === ">" && fieldVal !== undefined && fieldVal !== null) {
          // Timestamps compare by millis; a missing field, or a value of
          // another type, never matches, as in Firestore.
          if (
            fieldVal instanceof admin.firestore.Timestamp &&
            value instanceof admin.firestore.Timestamp &&
            fieldVal.toMillis() > value.toMillis()
          ) {
            matches.push({ path, data });
          }
        }
      }
      return matches;
    };
    // Same union as `matching` and `readField`. `asDb` casts through `unknown`,
    // so this type is never checked against production either way — what it buys
    // is inside the seam: under the union an inline `field.split(".")` is a
    // compile error, and that is the defect that shipped.
    // BUT-2046 follow-up: filters ACCUMULATE. `hasOpenModerationCase` chains
    // two `where()` calls (`contentOwnerId ==` then `status in`), and the
    // object this returned had no `where` of its own — so the second call threw
    // a TypeError, which the runner's single bottom-level catch turns into a
    // SHRUNKEN suite rather than a named failure.
    type Filter = {
      field: string | admin.firestore.FieldPath;
      op: string;
      value: unknown;
    };
    const matchingAll = (filters: Filter[]) =>
      filters
        .slice(1)
        .reduce(
          (acc, f) => {
            const next = matching(f.field, f.op, f.value);
            const keep = new Set(next.map((m) => m.path));
            return acc.filter((m) => keep.has(m.path));
          },
          matching(filters[0].field, filters[0].op, filters[0].value),
        );
    const matcher = (
      field: string | admin.firestore.FieldPath,
      op: string,
      value: unknown,
      prior: Filter[] = [],
    ): Record<string, unknown> => {
      const filters: Filter[] = [...prior, { field, op, value }];
      const matching = (
        _f: string | admin.firestore.FieldPath,
        _o: string,
        _v: unknown,
      ) => matchingAll(filters);
      return matcherFor(matching, filters);
    };
    const matcherFor = (
      matching: (
        field: string | admin.firestore.FieldPath,
        op: string,
        value: unknown,
      ) => { path: string; data: DocData }[],
      filters: Filter[],
    ) => {
      // The three names the body below reads. `matching` ignores its arguments
      // — it closes over the whole filter list — so these carry no meaning
      // beyond keeping the original single-filter body unchanged.
      const { field, op, value } = filters[0];
      return {
      where: (
        field: string | admin.firestore.FieldPath,
        op: string,
        value: unknown,
      ) => matcher(field, op, value, filters),
      // BUT-1822: `count()` was missing, which is why `probeResidualData` — the
      // cascade's own safety net — had no test in this file at all.
      count: () => ({
        get: async () => {
          const size = matching(field, op, value).length;
          return { data: () => ({ count: size }) };
        },
      }),
      // BUT-1838: a FILTERED-AND-LIMITED top-level read. `deleteChatGroupMemberships`
      // does `.where("memberIds","array-contains",uid).limit(MAX + 1).get()` so it
      // can tell "plausible" from "seeded" and DECLINE rather than truncate — the
      // same shape the collection-group matcher below already had, and without it
      // the step throws a TypeError that says nothing about the logic under test.
      limit: (max: number) => ({
        get: async () => {
          const matches = matching(field, op, value).slice(0, max);
          return {
            empty: matches.length === 0,
            size: matches.length,
            docs: matches.map((d) => ({
              ref: this.makeRef(d.path),
              id: d.path.split("/")[1],
              data: () => d.data,
              get: (f: string) => FakeFirestore.readField(d.data, f),
            })),
          };
        },
      }),
      get: async () => {
        const matches = matching(field, op, value);
        return {
          empty: matches.length === 0,
          size: matches.length,
          docs: matches.map((d) => ({
            ref: this.makeRef(d.path),
            id: d.path.split("/")[1],
            data: () => d.data,
            // Real QueryDocumentSnapshots expose get(); the shared_content
            // membership scrub uses it to skip docs it is about to hard-delete.
            get: (f: string) => FakeFirestore.readField(d.data, f),
          })),
        };
      },
      };
    };
    // BUT-1822: `name` can be a SLASH-SEPARATED path, and the read can be
    // unfiltered-but-limited. `tryClearRoster` — which the cascade now calls
    // before deleting a 1:1 conversation — does exactly
    // `db.collection("conversations/<id>/participants").limit(N + 1).get()`.
    // The matcher above cannot serve that: it only ever considers 2-segment
    // paths, and it is reached only through `where()` — the object `collection()`
    // itself returned had neither `get` nor `limit`, so wiring the roster clear
    // in without this would throw a TypeError that says nothing about the logic
    // under test.
    const unfiltered = (max?: number) => ({
      get: async () => {
        const paths = this.pathsUnder(name);
        return this.snapshotOfPaths(
          max === undefined ? paths : paths.slice(0, max),
        );
      },
    });
    // BUT-1957: `deleteUserSubcollections` finishes with the `system_rate_limits`
    // sweep, a documentId() PREFIX RANGE — `orderBy(documentId()).startAt(`${uid}_`)
    // .endAt(`${uid}_`)`. The matcher above cannot serve it (it is reached
    // only through `where()`), so without this the whole deleter throws before
    // any assertion about the subcollections it just swept can run.
    //
    // Modelled as a real lexicographic range on the document ID rather than as a
    // pass-through: the trailing sentinel in the production upper bound is
    // load-bearing and invisible in a diff, and a stub that ignored the bounds
    // would report an erase-everything mutant as passing.
    const idRange = (lower: string | null, upper: string | null) => ({
      startAt: (from: string) => idRange(from, upper),
      endAt: (to: string) => idRange(lower, to),
      get: async () => {
        const paths = this.pathsUnder(name).filter((p) => {
          const id = p.split("/")[1];
          if (lower !== null && id < lower) return false;
          if (upper !== null && id > upper) return false;
          return true;
        });
        return this.snapshotOfPaths(paths);
      },
    });
    return {
      where: (
        field: string | admin.firestore.FieldPath,
        op: string,
        value: unknown,
      ) => matcher(field, op, value),
      // BUT-2032: `.doc()` with no argument mints an id, as Firestore does.
      // Without it every `collection("audit_logs").doc()` in one run resolved to
      // the same `audit_logs/undefined` path and three staged rows collapsed
      // into one — a count that reads as a real measurement.
      doc: (id?: string) => this.makeRef(`${name}/${id ?? this.mintId()}`),
      get: unfiltered().get,
      limit: (max: number) => unfiltered(max),
      orderBy: (field: string | admin.firestore.FieldPath) => {
        if (!(field instanceof admin.firestore.FieldPath)) {
          throw new Error(
            `fake: orderBy is modelled for documentId() only, got ${String(field)}`,
          );
        }
        return idRange(null, null);
      },
    };
  }

  /** Shared snapshot shape for path-listing reads. */
  private snapshotOfPaths(paths: string[]): FakeQuerySnapshot {
    return {
      empty: paths.length === 0,
      size: paths.length,
      docs: paths.map((p) => ({
        ref: this.makeRef(p),
        id: p.split("/").pop() as string,
        data: () => this.docs.get(p) as DocData,
        // BUT-2046 follow-up: `sweepErasureHolds` reads `doc.get("holdUntil")`
        // off an unfiltered-and-limited read, which came through here. Real
        // QueryDocumentSnapshots expose it; the two filtered snapshots above
        // already did, so this was the one route that did not.
        get: (f: string) =>
          FakeFirestore.readField(this.docs.get(p) as DocData, f),
      })),
    };
  }

  /**
   * BUT-1798. Until now this stub had no `collectionGroup`, which is exactly why
   * `removeFromSharedContent` — whose first act is a collectionGroup read — had
   * no scenario in this file at all. Matches any path whose LAST collection
   * segment is `name`, at any depth, which is what a real collection-group query
   * does.
   */
  collectionGroup(name: string): unknown {
    const matching = (
      field: string | admin.firestore.FieldPath,
      op: string,
      value: unknown,
    ) => {
      const matches: { path: string; data: DocData }[] = [];
      for (const [path, data] of this.docs) {
        const segments = path.split("/");
        // A document path is collection/doc/collection/doc/... so the
        // owning collection is the second-to-last segment.
        if (segments.length < 2) continue;
        if (segments[segments.length - 2] !== name) continue;
        const fieldVal = FakeFirestore.readField(data, field);
        if (op === "==" && fieldVal === value) {
          matches.push({ path, data });
        } else if (
          op === "array-contains" &&
          Array.isArray(fieldVal) &&
          fieldVal.includes(value)
        ) {
          matches.push({ path, data });
        } else if (op === "!=") {
          // BUT-2272: `!= null` is how a map KEY is tested for presence. Only
          // that form is modelled; any other `!=` throws rather than matching
          // nothing in silence.
          if (value !== null) {
            throw new Error("fake collectionGroup: only `!= null` is modelled");
          }
          if (fieldVal !== undefined && fieldVal !== null) {
            matches.push({ path, data });
          }
        }
      }
      return matches;
    };
    const snapshotOf = (matches: { path: string; data: DocData }[]) => ({
      empty: matches.length === 0,
      size: matches.length,
      docs: matches.map((d) => ({
        ref: this.makeRef(d.path),
        id: d.path.split("/").pop() as string,
        data: () => d.data,
        get: (f: string) => FakeFirestore.readField(d.data, f),
      })),
    });
    return {
      where: (
        field: string | admin.firestore.FieldPath,
        op: string,
        value: unknown,
      ) => ({
        get: async () => snapshotOf(matching(field, op, value)),
        // BUT-1822. The roster sweep reads `.limit(MAX + 1)` so it can tell
        // "plausible" from "seeded" and decline rather than truncate, and the
        // residual probe reads `.count()`. Neither existed on this stub, so
        // neither could be tested — and `probeResidualData` had no test at all.
        limit: (max: number) => ({
          get: async () => snapshotOf(matching(field, op, value).slice(0, max)),
        }),
        count: () => ({
          get: async () => {
            const size = matching(field, op, value).length;
            return { data: () => ({ count: size }) };
          },
        }),
      }),
    };
  }

  batch(): {
    delete: (ref: FakeRef) => void;
    update: (
      ref: FakeRef,
      dataOrField: DocData | admin.firestore.FieldPath,
      ...moreFieldsAndValues: unknown[]
    ) => void;
    set: (ref: FakeRef, data: DocData) => void;
    commit: () => Promise<void>;
  } {
    const deletes: string[] = [];
    const updates: {
      path: string;
      data?: DocData;
      fieldPairs?: [string[], unknown][];
    }[] = [];
    const sets: { path: string; data: DocData }[] = [];
    return {
      delete: (ref) => {
        deletes.push(ref.path);
      },
      // BUT-2272: the Admin SDK's other `update` form, alternating
      // `FieldPath`, value, `FieldPath`, value. Kept as segment lists, never
      // joined into a dotted string, so a key holding a dot stays one key.
      update: (ref, dataOrField, ...moreFieldsAndValues) => {
        this.updatedPaths.push(ref.path);
        if (!(dataOrField instanceof admin.firestore.FieldPath)) {
          updates.push({ path: ref.path, data: dataOrField });
          return;
        }
        const args = [dataOrField, ...moreFieldsAndValues];
        if (args.length % 2 !== 0) {
          throw new Error("fake batch.update: unpaired FieldPath argument");
        }
        const fieldPairs: [string[], unknown][] = [];
        for (let i = 0; i < args.length; i += 2) {
          if (!(args[i] instanceof admin.firestore.FieldPath)) {
            throw new Error("fake batch.update: expected a FieldPath");
          }
          fieldPairs.push([
            (args[i] as unknown as { segments: string[] }).segments,
            args[i + 1],
          ]);
        }
        updates.push({ path: ref.path, fieldPairs });
      },
      // BUT-2032: `set` CREATES, where `update` requires the document to exist.
      // Routing both through `applyUpdate` made a `batch.set` on a new path a
      // silent no-op, which is the shape `stageCascadeAuditEntry` writes — so an
      // audit row staged by the cascade was invisible to every assertion in this
      // file, and a test counting them read zero while the production call was
      // correct.
      set: (ref, data) => {
        sets.push({ path: ref.path, data });
      },
      commit: async () => {
        // BUT-1716: the seam the `updateFailures` map above cannot reach. A
        // `batch.update`/`batch.delete` never goes through `makeRef`, so every
        // strict-vs-swallow posture in `commitInChunks` was unstageable — and a
        // swallowed chunk is exactly how an erasure reports success over rows it
        // left behind. Keyed on a path IN the batch, so a test names the write
        // it wants to fail rather than the chunk it happens to land in.
        for (const path of [
          ...sets.map((s) => s.path),
          ...updates.map((u) => u.path),
          ...deletes,
        ]) {
          const injected = this.batchFailures.get(path);
          if (injected !== undefined) {
            throw Object.assign(
              new Error(`injected batch failure on ${path}`),
              { code: injected },
            );
          }
        }
        for (const s of sets) this.docs.set(s.path, { ...s.data });
        for (const u of updates) {
          if (u.fieldPairs) this.applyFieldPairs(u.path, u.fieldPairs);
          else this.applyUpdate(u.path, u.data as DocData);
        }
        for (const path of deletes) {
          this.deletedPaths.push(path);
          this.docs.delete(path);
        }
      },
    };
  }

  /**
   * Passthrough, not a real transaction — no isolation, no retry, writes
   * apply immediately against the same in-memory store `get`/`update` use.
   * Enough to drive the re-read-then-write logic the two callers in
   * account-deletion-cascade.ts need proven (a fresh `.exists`/`.data()` read
   * inside the handler, not the stale outer-query snapshot); nothing here
   * proves the code resists an ACTUAL concurrent writer.
   */
  async runTransaction<T>(
    handler: (tx: {
      get: (
        ref: FakeRef,
      ) => Promise<{ exists: boolean; data: () => DocData | undefined }>;
      getAll: (
        ...refs: FakeRef[]
      ) => Promise<{ exists: boolean; data: () => DocData | undefined }[]>;
      set: (ref: FakeRef, data: DocData) => void;
      update: (ref: FakeRef, data: DocData) => void;
      delete: (ref: FakeRef) => void;
    }) => Promise<T>,
  ): Promise<T> {
    const tx = {
      get: async (ref: FakeRef) => {
        const data = this.docs.get(ref.path);
        return { exists: data !== undefined, data: () => data };
      },
      // BUT-2046: `migrate-report-history.ts` reads every candidate target in
      // ONE call after the parent read, rather than a `get` per entry.
      getAll: async (...refs: FakeRef[]) =>
        refs.map((ref) => {
          const data = this.docs.get(ref.path);
          return { exists: data !== undefined, data: () => data };
        }),
      // BUT-2046: `set` CREATES. The batch's `set` had the same gap — routing
      // it through `applyUpdate` made a write to a new path a silent no-op,
      // which is the shape this migration's every write has.
      set: (ref: FakeRef, data: DocData) => {
        this.docs.set(ref.path, { ...data });
      },
      update: (ref: FakeRef, data: DocData) => {
        this.applyUpdate(ref.path, data);
      },
      delete: (ref: FakeRef) => {
        this.docs.delete(ref.path);
      },
    };
    return handler(tx);
  }
}
