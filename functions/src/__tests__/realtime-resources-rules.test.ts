/**
 * BUT-2151 (ADR-0023): Firestore rules tests for `/realtime_resources/{id}`,
 * the collection that carries live menus. Fixtures follow
 * RealtimeMenu.toFirestore() as RealtimeMenuFactory builds it: the owner is
 * seated in `participants` as 'owner', and the id starts with the owner's uid.
 *
 * Each test name states the behaviour it proves. If a test fails, either the
 * rule changed or the design intent changed — decide which.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore --project demo-test`).
 *
 * Run with: npx ts-node src/__tests__/realtime-resources-rules.test.ts
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

const PROJECT_ID = "butlery-rules-rt-resources";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER_UID = "rtresowner";
const EDITOR_UID = "rtreseditor";
const VIEWER_UID = "rtresviewer";
const STRANGER_UID = "rtresstranger";
const MENU_ID = `${OWNER_UID}_menu-1`;
const CREATED_AT = new Date("2026-01-01T00:00:00Z");

let env: RulesTestEnvironment;

function menuDoc(
  overrides: Record<string, unknown> = {},
  participants: Record<string, string> = {
    [OWNER_UID]: "owner",
    [EDITOR_UID]: "editor",
    [VIEWER_UID]: "viewer",
  }
): Record<string, unknown> {
  return {
    type: "menu",
    ownerId: OWNER_UID,
    ownerDisplayName: "Ägare",
    participants,
    participantIds: Object.keys(participants),
    createdAt: CREATED_AT,
    lastEditedAt: new Date(),
    lastEditedBy: OWNER_UID,
    lastEditedByDisplayName: "Ägare",
    editCount: 0,
    isActive: true,
    metadata: {},
    menuTitle: "Veckans meny",
    createdForDate: new Date(),
    menuSnapshot: { middag: [] },
    menuNotes: "",
    favoriteRecipeIds: [],
    originalPrompt: "",
    ...overrides,
  };
}

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
}

// Every test starts from the same seed: one existing menu resource.
async function seed(): Promise<void> {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`realtime_resources/${MENU_ID}`).set(menuDoc());
  });
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

function menuRef(uid: string, id = MENU_ID) {
  return env.authenticatedContext(uid).firestore().doc(`realtime_resources/${id}`);
}

// ---- create ----

test("owner creates a menu under an id that starts with their uid", async () => {
  await assertSucceeds(menuRef(OWNER_UID, `${OWNER_UID}_menu-new`).set(menuDoc()));
});

test("an id that does not start with the caller's uid is refused", async () => {
  await assertFails(menuRef(OWNER_UID, "menu-unprefixed").set(menuDoc()));
});

test("an id that starts with someone else's uid is refused (squat)", async () => {
  await assertFails(
    menuRef(STRANGER_UID, `${OWNER_UID}_menu-squat`).set(
      menuDoc(
        { ownerId: STRANGER_UID, lastEditedBy: STRANGER_UID },
        { [STRANGER_UID]: "owner" }
      )
    )
  );
});

test("creating a resource owned by someone else is refused", async () => {
  await assertFails(
    menuRef(EDITOR_UID, `${EDITOR_UID}_menu-x`).set(
      menuDoc({ lastEditedBy: EDITOR_UID })
    )
  );
});

test("a recipe resource is refused until a writer for it exists", async () => {
  const recipe = menuDoc({ type: "recipe" });
  for (const key of [
    "menuTitle",
    "createdForDate",
    "menuSnapshot",
    "menuNotes",
    "favoriteRecipeIds",
    "originalPrompt",
  ]) {
    delete recipe[key];
  }
  await assertFails(menuRef(OWNER_UID, `${OWNER_UID}_recipe-1`).set(recipe));
});

test("type shopping_list is refused at create", async () => {
  await assertFails(
    menuRef(OWNER_UID, `${OWNER_UID}_list`).set(menuDoc({ type: "shopping_list" }))
  );
});

test("an owner missing from participantIds is refused", async () => {
  await assertFails(
    menuRef(OWNER_UID, `${OWNER_UID}_menu-y`).set(
      menuDoc({}, { [EDITOR_UID]: "editor" })
    )
  );
});

test("participantIds out of sync with participants is refused", async () => {
  await assertFails(
    menuRef(OWNER_UID, `${OWNER_UID}_menu-z`).set(
      menuDoc({ participantIds: [OWNER_UID] })
    )
  );
});

test("a key outside the allowlist is refused", async () => {
  await assertFails(
    menuRef(OWNER_UID, `${OWNER_UID}_menu-extra`).set(menuDoc({ smuggled: true }))
  );
});

test("a create without createdAt is refused", async () => {
  const doc = menuDoc();
  delete doc.createdAt;
  await assertFails(menuRef(OWNER_UID, `${OWNER_UID}_menu-noc`).set(doc));
});

test("a create naming someone else as the last editor is refused", async () => {
  await assertFails(
    menuRef(OWNER_UID, `${OWNER_UID}_menu-forged`).set(
      menuDoc({ lastEditedBy: EDITOR_UID })
    )
  );
});

// ---- read ----

test("owner and participants read; a stranger does not", async () => {
  await assertSucceeds(menuRef(OWNER_UID).get());
  await assertSucceeds(menuRef(EDITOR_UID).get());
  await assertSucceeds(menuRef(VIEWER_UID).get());
  await assertFails(menuRef(STRANGER_UID).get());
});

test("an unauthenticated read is refused", async () => {
  await assertFails(
    env
      .unauthenticatedContext()
      .firestore()
      .doc(`realtime_resources/${MENU_ID}`)
      .get()
  );
});

// ---- update ----

test("an editor writes the whole menu document back (the app's verb)", async () => {
  await assertSucceeds(
    menuRef(EDITOR_UID).set(
      menuDoc({ menuTitle: "Ny titel", lastEditedBy: EDITOR_UID, editCount: 1 })
    )
  );
});

test("an editor may not name someone else as the last editor", async () => {
  await assertFails(
    menuRef(EDITOR_UID).update({ menuTitle: "Ny titel", lastEditedBy: VIEWER_UID })
  );
});

test("a viewer may not change the menu", async () => {
  await assertFails(
    menuRef(VIEWER_UID).update({ menuTitle: "Ny titel", lastEditedBy: VIEWER_UID })
  );
});

test("an editor may not change who takes part", async () => {
  await assertFails(
    menuRef(EDITOR_UID).update({
      participants: {
        [OWNER_UID]: "owner",
        [EDITOR_UID]: "editor",
        [STRANGER_UID]: "editor",
      },
      participantIds: [OWNER_UID, EDITOR_UID, STRANGER_UID],
    })
  );
});

test("the owner changes who takes part", async () => {
  await assertSucceeds(
    menuRef(OWNER_UID).update({
      participants: { [OWNER_UID]: "owner" },
      participantIds: [OWNER_UID],
    })
  );
});

test("a stranger may not change the menu", async () => {
  await assertFails(
    menuRef(STRANGER_UID).update({ menuTitle: "Kapad", lastEditedBy: STRANGER_UID })
  );
});

test("ownerId cannot change", async () => {
  await assertFails(menuRef(OWNER_UID).update({ ownerId: EDITOR_UID }));
});

test("createdAt cannot change", async () => {
  await assertFails(menuRef(OWNER_UID).update({ createdAt: new Date(0) }));
});

test("an update adding a key outside the allowlist is refused", async () => {
  await assertFails(menuRef(OWNER_UID).update({ smuggled: true }));
});

test("an update putting the roster out of sync is refused", async () => {
  await assertFails(menuRef(OWNER_UID).update({ participantIds: [OWNER_UID] }));
});

// ---- delete ----

test("only the owner deletes", async () => {
  await assertFails(menuRef(EDITOR_UID).delete());
  await assertSucceeds(menuRef(OWNER_UID).delete());
});

// ---- the retired `realtime_recipes` collection ----

// BUT-2213: no block matches `realtime_recipes` any more, so the terminal
// deny answers. The payload carries every field the removed create rule
// required, and the read is by the seeded document's own owner.
test("realtime_recipes is denied to its owner, every verb", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc("realtime_recipes/legacy-1").set({
      ownerId: OWNER_UID,
      participants: [{ userId: OWNER_UID }],
      participantIds: [OWNER_UID],
      recipe: { title: "Gammalt recept" },
      createdAt: CREATED_AT,
    });
  });
  const db = env.authenticatedContext(OWNER_UID).firestore();
  await assertFails(db.doc("realtime_recipes/legacy-1").get());
  await assertFails(
    db.doc("realtime_recipes/x").set({
      ownerId: OWNER_UID,
      participants: [{ userId: OWNER_UID }],
      participantIds: [OWNER_UID],
      recipe: { title: "Nytt recept" },
      createdAt: CREATED_AT,
    })
  );
  await assertFails(
    db.doc("realtime_recipes/legacy-1").update({ recipe: { title: "Ny" } })
  );
  await assertFails(db.doc("realtime_recipes/legacy-1").delete());
  await assertFails(
    db
      .doc(`realtime_recipes/legacy-1/presence/${OWNER_UID}`)
      .set({ userId: OWNER_UID })
  );
});

// ---- votes (BUT-2118): one ballot document per person and menu ----

const DAY_MS = 24 * 60 * 60 * 1000;

function voteRef(uid: string, voteUid = uid) {
  return env
    .authenticatedContext(uid)
    .firestore()
    .doc(`realtime_resources/${MENU_ID}/votes/${voteUid}`);
}

// The shape FirebaseMenuVotingRepository writes: `updatedAt` is the server
// time and `expireAt` sits inside the 91-day TTL window.
function ballotDoc(
  uid: string,
  overrides: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    userId: uid,
    started: {},
    proposals: {},
    ballots: {},
    resolved: {},
    updatedAt: serverTimestamp(),
    expireAt: new Date(Date.now() + 90 * DAY_MS),
    ...overrides,
  };
}

const STARTED = {
  "middag#0": {
    id: "vote-1",
    options: [
      { id: "opt-a", dish: { id: "r1", title: "Svamppasta" }, votersBefore: 0 },
      { id: "opt-b", dish: { id: "r2", title: "Ugnslax" }, votersBefore: 0 },
    ],
    deadline: new Date(Date.now() + DAY_MS),
    createdAt: new Date(),
  },
};

async function seedBallot(uid: string, data: Record<string, unknown>) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`realtime_resources/${MENU_ID}/votes/${uid}`).set({
      userId: uid,
      started: {},
      proposals: {},
      ballots: {},
      resolved: {},
      updatedAt: new Date(),
      expireAt: new Date(Date.now() + 30 * DAY_MS),
      ...data,
    });
  });
}

async function seedMirror(uid: string, blockers: string[]): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`users/${uid}/block_mirror/current`).set({
      blockedByUserIds: blockers,
      sourceRev: 1,
      truncated: false,
      updatedAt: new Date("2026-10-09T00:00:00Z"),
    });
  });
}

test("votes: a viewer casts a ballot in their own document", async () => {
  await assertSucceeds(
    voteRef(VIEWER_UID).set(ballotDoc(VIEWER_UID, { ballots: { "vote-1": "opt-a" } }))
  );
});

// The erasure and the export find ballot documents by `userId`, so a
// document naming someone else would land in their Art. 15 bundle.
test("votes: a ballot document naming someone else as its owner is refused", async () => {
  await assertFails(
    voteRef(VIEWER_UID).set(
      ballotDoc(VIEWER_UID, { userId: EDITOR_UID, ballots: { "vote-1": "opt-a" } })
    )
  );
});

test("votes: an editor starts a vote", async () => {
  await assertSucceeds(voteRef(EDITOR_UID).set(ballotDoc(EDITOR_UID, { started: STARTED })));
});

test("votes: a viewer cannot start a vote", async () => {
  await assertFails(voteRef(VIEWER_UID).set(ballotDoc(VIEWER_UID, { started: STARTED })));
});

test("votes: a viewer cannot propose or settle on create", async () => {
  await assertFails(
    voteRef(VIEWER_UID).set(
      ballotDoc(VIEWER_UID, { proposals: { "vote-1": { id: "opt-c" } } })
    )
  );
  await assertFails(
    voteRef(VIEWER_UID).set(
      ballotDoc(VIEWER_UID, { resolved: { "vote-1": { outcome: "released" } } })
    )
  );
});

test("votes: a viewer cannot add a proposal by update; an editor can", async () => {
  await seedBallot(VIEWER_UID, { ballots: {} });
  await assertFails(
    voteRef(VIEWER_UID).set(
      ballotDoc(VIEWER_UID, { proposals: { "vote-1": { id: "opt-c" } } })
    )
  );
  await seedBallot(EDITOR_UID, { ballots: {} });
  await assertSucceeds(
    voteRef(EDITOR_UID).set(
      ballotDoc(EDITOR_UID, { proposals: { "vote-1": { id: "opt-c" } } })
    )
  );
});

test("votes: nobody writes another person's document", async () => {
  await assertFails(voteRef(EDITOR_UID, VIEWER_UID).set(ballotDoc(EDITOR_UID)));
  await assertFails(voteRef(EDITOR_UID, VIEWER_UID).set(ballotDoc(VIEWER_UID)));
});

// An UPDATE: the target exists, and the payload names the writer, so only
// the document id differs from the writer's own.
test("votes: nobody overwrites another participant's existing document", async () => {
  await seedBallot(VIEWER_UID, { ballots: { "vote-1": "opt-a" } });
  await assertFails(
    voteRef(EDITOR_UID, VIEWER_UID).set(
      ballotDoc(EDITOR_UID, { ballots: { "vote-1": "opt-a" } })
    )
  );
});

// One deny per agenda map: `proposals` has its own above.
test("votes: a viewer cannot start or settle a vote by update", async () => {
  await seedBallot(VIEWER_UID, { ballots: {} });
  await assertFails(voteRef(VIEWER_UID).set(ballotDoc(VIEWER_UID, { started: STARTED })));
  await assertFails(
    voteRef(VIEWER_UID).set(
      ballotDoc(VIEWER_UID, {
        resolved: { "vote-1": { outcome: "released", at: new Date() } },
      })
    )
  );
});

// A mirror naming someone off the menu blocks nothing, on update as on create.
test("votes: a block by someone outside the menu does not stop an update", async () => {
  await seedMirror(VIEWER_UID, [STRANGER_UID]);
  await seedBallot(VIEWER_UID, { ballots: {} });
  await assertSucceeds(
    voteRef(VIEWER_UID).set(ballotDoc(VIEWER_UID, { ballots: { "vote-1": "opt-a" } }))
  );
});

test("votes: a stranger cannot vote or read", async () => {
  await assertFails(voteRef(STRANGER_UID).set(ballotDoc(STRANGER_UID)));
  await seedBallot(VIEWER_UID, { ballots: { "vote-1": "opt-a" } });
  await assertFails(voteRef(STRANGER_UID, VIEWER_UID).get());
});

test("votes: a participant reads another participant's document", async () => {
  await seedBallot(VIEWER_UID, { ballots: { "vote-1": "opt-a" } });
  await assertSucceeds(voteRef(EDITOR_UID, VIEWER_UID).get());
});

test("votes: a key outside the allowlist is refused", async () => {
  await assertFails(voteRef(VIEWER_UID).set(ballotDoc(VIEWER_UID, { note: "x" })));
});

test("votes: a client-chosen updatedAt is refused", async () => {
  await assertFails(
    voteRef(VIEWER_UID).set(ballotDoc(VIEWER_UID, { updatedAt: new Date() }))
  );
});

test("votes: expireAt beyond 91 days or in the past is refused", async () => {
  await assertFails(
    voteRef(VIEWER_UID).set(
      ballotDoc(VIEWER_UID, { expireAt: new Date(Date.now() + 92 * DAY_MS) })
    )
  );
  await assertFails(
    voteRef(VIEWER_UID).set(
      ballotDoc(VIEWER_UID, { expireAt: new Date(Date.now() - DAY_MS) })
    )
  );
});

test("votes: a map that is not a map, or too large, is refused", async () => {
  await assertFails(voteRef(VIEWER_UID).set(ballotDoc(VIEWER_UID, { ballots: null })));
  const tooMany: Record<string, string> = {};
  for (let i = 0; i < 101; i++) tooMany[`vote-${i}`] = "opt-a";
  await assertFails(voteRef(VIEWER_UID).set(ballotDoc(VIEWER_UID, { ballots: tooMany })));
  const slots: Record<string, unknown> = {};
  for (let i = 0; i < 29; i++) slots[`middag#${i}`] = STARTED["middag#0"];
  await assertFails(voteRef(EDITOR_UID).set(ballotDoc(EDITOR_UID, { started: slots })));
  // Each agenda map is checked on its own; the editor may write all three.
  const hundredAndOne: Record<string, unknown> = {};
  for (let i = 0; i < 101; i++) hundredAndOne[`vote-${i}`] = { id: `opt-${i}` };
  await assertFails(voteRef(EDITOR_UID).set(ballotDoc(EDITOR_UID, { proposals: hundredAndOne })));
  await assertFails(voteRef(EDITOR_UID).set(ballotDoc(EDITOR_UID, { resolved: hundredAndOne })));
  await assertFails(voteRef(EDITOR_UID).set(ballotDoc(EDITOR_UID, { started: null })));
  await assertFails(voteRef(EDITOR_UID).set(ballotDoc(EDITOR_UID, { proposals: null })));
  await assertFails(voteRef(EDITOR_UID).set(ballotDoc(EDITOR_UID, { resolved: null })));
  // A string has a size too, so only the type check refuses these.
  await assertFails(voteRef(EDITOR_UID).set(ballotDoc(EDITOR_UID, { started: "x" })));
  await assertFails(voteRef(EDITOR_UID).set(ballotDoc(EDITOR_UID, { proposals: "x" })));
  await assertFails(voteRef(EDITOR_UID).set(ballotDoc(EDITOR_UID, { resolved: "x" })));
});

test("votes: a ballot on a new vote is added to an existing document", async () => {
  await seedBallot(VIEWER_UID, { ballots: { "vote-1": "opt-a" } });
  await assertSucceeds(
    voteRef(VIEWER_UID).set(
      ballotDoc(VIEWER_UID, { ballots: { "vote-1": "opt-a", "vote-2": "opt-x" } })
    )
  );
});

// A document written before a key existed has no `started`; adding the
// empty map is not starting a vote.
test("votes: a viewer's ballot is added to a document stored without the agenda maps", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`realtime_resources/${MENU_ID}/votes/${VIEWER_UID}`).set({
      userId: VIEWER_UID,
      ballots: {},
      updatedAt: new Date(),
      expireAt: new Date(Date.now() + 30 * DAY_MS),
    });
  });
  await assertSucceeds(
    voteRef(VIEWER_UID).set(ballotDoc(VIEWER_UID, { ballots: { "vote-1": "opt-a" } }))
  );
});

test("votes: a cast ballot cannot be changed", async () => {
  await seedBallot(VIEWER_UID, { ballots: { "vote-1": "opt-a" } });
  await assertFails(
    voteRef(VIEWER_UID).set(ballotDoc(VIEWER_UID, { ballots: { "vote-1": "opt-b" } }))
  );
});

test("votes: a cast ballot cannot be withdrawn, by update or by delete", async () => {
  await seedBallot(VIEWER_UID, { ballots: { "vote-1": "opt-a" } });
  await assertFails(voteRef(VIEWER_UID).set(ballotDoc(VIEWER_UID, { ballots: {} })));
  await assertFails(voteRef(VIEWER_UID).delete());
});

test("votes: a document without ballots can be deleted by its owner only", async () => {
  await seedBallot(EDITOR_UID, { started: STARTED, ballots: {} });
  await assertFails(voteRef(VIEWER_UID, EDITOR_UID).delete());
  await assertSucceeds(voteRef(EDITOR_UID).delete());
});

test("votes: a participant someone on the menu blocked cannot create or update", async () => {
  await seedBallot(VIEWER_UID, { ballots: {} });
  await seedMirror(VIEWER_UID, [OWNER_UID]);
  await assertFails(
    voteRef(VIEWER_UID).set(ballotDoc(VIEWER_UID, { ballots: { "vote-1": "opt-a" } }))
  );
  await seedMirror(EDITOR_UID, [OWNER_UID]);
  await assertFails(voteRef(EDITOR_UID).set(ballotDoc(EDITOR_UID)));
});

test("votes: a block by someone outside the menu does not stop the vote", async () => {
  await seedMirror(VIEWER_UID, [STRANGER_UID]);
  await assertSucceeds(voteRef(VIEWER_UID).set(ballotDoc(VIEWER_UID)));
});

// The mirror exists, so the gate reaches `hasAny(participantIds)`; a missing
// roster is an evaluation error there, which denies.
test("votes: a menu without participantIds denies (no fail-open default)", async () => {
  await seedMirror(OWNER_UID, [STRANGER_UID]);
  await env.withSecurityRulesDisabled(async (ctx) => {
    const d = menuDoc();
    delete d.participantIds;
    await ctx.firestore().doc(`realtime_resources/${MENU_ID}`).set(d);
  });
  await assertFails(voteRef(OWNER_UID).set(ballotDoc(OWNER_UID)));
});

test("votes: no document is written under a menu that does not exist", async () => {
  await assertFails(
    env
      .authenticatedContext(OWNER_UID)
      .firestore()
      .doc(`realtime_resources/${OWNER_UID}_missing/votes/${OWNER_UID}`)
      .set(ballotDoc(OWNER_UID))
  );
});

async function run(): Promise<void> {
  console.log("BUT-2151: realtime_resources rules tests\n");
  console.log("==========================================\n");
  await setup();
  let failed = 0;
  for (const t of tests) {
    try {
      await seed();
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(err);
    }
  }
  await teardown();
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
