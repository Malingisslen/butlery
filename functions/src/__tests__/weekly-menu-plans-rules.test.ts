/**
 * Firestore rules tests for `/weekly_menu_plans/{planId}` and
 * `/group_weekly_menu_plans/{planId}` (BUT-1961 follow-up).
 *
 * Why this file exists, measured 2026-08-27: neither collection had a rules
 * test. Both update rules refuse a changed `createdAt`, and nothing checked it.
 *
 * That deny is what keeps a stale-read save from landing on a stored week: a
 * plan built from `WeeklyMenuPlan.empty` or `GroupWeeklyMenuPlan.empty` carries
 * a FRESH `createdAt` (both stamp `clock.now()`), `copyWith` preserves it, and
 * both repositories' `save()` writes the whole document with a non-merge `.set`.
 *
 * The protection therefore has two halves, and this file pins ONE of them.
 * W2 and G1 pin the RULE half — they build their bodies from a literal, not
 * from `empty()`, so a change to the constructor leaves them green.
 *
 * The constructor half is pinned in Dart, once per constructor:
 * `weekly_menu_plan_test.dart`'s "empty starts on a Monday with no entries
 * (clock-pinned)" and `group_weekly_menu_plan_test.dart`'s "stamps a FRESH
 * createdAt from the clock". The group one was added 2026-08-27 — until then
 * that half was unguarded, and G1 would have kept passing while pinning a
 * hazard that no longer existed.
 *
 * Mutation-probed 2026-08-27: dropping `createdAt` from either collection's
 * `cannotModify` reddens exactly that collection's test and nothing else.
 *
 * Prerequisite: Firestore emulator running locally
 * (`firebase emulators:start --only firestore --project demo-test`).
 *
 * Run with: npx ts-node src/__tests__/weekly-menu-plans-rules.test.ts
 */

import * as fs from "fs";
import {
  MAX_TRAIL_ROWS,
  MAX_CONTRIBUTOR_UIDS,
} from "../groups/remove-chat-group-member";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-weekly-menu-plans";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER_UID = "wmp-owner-uid";
const STRANGER_UID = "wmp-stranger-uid";

/** Doc ids are `{uid}_{YYYY-Www}` — the rule matches on that prefix. */
const OWNED_ID = `${OWNER_UID}_2026-W18`;

const GROUP_ID = "wmp-group";
const GROUP_PLAN_ID = `${GROUP_ID}_2026-W18`;

const CREATED_AT = new Date("2026-04-01T10:00:00Z");
const LATER = new Date("2026-04-28T10:00:00Z");

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  // Without this a second local run against a warm emulator turns W1's CREATE
  // into an UPDATE, which the rule also allows — the test keeps its name and
  // stops testing it.
  await env.clearFirestore();
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

function planBody(
  uid: string,
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    userId: uid,
    weekStartDate: new Date("2026-04-27T00:00:00Z"),
    entries: [],
    createdAt: CREATED_AT,
    updatedAt: CREATED_AT,
    schemaVersion: 1,
    ...extra,
  };
}

async function seed(id: string, body: Record<string, unknown>): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`weekly_menu_plans/${id}`).set(body);
  });
}

// W1: a week with no document yet is a CREATE, and it is allowed. This is the
// case BUT-1961 restored offline — planning a week that does not exist.
test("a week with no document can be created by its owner", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`weekly_menu_plans/${OWNER_UID}_2026-W19`)
      .set(planBody(OWNER_UID))
  );
});

// W2: the load-bearing one. A plan built from `WeeklyMenuPlan.empty` carries a
// FRESH createdAt, so writing it over an existing week is an update with a
// changed createdAt, and the rule refuses it.
test("an empty plan with a fresh createdAt cannot overwrite a real week", async () => {
  await seed(
    OWNED_ID,
    planBody(OWNER_UID, { entries: [{ recipeId: "r1", day: "mon" }] })
  );
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`weekly_menu_plans/${OWNED_ID}`)
      .set(planBody(OWNER_UID, { createdAt: LATER, updatedAt: LATER }))
  );
});

