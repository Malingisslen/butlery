/**
 * Firestore rules tests for the per-user burst guard, `rateLimitStamped`, and
 * for the `users/{uid}/rate_limits/{type}` bucket it reads.
 *
 * Contract:
 *   - A guarded write is accepted only when the SAME request stamps
 *     `users/{uid}/rate_limits/{type}` with `lastWrite == request.time` and
 *     `lastDocId` equal to the call site's key (the guarded document's id, or
 *     `<groupId>/<pingId>` for pings), and the previous stamp is
 *     older than the type's window.
 *   - The bucket accepts exactly `lastWrite`, `expireAt`, `lastDocId` from its
 *     owner, at server time, and never a client delete. `imports` and
 *     `friendSearchMigrated` keep plain owner writes.
 *   - `messages` carry no burst guard (ADR-0020).
 *
 * Each guarded type gets the same four cases, and each DENY differs from its
 * ALLOW control in one variable: fresh stamped write (ALLOW) vs fresh unstamped
 * write (DENY); stamped write after a seeded stamp older than the window
 * (ALLOW) vs one inside it (DENY).
 *
 * Prerequisite: Firestore emulator running locally
 * (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/rate-limit-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { serverTimestamp } from "firebase/firestore";

const PROJECT_ID = "butlery-rules-rate-limit";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

// Per-run token: the emulator persists documents across invocations, so fixed
// ids would turn a create into an update on the second run.
const RUN = Date.now().toString(36);

const CLAIMS = { ageCompliant: true, email_verified: true };
const DAY_MS = 24 * 60 * 60 * 1000;

let env: RulesTestEnvironment;

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

/** One guarded create: where it goes and what the writer sends. */
interface Kind {
  type: string;
  windowSeconds: number;
  /** Document path for actor [uid], distinct per [tag]. */
  path: (uid: string, tag: string) => string;
  body: (uid: string, tag: string) => Record<string, unknown>;
  /** The key the rule compares `lastDocId` against, when it is not the doc id. */
  key?: (path: string) => string;
}

const lastSegment = (p: string): string => p.split("/").pop() as string;

/**
 * The recipient record `shopping_social_share_module` (idKey "listId") and
 * `social_menu_operations` (idKey "menuId") write, key for key.
 */
function receipt(uid: string, idKey: "listId" | "menuId", id: string): Record<string, unknown> {
  return idKey === "listId"
    ? { listId: id, sharedListId: id, sharedByUserId: uid, sharedByDisplayName: "Anna",
        listTitle: "Lista", sharedAt: new Date(), isViewed: false, isImported: false }
    : { menuId: id, sharedMenuId: id, sharedByUserId: uid, sharedByDisplayName: "Anna",
        menuTitle: "Meny", sharedAt: new Date(), isViewed: false, isImported: false };
}

