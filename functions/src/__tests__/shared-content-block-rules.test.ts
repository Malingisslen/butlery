/**
 * BUT-2169: the `shared_content` rules a block leans on.
 *
 *   - `blockHeldUserIds` / `blockHeld` are server-written: a client can neither
 *     create them nor change them, nor put a held person back into
 *     `sharedToUserIds`, nor give them a member row.
 *   - A share to someone who has blocked the sharer is refused through the
 *     sharer's block mirror, on create and whenever the recipient list gains
 *     someone. A list that only shrinks never consults the mirror.
 *
 * Prerequisite: Firestore emulator on 127.0.0.1:8080.
 * Run with: npx ts-node src/__tests__/shared-content-block-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { arrayRemove, arrayUnion, serverTimestamp } from "firebase/firestore";

const PROJECT_ID = "butlery-rules-shared-content-block";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");
const RUN = Date.now().toString(36);
const CLAIMS = { ageCompliant: true, email_verified: true };
const DAY_MS = 24 * 60 * 60 * 1000;

let env: RulesTestEnvironment;

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

function stamp(key: string): Record<string, unknown> {
  return {
    lastWrite: serverTimestamp(),
    expireAt: new Date(Date.now() + 2 * DAY_MS),
    lastDocId: key,
  };
}

async function seed(docPath: string, data: Record<string, unknown>): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(docPath).set(data);
  });
}

async function seedMirror(uid: string, blockedBy: string[]): Promise<void> {
  await seed(`users/${uid}/block_mirror/current`, {
    blockedByUserIds: blockedBy,
    sourceRev: 1,
    truncated: false,
  });
}

/** The create `BaseSharedContentRepository.createSharedContent` sends. */
async function share(
  uid: string,
  tag: string,
  recipients: string[],
  extra: Record<string, unknown> = {},
): Promise<void> {
  const id = `sc-${tag}-${RUN}`;
  const db = env.authenticatedContext(uid, CLAIMS).firestore();
  const batch = db.batch();
  batch.set(db.doc(`shared_content/${id}`), {
    contentType: "menu",
    sharedByUserId: uid,
    sharedByDisplayName: "Anna",
    sharedAt: new Date(),
    sharedToUserIds: [uid, ...recipients],
    ...extra,
  });
  batch.set(db.doc(`users/${uid}/rate_limits/shared_content`), stamp(id), { merge: true });
  await batch.commit();
}

function u(name: string): string {
  return `${name}-${RUN}`;
}

// ---- create

test("create: a share to someone who has not blocked the sharer is allowed", async () => {
  const sharer = u("c1-sharer");
  await assertSucceeds(share(sharer, "c1", [u("c1-friend")]));
});

test("create: a share to someone who has blocked the sharer is denied", async () => {
  const sharer = u("c2-sharer");
  const blocker = u("c2-blocker");
  await seedMirror(sharer, [blocker]);
  await assertFails(share(sharer, "c2", [blocker]));
});

test("create: the same sharer with the same mirror may still share with someone else", async () => {
  const sharer = u("c3-sharer");
  await seedMirror(sharer, [u("c3-blocker")]);
  await assertSucceeds(share(sharer, "c3", [u("c3-friend")]));
});

test("create: a client cannot write blockHeldUserIds", async () => {
  const sharer = u("c4-sharer");
  await assertFails(share(sharer, "c4", [u("c4-friend")], { blockHeldUserIds: [] }));
});

test("create: a client cannot write blockHeld", async () => {
  const sharer = u("c5-sharer");
  await assertFails(share(sharer, "c5", [u("c5-friend")], { blockHeld: {} }));
});

// ---- update

async function seedRow(tag: string, sharer: string, recipients: string[], held: string[]): Promise<string> {
  const id = `row-${tag}-${RUN}`;
  await seed(`shared_content/${id}`, {
    contentType: "menu",
    sharedByUserId: sharer,
    sharedAt: new Date(),
    sharedToUserIds: [sharer, ...recipients],
    blockHeldUserIds: held,
    blockHeld: Object.fromEntries(held.map((h) => [h, { member: null }])),
    title: "Meny",
  });
  return id;
}

test("update: the sharer may edit the title of a row with a held person", async () => {
  const sharer = u("u1-sharer");
  const id = await seedRow("u1", sharer, [u("u1-friend")], [u("u1-held")]);
  const db = env.authenticatedContext(sharer, CLAIMS).firestore();
  await assertSucceeds(db.doc(`shared_content/${id}`).update({ title: "Ny" }));
});

test("update: the sharer cannot put a held person back in the recipient list", async () => {
  const sharer = u("u2-sharer");
  const held = u("u2-held");
  const id = await seedRow("u2", sharer, [u("u2-friend")], [held]);
  const db = env.authenticatedContext(sharer, CLAIMS).firestore();
  await assertFails(db.doc(`shared_content/${id}`).update({ sharedToUserIds: arrayUnion(held) }));
});

