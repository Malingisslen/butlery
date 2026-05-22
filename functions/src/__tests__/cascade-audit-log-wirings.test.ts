/**
 * BUT-886: integration-style tests that exercise the new cascade-audit
 * wirings end-to-end. Each case drives one of the wave-8 wirings against an
 * in-memory FakeFirestore stub and asserts that an `audit_logs` row is
 * staged in the same batch as the cascade mutation.
 *
 * Wave-7 covered `stageCascadeAuditEntry` / `writeCascadeAuditEntry` shape
 * (see `cascade-audit-log.test.ts`). This file covers the 10 *callers*
 * added in wave-8 — proving that the contract holds at the integration
 * boundary, not just the helper.
 *
 * Run with: npx ts-node src/__tests__/cascade-audit-log-wirings.test.ts
 */

import * as admin from "firebase-admin";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-but886" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { cascadeArrayRemove } = require("../shared/batch-update");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { stageCascadeAuditEntry } = require("../cleanup/cascade-audit-log");

const SERVER_TIMESTAMP_MARKER = Symbol("serverTimestamp");
(admin.firestore.FieldValue as unknown as {
  serverTimestamp: () => unknown;
  arrayRemove: (value: unknown) => unknown;
}).serverTimestamp = () => SERVER_TIMESTAMP_MARKER;
(admin.firestore.FieldValue as unknown as {
  arrayRemove: (value: unknown) => unknown;
}).arrayRemove = (value: unknown) => ({ __op: "arrayRemove", value });

interface FakeDocRef {
  path: string;
  id: string;
  parent: FakeCollRef;
}

interface FakeCollRef {
  id: string;
  parent: FakeDocRef | null;
}

interface FakeDocSnap {
  id: string;
  ref: FakeDocRef;
  data: () => Record<string, unknown>;
}

interface BatchOp {
  kind: "set" | "update" | "delete";
  path: string;
  data?: Record<string, unknown>;
}

/**
 * FakeFirestore for cascadeArrayRemove + audit assertions. Implements only
 * the surface the helpers under test touch: `db.batch()`, `batch.update`,
 * `batch.set`, `batch.delete`, `batch.commit`, and `db.collection(name).doc()`
 * (used by the audit helper).
 */
class FakeFirestore {
  private docs = new Map<string, Record<string, unknown>>();
  private nextId = 0;
  private fixedDocs: FakeDocSnap[] = [];

  /** Seed an array of `{id, data}` to be returned from any `.get()`. */
  seedQueryResults(docs: { id: string; data: Record<string, unknown>; path?: string }[]): void {
    this.fixedDocs = docs.map((d) => {
      const path = d.path ?? `seeded/${d.id}`;
      const parts = path.split("/");
      const id = parts[parts.length - 1];
      const collId = parts[parts.length - 2] ?? "seeded";
      const collRef: FakeCollRef = { id: collId, parent: null };
      const ref: FakeDocRef = { path, id, parent: collRef };
      return { id, ref, data: () => d.data };
    });
  }

  /** Stub query — `.get()` returns the seeded snapshot. */
  collectionGroupOrCollection(): {
    get: () => Promise<{ empty: boolean; size: number; docs: FakeDocSnap[] }>;
    where: (...args: unknown[]) => unknown;
  } {
    const docs = this.fixedDocs;
    const obj = {
      get: async () => ({ empty: docs.length === 0, size: docs.length, docs }),
      where: (..._args: unknown[]) => obj,
    };
    return obj;
  }

  collection(name: string): {
    doc: (id?: string) => FakeDocRef;
    where: (...args: unknown[]) => unknown;
    get: () => Promise<{ empty: boolean; size: number; docs: FakeDocSnap[] }>;
  } {
    const dbRef = this;
    return {
      doc: (id?: string) => {
        const docId = id ?? `auto-${this.nextId++}`;
        const path = `${name}/${docId}`;
        const collRef: FakeCollRef = { id: name, parent: null };
        return { path, id: docId, parent: collRef };
      },
      where: (..._args: unknown[]) => dbRef.collectionGroupOrCollection(),
      get: async () => ({
        empty: dbRef.fixedDocs.length === 0,
        size: dbRef.fixedDocs.length,
        docs: dbRef.fixedDocs,
      }),
    };
  }

  batch(): {
    set: (ref: FakeDocRef, data: Record<string, unknown>) => void;
    update: (ref: FakeDocRef, data: Record<string, unknown>) => void;
    delete: (ref: FakeDocRef) => void;
    commit: () => Promise<void>;
  } {
    const ops: BatchOp[] = [];
    return {
      set: (ref, data) => ops.push({ kind: "set", path: ref.path, data }),
      update: (ref, data) =>
        ops.push({ kind: "update", path: ref.path, data }),
      delete: (ref) => ops.push({ kind: "delete", path: ref.path }),
      commit: async () => {
        for (const op of ops) {
          if (op.kind === "delete") this.docs.delete(op.path);
          else this.docs.set(op.path, op.data ?? {});
        }
      },
    };
  }