// W3: the counterpart, so W2 is not passing because ALL writes fail. A genuine
// edit keeps createdAt and is allowed.
test("an edit that preserves createdAt is allowed", async () => {
  await seed(OWNED_ID, planBody(OWNER_UID));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`weekly_menu_plans/${OWNED_ID}`)
      .set(
        planBody(OWNER_UID, {
          entries: [{ recipeId: "r2", day: "tue" }],
          updatedAt: LATER,
        })
      )
  );
});

// W4: a userId change is denied. Note this is over-determined — the two
// `request.auth.uid == …userId` conjuncts deny it on their own, so removing
// `'userId'` from `cannotModify` leaves the whole suite green (probed).
test("an edit that changes userId is denied", async () => {
  await seed(OWNED_ID, planBody(OWNER_UID));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`weekly_menu_plans/${OWNED_ID}`)
      .set(planBody(STRANGER_UID))
  );
});

// W5: the doc id's `{uid}_` prefix is its own ownership conjunct. Isolated by
// making this a CREATE at an unwritten id whose body names the STRANGER, so
// every `uid == …userId` conjunct is satisfied and only the prefix can deny.
// The earlier shape sent the OWNER's body and was denied by those conjuncts
// instead — it passed with the prefix check removed.
test("a stranger cannot create a plan under another user's id prefix", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`weekly_menu_plans/${OWNER_UID}_2026-W21`)
      .set(planBody(STRANGER_UID))
  );
});

// W6: the ALLOW control for W7. Without it the read rule could be `if false`
// and this file would stay fully green (probed).
test("an owner can read their own plan", async () => {
  await seed(OWNED_ID, planBody(OWNER_UID));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`weekly_menu_plans/${OWNED_ID}`).get()
  );
});

// W7: and a stranger cannot.
test("a stranger cannot read another user's plan", async () => {
  await seed(OWNED_ID, planBody(OWNER_UID));
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().doc(`weekly_menu_plans/${OWNED_ID}`).get()
  );
});

function groupPlanBody(
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    groupId: GROUP_ID,
    weekStartDate: new Date("2026-04-27T00:00:00Z"),
    entries: [],
    participants: [{ userId: OWNER_UID, permission: "admin" }],
    participantUserIds: [OWNER_UID],
    memberPermissions: { [OWNER_UID]: "admin" },
    createdAt: CREATED_AT,
    lastModifiedAt: CREATED_AT,
    ...extra,
  };
}

/**
 * The `group_weekly_menu_plans` match block, comments stripped.
 *
 * Slicing matters: several literals in this file are shared with
 * `unified_shared_shopping_lists`, so a whole-file search can be satisfied by
 * the wrong collection's copy.
 */
function groupPlanRulesBlock(): string {
  const text = fs
    .readFileSync(RULES_PATH, "utf8")
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/(^|[^:])\/\/.*$/gm, (_m, keep: string) => keep);
  const start = text.indexOf("match /group_weekly_menu_plans");
  if (start === -1) {
    throw new Error("group_weekly_menu_plans block not found in firestore.rules");
  }
  const next = text.indexOf("match /", start + 1);
  return next === -1 ? text.slice(start) : text.slice(start, next);
}

async function seedGroup(body: Record<string, unknown>): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set(body);
  });
}

// G1: the group collection carries the same shape — `GroupWeeklyMenuPlan.empty`
// also stamps a fresh createdAt, and the update rule also refuses a changed one.
// `GroupWeeklyMenuPlanService.readOrBuildWeek` exists for the same reason
// `readWeek` does, so the same protection needs the same proof.
test("a group plan with a fresh createdAt cannot overwrite a real week", async () => {
  await seedGroup(
    groupPlanBody({ entries: [{ recipeId: "r1", day: "mon" }] })
  );
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set(groupPlanBody({ createdAt: LATER, lastModifiedAt: LATER }))
  );
});

// G2: the counterpart, so G1 is not passing because all group writes fail.
test("a group edit that preserves createdAt is allowed", async () => {
  await seedGroup(groupPlanBody());
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set(
        groupPlanBody({
          entries: [{ recipeId: "r2", day: "tue" }],
          lastModifiedAt: LATER,
        })
      )
  );
});