const KINDS: Kind[] = [
  {
    type: "social_requests",
    windowSeconds: 10,
    path: (_uid, tag) => `social_requests/sr-${tag}-${RUN}`,
    body: (uid, tag) => ({
      type: "friend",
      fromUserId: uid,
      toUserId: `sr-target-${tag}-${RUN}`,
      status: "pending",
      sentAt: new Date(),
    }),
  },
  {
    type: "comments",
    windowSeconds: 5,
    path: (_uid, tag) => `recipe_comments/c-${tag}-${RUN}`,
    body: (uid) => ({
      recipeId: "recipe-1",
      authorId: uid,
      authorDisplayName: "Testperson",
      text: "ser gott ut!",
      parentCommentId: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      isDeleted: false,
      likesCount: 0,
      replyCount: 0,
      sharedWithUserIds: [],
    }),
  },
  {
    type: "activity_events",
    windowSeconds: 2,
    path: (_uid, tag) => `activity_events/ae-${tag}-${RUN}`,
    body: (uid) => ({
      actorId: uid,
      actorDisplayName: "Anna",
      type: "cooked",
      recipeId: "recipe-1",
      recipeTitle: "Köttbullar",
      extraData: {},
      createdAt: new Date(),
    }),
  },
  {
    type: "shared_content",
    windowSeconds: 3,
    path: (_uid, tag) => `shared_content/sc-${tag}-${RUN}`,
    body: (uid) => ({
      sharedByUserId: uid,
      contentType: "recipe",
      sharedAt: new Date(),
      sharedToUserIds: [uid],
    }),
  },
  {
    type: "pings",
    windowSeconds: 60,
    path: (_uid, tag) => `pings/group-${RUN}/pings/p-${tag}-${RUN}`,
    key: (p) => `group-${RUN}/${lastSegment(p)}`,
    body: (uid) => ({
      groupId: `group-${RUN}`,
      fromUserId: uid,
      type: "nudge",
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + DAY_MS),
      acknowledged: false,
    }),
  },
  {
    type: "cook_snaps",
    windowSeconds: 5,
    path: (_uid, tag) => `cook_snaps/cs-${tag}-${RUN}`,
    body: (uid) => ({
      recipeId: "recipe-1",
      userId: uid,
      userDisplayName: "Anna",
      photoUrl: "https://example.com/snap.jpg",
      createdAt: new Date(),
    }),
  },
  {
    type: "conversations",
    windowSeconds: 3,
    // An unseeded peer is an adult to `passesMinorDmGate`, and the id must be
    // derived from the two participants or `directIdBinds` denies first.
    path: (uid, tag) => `conversations/direct_${uid}_peer-${tag}-${RUN}`,
    body: (uid, tag) => ({
      participantIds: [uid, `peer-${tag}-${RUN}`],
      createdAt: new Date(),
      isGroup: false,
      metadata: { creatorId: uid },
    }),
  },
  {
    type: "received_list",
    windowSeconds: 3,
    path: (_uid, tag) =>
      `user_shared_shopping_lists/friend-${RUN}/received_lists/l-${tag}-${RUN}`,
    body: (uid, tag) => receipt(uid, "listId", `l-${tag}-${RUN}`),
  },
  {
    type: "received_menu",
    windowSeconds: 3,
    path: (_uid, tag) =>
      `user_shared_menus/friend-${RUN}/received_menus/m-${tag}-${RUN}`,
    body: (uid, tag) => receipt(uid, "menuId", `m-${tag}-${RUN}`),
  },
  {
    type: "recipe_ratings",
    windowSeconds: 5,
    path: (uid, tag) => `recipe_ratings/recipe-${tag}-${RUN}_${uid}`,
    body: (uid, tag) => ({
      recipeId: `recipe-${tag}-${RUN}`,
      userId: uid,
      rating: 4,
      review: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  },
];

function stamp(key: string): Record<string, unknown> {
  return {
    lastWrite: serverTimestamp(),
    expireAt: new Date(Date.now() + 2 * DAY_MS),
    lastDocId: key,
  };
}

/** Commit [docs] plus, when [stampKey] is given, one stamp keyed on it. */
async function commit(
  uid: string,
  type: string,
  docs: { path: string; body: Record<string, unknown> }[],
  stampKey?: string
): Promise<void> {
  const db = env.authenticatedContext(uid, CLAIMS).firestore();
  const batch = db.batch();
  for (const d of docs) batch.set(db.doc(d.path), d.body);
  if (stampKey !== undefined) {
    batch.set(db.doc(`users/${uid}/rate_limits/${type}`), stamp(stampKey), {
      merge: true,
    });
  }
  await batch.commit();
}

async function seedStamp(uid: string, type: string, ageMs: number) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`users/${uid}/rate_limits/${type}`)
      .set({
        lastWrite: new Date(Date.now() - ageMs),
        expireAt: new Date(Date.now() + 2 * DAY_MS),
        lastDocId: "seeded",
      });
  });
}

const keyOf = (k: Kind, p: string): string => (k.key ? k.key(p) : lastSegment(p));