  /** Inspect committed audit rows in order. */
  auditLogs(): Record<string, unknown>[] {
    const rows: Record<string, unknown>[] = [];
    for (const [path, data] of this.docs) {
      if (path.startsWith("audit_logs/")) rows.push(data);
    }
    return rows;
  }

  /** Inspect committed mutations under a specific top-level collection. */
  mutationsUnder(prefix: string): { path: string; data: Record<string, unknown> }[] {
    const out: { path: string; data: Record<string, unknown> }[] = [];
    for (const [path, data] of this.docs) {
      if (path.startsWith(prefix)) out.push({ path, data });
    }
    return out;
  }
}

const cases: UnitCase[] = [
  {
    name:
      "cascadeArrayRemove with onItemOp: stages audit row per affected doc in same batch",
    fn: async () => {
      const db = new FakeFirestore();
      db.seedQueryResults([
        { id: "group-A", data: { friendUserIds: ["deletedUid", "alice"] } },
        { id: "group-B", data: { friendUserIds: ["bob", "deletedUid"] } },
        { id: "group-C", data: { friendUserIds: ["deletedUid"] } },
      ]);

      const matched = await cascadeArrayRemove(
        // The fake `.where(...)` returns a chainable stub — pass the
        // collection's `.where()` result through to satisfy the helper's
        // signature.
        db.collection("friend_categories").where(),
        "friendUserIds",
        "deletedUid",
        db,
        {
          onItemOp: (
            batch: admin.firestore.WriteBatch,
            doc: { id: string }
          ) => {
            stageCascadeAuditEntry(db, batch, {
              subjectUserId: "deletedUid",
              targetUid: null,
              operation: "cascade_delete",
              resourceType: "friend_categories",
              resourceId: doc.id,
              extra: { field: "friendUserIds" },
            });
          },
        }
      );

      assertEqual(matched, 3, "3 docs matched query");

      const audits = db.auditLogs();
      assertEqual(audits.length, 3, "one audit row per affected doc");

      const ids = audits.map((r) => r.resourceId).sort();
      assertEqual(ids[0], "group-A", "audit references group-A");
      assertEqual(ids[1], "group-B", "audit references group-B");
      assertEqual(ids[2], "group-C", "audit references group-C");

      for (const row of audits) {
        assertEqual(row.userId, "deletedUid", "subject is deletedUid");
        assertEqual(row.operation, "cascade_delete", "op tag");
        assertEqual(row.resourceType, "friend_categories", "resourceType");
        const meta = row.metadata as Record<string, unknown>;
        assertEqual(meta.actor, "system", "actor=system");
        assertEqual(meta.reason, "gdpr_article_17", "reason");
        assertEqual(meta.field, "friendUserIds", "extra fields merged");
      }
    },
  },
  {
    name:
      "cascadeArrayRemove with onItemOp: arrayRemove + audit commit atomically",
    fn: async () => {
      const db = new FakeFirestore();
      db.seedQueryResults([
        {
          id: "doc-X",
          path: "shared_content/doc-X",
          data: { sharedWith: ["deletedUid"], sharedByUserId: "sharerUid" },
        },
      ]);

      await cascadeArrayRemove(
        db.collection("shared_content").where(),
        "sharedWith",
        "deletedUid",
        db,
        {
          bestEffort: true,
          onItemOp: (
            batch: admin.firestore.WriteBatch,
            doc: { id: string; data: () => Record<string, unknown> }
          ) => {
            stageCascadeAuditEntry(db, batch, {
              subjectUserId: "deletedUid",
              targetUid: doc.data().sharedByUserId as string,
              operation: "cascade_delete",
              resourceType: "shared_content",
              resourceId: doc.id,
              extra: { field: "sharedWith", legacy: true },
            });
          },
        }
      );

      // Mutation landed: the arrayRemove update was applied to shared_content/doc-X.
      const mutations = db.mutationsUnder("shared_content/");
      assertEqual(mutations.length, 1, "shared_content doc mutated");

      const audits = db.auditLogs();
      assertEqual(audits.length, 1, "one audit row committed alongside");
      const audit = audits[0];
      const meta = audit.metadata as Record<string, unknown>;
      assertEqual(
        meta.targetUid,
        "sharerUid",
        "targetUid points at the doc owner (sharer)"
      );
      assertEqual(meta.legacy, true, "legacy flag merged via extra");
    },
  },
  {
    name: "cascadeArrayRemove without onItemOp: backward-compatible — no audit rows",
    fn: async () => {
      const db = new FakeFirestore();
      db.seedQueryResults([
        { id: "doc-1", data: { friendUserIds: ["x", "y"] } },
      ]);

      await cascadeArrayRemove(
        db.collection("friend_categories").where(),
        "friendUserIds",
        "x",
        db
      );

      assertEqual(
        db.auditLogs().length,
        0,
        "no audit rows when caller omits onItemOp"
      );
    },
  },
];

runTests("BUT-886: cascade-audit wirings via cascadeArrayRemove.onItemOp", cases);