// G3: a member with only `view` cannot write at all.
test("a view-only member cannot write a group plan", async () => {
  await seedGroup(
    groupPlanBody({
      participantUserIds: [OWNER_UID, STRANGER_UID],
      memberPermissions: { [OWNER_UID]: "admin", [STRANGER_UID]: "view" },
    })
  );
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set(
        groupPlanBody({
          participantUserIds: [OWNER_UID, STRANGER_UID],
          memberPermissions: { [OWNER_UID]: "admin", [STRANGER_UID]: "view" },
          entries: [{ recipeId: "r3", day: "wed" }],
          lastModifiedAt: LATER,
        })
      )
  );
});

// G4: the single-variable ALLOW control for G3 — the SAME stranger, promoted
// to `edit`. Without it the rule could be narrowed to admin-only and G3 would
// still pass (probed), leaving the collaborative grant unguarded.
test("an edit member can write a group plan", async () => {
  const body = groupPlanBody({
    participantUserIds: [OWNER_UID, STRANGER_UID],
    memberPermissions: { [OWNER_UID]: "admin", [STRANGER_UID]: "edit" },
  });
  await seedGroup(body);
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set({
        ...body,
        entries: [{ recipeId: "r4", day: "thu" }],
        lastModifiedAt: LATER,
      })
  );
});

// G5/G6: the read pair, as an ALLOW/DENY couple for the same reason as W6/W7.
test("a group member can read the group plan", async () => {
  await seedGroup(groupPlanBody());
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`).get()
  );
});

test("a non-member cannot read the group plan", async () => {
  await seedGroup(groupPlanBody());
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`).get()
  );
});

// G7: the ABSENT document. `resource` is null for a document that does not
// exist, and dereferencing it errors, which Firestore evaluates as a deny — so
// before the null arm every unplanned week was refused (BUT-1971).
//
// Measured, so the pair is not read as wider than it is: dropping the null arm
// reddens THIS test alone; dropping the membership arm reddens G5; and widening
// the membership arm to `true` reddens G6 while this stays green. G6 is
// therefore already the control against the arm buying more than existence — a
// second copy of it here added no kill and was removed.
//
// What the arm accepts, stated in the direction it actually runs: an ALLOW here
// means the week is unplanned, so a DENY means a plan EXISTS.
// The actor is a STRANGER on purpose: the outcome is actor-independent (with
// `resource` null the membership arm errors whoever asks), and this is the
// residual the rule accepts, so the test should be the one that demonstrates it.
test("any signed-in user can read a group week that has no plan yet", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`group_weekly_menu_plans/${GROUP_ID}_2099-W01`).get()
  );
});

// The edit trail's 50-row cap (BUT-1971).
//
// The cap sits on BOTH limbs. A cap on `update` alone would be evaded by
// seeding an oversized trail on the CREATE write, because create requires no
// `editTrail` and rejects no extra fields.
//
// `.size()` is polymorphic over list, map and string, so a 50-key MAP is
// ALLOWED here — measured per type on the emulator. The cap bounds row count,
// not type and not bytes. The type gap is left open here and absorbed
// downstream: the export's redaction helper fails closed on a non-list trail. An explicit `null` DENIES, because
// `.get()`'s default covers an ABSENT field, not a present-null one — safe only
// while `GroupWeeklyMenuPlan.toFirestore` omits the field when empty.
function trailRows(n: number): Record<string, unknown>[] {
  return Array.from({ length: n }, (_, i) => ({
    actorId: OWNER_UID,
    at: CREATED_AT,
    action: "removed",
    entryId: `e${i}`,
  }));
}

test("a create carrying more than 50 trail rows is denied", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_ID}_2030-W02`)
      .set(groupPlanBody({ editTrail: trailRows(51) }))
  );
});

test("an update carrying more than 50 trail rows is denied", async () => {
  await seedGroup(groupPlanBody());
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set(groupPlanBody({ editTrail: trailRows(51) }))
  );
});

// The create denial's own ALLOW control. Without it a rule that denied EVERY group create
// would keep the 51-row create test green and the cap could vanish unnoticed.
test("a create at exactly 50 trail rows is allowed", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_ID}_2030-W03`)
      .set(groupPlanBody({ editTrail: trailRows(50) }))
  );
});