test("update: the sharer may add someone who is neither held nor blocking them", async () => {
  const sharer = u("u3-sharer");
  const id = await seedRow("u3", sharer, [u("u3-friend")], [u("u3-held")]);
  const db = env.authenticatedContext(sharer, CLAIMS).firestore();
  await assertSucceeds(db.doc(`shared_content/${id}`).update({ sharedToUserIds: arrayUnion(u("u3-new")) }));
});

test("update: the sharer cannot release a held person by editing blockHeldUserIds", async () => {
  const sharer = u("u4-sharer");
  const held = u("u4-held");
  const id = await seedRow("u4", sharer, [u("u4-friend")], [held]);
  const db = env.authenticatedContext(sharer, CLAIMS).firestore();
  await assertFails(db.doc(`shared_content/${id}`).update({ blockHeldUserIds: arrayRemove(held) }));
});

test("update: the sharer cannot add someone who has blocked them", async () => {
  const sharer = u("u5-sharer");
  const blocker = u("u5-blocker");
  await seedMirror(sharer, [blocker]);
  const id = await seedRow("u5", sharer, [u("u5-friend")], []);
  const db = env.authenticatedContext(sharer, CLAIMS).firestore();
  await assertFails(db.doc(`shared_content/${id}`).update({ sharedToUserIds: arrayUnion(blocker) }));
});

test("update: the sharer cannot rewrite what an unblock would restore", async () => {
  const sharer = u("u7-sharer");
  const held = u("u7-held");
  const id = await seedRow("u7", sharer, [u("u7-friend")], [held]);
  const db = env.authenticatedContext(sharer, CLAIMS).firestore();
  await assertFails(
    db.doc(`shared_content/${id}`).update({ [`blockHeld.${held}.recipePermission`]: "admin" }),
  );
});

test("update: a member leaves even when someone in the list has blocked them", async () => {
  const sharer = u("u6-sharer");
  const member = u("u6-member");
  await seedMirror(member, [sharer]);
  const id = await seedRow("u6", sharer, [member], []);
  await seed(`shared_content/${id}/members/${member}`, { userId: member, addedBy: sharer, addedAt: new Date() });
  const db = env.authenticatedContext(member, CLAIMS).firestore();
  await assertSucceeds(db.doc(`shared_content/${id}`).update({ sharedToUserIds: arrayRemove(member) }));
});

// ---- members

test("members: the sharer may add a member row for someone not held", async () => {
  const sharer = u("m1-sharer");
  const friend = u("m1-friend");
  const id = await seedRow("m1", sharer, [friend], [u("m1-held")]);
  const db = env.authenticatedContext(sharer, CLAIMS).firestore();
  await assertSucceeds(
    db.doc(`shared_content/${id}/members/${friend}`).set({ userId: friend, addedBy: sharer, addedAt: new Date() }),
  );
});

test("members: the sharer cannot add a member row for someone who blocked them", async () => {
  const sharer = u("m3-sharer");
  const blocker = u("m3-blocker");
  await seedMirror(sharer, [blocker]);
  const id = await seedRow("m3", sharer, [], []);
  const db = env.authenticatedContext(sharer, CLAIMS).firestore();
  await assertFails(
    db.doc(`shared_content/${id}/members/${blocker}`).set({ userId: blocker, addedBy: sharer, addedAt: new Date() }),
  );
});

test("members: the same sharer and mirror may add a member row for a friend", async () => {
  const sharer = u("m4-sharer");
  const friend = u("m4-friend");
  await seedMirror(sharer, [u("m4-blocker")]);
  const id = await seedRow("m4", sharer, [], []);
  const db = env.authenticatedContext(sharer, CLAIMS).firestore();
  // The order `BaseSharedContentRepository.addMember` writes in.
  await assertSucceeds(
    db.doc(`shared_content/${id}/members/${friend}`).set({ userId: friend, addedBy: sharer, addedAt: new Date() }),
  );
  await assertSucceeds(db.doc(`shared_content/${id}`).update({ sharedToUserIds: arrayUnion(friend) }));
});

test("members: the sharer cannot add a member row for a held person", async () => {
  const sharer = u("m2-sharer");
  const held = u("m2-held");
  const id = await seedRow("m2", sharer, [u("m2-friend")], [held]);
  const db = env.authenticatedContext(sharer, CLAIMS).firestore();
  await assertFails(
    db.doc(`shared_content/${id}/members/${held}`).set({ userId: held, addedBy: sharer, addedAt: new Date() }),
  );
});

async function run(): Promise<void> {
  console.log("shared_content block rules tests\n");
  console.log("========================================\n");
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  // Suites share one long-lived emulator; leftovers from an earlier run
  // turn a create-only write into a denied update.
  await env.clearFirestore();
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(err);
    }
  }
  await env.cleanup();
  console.log(
    `\n${tests.length - failed}/${tests.length} passed` +
      (failed ? `, ${failed} failed` : ""),
  );
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
