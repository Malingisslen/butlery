/**
 * BUT-455: cascade-audit-log helper unit tests.
 *
 * Verifies that `stageCascadeAuditEntry` (in-batch) and `writeCascadeAuditEntry`
 * (standalone) emit the exact `audit_logs` schema that callers rely on for
 * GDPR Article 17 traceability:
 *
 *   userId / operation / resourceType / resourceId / granted / timestamp /
 *   metadata.{ actor, targetUid, reason, ...extra }
 *
 * Also confirms that the in-batch variant commits atomically with the cascade
 * write — if the batch fails, the audit row never reaches Firestore.
 *
 * Run with: npx ts-node src/__tests__/cascade-audit-log.test.ts
 */

import * as admin from "firebase-admin";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-but455" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  stageCascadeAuditEntry,
  writeCascadeAuditEntry,
} = require("../cleanup/cascade-audit-log");

const SERVER_TIMESTAMP_MARKER = Symbol("serverTimestamp");
(admin.firestore.FieldValue as unknown as {
  serverTimestamp: () => unknown;
}).serverTimestamp = () => SERVER_TIMESTAMP_MARKER;

interface FakeRef {
  path: string;
}

interface BatchOp {
  path: string;
  data: Record<string, unknown>;
}

/**
 * Minimal Firestore stub. Implements only the calls
 * `stageCascadeAuditEntry` / `writeCascadeAuditEntry` make:
 *   - `db.collection(name).doc()` → auto-id ref
 *   - `db.batch().set(ref, data) + commit()`
 *   - `ref.set(data)` (standalone path)
 */
class FakeFirestore {
  private docs = new Map<string, Record<string, unknown>>();
  private nextId = 0;
  public failNextCommit = false;

  collection(name: string): {
    doc: () => FakeRef & { set: (d: Record<string, unknown>) => Promise<void> };
  } {
    return {
      doc: () => {
        const path = `${name}/auto-${this.nextId++}`;
        const ref: FakeRef = { path };
        return {
          ...ref,
          set: async (d: Record<string, unknown>) => {
            this.docs.set(path, d);
          },
        };
      },
    };
  }

  batch(): {
    set: (ref: FakeRef, data: Record<string, unknown>) => void;
    commit: () => Promise<void>;
  } {
    const ops: BatchOp[] = [];
    return {
      set: (ref, data) => {
        ops.push({ path: ref.path, data });
      },
      commit: async () => {
        if (this.failNextCommit) {
          this.failNextCommit = false;
          throw new Error("simulated commit failure");
        }
        for (const op of ops) {
          this.docs.set(op.path, op.data);
        }
      },
    };
  }

  // Test helpers
  audit_logs(): Record<string, unknown>[] {
    const rows: Record<string, unknown>[] = [];
    for (const [path, data] of this.docs) {
      if (path.startsWith("audit_logs/")) rows.push(data);
    }
    return rows;
  }
}

const cases: UnitCase[] = [
  {
    name: "stageCascadeAuditEntry: writes the documented shape on batch commit",
    fn: async () => {
      const db = new FakeFirestore();
      const batch = db.batch();

      stageCascadeAuditEntry(db, batch, {
        subjectUserId: "deletedUid",
        targetUid: "friendUid",
        operation: "cascade_delete",
        resourceType: "friends",
        resourceId: "friendUid",
        extra: { sourceCollection: "users/friendUid/friends/deletedUid" },
      });

      await batch.commit();

      const rows = db.audit_logs();
      assertEqual(rows.length, 1, "exactly one audit row committed");

      const row = rows[0];
      assertEqual(row.userId, "deletedUid", "userId = subject");
      assertEqual(row.operation, "cascade_delete", "operation tag");
      assertEqual(row.resourceType, "friends", "resourceType");
      assertEqual(row.resourceId, "friendUid", "resourceId");
      assertEqual(row.granted, true, "granted=true (system-authorized)");
      assertEqual(
        row.timestamp,
        SERVER_TIMESTAMP_MARKER,
        "timestamp uses serverTimestamp()"
      );

      const meta = row.metadata as Record<string, unknown>;
      assertEqual(meta.actor, "system", "metadata.actor=system");
      assertEqual(meta.targetUid, "friendUid", "metadata.targetUid");
      assertEqual(
        meta.reason,
        "gdpr_article_17",
        "metadata.reason=gdpr_article_17"
      );
      assertEqual(
        meta.sourceCollection,
        "users/friendUid/friends/deletedUid",
        "metadata.extra fields merged in"
      );
    },
  },
  {
    name: "stageCascadeAuditEntry: failed batch commit drops the audit row (atomic)",
    fn: async () => {
      const db = new FakeFirestore();
      db.failNextCommit = true;
      const batch = db.batch();

      stageCascadeAuditEntry(db, batch, {
        subjectUserId: "deletedUid",
        targetUid: "otherUid",
        operation: "cascade_delete",
        resourceType: "friend_categories",
        resourceId: "groupX",
      });

      let threw = false;
      try {
        await batch.commit();
      } catch {
        threw = true;
      }

      assertEqual(threw, true, "commit failure surfaces to caller");
      assertEqual(
        db.audit_logs().length,
        0,
        "no audit row persisted when batch fails"
      );
    },
  },
  {
    name: "writeCascadeAuditEntry: standalone write also produces the documented shape",
    fn: async () => {
      const db = new FakeFirestore();

      await writeCascadeAuditEntry(db, {
        subjectUserId: "deletedUid",
        targetUid: null,
        operation: "cascade_anonymize",
        resourceType: "reports",
        resourceId: "reportX",
      });

      const rows = db.audit_logs();
      assertEqual(rows.length, 1, "one audit row from standalone write");

      const row = rows[0];
      assertEqual(row.operation, "cascade_anonymize", "operation");
      assertEqual(row.resourceType, "reports", "resourceType");
      const meta = row.metadata as Record<string, unknown>;
      assertEqual(
        meta.targetUid,
        null,
        "targetUid can be null for own-data cleanup"
      );
      assertEqual(meta.actor, "system", "actor=system");
      assertEqual(meta.reason, "gdpr_article_17", "reason");
    },
  },
];

runTests("BUT-455: cascade-audit-log helper", cases);
