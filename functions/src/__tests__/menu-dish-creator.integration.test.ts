/**
 * BUT-2352: emulator-backed tests for the dish-creator check
 * (`moderation/on-menu-dish-creator.ts`), calling the trigger body directly.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/menu-dish-creator.integration.test.ts
 */

const PROJECT_ID = "butlery-menu-dish-creator-integration";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

import {
  handleMenuDishCreator,
  MenuDishCreatorEvent,
  onMenuDishCreatorWrite,
} from "../moderation/on-menu-dish-creator";
import { MAX_CREDIT_CHECKS } from "../moderation/menu-dish-creator";

type Data = admin.firestore.DocumentData;

const RUN = Date.now().toString(36);
const WRITER = `wri${RUN}`;
const ALICE = `ali${RUN}`;
const MALLORY = `mal${RUN}`;

let run = 0;
let failed = 0;
function check(name: string, ok: boolean, detail?: string): void {
  run++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}${detail ? ` — ${detail}` : ""}`);
  }
}

let seq = 0;
const nextId = (prefix: string) => `${prefix}${RUN}${seq++}`;

async function recipe(owner: string, id: string, core: Data, members: string[] = [WRITER]): Promise<void> {
  await db.collection("users").doc(owner).collection("recipes").doc(id).set({
    core,
    socialData: { memberPermissions: Object.fromEntries(members.map((m) => [m, "view"])) },
  });
}

function menuDoc(snapshot: Data, extra: Data = {}): Data {
  return {
    sharedByUserId: WRITER,
    contentType: "menu",
    sharedToUserIds: [ALICE],
    menuName: "Veckan",
    menuSnapshot: snapshot,
    ...extra,
  };
}

/** Stores [after] as the menu and returns the event of that write. */
async function write(
  menuId: string,
  before: Data | undefined,
  after: Data,
  auth: { authType?: string; authId?: string } = { authType: "app_user", authId: WRITER },
): Promise<MenuDishCreatorEvent> {
  await db.collection("shared_content").doc(menuId).set(after);
  return {
    data: { before: { data: () => before }, after: { data: () => after } },
    params: { contentId: menuId },
    ...auth,
  };
}

async function stored(menuId: string): Promise<Data | undefined> {
  return (await db.collection("shared_content").doc(menuId).get()).data();
}

async function updateTime(menuId: string): Promise<string | undefined> {
  return (await db.collection("shared_content").doc(menuId).get()).updateTime?.toDate().toISOString();
}

const deps = { db };

/** A single-dish menu written by WRITER; returns the outcome and the stored dish. */
async function single(
  dish: Data,
  setup: () => Promise<void> = async () => {},
  menuId = nextId("m"),
): Promise<{ outcome: string; dish: Data; menuId: string }> {
  await setup();
  const ev = await write(menuId, undefined, menuDoc({ Middag: [dish] }));
  const outcome = await handleMenuDishCreator(ev, deps);
  return { outcome, dish: (await stored(menuId))?.menuSnapshot.Middag[0], menuId };
}

async function keepConditions(): Promise<void> {
  {
    const r = nextId("r");
    const res = await single({ id: r, createdBy: ALICE, title: "Soppa" }, () =>
      recipe(ALICE, r, { createdBy: ALICE, title: "Soppa" }));
    check("a dish from a recipe shared with the writer keeps its name",
      res.outcome === "kept" && res.dish.createdBy === ALICE, `${res.outcome} ${JSON.stringify(res.dish)}`);
  }
  {
    const r = nextId("r");
    await db.collection("users").doc(ALICE).collection("recipes").doc(r).set({
      createdBy: ALICE, title: "Platt", socialData: { memberPermissions: { [WRITER]: "view" } },
    });
    const res = await single({ id: r, createdBy: ALICE, title: "Platt" });
    check("a flat (pre-core) recipe backs the name too", res.dish.createdBy === ALICE, res.outcome);
  }
  {
    const r = nextId("r");
    const res = await single({ id: r, createdBy: ALICE, title: "Soppa" });
    check("no such recipe → name removed", res.outcome === "removed" && !("createdBy" in res.dish), res.outcome);
  }
  {
    const r = nextId("r");
    const res = await single({ id: r, createdBy: ALICE, title: "Soppa" }, () =>
      recipe(ALICE, r, { createdBy: MALLORY, title: "Soppa" }));
    check("the recipe names another creator → name removed", !("createdBy" in res.dish), res.outcome);
  }
  {
    const r = nextId("r");
    const res = await single({ id: r, createdBy: ALICE, title: "Påhittad" }, () =>
      recipe(ALICE, r, { createdBy: ALICE, title: "Soppa" }));
    check("a different title → name removed", !("createdBy" in res.dish), res.outcome);
  }
  {
    const r = nextId("r");
    const res = await single({ id: r, createdBy: ALICE, title: "Soppa" }, () =>
      recipe(ALICE, r, { createdBy: ALICE, title: "Soppa" }, [MALLORY]));
    check("a recipe the writer cannot read → name removed", !("createdBy" in res.dish), res.outcome);
  }
  {
    const res = await single({ id: nextId("r"), createdBy: WRITER, title: "Egen" });
    check("the writer's own name is kept unread",
      res.outcome === "nothing_new" && res.dish.createdBy === WRITER, res.outcome);
  }
  {
    const r = nextId("r");
    const other = nextId("r");
    const menuId = nextId("m");
    const res = await single({ id: r, createdBy: ALICE, title: "Soppa" }, async () => {
      await recipe(ALICE, r, { createdBy: ALICE, title: "Soppa" });
      await db.collection("reports").doc(nextId("rep")).set({
        reporterId: ALICE, contentId: menuId, dishId: other,
        contentType: "menu_dish", reason: "misattribution",
      });
    }, menuId);
    check("a misattribution report on ANOTHER dish does not remove this name",
      res.dish.createdBy === ALICE, res.outcome);
  }
}

async function forgedRemovedOnly(): Promise<void> {
  const menuId = nextId("m");
  const shared = nextId("r");
  await recipe(ALICE, shared, { createdBy: ALICE, title: "Soppa" });
  const forged = { id: nextId("r"), createdBy: MALLORY, title: "Gryta", servings: 4, ingredients: ["a"] };
  const before = menuDoc({ Lunch: [{ id: shared, createdBy: ALICE, title: "Soppa" }], Middag: [] });
  const after = menuDoc({
    Lunch: [{ id: shared, createdBy: ALICE, title: "Soppa" }],
    Middag: [forged, { id: "plain", title: "Sallad" }],
  });
  const ev = await write(menuId, before, after);
  const outcome = await handleMenuDishCreator(ev, deps);
  const now = await stored(menuId);
  const { createdBy: _drop, ...forgedWithout } = forged;
  void _drop;
  const expected = { ...after, menuSnapshot: { ...after.menuSnapshot, Middag: [forgedWithout, { id: "plain", title: "Sallad" }] } };
  check("a forged name is removed and every other field is left as written",
    outcome === "removed" && JSON.stringify(sortKeys(now)) === JSON.stringify(sortKeys(expected)),
    `${outcome} ${JSON.stringify(now)}`);

  const t0 = await updateTime(menuId);
  const again = await handleMenuDishCreator(ev, deps);
  check("a redelivery writes nothing", again === "already_gone" && (await updateTime(menuId)) === t0, again);
}

function sortKeys(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(sortKeys);
  if (typeof v === "object" && v !== null) {
    return Object.fromEntries(Object.keys(v).sort().map((k) => [k, sortKeys((v as Data)[k])]));
  }
  return v;
}

async function staleResaveAfterWithdrawal(): Promise<void> {
  const menuId = nextId("m");
  const r = nextId("r");
  await recipe(ALICE, r, { createdBy: ALICE, title: "Soppa" });
  await db.collection("reports").doc(nextId("rep")).set({
    reporterId: ALICE, contentId: menuId, dishId: r, contentType: "menu_dish", reason: "misattribution",
  });
  // The withdrawal left the dish without `createdBy`; a client holding the
  // older copy saves the whole menu back.
  const before = menuDoc({ Middag: [{ id: r, title: "Soppa" }] });
  const after = menuDoc({ Middag: [{ id: r, createdBy: ALICE, title: "Soppa" }] });
  const outcome = await handleMenuDishCreator(await write(menuId, before, after), deps);
  const dish = (await stored(menuId))?.menuSnapshot.Middag[0];
  check("a stale re-save after the withdrawal loses the name again",
    outcome === "removed" && !("createdBy" in dish), `${outcome} ${JSON.stringify(dish)}`);
}

async function skips(): Promise<void> {
  const forged = { Middag: [{ id: nextId("r"), createdBy: MALLORY, title: "Gryta" }] };
  for (const authType of ["service_account", "system", "unauthenticated", undefined]) {
    const menuId = nextId("m");
    const ev = await write(menuId, undefined, menuDoc(forged), { authType, authId: WRITER });
    const outcome = await handleMenuDishCreator(ev, deps);
    const dish = (await stored(menuId))?.menuSnapshot.Middag[0];
    check(`a ${authType ?? "missing"} write is not checked`,
      outcome === "skipped" && dish.createdBy === MALLORY, outcome);
  }
  {
    const menuId = nextId("m");
    const ev = await write(menuId, undefined, menuDoc(forged, { contentType: "recipe" }));
    const outcome = await handleMenuDishCreator(ev, deps);
    check("a non-menu share is not checked",
      outcome === "skipped" && (await stored(menuId))?.menuSnapshot.Middag[0].createdBy === MALLORY, outcome);
  }
  {
    const menuId = nextId("m");
    const ev = await write(menuId, menuDoc(forged), menuDoc(forged, { menuName: "Ny" }));
    const outcome = await handleMenuDishCreator(ev, deps);
    check("a name already on the menu before the write is left alone",
      outcome === "nothing_new" && (await stored(menuId))?.menuSnapshot.Middag[0].createdBy === MALLORY, outcome);
  }
  {
    const ev: MenuDishCreatorEvent = {
      data: { before: { data: () => menuDoc(forged) }, after: { data: () => undefined } },
      params: { contentId: nextId("m") },
      authType: "app_user",
      authId: WRITER,
    };
    check("a delete is not checked", (await handleMenuDishCreator(ev, deps)) === "skipped");
  }
}

async function concurrentChange(): Promise<void> {
  const menuId = nextId("m");
  const r = nextId("r");
  const ev = await write(menuId, undefined, menuDoc({ Middag: [{ id: r, createdBy: MALLORY, title: "Gryta" }] }));
  // Another save lands before the check runs, retitling the dish.
  await db.collection("shared_content").doc(menuId).update({
    menuSnapshot: { Middag: [{ id: r, createdBy: MALLORY, title: "Ny gryta" }] },
  });
  const t0 = await updateTime(menuId);
  const outcome = await handleMenuDishCreator(ev, deps);
  check("a dish changed since the write is left to that write's own run",
    outcome === "already_gone" && (await updateTime(menuId)) === t0, outcome);
}

async function ownWriteAndCopies(): Promise<void> {
  {
    // The trigger's own strip, even if it arrived marked as a person's write.
    const menuId = nextId("m");
    const r = nextId("r");
    const forged = { Middag: [{ id: r, createdBy: MALLORY, title: "Gryta" }] };
    const ev = await write(menuId, menuDoc(forged), menuDoc({ Middag: [{ id: r, title: "Gryta" }] }));
    const t0 = await updateTime(menuId);
    const outcome = await handleMenuDishCreator(ev, deps);
    check("the strip itself introduces nothing, whatever its auth type",
      outcome === "nothing_new" && (await updateTime(menuId)) === t0, outcome);
  }
  {
    // WRITER cannot read the recipe, but the name was already on the menu.
    const menuId = nextId("m");
    const r = nextId("r");
    const legit = { id: r, createdBy: ALICE, title: "Soppa" };
    const ev = await write(menuId, menuDoc({ Middag: [legit] }), menuDoc({ Middag: [legit], Lunch: [legit] }));
    const outcome = await handleMenuDishCreator(ev, deps);
    const now = (await stored(menuId))?.menuSnapshot;
    check("copying a name already on the menu keeps both copies",
      outcome === "nothing_new" && now.Middag[0].createdBy === ALICE && now.Lunch[0].createdBy === ALICE, outcome);
  }
  {
    const retry = (onMenuDishCreatorWrite as unknown as { __endpoint: { eventTrigger?: { retry?: unknown } } })
      .__endpoint.eventTrigger?.retry;
    check("a failed check is retried", retry === true, String(retry));
  }
}

async function cap(): Promise<void> {
  const menuId = nextId("m");
  const dishes: Data[] = [];
  for (let i = 0; i <= MAX_CREDIT_CHECKS; i++) {
    const r = nextId("r");
    await recipe(ALICE, r, { createdBy: ALICE, title: `T${i}` });
    dishes.push({ id: r, createdBy: ALICE, title: `T${i}` });
  }
  const outcome = await handleMenuDishCreator(await write(menuId, undefined, menuDoc({ Middag: dishes })), deps);
  const now: Data[] = (await stored(menuId))?.menuSnapshot.Middag;
  const kept = now.filter((d) => d.createdBy === ALICE).length;
  check(`above ${MAX_CREDIT_CHECKS} new names the rest are removed unchecked`,
    outcome === "removed" && kept === MAX_CREDIT_CHECKS && !("createdBy" in now[MAX_CREDIT_CHECKS]),
    `${outcome} kept=${kept}`);
}

async function main(): Promise<void> {
  console.log("menu dish creator integration");
  await keepConditions();
  await forgedRemovedOnly();
  await staleResaveAfterWithdrawal();
  await skips();
  await concurrentChange();
  await ownWriteAndCopies();
  await cap();
  console.log(`\n${run - failed}/${run} passing`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