// The production writer is an EDIT member, not the admin every other trail test
// uses. The deny below is what measures the conjunct's placement; this is its
// allow control.
test("a non-admin editor may write a trail within the cap", async () => {
  await seedGroup(
    groupPlanBody({
      participants: [
        { userId: OWNER_UID, permission: "admin" },
        { userId: STRANGER_UID, permission: "edit" },
      ],
      participantUserIds: [OWNER_UID, STRANGER_UID],
      memberPermissions: { [OWNER_UID]: "admin", [STRANGER_UID]: "edit" },
    })
  );
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .update({ editTrail: trailRows(50) })
  );
});

// The production writer is an EDIT member, and an ALLOW cannot prove the cap
// binds them: a mutant scoping the cap to admins survived the entire suite,
// because every over-cap denial was sent by the admin. This is the one that
// measures the conjunct's placement relative to the admin gate.
test("a non-admin editor is also bound by the cap", async () => {
  await seedGroup(
    groupPlanBody({
      participants: [
        { userId: OWNER_UID, permission: "admin" },
        { userId: STRANGER_UID, permission: "edit" },
      ],
      participantUserIds: [OWNER_UID, STRANGER_UID],
      memberPermissions: { [OWNER_UID]: "admin", [STRANGER_UID]: "edit" },
    })
  );
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .update({ editTrail: trailRows(51) })
  );
});

// A present `null` is not an absent field: `.get()`'s default does not cover it
// and the whole save is refused. Pinned because it is one `toFirestore` change
// away from denying every group-menu write — the same shape as the read-rule
// bug this collection already shipped once.
test("an explicit null trail is denied", async () => {
  await seedGroup(groupPlanBody());
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .update({ editTrail: null })
  );
});

test("a trail at exactly 50 rows is allowed", async () => {
  await seedGroup(groupPlanBody());
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set(groupPlanBody({ editTrail: trailRows(50) }))
  );
});

// Pins `.get('editTrail', [])` rather than a bare dereference: a document
// written before the field existed carries no `editTrail`, and under a bare
// dereference the null errors, which Firestore evaluates as a DENY — refusing
// every ordinary save on this collection. The account of why that shape is
// dangerous here lives at the read rule in `firestore.rules`; this comment
// makes no claim of its own about it.
test("a save that carries no trail at all is allowed", async () => {
  await seedGroup(groupPlanBody());
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set(groupPlanBody({ entries: [{ recipeId: "r9", day: "tue" }] }))
  );
});


// ---------------------------------------------------------------------------
// BUT-1971 follow-up: `contributorUserIds`, the append-only erasure handle.
//
// Its whole job is to survive a departure, so the rule that matters is the one
// refusing a client write that SHRINKS it: a remaining member could otherwise
// strip a departed member's uid and hide their name from erasure forever.
// ---------------------------------------------------------------------------

function contributors(n: number): string[] {
  return Array.from({ length: n }, (_, i) => `contributor-${i}`);
}

test("an update that keeps every contributor is allowed", async () => {
  // The control. Without it, every deny below could be passing because group
  // updates fail for some unrelated reason.
  await seedGroup(groupPlanBody({ contributorUserIds: ["a", "b"] }));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .update({ contributorUserIds: ["a", "b", "c"] })
  );
});

test("an update that DROPS a contributor is denied", async () => {
  await seedGroup(groupPlanBody({ contributorUserIds: ["a", "b"] }));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .update({ contributorUserIds: ["a"] })
  );
});

test("an update that CLEARS the array is denied", async () => {
  // The shape a hand-rolled client would actually send — not a subtle drop but
  // the whole trail at once.
  await seedGroup(groupPlanBody({ contributorUserIds: ["a", "b"] }));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .update({ contributorUserIds: [] })
  );
});

