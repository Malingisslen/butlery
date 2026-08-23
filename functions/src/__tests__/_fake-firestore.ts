/**
 * BUT-1838: an in-memory Firestore double for the chat-group unit suites.
 *
 * The suites it serves all assert the same class of property: WHICH documents
 * an operation touched, and WHAT is left in them afterwards. A recording stub that only
 * pushes payloads into an array cannot answer the second half — the repo's own
 * lesson is that a fake which RE-DERIVES the intended effect, instead of
 * APPLYING the recorded write, makes the whole write vacuous. So this one
 * applies the payload: dot-path keys address a single literal key, `arrayRemove`
 * really shrinks the array, `FieldValue.delete()` really removes the map entry,
 * and an unrecognised sentinel THROWS rather than being silently stored.
 *
 * **What it is faithful to**, deliberately, because each one is load-bearing
 * somewhere in these suites:
 *  - `update()` on a MISSING document rejects with grpc code 5, like the real
 *    SDK. A double that silently no-ops there hides every NOT_FOUND poison-pill.
 *  - a transaction buffers its writes and applies them only after the callback
 *    RESOLVES, so a denial thrown mid-transaction leaves nothing behind — which
 *    is exactly what the "a denied removal writes nothing" cases assert. The
 *    update-target existence check runs before anything is applied, so a failing
 *    transaction is all-or-nothing.
 *  - a transactional read does NOT see that transaction's own pending writes.
 *  - an unmodelled method throws by name instead of answering.
 *
 * **What it is NOT**: it evaluates no security rules, it has no isolation,
 * contention, abort or retry (the callback runs exactly once, single-threaded),
 * and its query primitive is "the direct children of this collection",
 * optionally `.limit()`ed and filtered by `==` or `array-contains` — no
 * ordering, no ranges, no indexes, so a query that would need a composite index
 * in production answers happily here. Nothing may be cited as evidence about
 * concurrency or index coverage; both live on the emulator lane.
 */

import * as admin from "firebase-admin";

export type FakeDoc = Record<string, unknown>;

export interface FakeWrite {
  op: "set" | "update" | "delete";
  path: string;
  /** The payload exactly as the caller passed it, sentinels UNRESOLVED. */
  data?: FakeDoc;
}

export interface FakeFirestoreOptions {
  /** Return true to make `delete()` on that path reject (grpc code 13). */
  failDeleteAt?: (path: string) => boolean;
  /** Make every `collection().add()` reject. */
  failAdds?: boolean;
  /** The value every `serverTimestamp()` sentinel resolves to. */
  now?: admin.firestore.Timestamp;
}

export interface FakeDocSnap {
  id: string;
  exists: boolean;
  ref: FakeDocRef;
  data(): FakeDoc | undefined;
  get(field: string): unknown;
}

export interface FakeDocRef {
  id: string;
  path: string;
  collection(name: string): FakeColRef;
  get(): Promise<FakeDocSnap>;
  set(data: FakeDoc): Promise<void>;
  update(data: FakeDoc): Promise<void>;
  delete(): Promise<void>;
}

export interface FakeQuery {
  limit(n: number): FakeQuery;
  /** Only `==` and `array-contains` are modelled; anything else throws. */
  where(field: string, op: string, value: unknown): FakeQuery;
  get(): Promise<{ size: number; empty: boolean; docs: FakeDocSnap[] }>;
}

export interface FakeColRef extends FakeQuery {
  path: string;
  doc(id?: string): FakeDocRef;
  add(data: FakeDoc): Promise<FakeDocRef>;
}

interface Pending {
  op: "set" | "update" | "delete";
  path: string;
  data?: FakeDoc;
}

/** grpc NOT_FOUND, the code `retry:true` handlers branch on. */
function notFound(path: string): Error {
  return Object.assign(
    new Error(`fake-firestore: no document to update at ${path}`),
    { code: 5 },
  );
}

/**
 * Clones plain containers and passes CLASS INSTANCES through untouched — a
 * `Timestamp` deep-cloned into an object literal stops being a Timestamp, and
 * half these assertions compare stamps by identity.
 */
function clone(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(clone);
  if (
    value !== null &&
    typeof value === "object" &&
    (value.constructor === Object || value.constructor === undefined)
  ) {
    const out: FakeDoc = {};
    for (const [k, v] of Object.entries(value as FakeDoc)) out[k] = clone(v);
    return out;
  }
  return value;
}

/**
 * Names the FieldValue transform a value is, or null when it is ordinary data.
 *
 * Dispatches on the constructor name because that is what the installed SDK
 * exposes (`ArrayUnionTransform.elements` is a public own property). Anything
 * that IS a FieldValue but is not one of the five recognised shapes throws:
 * silently storing a sentinel would make a write assertion pass while the
 * production write did something else entirely.
 */
