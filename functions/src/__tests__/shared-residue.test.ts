/**
 * BUT-1747: `exportSharedResidue` — the Art. 15 export of shared shopping
 * lists the requester has LEFT and of `shared_content` item rows.
 *
 * What this file cannot prove: `_fake-firestore` answers queries without
 * indexes and evaluates no rules, so index coverage of the four `items`
 * collection-group queries is pinned in `firestore.indexes.json` and exercised
 * on the emulator lane, not here.
 *
 * Run: npx ts-node src/__tests__/shared-residue.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-shared-residue" });
}

import * as fs from "fs";
import * as path from "path";
import { HttpsError } from "firebase-functions/v2/https";
import { FakeFirestore, FakeDoc } from "./_fake-firestore";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";
import { assertGuardTriggersCoverItsDartInputs } from "./_dart-guard-triggers";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const residue = require("../exports/shared-residue") as typeof import("../exports/shared-residue");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const cascade = require("../account/account-deletion-cascade") as typeof import("../account/account-deletion-cascade");

const UID = "requester-uid";
const OTHER = "other-uid";
const THIRD = "third-uid";
const LISTS = "unified_shared_shopping_lists";
const T0 = admin.firestore.Timestamp.fromMillis(1_700_000_000_000);
const T0_ISO = new Date(1_700_000_000_000).toISOString();

function run(db: FakeFirestore) {
  return residue.runExportSharedResidueWithDb(db.db, UID);
}

function assertTrue(condition: boolean, msg: string): void {
  if (!condition) throw new Error(msg);
}

async function expectDecline(p: Promise<unknown>): Promise<void> {
  try {
    await p;
  } catch (err) {
    assertTrue(err instanceof HttpsError, `expected HttpsError, got ${String(err)}`);
    const e = err as HttpsError;
    assertEqual(e.code, "failed-precondition", "decline code");
    assertEqual(
      (e.details as { error_code?: string } | undefined)?.error_code,
      residue.TOO_LARGE_ERROR_CODE,
      "decline error_code",
    );
    return;
  }
  throw new Error("expected a decline, the export succeeded");
}

/** A row naming the requester as adder and two other people elsewhere. */
function mineRow(extra: FakeDoc = {}): FakeDoc {
  return {
    id: "mine",
    name: "Mjölk",
    amount: 2,
    unit: "l",
    category: "dairy",
    bought: true,
    addedByUserId: UID,
    addedByDisplayName: "Me",
    addedAt: T0,
    purchasedByUserId: OTHER,
    purchasedByDisplayName: "Them",
    purchasedAt: T0,
    lastModifiedByUserId: THIRD,
    lastModifiedByDisplayName: "Third",
    lastModifiedAt: T0,
    note: "laktosfri",
    estimatedPrice: 19.9,
    priority: 3,
    ...extra,
  };
}

function theirsRow(): FakeDoc {
  return {
    id: "theirs",
    name: "Bröd",
    addedByUserId: OTHER,
    addedByDisplayName: "Them",
  };
}

function seedList(db: FakeFirestore, id: string, data: FakeDoc): void {
  db.seed(`${LISTS}/${id}`, {
    name: `List ${id}`,
    ownerId: OTHER,
    ownerDisplayName: "Them",
    memberPermissions: { [OTHER]: "admin" },
    createdAt: T0,
    updatedAt: T0,
    items: [],
    ...data,
  });
}