for (const k of KINDS) {
  test(`${k.type}: a first write stamped in the same request is allowed`, async () => {
    const uid = `rl-${k.type}-first-${RUN}`;
    const p = k.path(uid, "first");
    await assertSucceeds(
      commit(uid, k.type, [{ path: p, body: k.body(uid, "first") }], keyOf(k, p))
    );
  });

  test(`${k.type}: a first write WITHOUT a stamp is denied`, async () => {
    const uid = `rl-${k.type}-nostamp-${RUN}`;
    const p = k.path(uid, "nostamp");
    await assertFails(
      commit(uid, k.type, [{ path: p, body: k.body(uid, "nostamp") }])
    );
  });

  test(`${k.type}: a stamped write after the window is allowed`, async () => {
    const uid = `rl-${k.type}-after-${RUN}`;
    await seedStamp(uid, k.type, (k.windowSeconds + 5) * 1000);
    const p = k.path(uid, "after");
    await assertSucceeds(
      commit(uid, k.type, [{ path: p, body: k.body(uid, "after") }], keyOf(k, p))
    );
  });

  test(`${k.type}: a stamped write inside the window is denied`, async () => {
    const uid = `rl-${k.type}-inside-${RUN}`;
    await seedStamp(uid, k.type, 0);
    const p = k.path(uid, "inside");
    await assertFails(
      commit(uid, k.type, [{ path: p, body: k.body(uid, "inside") }], keyOf(k, p))
    );
  });
}

const EVENTS = KINDS.find((k) => k.type === "activity_events") as Kind;

test("two guarded writes sharing one stamp in one batch are denied", async () => {
  const uid = `rl-shared-stamp-${RUN}`;
  const a = EVENTS.path(uid, "shared-a");
  const b = EVENTS.path(uid, "shared-b");
  await assertFails(
    commit(
      uid,
      EVENTS.type,
      [
        { path: a, body: EVENTS.body(uid, "shared-a") },
        { path: b, body: EVENTS.body(uid, "shared-b") },
      ],
      lastSegment(a)
    )
  );
});

test("a stamp keyed on a different document id is denied", async () => {
  const uid = `rl-wrong-key-${RUN}`;
  const p = EVENTS.path(uid, "wrong-key");
  await assertFails(
    commit(uid, EVENTS.type, [{ path: p, body: EVENTS.body(uid, "wrong-key") }], "not-this-doc")
  );
});

test("a stamp written in an earlier request does not license a later write", async () => {
  const uid = `rl-prestamped-${RUN}`;
  const p = EVENTS.path(uid, "prestamped");
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`users/${uid}/rate_limits/${EVENTS.type}`)
      .set({
        lastWrite: new Date(Date.now() - 60 * 1000),
        expireAt: new Date(Date.now() + 2 * DAY_MS),
        lastDocId: lastSegment(p),
      });
  });
  await assertFails(
    commit(uid, EVENTS.type, [{ path: p, body: EVENTS.body(uid, "prestamped") }])
  );
});

test("a stamp written in this request, seeded bucket 60 s old, is allowed (control)", async () => {
  const uid = `rl-prestamped-control-${RUN}`;
  const p = EVENTS.path(uid, "prestamped-control");
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`users/${uid}/rate_limits/${EVENTS.type}`)
      .set({
        lastWrite: new Date(Date.now() - 60 * 1000),
        expireAt: new Date(Date.now() + 2 * DAY_MS),
        lastDocId: lastSegment(p),
      });
  });
  await assertSucceeds(
    commit(uid, EVENTS.type, [{ path: p, body: EVENTS.body(uid, "prestamped-control") }], lastSegment(p))
  );
});

test("pings: one stamp does not cover pings in two groups", async () => {
  const uid = `rl-ping-fanout-${RUN}`;
  const pingId = `p-fanout-${RUN}`;
  const body = (group: string) => ({
    groupId: group,
    fromUserId: uid,
    type: "nudge",
    createdAt: new Date(),
    expiresAt: new Date(Date.now() + DAY_MS),
    acknowledged: false,
  });
  const docs = [
    { path: `pings/g1-${RUN}/pings/${pingId}`, body: body(`g1-${RUN}`) },
    { path: `pings/g2-${RUN}/pings/${pingId}`, body: body(`g2-${RUN}`) },
  ];
  await assertFails(commit(uid, "pings", docs, `g1-${RUN}/${pingId}`));
  // The ping id alone is the key that let one stamp cover every group.
  await assertFails(commit(uid, "pings", docs, pingId));
});

test("pings: one stamp does not cover a group/ping split of the same characters", async () => {
  const uid = `rl-ping-split-${RUN}`;
  const body = (group: string) => ({
    groupId: group,
    fromUserId: uid,
    type: "nudge",
    createdAt: new Date(),
    expiresAt: new Date(Date.now() + DAY_MS),
    acknowledged: false,
  });
  const a = `a${RUN}`;
  const docs = [
    { path: `pings/${a}/pings/b_c`, body: body(a) },
    { path: `pings/${a}_b/pings/c`, body: body(`${a}_b`) },
  ];
  await assertFails(commit(uid, "pings", docs, `${a}/b_c`));
  // Joined with `_`, both documents would build this one key.
  await assertFails(commit(uid, "pings", docs, `${a}_b_c`));
});