test("an update to a document that never had the field is allowed", async () => {
  // Back-compat, and the reason both sides read `.get(..., [])`. Every plan
  // written before this field existed must stay savable; a raw dereference
  // would deny them all, which is the defect this collection's READ rule
  // already shipped once.
  await seedGroup(groupPlanBody());
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .update({ lastModifiedAt: new Date("2026-05-01T00:00:00Z") })
  );
});

test("a non-admin editor is bound by the contributor rule too", async () => {
  // The production writer is an EDIT member. An admin-only deny would leave the
  // rule unenforced for exactly the people who write these documents — the same
  // hole the trail-cap tests above were extended to close.
  await seedGroup(
    groupPlanBody({
      participants: [
        { userId: OWNER_UID, permission: "admin" },
        { userId: STRANGER_UID, permission: "edit" },
      ],
      participantUserIds: [OWNER_UID, STRANGER_UID],
      memberPermissions: { [OWNER_UID]: "admin", [STRANGER_UID]: "edit" },
      contributorUserIds: ["a", "b"],
    })
  );
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .update({ contributorUserIds: ["a"] })
  );
});

test("a create above the contributor cap is denied", async () => {
  // On CREATE as well as update. A cap on update alone lets a hand-rolled
  // client seed an oversized array on the create write, before the update limb
  // ever runs — the same hole `groupMenuTrailWithinCap` exists to close, and
  // the shopping-list precedent splits its rule the same way.
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_ID}_2030-W04`)
      .set(groupPlanBody({ contributorUserIds: contributors(201) }))
  );
});

test("a create at exactly the contributor cap is allowed", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_ID}_2030-W05`)
      .set(groupPlanBody({ contributorUserIds: contributors(200) }))
  );
});

test("an update above the contributor cap is denied", async () => {
  await seedGroup(groupPlanBody({ contributorUserIds: contributors(200) }));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .update({ contributorUserIds: contributors(201) })
  );
});


// ---------------------------------------------------------------------------
// Can a CLIENT read by `contributorUserIds` at all? Rules are not filters: a
// list query is denied unless the rule can prove EVERY document the query could
// return is readable. The read rule here tests `memberPermissions`, and no
// implication exists between that and `contributorUserIds` — so the expected
// answer is "denied for everybody, always", not "denied only for a leaver".
//
// The whole shape of the Art. 15 gap note depends on which of those it is, so
// it is measured here rather than reasoned about.
// ---------------------------------------------------------------------------

test("MEASUREMENT: a contributor query is denied even to a CURRENT member", async () => {
  await seedGroup(groupPlanBody({ contributorUserIds: [OWNER_UID] }));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .collection("group_weekly_menu_plans")
      .where("contributorUserIds", "array-contains", OWNER_UID)
      .limit(1)
      .get()
  );
});

test("MEASUREMENT: the same query by memberPermissions IS allowed", async () => {
  // The control. Without it the deny above could be "list queries fail here",
  // which would say nothing about the contributor field.
  await seedGroup(groupPlanBody({ contributorUserIds: [OWNER_UID] }));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .collection("group_weekly_menu_plans")
      .where(`memberPermissions.${OWNER_UID}`, "!=", null)
      .limit(1)
      .get()
  );
});

test("a whole-document set() that OMITS the field is denied", async () => {
  // The production verb. `FirebaseGroupWeeklyMenuPlanRepository.save` is a
  // non-merge `set()` on the deterministic id, which evaluates the UPDATE limb,
  // so a client build whose `toFirestore` lacks the field would silently drop
  // the whole trail on every save. `hasAll` against `.get(..., [])` denies it,
  // and this is the case that pins that: a mutant defaulting the request side
  // to the STORED value — the obvious "let older clients through" fix — passed
  // the entire suite without it.
  await seedGroup(groupPlanBody({ contributorUserIds: ["a", "b"] }));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set(groupPlanBody())
  );
});

test("…and the same set() PRESERVING the field is allowed", async () => {
  // The control for the deny above: without it that test could be passing
  // because a whole-document `set()` fails here for some unrelated reason.
  await seedGroup(groupPlanBody({ contributorUserIds: ["a", "b"] }));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .set(groupPlanBody({ contributorUserIds: ["a", "b", "c"] }))
  );
});

