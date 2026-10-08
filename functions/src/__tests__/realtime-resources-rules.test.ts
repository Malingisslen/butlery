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