test("rate_limits: a stamp without lastDocId is denied", async () => {
  const uid = `rl-no-docid-${RUN}`;
  const db = env.authenticatedContext(uid, CLAIMS).firestore();
  await assertFails(
    db.doc(`users/${uid}/rate_limits/comments`).set({
      lastWrite: serverTimestamp(),
      expireAt: new Date(Date.now() + 2 * DAY_MS),
    })
  );
});

test("received_list: one share to two recipients with one stamp is allowed", async () => {
  const uid = `rl-fanout-${RUN}`;
  const listId = `l-fanout-${RUN}`;
  const body = receipt(uid, "listId", listId);
  await assertSucceeds(
    commit(
      uid,
      "received_list",
      [
        { path: `user_shared_shopping_lists/friend-a-${RUN}/received_lists/${listId}`, body },
        { path: `user_shared_shopping_lists/friend-b-${RUN}/received_lists/${listId}`, body },
      ],
      listId
    )
  );
});

// The shape `shopping_social_share_module` and `social_menu_operations` write:
// the shared document, every recipient's record and both stamps in one batch.
for (const [kind, idKey, receivedType, receivedPath, contentType] of [
  ["list", "listId", "received_list", "user_shared_shopping_lists", "shopping_list"],
  ["menu", "menuId", "received_menu", "user_shared_menus", "menu"],
] as const) {
  test(`a ${kind} share batch carrying shared_content, two records and both stamps is allowed`, async () => {
    const uid = `rl-share-batch-${kind}-${RUN}`;
    const id = `share-batch-${kind}-${RUN}`;
    const friends = [`friend-a-${RUN}`, `friend-b-${RUN}`];
    const collection = receivedType === "received_list" ? "received_lists" : "received_menus";
    const db = env.authenticatedContext(uid, CLAIMS).firestore();
    const batch = db.batch();
    batch.set(db.doc(`shared_content/${id}`), {
      contentType,
      title: "Delat",
      description: null,
      sharedByUserId: uid,
      sharedByDisplayName: "Anna",
      sharedByAvatarUrl: null,
      sharedAt: new Date(),
      sharedToUserIds: friends,
      isActive: true,
    });
    for (const friend of friends) {
      batch.set(db.doc(`${receivedPath}/${friend}/${collection}/${id}`), receipt(uid, idKey, id));
    }
    batch.set(db.doc(`users/${uid}/rate_limits/shared_content`), stamp(id), { merge: true });
    batch.set(db.doc(`users/${uid}/rate_limits/${receivedType}`), stamp(id), { merge: true });
    await assertSucceeds(batch.commit());
  });
}

// ---- the bucket itself

test("rate_limits: the owner cannot delete their own stamp", async () => {
  const uid = `rl-delete-${RUN}`;
  await seedStamp(uid, "comments", 0);
  const db = env.authenticatedContext(uid, CLAIMS).firestore();
  await assertFails(db.doc(`users/${uid}/rate_limits/comments`).delete());
});

test("rate_limits: a stamp with a client-chosen lastWrite is denied", async () => {
  const uid = `rl-backdate-${RUN}`;
  const db = env.authenticatedContext(uid, CLAIMS).firestore();
  await assertFails(
    db.doc(`users/${uid}/rate_limits/comments`).set({
      lastWrite: new Date(0),
      expireAt: new Date(Date.now() + 2 * DAY_MS),
      lastDocId: "x",
    })
  );
});

test("rate_limits: a server-time stamp is allowed (control)", async () => {
  const uid = `rl-control-${RUN}`;
  const db = env.authenticatedContext(uid, CLAIMS).firestore();
  await assertSucceeds(db.doc(`users/${uid}/rate_limits/comments`).set(stamp("x")));
});

test("rate_limits: a stamp carrying an extra key is denied", async () => {
  const uid = `rl-extra-${RUN}`;
  const db = env.authenticatedContext(uid, CLAIMS).firestore();
  await assertFails(
    db.doc(`users/${uid}/rate_limits/comments`).set({ ...stamp("x"), extra: 1 })
  );
});