test("a SAME-SIZE substitution is denied", async () => {
  // The Art. 17 evasion the rule exists to stop, and the one a size comparison
  // would let through: swap a departed member's uid for another and the array
  // is the same length while erasure has lost that handle on them. A mutant
  // replacing `hasAll` with `size() >= size()` survived the whole suite until
  // this case existed.
  await seedGroup(groupPlanBody({ contributorUserIds: ["a", "b"] }));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .update({ contributorUserIds: ["a", "z"] })
  );
});

test("a reorder of the same set is allowed", async () => {
  // Production shape, not a kill: the client builds this array from a Dart
  // `Set`, whose iteration order is not stable between saves. A rule that
  // compared sequences rather than membership would deny an ordinary save.
  await seedGroup(groupPlanBody({ contributorUserIds: ["a", "b", "c"] }));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .update({ contributorUserIds: ["c", "a", "b"] })
  );
});

test("a document already OVER the cap is frozen, even for an unrelated edit", async () => {
  // A documented consequence rather than a guard: nothing prunes this array
  // client-side, so a plan that somehow exceeds the cap — the Admin SDK
  // bypasses rules and can write one — can never be saved by a client again,
  // not even to touch a timestamp. Stated here so it is found in a test rather
  // than in production.
  await seedGroup(groupPlanBody({ contributorUserIds: contributors(205) }));
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .update({ lastModifiedAt: new Date("2026-05-01T00:00:00Z") })
  );
});

test("the Cloud Function's copies of both caps match the rules literals", async () => {
  // A THIRD language holds each of these numbers, and the Dart-vs-rules drift
  // guard cannot see a TypeScript literal — so without this a drift in the CF
  // copy alone is invisible.
  //
  // SLICED to this collection's block, and the occurrence count asserted. The
  // contributor needle is NOT unique in the file: `unified_shared_shopping_lists`
  // carries the same literal at the same cap, so an unanchored search stays
  // green when the GROUP cap moves — matching the shopping list's copy instead,
  // forever, which is the one drift this test exists to catch. The trail needle
  // happens to be unique today; anchoring by luck is not anchoring.
  //
  // Comments are stripped first: the raw text is searched, so a commented-out
  // cap would satisfy the match while enforcing nothing. Same reason the Dart
  // guard strips them.
  const block = groupPlanRulesBlock();
  for (const [field, cap] of [
    ["editTrail", MAX_TRAIL_ROWS],
    ["contributorUserIds", MAX_CONTRIBUTOR_UIDS],
  ] as const) {
    const needle = `.get('${field}', []).size() <= ${cap}`;
    const hits = block.split(needle).length - 1;
    if (hits !== 1) {
      throw new Error(
        `expected exactly one \`${needle}\` in the group_weekly_menu_plans ` +
          `block, found ${hits}. Either remove-chat-group-member.ts and ` +
          "firestore.rules disagree about this cap, or the rule was reshaped " +
          "and this guard can no longer read it. Both need a human.",
      );
    }
  }
});

test("a MAP-shaped editTrail with 50 keys is ALLOWED by the cap", async () => {
  // `.size()` is polymorphic over list, map and string, so the row cap does not
  // bound TYPE. Several comments elsewhere cite that as measured on the
  // emulator; before this case, none was committed. The gap is
  // absorbed downstream: the Art. 15 redaction and the deletion cascade both
  // fail CLOSED on a non-list, and each has its own test.
  const trailMap: Record<string, unknown> = {};
  for (let i = 0; i < 50; i++) trailMap[`k${i}`] = { actorId: OWNER_UID };
  await seedGroup(groupPlanBody());
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`group_weekly_menu_plans/${GROUP_PLAN_ID}`)
      .update({ editTrail: trailMap })
  );
});

async function run(): Promise<void> {
  console.log("weekly_menu_plans + group_weekly_menu_plans rules tests");
  console.log("==================================================\n");
  await setup();
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