const cases: UnitCase[] = [
  {
    name: "contributorUserIds finder: a left list exports only the requester's row",
    fn: async () => {
      const db = new FakeFirestore();
      seedList(db, "L1", {
        contributorUserIds: [OTHER, UID],
        lastActivityByUserId: OTHER,
        lastActivityByDisplayName: "Them",
        lastActivityAt: T0,
        items: [mineRow(), theirsRow()],
      });
      const out = await run(db);
      assertEqual(out.shared_lists_left.length, 1, "lists");
      const list = out.shared_lists_left[0];
      assertEqual(list.id, "L1", "id");
      assertEqual(list.name, "List L1", "name");
      assertEqual(list.ownerId, OTHER, "ownerId kept");
      assertEqual(list.createdAt, T0_ISO, "createdAt as ISO");
      assertEqual(list.recorded_as_contributor, true, "recorded_as_contributor");
      assertEqual(list.items.length, 1, "only the requester's row");
      assertEqual(list.items[0].id, "mine", "row id");
      assertEqual("lastActivityByUserId" in list, false, "someone else's activity withheld");
      assertEqual("lastActivityByDisplayName" in list, false, "their name withheld");
      assertEqual("lastActivityAt" in list, false, "their activity time withheld");
      assertEqual(JSON.stringify(list).includes("contributorUserIds"), false, "trail not exported");
      assertEqual(JSON.stringify(list).includes("ownerDisplayName"), false, "owner name not exported");
    },
  },
  {
    name: "lastActivityByUserId finder: a left list off the trail is found, activity exported",
    fn: async () => {
      const db = new FakeFirestore();
      seedList(db, "L2", {
        contributorUserIds: [OTHER],
        lastActivityByUserId: UID,
        lastActivityByDisplayName: "Me",
        lastActivityAt: T0,
        items: [mineRow()],
      });
      const out = await run(db);
      assertEqual(out.shared_lists_left.length, 1, "lists");
      const list = out.shared_lists_left[0];
      assertEqual(list.recorded_as_contributor, false, "not on the trail");
      assertEqual(list.lastActivityByUserId, UID, "own activity uid");
      assertEqual(list.lastActivityByDisplayName, "Me", "own activity name");
      assertEqual(list.lastActivityAt, T0_ISO, "own activity time");
    },
  },
  {
    name: "a list matched by both finders is exported once",
    fn: async () => {
      const db = new FakeFirestore();
      seedList(db, "L3", {
        contributorUserIds: [UID],
        lastActivityByUserId: UID,
        items: [mineRow()],
      });
      const out = await run(db);
      assertEqual(out.shared_lists_left.length, 1, "deduped");
    },
  },
  {
    name: "owned and current-member lists are left to the client section",
    fn: async () => {
      const db = new FakeFirestore();
      seedList(db, "owned", {
        ownerId: UID,
        memberPermissions: { [OTHER]: "edit" },
        contributorUserIds: [UID],
        items: [mineRow()],
      });
      seedList(db, "member", {
        memberPermissions: { [OTHER]: "admin", [UID]: "edit" },
        lastActivityByUserId: UID,
        items: [mineRow()],
      });
      const out = await run(db);
      assertEqual(out.shared_lists_left.length, 0, "neither exported");
    },
  },
  {
    name: "a memberPermissions key whose value is null is a left list",
    fn: async () => {
      const db = new FakeFirestore();
      seedList(db, "nulled", {
        memberPermissions: { [OTHER]: "admin", [UID]: null },
        contributorUserIds: [UID],
        items: [mineRow()],
      });
      const out = await run(db);
      assertEqual(out.shared_lists_left.map((l) => l.id).join(","), "nulled", "exported as left");
    },
  },
  {
    name: "a rejoin between the membership read and the full read is not exported",
    fn: async () => {
      const db = new FakeFirestore();
      seedList(db, "rejoined", { contributorUserIds: [UID], items: [mineRow()] });
      const getAll = db.getAll.bind(db);
      db.getAll = async (...args) => {
        seedList(db, "rejoined", {
          memberPermissions: { [OTHER]: "admin", [UID]: "edit" },
          contributorUserIds: [UID],
          items: [mineRow()],
        });
        return getAll(...args);
      };
      const out = await run(db);
      assertEqual(out.shared_lists_left.length, 0, "re-checked on the full read");
    },
  },
  {
    name: "projection: other uids stripped, own name kept, other names dropped",
    fn: async () => {
      const db = new FakeFirestore();
      seedList(db, "L4", {
        contributorUserIds: [UID],
        items: [mineRow({ assignedToUserId: OTHER, assignedToDisplayName: "Them" })],
      });
      const item = (await run(db)).shared_lists_left[0].items[0];
      assertEqual(item.addedByUserId, UID, "own uid kept");
      assertEqual(item.addedByDisplayName, "Me", "own name kept");
      assertEqual(item.addedAt, T0_ISO, "own timestamp as ISO");
      for (const key of [
        "purchasedByUserId",
        "purchasedByDisplayName",
        "lastModifiedByUserId",
        "lastModifiedByDisplayName",
        "assignedToUserId",
        "assignedToDisplayName",
      ]) {
        assertEqual(key in item, false, `${key} stripped`);
      }
      const text = JSON.stringify(item);
      assertEqual(text.includes(OTHER) || text.includes(THIRD), false, "no other uid anywhere");
      assertEqual(text.includes("Them") || text.includes("Third"), false, "no other name anywhere");
      assertEqual(item.note, "laktosfri", "content kept");
      assertEqual(item.amount, 2, "amount kept");
    },
  },
  {
    name: "allowlist: an unknown key and an unpaired display name are dropped",
    fn: async () => {
      const item = residue.projectItem(
        mineRow({
          secretField: "x",
          contributorUserIds: [OTHER],
          assignedToDisplayName: "Ghost",
        }),
        UID,
      );
      assertEqual("secretField" in item, false, "unknown key dropped");
      assertEqual("contributorUserIds" in item, false, "list-level key dropped");
      assertEqual("assignedToDisplayName" in item, false, "unpaired name dropped");
    },
  },
  {
    name: "values: only scalars, null and Timestamps pass; a reference or container is dropped",
    fn: async () => {
      const item = residue.projectItem(
        mineRow({
          note: admin.firestore().doc("users/x"),
          category: { nested: { deeper: OTHER } },
          unit: [OTHER],
          priority: null,
        }),
        UID,
      );
      assertEqual("note" in item, false, "reference dropped");
      assertEqual("category" in item, false, "nested map dropped");
      assertEqual("unit" in item, false, "array dropped");
      assertEqual(item.priority, null, "null kept");
      assertEqual(item.amount, 2, "number kept");
      assertEqual(item.bought, true, "boolean kept");
      assertEqual(item.name, "Mjölk", "string kept");
      assertEqual(item.addedAt, T0_ISO, "Timestamp as ISO");
      assertEqual(JSON.stringify(item).includes(OTHER), false, "nothing nested leaks");
    },
  },
  {
    name: "previous: the snapshot's content keys export, anything else in it is dropped",
    fn: async () => {
      const item = residue.projectItem(
        mineRow({
          previous: {
            id: "r1",
            name: "Filmjölk",
            amount: 1,
            unit: "l",
            category: "Mejeri",
            note: null,
            at: admin.firestore.Timestamp.fromDate(new Date(T0_ISO)),
            editedByUserId: OTHER,
            nested: { who: OTHER },
          },
        }),
        UID,
      );
      const previous = item.previous as Record<string, unknown>;
      assertEqual(
        JSON.stringify(Object.keys(previous).sort()),
        JSON.stringify(["amount", "at", "category", "id", "name", "note", "unit"]),
        "every snapshot key kept",
      );
      assertEqual(previous.name, "Filmjölk", "content kept");
      assertEqual(previous.at, T0_ISO, "Timestamp as ISO");
      assertEqual("editedByUserId" in previous, false, "unknown key dropped");
      assertEqual(JSON.stringify(item).includes(OTHER), false, "no other uid leaks");
    },
  },
  {
    name: "allowlist key set equals UnifiedShoppingItem.toFirestore's keys",
    fn: async () => {
      const repoRoot = path.join(__dirname, "..", "..", "..");
      const dartFile = path.join(
        repoRoot,
        "lib",
        "models",
        "unified",
        "unified_shopping_item.dart",
      );
      const source = fs.readFileSync(dartFile, "utf8");
      const start = source.indexOf("Map<String, dynamic> toFirestore()");
      assertTrue(start >= 0, "toFirestore not found in the Dart model");
      const end = source.indexOf("};", start);
      const body = source.slice(start, end);
      const dartKeys = [...body.matchAll(/^\s*'(\w+)'\s*:/gm)].map((m) => m[1]).sort();
      assertTrue(dartKeys.includes("estimatedPrice"), `scan found ${JSON.stringify(dartKeys)}`);
      assertEqual(
        JSON.stringify([...residue.ITEM_EXPORT_KEYS].sort()),
        JSON.stringify(dartKeys),
        "allowlist vs Dart toFirestore",
      );

      for (const field of cascade.ITEM_UID_FIELDS) {
        assertTrue(residue.ITEM_EXPORT_KEYS.includes(field), `${field} allowlisted`);
        assertTrue(
          residue.ITEM_EXPORT_KEYS.includes(residue.DISPLAY_NAME_OF[field]),
          `${residue.DISPLAY_NAME_OF[field]} allowlisted`,
        );
      }

      const snapshotFile = path.join(
        repoRoot,
        "lib",
        "models",
        "unified",
        "shopping_row_snapshot.dart",
      );
      const snapshotSource = fs.readFileSync(snapshotFile, "utf8");
      const snapshotStart = snapshotSource.indexOf("Map<String, dynamic> toFirestore()");
      assertTrue(snapshotStart >= 0, "toFirestore not found in the snapshot model");
      const snapshotBody = snapshotSource.slice(
        snapshotStart,
        snapshotSource.indexOf("};", snapshotStart),
      );
      const snapshotKeys = [...snapshotBody.matchAll(/^\s*'(\w+)'\s*:/gm)]
        .map((m) => m[1])
        .sort();
      assertEqual(
        JSON.stringify([...residue.SNAPSHOT_EXPORT_KEYS].sort()),
        JSON.stringify(snapshotKeys),
        "snapshot allowlist vs Dart toFirestore",
      );

      const failures: string[] = [];
      assertGuardTriggersCoverItsDartInputs(repoRoot, [dartFile, snapshotFile], (name, ok, reason) => {
        if (!ok) failures.push(`${name}: ${reason ?? ""}`);
      });
      assertEqual(failures.join("; ") || "(none)", "(none)", "CI trigger covers the Dart input");
    },
  },
  {
    name: "shared_content: rows found by a uid query, other rows and uids left out",
    fn: async () => {
      const db = new FakeFirestore();
      db.seed("shared_content/S1", { sharedByUserId: OTHER });
      db.seed("shared_content/S1/items/i1", {
        name: "Ägg",
        assignedToUserId: UID,
        assignedToDisplayName: "Me",
        addedByUserId: OTHER,
        addedByDisplayName: "Them",
      });
      db.seed("shared_content/S1/items/i2", { name: "Ost", addedByUserId: OTHER });
      const out = await run(db);
      assertEqual(out.shared_content_items.length, 1, "one row");
      const row = out.shared_content_items[0];
      assertEqual(row.shareId, "S1", "shareId");
      assertEqual(row.itemId, "i1", "itemId");
      assertEqual(row.item.assignedToUserId, UID, "own uid");
      assertEqual(row.item.assignedToDisplayName, "Me", "own name");
      assertEqual("addedByUserId" in row.item, false, "other uid stripped");
      assertEqual("addedByDisplayName" in row.item, false, "other name stripped");
    },
  },
  {
    name: "shared_content: every row under an owned share, deduped against the uid queries",
    fn: async () => {
      const db = new FakeFirestore();
      db.seed("shared_content/S2", { sharedByUserId: UID });
      db.seed("shared_content/S2/items/j1", {
        name: "Smör",
        addedByUserId: OTHER,
        addedByDisplayName: "Them",
      });
      db.seed("shared_content/S2/items/j2", { name: "Salt", addedByUserId: UID });
      const out = await run(db);
      const ids = out.shared_content_items.map((r) => r.itemId).join(",");
      assertEqual(ids, "j1,j2", "both rows, once each");
      const j1 = out.shared_content_items[0].item;
      assertEqual(j1.name, "Smör", "content kept");
      assertEqual("addedByUserId" in j1, false, "other uid stripped on an owned share too");
      assertEqual("addedByDisplayName" in j1, false, "other name stripped on an owned share too");
    },
  },
  {
    name: "items outside a top-level shared_content parent are excluded",
    fn: async () => {
      const db = new FakeFirestore();
      db.seed(`users/${UID}/unified_shopping_lists/p/items/k`, { addedByUserId: UID });
      db.seed("groups/g/shared_content/x/items/y", { addedByUserId: UID });
      db.seed("shared_content/S/x/y/items/z", { addedByUserId: UID });
      const out = await run(db);
      assertEqual(out.shared_content_items.length, 0, "none exported");
    },
  },
  {
    name: "personal-list rows do not count toward the item cap",
    fn: async () => {
      const db = new FakeFirestore();
      for (let i = 0; i < residue.MAX_ITEM_ROWS + 5; i++) {
        db.seed(`users/${UID}/unified_shopping_lists/p/items/k${i}`, { addedByUserId: UID });
      }
      db.seed("shared_content/S3/items/z", { addedByUserId: UID });
      const out = await run(db);
      assertEqual(out.shared_content_items.length, 1, "exported, not declined");
    },
  },
  {
    name: "item cap: one row over declines",
    fn: async () => {
      const db = new FakeFirestore();
      for (let i = 0; i <= residue.MAX_ITEM_ROWS; i++) {
        db.seed(`shared_content/S4/items/r${i}`, { addedByUserId: UID });
      }
      await expectDecline(run(db));
    },
  },
  {
    name: "item cap: rows under owned shares count toward it",
    fn: async () => {
      const db = new FakeFirestore();
      db.seed("shared_content/S5", { sharedByUserId: UID });
      for (let i = 0; i <= residue.MAX_ITEM_ROWS; i++) {
        db.seed(`shared_content/S5/items/r${i}`, { name: "x" });
      }
      await expectDecline(run(db));
    },
  },
  {
    name: "left-list cap: one list over declines",
    fn: async () => {
      const db = new FakeFirestore();
      for (let i = 0; i <= residue.MAX_LEFT_LISTS; i++) {
        seedList(db, `c${i}`, { contributorUserIds: [UID] });
      }
      await expectDecline(run(db));
    },
  },
  {
    name: "raw item read bound declines even when every row would be filtered out",
    fn: async () => {
      const db = new FakeFirestore();
      for (let i = 0; i <= residue.MAX_RAW_ITEM_READS; i++) {
        db.seed(`shared_content/S/x/y/items/k${i}`, { addedByUserId: UID });
      }
      await expectDecline(run(db));
    },
  },
  {
    name: "personal-list rows past the raw read bound do not decline",
    fn: async () => {
      const db = new FakeFirestore();
      for (let i = 0; i <= residue.MAX_RAW_ITEM_READS; i++) {
        db.seed(`users/${OTHER}/unified_shopping_lists/p/items/k${i}`, { addedByUserId: UID });
      }
      db.seed("shared_content/S6/items/z", { addedByUserId: UID });
      const out = await run(db);
      assertEqual(out.shared_content_items.length, 1, "exported, not declined");
    },
  },
  {
    name: "owned-share cap: one share over declines",
    fn: async () => {
      const db = new FakeFirestore();
      for (let i = 0; i <= residue.MAX_OWNED_SHARES; i++) {
        db.seed(`shared_content/o${i}`, { sharedByUserId: UID });
      }
      await expectDecline(run(db));
    },
  },
  {
    name: "raw list read bound declines even when every list is still held",
    fn: async () => {
      const db = new FakeFirestore();
      for (let i = 0; i <= residue.MAX_RAW_LIST_READS; i++) {
        seedList(db, `m${i}`, {
          memberPermissions: { [OTHER]: "admin", [UID]: "edit" },
          contributorUserIds: [UID],
        });
      }
      await expectDecline(run(db));
    },
  },
  {
    name: "a response over the byte bound declines",
    fn: async () => {
      const db = new FakeFirestore();
      seedList(db, "big", {
        contributorUserIds: [UID],
        items: [mineRow({ note: "x".repeat(residue.MAX_RESPONSE_BYTES) })],
      });
      await expectDecline(run(db));
    },
  },
  {
    name: "unauthenticated: refused before rate limit or reads",
    fn: async () => {
      const calls: string[] = [];
      try {
        await residue.handleExportSharedResidue(
          { auth: null },
          {
            rateLimit: async () => void calls.push("rateLimit"),
            run: async () => {
              calls.push("run");
              throw new Error("must not run");
            },
          },
        );
        throw new Error("expected unauthenticated");
      } catch (err) {
        assertTrue(err instanceof HttpsError, `got ${String(err)}`);
        assertEqual((err as HttpsError).code, "unauthenticated", "code");
      }
      assertEqual(calls.join(","), "", "nothing called");
    },
  },
  {
    name: "a forged payload uid is ignored; the rate limit uses the right key",
    fn: async () => {
      const calls: string[] = [];
      const request = {
        auth: { uid: UID },
        data: { uid: OTHER, userId: OTHER },
      };
      await residue.handleExportSharedResidue(request, {
        rateLimit: async (uid, op) => void calls.push(`rateLimit:${uid}:${op}`),
        run: async (uid) => {
          calls.push(`run:${uid}`);
          return run(new FakeFirestore());
        },
      });
      assertEqual(
        calls.join(","),
        `rateLimit:${UID}:exportSharedResidue,run:${UID}`,
        "uid from auth, rate limit before the run",
      );
    },
  },
  {
    name: "a rate-limit refusal stops the export",
    fn: async () => {
      let ran = false;
      try {
        await residue.handleExportSharedResidue(
          { auth: { uid: UID } },
          {
            rateLimit: async () => {
              throw new HttpsError("resource-exhausted", "slow down");
            },
            run: async () => {
              ran = true;
              return run(new FakeFirestore());
            },
          },
        );
        throw new Error("expected resource-exhausted");
      } catch (err) {
        assertEqual((err as HttpsError).code, "resource-exhausted", "code");
      }
      assertEqual(ran, false, "no reads after a refusal");
    },
  },
  {
    name: "callable options: 1 GiB and App Check enforced",
    fn: async () => {
      const endpoint = (residue.exportSharedResidue as unknown as {
        __endpoint: { availableMemoryMb?: number; callableTrigger?: unknown };
      }).__endpoint;
      assertEqual(endpoint.availableMemoryMb, 1024, "memory");
      const source = fs.readFileSync(
        path.join(__dirname, "..", "exports", "shared-residue.ts"),
        "utf8",
      );
      assertTrue(/enforceAppCheck:\s*true/.test(source), "enforceAppCheck: true");
    },
  },
];

runTests("BUT-1747 exportSharedResidue", cases);