function transformKind(value: unknown): string | null {
  if (value === null || typeof value !== "object") return null;
  const name = value.constructor?.name;
  const known = [
    "DeleteTransform",
    "ServerTimestampTransform",
    "ArrayUnionTransform",
    "ArrayRemoveTransform",
    "NumericIncrementTransform",
  ];
  if (name && known.includes(name)) return name;
  if (value instanceof admin.firestore.FieldValue) {
    throw new Error(
      `fake-firestore: unrecognised FieldValue sentinel ${String(name)} — teach the fake about it rather than storing it`,
    );
  }
  return null;
}

function elementsOf(value: unknown): unknown[] {
  return (value as { elements?: unknown[] }).elements ?? [];
}

function getAt(doc: FakeDoc, segments: string[]): unknown {
  let cursor: unknown = doc;
  for (const segment of segments) {
    if (cursor === null || typeof cursor !== "object") return undefined;
    cursor = (cursor as FakeDoc)[segment];
  }
  return cursor;
}

function setAt(doc: FakeDoc, segments: string[], value: unknown): void {
  let cursor: FakeDoc = doc;
  for (const segment of segments.slice(0, -1)) {
    const next = cursor[segment];
    if (next === null || typeof next !== "object" || Array.isArray(next)) {
      cursor[segment] = {};
    }
    cursor = cursor[segment] as FakeDoc;
  }
  cursor[segments[segments.length - 1]] = value;
}

function deleteAt(doc: FakeDoc, segments: string[]): void {
  let cursor: unknown = doc;
  for (const segment of segments.slice(0, -1)) {
    if (cursor === null || typeof cursor !== "object") return;
    cursor = (cursor as FakeDoc)[segment];
  }
  if (cursor !== null && typeof cursor === "object") {
    delete (cursor as FakeDoc)[segments[segments.length - 1]];
  }
}

interface Filter {
  field: string;
  op: string;
  value: unknown;
}

/**
 * The two operators these suites need. Anything else throws rather than
 * silently matching everything — a query the fake does not understand would
 * make an assertion pass for the wrong reason.
 */
function matches(stored: unknown, filter: Filter): boolean {
  switch (filter.op) {
    case "==":
      return stored === filter.value;
    case "array-contains":
      return Array.isArray(stored) && stored.includes(filter.value);
    default:
      throw new Error(
        `fake-firestore: operator ${filter.op} is not modelled — teach the fake about it`,
      );
  }
}

export class FakeFirestore {
  /** Live document store, keyed by full path. */
  readonly docs = new Map<string, FakeDoc>();
  /** Every APPLIED write, in order. Seeding is not recorded. */
  readonly writes: FakeWrite[] = [];
  private autoId = 0;
  private readonly options: FakeFirestoreOptions;
  private readonly now: admin.firestore.Timestamp;

  constructor(options: FakeFirestoreOptions = {}) {
    this.options = options;
    this.now = options.now ?? admin.firestore.Timestamp.fromMillis(1_700_000_000_000);
  }

  /** The SUT-facing handle. */
  get db(): admin.firestore.Firestore {
    return this as unknown as admin.firestore.Firestore;
  }

  /** Puts a document in place without recording a write. */
  seed(path: string, data: FakeDoc): void {
    this.docs.set(path, clone(data) as FakeDoc);
  }

  /** Current stored state of a document, or undefined. */
  read(path: string): FakeDoc | undefined {
    const doc = this.docs.get(path);
    return doc === undefined ? undefined : (clone(doc) as FakeDoc);
  }

  has(path: string): boolean {
    return this.docs.has(path);
  }

  /** Paths of the direct children of a collection path. */
  childPaths(collectionPath: string): string[] {
    const prefix = `${collectionPath}/`;
    return [...this.docs.keys()]
      .filter(
        (path) => path.startsWith(prefix) && !path.slice(prefix.length).includes("/"),
      )
      .sort();
  }

  // --- the admin.firestore.Firestore surface the SUTs use --------------------

  collection(path: string): FakeColRef {
    return this.colRef(path);
  }

  doc(path: string): FakeDocRef {
    return this.docRef(path);
  }

  async getAll(...refs: FakeDocRef[]): Promise<FakeDocSnap[]> {
    return refs.map((ref) => this.snapshot(ref.path));
  }

  async runTransaction<T>(fn: (tx: unknown) => Promise<T>): Promise<T> {
    const pending: Pending[] = [];
    const tx = {
      get: async (ref: FakeDocRef) => this.snapshot(ref.path),
      set: (ref: FakeDocRef, data: FakeDoc) =>
        void pending.push({ op: "set", path: ref.path, data }),
      update: (ref: FakeDocRef, data: FakeDoc) =>
        void pending.push({ op: "update", path: ref.path, data }),
      delete: (ref: FakeDocRef) =>
        void pending.push({ op: "delete", path: ref.path }),
    };
    const result = await fn(tx);
    // Existence is checked for the WHOLE batch first: a real commit that hits a
    // missing update target applies none of its writes, and the "nothing was
    // written" assertions would be wrong if this applied a prefix of them.
    for (const write of pending) {
      if (write.op === "update" && !this.docs.has(write.path)) {
        throw notFound(write.path);
      }
    }
    for (const write of pending) this.apply(write);
    return result;
  }

