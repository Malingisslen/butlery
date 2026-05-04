/**
 * BUT-627: ping rate-limit + sweeper tests.
 *
 * Coverage:
 *   1. 5 pings within the past hour → 6th create is deleted + audit row written.
 *   2. ≤5 pings within the past hour → ping kept, no audit row.
 *   3. Pings older than 1h don't count toward the cap.
 *   4. Sweeper deletes only `expiresAt < now` pings.
 *
 * Run with: npx ts-node src/__tests__/ping_rate_limit.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-ping-rate-limit" });
}

import { enforcePingRateLimit } from "../triggers/ping_onCreate";
import { runPingSweeper } from "../scheduled/ping_sweeper";

let totalRun = 0;
let totalFailed = 0;

function record(name: string, ok: boolean, detail?: string): void {
  totalRun++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    totalFailed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

interface FakeDoc {
  path: string;
  data: Record<string, unknown>;
}

const ts = (ms: number): admin.firestore.Timestamp =>
  admin.firestore.Timestamp.fromMillis(ms);

class FakeFirestore {
  public docs = new Map<string, Record<string, unknown>>();
  public deletes: string[] = [];
  public addedDocs: { collectionPath: string; data: Record<string, unknown> }[] =
    [];
  private autoIdCounter = 0;

  set(path: string, data: Record<string, unknown>): void {
    this.docs.set(path, data);
  }

  size(): number {
    return this.docs.size;
  }

  // ---------- doc ref ----------
  doc(path: string) {
    return this.makeRef(path);
  }

  private makeRef(path: string) {
    const self = this;
    return {
      path,
      async delete() {
        self.docs.delete(path);
        self.deletes.push(path);
      },
      async set(data: Record<string, unknown>) {
        self.docs.set(path, data);
      },
      collection: (sub: string) => self.makeCollectionPath(`${path}/${sub}`),
    };
  }

  // ---------- collection ----------
  collection(name: string) {
    return this.makeCollectionPath(name);
  }

  private makeCollectionPath(collectionPath: string) {
    const self = this;
    return {
      doc(id: string) {
        return self.makeRef(`${collectionPath}/${id}`);
      },
      async add(data: Record<string, unknown>) {
        const id = `auto_${++self.autoIdCounter}`;
        const path = `${collectionPath}/${id}`;
        self.docs.set(path, data);
        self.addedDocs.push({ collectionPath, data });
        return self.makeRef(path);
      },
    };
  }

  // ---------- collectionGroup ----------
  collectionGroup(name: string) {
    return this.makeCgQuery(name, []);
  }

  private makeCgQuery(
    cgName: string,
    wheres: Array<{ field: string; op: string; value: unknown }>
  ) {
    const self = this;
    const limitVal = { n: undefined as number | undefined };
    const obj = {
      where(field: string, op: string, value: unknown) {
        return self.makeCgQuery(cgName, [...wheres, { field, op, value }]);
      },
      limit(n: number) {
        limitVal.n = n;
        return obj;
      },
      count() {
        return {
          async get() {
            const matches = self.matchCg(cgName, wheres);
            return { data: () => ({ count: matches.length }) };
          },
        };
      },
      async get() {
        const matches = self.matchCg(cgName, wheres);
        const sliced =
          limitVal.n !== undefined ? matches.slice(0, limitVal.n) : matches;
        return {
          empty: sliced.length === 0,
          size: sliced.length,
          docs: sliced.map((m) => ({
            ref: self.makeRef(m.path),
            data: () => m.data,
          })),
        };
      },
    };
    return obj;
  }

  private matchCg(
    cgName: string,
    wheres: Array<{ field: string; op: string; value: unknown }>
  ): FakeDoc[] {
    const out: FakeDoc[] = [];
    for (const [path, data] of this.docs) {
      const segments = path.split("/");
      // collection-group match: any segment N (even-index) named cgName
      // AND segment N+1 is the doc id.
      let isMember = false;
      for (let i = 0; i < segments.length - 1; i += 2) {
        if (segments[i] === cgName) {
          isMember = true;
          break;
        }
      }
      if (!isMember) continue;

      let match = true;
      for (const w of wheres) {
        const v = data[w.field] as { toMillis?: () => number } | string;
        if (w.op === "==") {
          if (v !== w.value) match = false;
        } else if (
          w.op === "<" ||
          w.op === ">=" ||
          w.op === "<=" ||
          w.op === ">"
        ) {
          const vMs =
            typeof (v as { toMillis?: () => number })?.toMillis === "function"
              ? (v as { toMillis: () => number }).toMillis()
              : NaN;
          const tMs =
            typeof (w.value as { toMillis?: () => number })?.toMillis ===
            "function"
              ? (w.value as { toMillis: () => number }).toMillis()
              : NaN;
          if (w.op === "<" && !(vMs < tMs)) match = false;
          if (w.op === ">=" && !(vMs >= tMs)) match = false;
          if (w.op === "<=" && !(vMs <= tMs)) match = false;
          if (w.op === ">" && !(vMs > tMs)) match = false;
        }
      }
      if (match) out.push({ path, data });
    }
    return out;
  }

  // ---------- batch ----------
  batch() {
    const ops: Array<() => void> = [];
    const self = this;
    return {
      delete(ref: { path: string }) {
        ops.push(() => {
          self.docs.delete(ref.path);
          self.deletes.push(ref.path);
        });
      },
      async commit() {
        for (const op of ops) op();
      },
    };
  }
}

async function rateLimitKeepsUpToFive(): Promise<void> {
  const db = new FakeFirestore();
  const NOW = 1_000_000_000;
  const HOUR = 60 * 60 * 1000;
  // Seed 4 existing pings from the same user, all within the past hour
  for (let i = 0; i < 4; i++) {
    db.set(`pings/g1/pings/old_${i}`, {
      fromUserId: "user-A",
      createdAt: ts(NOW - HOUR + 1000 + i * 1000),
      expiresAt: ts(NOW + HOUR),
    });
  }
  // Now the 5th ping fires
  db.set("pings/g1/pings/p5", {
    fromUserId: "user-A",
    createdAt: ts(NOW - 1000),
    expiresAt: ts(NOW + HOUR),
  });

  const result = await enforcePingRateLimit(
    "p5",
    "g1",
    {
      fromUserId: "user-A",
      createdAt: ts(NOW - 1000),
    },
    { db: db as never, now: () => new Date(NOW) }
  );

  const stillExists = db.docs.has("pings/g1/pings/p5");
  const noAudit = db.addedDocs.length === 0;
  record(
    "5 pings within 1h → kept, no audit",
    result.deleted === false &&
      result.count === 5 &&
      stillExists &&
      noAudit,
    `deleted=${result.deleted} count=${result.count} stillExists=${stillExists} audit=${db.addedDocs.length}`
  );
}

async function rateLimitDeletesSixth(): Promise<void> {
  const db = new FakeFirestore();
  const NOW = 2_000_000_000;
  const HOUR = 60 * 60 * 1000;

  // Seed 5 existing pings from same user within the past hour
  for (let i = 0; i < 5; i++) {
    db.set(`pings/g1/pings/old_${i}`, {
      fromUserId: "user-B",
      createdAt: ts(NOW - HOUR + 1000 + i * 1000),
      expiresAt: ts(NOW + HOUR),
    });
  }
  // 6th ping fires
  db.set("pings/g1/pings/p6", {
    fromUserId: "user-B",
    createdAt: ts(NOW - 100),
    expiresAt: ts(NOW + HOUR),
  });

  const result = await enforcePingRateLimit(
    "p6",
    "g1",
    {
      fromUserId: "user-B",
      createdAt: ts(NOW - 100),
    },
    { db: db as never, now: () => new Date(NOW) }
  );

  const deleted = !db.docs.has("pings/g1/pings/p6");
  const auditRow = db.addedDocs.find(
    (d) => d.collectionPath === "audit_logs"
  );
  const auditCorrect =
    auditRow !== undefined &&
    (auditRow.data.userId as string) === "user-B" &&
    (auditRow.data.operation as string) === "ping_rate_limit_exceeded" &&
    (auditRow.data.resourceType as string) === "ping" &&
    (auditRow.data.deletedPingId as string) === "p6" &&
    (auditRow.data.count as number) === 6;

  record(
    "6th ping in 1h → deleted + audit row",
    result.deleted === true &&
      result.count === 6 &&
      deleted &&
      auditCorrect,
    `deleted=${result.deleted} count=${result.count} dbDeleted=${deleted} audit=${JSON.stringify(auditRow?.data)}`
  );
}

async function oldPingsDontCount(): Promise<void> {
  const db = new FakeFirestore();
  const NOW = 3_000_000_000;
  const HOUR = 60 * 60 * 1000;

  // 6 pings from user-C BUT all >1h old
  for (let i = 0; i < 6; i++) {
    db.set(`pings/g1/pings/old_${i}`, {
      fromUserId: "user-C",
      createdAt: ts(NOW - 2 * HOUR - i * 1000),
      expiresAt: ts(NOW + HOUR),
    });
  }
  // Fresh 1st ping in window
  db.set("pings/g1/pings/p_new", {
    fromUserId: "user-C",
    createdAt: ts(NOW - 100),
    expiresAt: ts(NOW + HOUR),
  });

  const result = await enforcePingRateLimit(
    "p_new",
    "g1",
    {
      fromUserId: "user-C",
      createdAt: ts(NOW - 100),
    },
    { db: db as never, now: () => new Date(NOW) }
  );

  record(
    "old pings outside 1h window don't count",
    result.deleted === false && result.count === 1,
    `deleted=${result.deleted} count=${result.count}`
  );
}

async function sweeperDeletesOnlyExpired(): Promise<void> {
  const db = new FakeFirestore();
  const NOW = 4_000_000_000;
  const HOUR = 60 * 60 * 1000;

  db.set("pings/g1/pings/expired_1", {
    fromUserId: "u1",
    createdAt: ts(NOW - HOUR),
    expiresAt: ts(NOW - 1000), // expired
  });
  db.set("pings/g2/pings/expired_2", {
    fromUserId: "u2",
    createdAt: ts(NOW - HOUR),
    expiresAt: ts(NOW - 5_000), // expired
  });
  db.set("pings/g1/pings/fresh_1", {
    fromUserId: "u1",
    createdAt: ts(NOW),
    expiresAt: ts(NOW + HOUR), // fresh
  });

  const result = await runPingSweeper({
    db: db as never,
    now: () => new Date(NOW),
  });

  const expired1Gone = !db.docs.has("pings/g1/pings/expired_1");
  const expired2Gone = !db.docs.has("pings/g2/pings/expired_2");
  const freshKept = db.docs.has("pings/g1/pings/fresh_1");

  record(
    "sweeper deletes only expired pings",
    result.deleted === 2 && expired1Gone && expired2Gone && freshKept,
    `deleted=${result.deleted} e1=${expired1Gone} e2=${expired2Gone} fresh=${freshKept}`
  );
}

async function missingFromUserIdNoOp(): Promise<void> {
  const db = new FakeFirestore();
  const NOW = 5_000_000_000;
  db.set("pings/g1/pings/p_bad", {
    // fromUserId missing
    createdAt: ts(NOW - 100),
    expiresAt: ts(NOW + 1000),
  });

  const result = await enforcePingRateLimit(
    "p_bad",
    "g1",
    {
      // fromUserId missing
      createdAt: ts(NOW - 100),
    },
    { db: db as never, now: () => new Date(NOW) }
  );

  record(
    "ping with no fromUserId → no-op (no delete, no audit)",
    result.deleted === false &&
      result.count === 0 &&
      db.docs.has("pings/g1/pings/p_bad") &&
      db.addedDocs.length === 0,
    `deleted=${result.deleted} stillThere=${db.docs.has("pings/g1/pings/p_bad")} audits=${db.addedDocs.length}`
  );
}

async function runAll(): Promise<void> {
  console.log("BUT-627: ping rate-limit + sweeper tests\n");
  console.log("==============================================\n");
  await rateLimitKeepsUpToFive();
  await rateLimitDeletesSixth();
  await oldPingsDontCount();
  await sweeperDeletesOnlyExpired();
  await missingFromUserIdNoOp();

  console.log(
    `\n${totalRun - totalFailed}/${totalRun} passed` +
      (totalFailed ? `, ${totalFailed} failed` : "")
  );
  if (totalFailed > 0) process.exit(1);
}

runAll().catch((err) => {
  console.error(err);
  process.exit(1);
});