test("rate_limits: a stamp that has already expired is denied", async () => {
  const uid = `rl-expired-${RUN}`;
  const db = env.authenticatedContext(uid, CLAIMS).firestore();
  await assertFails(
    db.doc(`users/${uid}/rate_limits/comments`).set({
      ...stamp("x"),
      expireAt: new Date(Date.now() - 60 * 1000),
    })
  );
});

// A stamp the TTL could delete inside a window would reset that window.
test("rate_limits: a stamp expiring within the longest window is denied", async () => {
  const uid = `rl-within-window-${RUN}`;
  const db = env.authenticatedContext(uid, CLAIMS).firestore();
  await assertFails(
    db.doc(`users/${uid}/rate_limits/comments`).set({
      ...stamp("x"),
      expireAt: new Date(Date.now() + 30 * 1000),
    })
  );
});

test("rate_limits: a stamp expiring more than 4 days out is denied", async () => {
  const uid = `rl-long-expiry-${RUN}`;
  const db = env.authenticatedContext(uid, CLAIMS).firestore();
  await assertFails(
    db.doc(`users/${uid}/rate_limits/comments`).set({
      ...stamp("x"),
      expireAt: new Date(Date.now() + 5 * DAY_MS),
    })
  );
});

// The writer adds 2 days to the DEVICE clock; these are that value from a
// device a day behind and a day ahead of the server.
for (const [label, offsetDays] of [["behind", 1], ["ahead", 3]] as const) {
  test(`rate_limits: a stamp from a device clock a day ${label} is allowed`, async () => {
    const uid = `rl-skew-${label}-${RUN}`;
    const db = env.authenticatedContext(uid, CLAIMS).firestore();
    await assertSucceeds(
      db.doc(`users/${uid}/rate_limits/comments`).set({
        ...stamp("x"),
        expireAt: new Date(Date.now() + offsetDays * DAY_MS),
      })
    );
  });
}

test("rate_limits: writing another user's stamp is denied", async () => {
  const db = env.authenticatedContext(`rl-intruder-${RUN}`, CLAIMS).firestore();
  await assertFails(
    db.doc(`users/rl-victim-${RUN}/rate_limits/comments`).set(stamp("x"))
  );
});

test("rate_limits: the owner writes the imports counters freely", async () => {
  const uid = `rl-imports-${RUN}`;
  const db = env.authenticatedContext(uid, CLAIMS).firestore();
  await assertSucceeds(
    db
      .doc(`users/${uid}/rate_limits/imports`)
      .set({ importsThisMinute: 1, llmCostToday: 0.1 }, { merge: true })
  );
});

test("rate_limits: the owner writes the friendSearchMigrated flag", async () => {
  const uid = `rl-migrated-${RUN}`;
  const db = env.authenticatedContext(uid, CLAIMS).firestore();
  await assertSucceeds(
    db.doc(`users/${uid}/rate_limits/friendSearchMigrated`).set({ migratedAt: new Date() })
  );
});

test("rate_limits: another user cannot write someone's imports counters", async () => {
  const db = env.authenticatedContext(`rl-imports-intruder-${RUN}`, CLAIMS).firestore();
  await assertFails(
    db.doc(`users/rl-imports-victim-${RUN}/rate_limits/imports`).set({ llmCostToday: 0 })
  );
});

// ---- the guard ADR-0020 removed

test("messages: two sends in a row without any stamp are both allowed", async () => {
  const uid = `rl-msg-${RUN}`;
  const convId = `direct_${uid}_rl-msg-peer-${RUN}`;
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`conversations/${convId}`).set({
      participantIds: [uid, `rl-msg-peer-${RUN}`],
      createdAt: new Date(Date.now() - DAY_MS),
      isGroup: false,
    });
  });
  const db = env.authenticatedContext(uid, CLAIMS).firestore();
  for (const n of [1, 2]) {
    await assertSucceeds(
      db.doc(`messages/rl-msg-${n}-${RUN}`).set({
        senderId: uid,
        conversationId: convId,
        content: "hej",
        sentAt: new Date(),
        type: "text",
      })
    );
  }
});

async function run(): Promise<void> {
  console.log("rate limit rules tests\n");
  console.log("========================================\n");
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
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
      (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