  batch(): never {
    throw new Error("fake-firestore: batch() is not modelled — add it if a SUT starts using it");
  }

  collectionGroup(): never {
    throw new Error("fake-firestore: collectionGroup() is not modelled");
  }

  // --- internals -------------------------------------------------------------

  private snapshot(path: string): FakeDocSnap {
    const stored = this.docs.get(path);
    const ref = this.docRef(path);
    return {
      id: ref.id,
      exists: stored !== undefined,
      ref,
      data: () => (stored === undefined ? undefined : (clone(stored) as FakeDoc)),
      get: (field: string) =>
        stored === undefined ? undefined : clone(getAt(stored, field.split("."))),
    };
  }

  private docRef(path: string): FakeDocRef {
    const segments = path.split("/");
    return {
      id: segments[segments.length - 1],
      path,
      collection: (name: string) => this.colRef(`${path}/${name}`),
      get: async () => this.snapshot(path),
      set: async (data: FakeDoc) => this.apply({ op: "set", path, data }),
      update: async (data: FakeDoc) => this.apply({ op: "update", path, data }),
      delete: async () => {
        if (this.options.failDeleteAt?.(path)) {
          throw Object.assign(new Error(`fake-firestore: delete refused at ${path}`), {
            code: 13,
          });
        }
        this.apply({ op: "delete", path });
      },
    };
  }

  private colRef(path: string): FakeColRef {
    const query = (limit: number | null, filters: Filter[]): FakeQuery => ({
      limit: (n: number) => query(n, filters),
      where: (field: string, op: string, value: unknown) =>
        query(limit, [...filters, { field, op, value }]),
      get: async () => {
        const matching = this.childPaths(path).filter((p) => {
          const stored = this.docs.get(p);
          return (
            stored !== undefined &&
            filters.every((f) => matches(getAt(stored, f.field.split(".")), f))
          );
        });
        const page = (limit === null ? matching : matching.slice(0, limit)).map(
          (p) => this.snapshot(p),
        );
        return { size: page.length, empty: page.length === 0, docs: page };
      },
    });
    return {
      path,
      doc: (id?: string) => this.docRef(`${path}/${id ?? `auto-${++this.autoId}`}`),
      add: async (data: FakeDoc) => {
        if (this.options.failAdds) {
          throw Object.assign(new Error("fake-firestore: add refused"), { code: 13 });
        }
        const ref = this.docRef(`${path}/auto-${++this.autoId}`);
        this.apply({ op: "set", path: ref.path, data });
        return ref;
      },
      ...query(null, []),
    };
  }

  private apply(write: Pending): void {
    if (write.op === "delete") {
      this.docs.delete(write.path);
    } else if (write.op === "set") {
      this.docs.set(write.path, this.resolveForSet(write.data ?? {}));
    } else {
      const current = this.docs.get(write.path);
      if (current === undefined) throw notFound(write.path);
      this.applyUpdate(current, write.data ?? {});
    }
    this.writes.push({ op: write.op, path: write.path, data: write.data });
  }

  /** `set()` accepts data plus `serverTimestamp()`; anything else is a bug. */
  private resolveForSet(data: FakeDoc): FakeDoc {
    const resolve = (value: unknown): unknown => {
      const kind = transformKind(value);
      if (kind === "ServerTimestampTransform") return this.now;
      if (kind !== null) {
        throw new Error(
          `fake-firestore: ${kind} is not valid inside a set() without merge`,
        );
      }
      if (Array.isArray(value)) return value.map(resolve);
      if (
        value !== null &&
        typeof value === "object" &&
        (value.constructor === Object || value.constructor === undefined)
      ) {
        const out: FakeDoc = {};
        for (const [k, v] of Object.entries(value as FakeDoc)) out[k] = resolve(v);
        return out;
      }
      return value;
    };
    return resolve(data) as FakeDoc;
  }

  private applyUpdate(doc: FakeDoc, data: FakeDoc): void {
    for (const [key, value] of Object.entries(data)) {
      // A dotted key addresses ONE literal path — which is the whole reason the
      // production code refuses a uid containing a dot.
      const segments = key.split(".");
      const kind = transformKind(value);
      if (kind === "DeleteTransform") {
        deleteAt(doc, segments);
        continue;
      }
      if (kind === "ServerTimestampTransform") {
        setAt(doc, segments, this.now);
        continue;
      }
      if (kind === "ArrayUnionTransform" || kind === "ArrayRemoveTransform") {
        const current = getAt(doc, segments);
        const base = Array.isArray(current) ? [...current] : [];
        const elements = elementsOf(value);
        for (const element of elements) {
          if (element !== null && typeof element === "object") {
            throw new Error(
              "fake-firestore: array transforms are modelled for primitives only",
            );
          }
        }
        setAt(
          doc,
          segments,
          kind === "ArrayUnionTransform"
            ? [...base, ...elements.filter((e) => !base.includes(e))]
            : base.filter((e) => !elements.includes(e)),
        );
        continue;
      }
      setAt(doc, segments, clone(value));
    }
  }
}
