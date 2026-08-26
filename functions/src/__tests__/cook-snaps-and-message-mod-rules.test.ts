/**
 * Firestore rules tests for two pre-launch hardening additions:
 *
 *   1. The new `cook_snaps` rule block (collection had no rules before — the
 *      cook-snap feature was silently failing in production via the
 *      default-deny). Friends-only read, owner CRUD, admin moderation.
 *
 *   2. The added `allow read: if isAdmin();` clause on `messages`. Base read
 *      rule restricted to conversation participants; admins (not in the
 *      conversation) couldn't preview a reported message before takedown.
 *
 * Each test name states the behavior it proves. If a test fails, either the
 * rules changed or the product contract changed — decide which before
 * editing the assertion.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/cook-snaps-and-message-mod-rules.test.ts
 */

import * as fs from "fs";
import * as http from "http";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

// Overridable so a mutation probe can point the suite at a MUTATED COPY of the
// rules in a scratch directory, under its own project id, without editing
// `firestore.rules` or duplicating this file. The real file stays
// byte-identical by construction — there is no restore step to skip.
const PROJECT_ID =
  process.env.PROBE_PROJECT_ID ?? "butlery-rules-cook-snaps-and-message-mod";
const RULES_PATH =
  process.env.PROBE_RULES_PATH ??
  path.resolve(__dirname, "../../../firestore.rules");

// The emulator keeps documents between `npm run` invocations, so a create-allow
// case with a fixed doc id becomes an UPDATE on the second local run and fails
// for the wrong reason. `setup()` clears the namespace, and this makes the
// create targets unique even if that clear is ever removed or races.
const RUN_TOKEN = Date.now().toString(36);

const OWNER_UID = "snap-owner-uid";
const FRIEND_UID = "friend-uid";
const STRANGER_UID = "stranger-uid";
const ADMIN_UID = "admin-uid";

// BUT-1418 (ADR-0002): cook_snaps create now ALSO requires `isAgeCompliant()`
// (custom claim `ageCompliant == true`). Every authed context that performs a
// create carries this claim so each test keeps isolating its intended gate
// (impersonation / required-field / size / visibility), not the new age gate.
// Without it every create-allow assertion here fails closed. Read/update/delete
// contexts are NOT age-gated and stay claimless.
const AGE_OK = { ageCompliant: true };

let env: RulesTestEnvironment;

// The emulator persists documents across separate `npm run` invocations
// (env.cleanup() only closes clients). The create-allow tests below use FIXED
// doc ids (cs-create-ok, cs-create-onlyme); on a 2nd+ run those already exist,
// so the create is evaluated as an UPDATE and the cook_snaps update rule denies
// a full-body re-set — a false FAIL. Clearing the namespace at setup keeps every
// create-allow target brand-new. (See firestore-rules-tester knowledge file,
// 2026-06-03 entry.)
function clearFirestore(): Promise<void> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        host: "127.0.0.1",
        port: 8080,
        method: "DELETE",
        path: `/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
      },
      (res) => {
        res.on("data", () => undefined);
        res.on("end", resolve);
      }
    );
    req.on("error", reject);
    req.end();
  });
}

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  await clearFirestore();

  await env.withSecurityRulesDisabled(async (ctx) => {
    // Seed the admin record (collection is rules-locked; admins are added
    // server-side via Firebase Console / Admin SDK).
    await ctx.firestore().doc(`admins/${ADMIN_UID}`).set({
      addedAt: new Date(),
    });
    // Seed the friendship: FRIEND_UID is in OWNER_UID's friends list.
    // Only the doc's existence matters per the cook_snaps read rule.
    await ctx
      .firestore()
      .doc(`users/${OWNER_UID}/friends/${FRIEND_UID}`)
      .set({ addedAt: new Date() });
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

// A snap body that satisfies the structural validation. Keep helpers minimal —
// individual tests override fields they want to vary.
function validSnapBody(
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    recipeId: "recipe-1",
    userId: OWNER_UID,
    userDisplayName: "Anna",
    photoUrl: "https://example.com/photo.jpg",
    createdAt: new Date(),
    ...extra,
  };
}

// ============================================================================
// COOK SNAPS — read access (friends-gated)
// ============================================================================

// snap-owner can read their own snap.
test("cook_snaps: owner can read own snap", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-own`)
      .set(validSnapBody());
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(ctx.firestore().doc(`cook_snaps/cs-own`).get());
});

// a friend of the snap-owner can read the owner's snap.
// (Friend doc seeded in setup at users/OWNER_UID/friends/FRIEND_UID.
// BUT-1214: the friend branch requires explicit visibility — post-backfill
// every readable doc carries 'sameAsRecipe'.)
test("cook_snaps: friend-of-owner can read owner's snap", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-friend-readable`)
      .set(validSnapBody({ visibility: "sameAsRecipe" }));
  });
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertSucceeds(
    ctx.firestore().doc(`cook_snaps/cs-friend-readable`).get()
  );
});

// a stranger (not in owner's friends list) cannot read.
// Privacy guarantee: friends-only is enforced at the rules layer.
test("cook_snaps: stranger cannot read another user's snap", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-private`)
      .set(validSnapBody());
  });
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(ctx.firestore().doc(`cook_snaps/cs-private`).get());
});

// unauthenticated request cannot read.
test("cook_snaps: unauthenticated user cannot read any snap", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-anon`)
      .set(validSnapBody());
  });
  const ctx = env.unauthenticatedContext();
  await assertFails(ctx.firestore().doc(`cook_snaps/cs-anon`).get());
});

// friends-gated query — BUT-1214 split-query contract: friends' snaps are
// queried with an explicit visibility constraint (rules can't prove a
// foreign doc isn't onlyMe otherwise).
test("cook_snaps: friend-scoped query with visibility constraint succeeds", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-q-friend`)
      .set(validSnapBody({ recipeId: "recipe-q", visibility: "sameAsRecipe" }));
  });
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .collection(`cook_snaps`)
      .where("recipeId", "==", "recipe-q")
      .where("userId", "in", [OWNER_UID])
      .where("visibility", "==", "sameAsRecipe")
      .get()
  );
});

// BUT-1214: the PRE-1214 query shape (no visibility constraint) is now
// denied for foreign userIds — it could surface an onlyMe snap. Proves the
// repository's own/friends query split is not optional.
test("cook_snaps: friend query without visibility constraint is denied", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .collection(`cook_snaps`)
      .where("recipeId", "==", "recipe-q")
      .where("userId", "in", [FRIEND_UID, OWNER_UID])
      .get()
  );
});

// BUT-1214: the viewer's own-snaps query needs NO visibility constraint —
// authors always see their own onlyMe snaps.
test("cook_snaps: own-snaps query without visibility constraint succeeds", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-q-own-onlyme`)
      .set(validSnapBody({ recipeId: "recipe-q3", visibility: "onlyMe" }));
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .collection(`cook_snaps`)
      .where("recipeId", "==", "recipe-q3")
      .where("userId", "==", OWNER_UID)
      .get()
  );
});

// ============================================================================
// COOK SNAPS — BUT-1214 per-snap visibility override (onlyMe)
// ============================================================================

// the author can still read their own onlyMe snap.
test("cook_snaps: owner can read own onlyMe snap", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-onlyme-own`)
      .set(validSnapBody({ visibility: "onlyMe" }));
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(ctx.firestore().doc(`cook_snaps/cs-onlyme-own`).get());
});

// a friend (who CAN read sameAsRecipe snaps) is denied an onlyMe snap —
// the core BUT-1214 privacy guarantee, enforced at the rules layer.
test("cook_snaps: friend cannot read an onlyMe snap", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-onlyme-friend`)
      .set(validSnapBody({ visibility: "onlyMe" }));
  });
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx.firestore().doc(`cook_snaps/cs-onlyme-friend`).get()
  );
});

// a legacy doc (no visibility field) is friend-UNREADABLE by design: any
// permissive back-compat clause (`!('visibility' in data)` / get-with-
// default) was proven on the emulator to leak onlyMe docs through
// unconstrained list queries. The backfill
// (functions/scripts/backfill-cook-snap-visibility.js) MUST therefore run
// before this rules version deploys; this test pins the deliberate
// trade-off. The owner can still read their own legacy snap.
test("cook_snaps: legacy snap without visibility is NOT friend-readable (backfill required)", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-legacy`)
      .set(validSnapBody());
  });
  await assertFails(
    env.authenticatedContext(FRIEND_UID).firestore().doc(`cook_snaps/cs-legacy`).get()
  );
  await assertSucceeds(
    env.authenticatedContext(OWNER_UID).firestore().doc(`cook_snaps/cs-legacy`).get()
  );
});

// create accepts both enum values…
test("cook_snaps: owner can create an onlyMe snap", async () => {
  const ctx = env.authenticatedContext(OWNER_UID, AGE_OK);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-create-onlyme`)
      .set(validSnapBody({ visibility: "onlyMe" }))
  );
});

// …but rejects a forged value (would be get-readable yet query-invisible —
// an inconsistent state the validation refuses to persist).
test("cook_snaps: create with forged visibility value is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID, AGE_OK);
  await assertFails(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-create-forged`)
      .set(validSnapBody({ visibility: "everyone" }))
  );
});

// owner may retro-hide a snap (visibility is mutable, identity fields not).
test("cook_snaps: owner can update visibility to onlyMe", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-retro-hide`)
      .set(validSnapBody({ visibility: "sameAsRecipe" }));
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-retro-hide`)
      .update({ visibility: "onlyMe" })
  );
});

// a forged visibility value is rejected on UPDATE too — without this the
// create-time check is trivially bypassed by create-valid-then-update.
test("cook_snaps: update with forged visibility value is rejected", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-update-forged`)
      .set(validSnapBody({ visibility: "sameAsRecipe" }));
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-update-forged`)
      .update({ visibility: "everyone" })
  );
});

// owner may also re-share (onlyMe -> sameAsRecipe) — the rule comment
// promises visibility is mutable in BOTH directions.
test("cook_snaps: owner can update visibility back to sameAsRecipe", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-reshare`)
      .set(validSnapBody({ visibility: "onlyMe" }));
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-reshare`)
      .update({ visibility: "sameAsRecipe" })
  );
});

// unauthenticated query is denied regardless of constraints.
test("cook_snaps: unauthenticated query is denied", async () => {
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx
      .firestore()
      .collection(`cook_snaps`)
      .where("recipeId", "==", "recipe-q")
      .where("visibility", "==", "sameAsRecipe")
      .get()
  );
});

// a friend query explicitly constrained to visibility == 'onlyMe' for a
// foreign userId is denied — the deny half of the query-level visibility
// gate (the allow half is the sameAsRecipe query above).
test("cook_snaps: friend query constrained to onlyMe is denied", async () => {
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .collection(`cook_snaps`)
      .where("recipeId", "==", "recipe-q")
      .where("userId", "==", OWNER_UID)
      .where("visibility", "==", "onlyMe")
      .get()
  );
});

// admin moderation override still works on onlyMe snaps (reported content
// must stay reviewable regardless of visibility).
test("cook_snaps: admin can read an onlyMe snap (moderation)", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-onlyme-mod`)
      .set(validSnapBody({ visibility: "onlyMe" }));
  });
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc(`cook_snaps/cs-onlyme-mod`).get());
});

// a query whose result set would include a stranger's snap is denied
// wholesale (Firestore rule semantics — per-doc evaluation; any deny
// fails the entire query). Proves the friend-list-pre-filter pattern is
// not optional at the app layer.
test("cook_snaps: query that would include a stranger's snap is denied", async () => {
  const STRANGER_OWNER = "stranger-owner-uid";
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-q-stranger`)
      .set(validSnapBody({ recipeId: "recipe-q2", userId: STRANGER_OWNER }));
  });
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .collection(`cook_snaps`)
      .where("recipeId", "==", "recipe-q2")
      .where("userId", "in", [FRIEND_UID, STRANGER_OWNER])
      .get()
  );
});

// ============================================================================
// COOK SNAPS — create (validated)
// ============================================================================

// authenticated user can create a snap with userId == auth.uid and all
// required fields.
test("cook_snaps: owner can create a valid snap", async () => {
  const ctx = env.authenticatedContext(OWNER_UID, AGE_OK);
  await assertSucceeds(
    ctx.firestore().doc(`cook_snaps/cs-create-ok`).set(validSnapBody())
  );
});

// BUT-1418: DENY — an owner whose token lacks the ageCompliant claim cannot
// create a snap, even with an otherwise-valid body and matching userId. This is
// the load-bearing deny for the new age gate: it fails closed on a missing
// claim (CEL `request.auth.token.ageCompliant` is undefined -> `== true` false).
test("cook_snaps: owner without ageCompliant claim cannot create a snap", async () => {
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx.firestore().doc(`cook_snaps/cs-noclaim`).set(validSnapBody())
  );
});

// BUT-1418: DENY — an explicit ageCompliant:false claim is also rejected.
test("cook_snaps: owner with ageCompliant=false cannot create a snap", async () => {
  const ctx = env.authenticatedContext(OWNER_UID, { ageCompliant: false });
  await assertFails(
    ctx.firestore().doc(`cook_snaps/cs-agefalse`).set(validSnapBody())
  );
});

// cannot impersonate — userId in body must match auth.uid.
test("cook_snaps: cannot create a snap impersonating another user", async () => {
  const ctx = env.authenticatedContext(STRANGER_UID, AGE_OK);
  await assertFails(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-impersonate`)
      .set(validSnapBody({ userId: OWNER_UID }))
  );
});

// missing required field (photoUrl) is rejected.
test("cook_snaps: create without required photoUrl is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID, AGE_OK);
  const bodyMissing = { ...validSnapBody() } as Record<string, unknown>;
  delete bodyMissing.photoUrl;
  await assertFails(
    ctx.firestore().doc(`cook_snaps/cs-no-photo`).set(bodyMissing)
  );
});

// oversized userDisplayName (>100) is rejected.
test("cook_snaps: oversized userDisplayName is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID, AGE_OK);
  await assertFails(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-big-name`)
      .set(validSnapBody({ userDisplayName: "x".repeat(101) }))
  );
});

// oversized caption (>200) is rejected.
test("cook_snaps: oversized caption is rejected", async () => {
  const ctx = env.authenticatedContext(OWNER_UID, AGE_OK);
  await assertFails(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-big-caption`)
      .set(validSnapBody({ caption: "x".repeat(201) }))
  );
});

// ============================================================================
// COOK SNAPS — update (owner-only, immutable identity fields)
// ============================================================================

// owner can update caption only.
test("cook_snaps: owner can update caption only", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-update`)
      .set(validSnapBody({ caption: "old" }));
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-update`)
      .update({ caption: "new" })
  );
});

// owner cannot modify the immutable userId field.
test("cook_snaps: owner cannot modify userId", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-mutate-uid`)
      .set(validSnapBody());
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`cook_snaps/cs-mutate-uid`)
      .update({ userId: STRANGER_UID })
  );
});

// ============================================================================
// COOK SNAPS — delete (owner or admin)
// ============================================================================

// non-owner non-admin cannot delete.
test("cook_snaps: non-owner non-admin cannot delete", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-stranger-del`)
      .set(validSnapBody());
  });
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx.firestore().doc(`cook_snaps/cs-stranger-del`).delete()
  );
});

// snap-owner can delete own snap.
test("cook_snaps: owner can delete own snap", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-self-del`)
      .set(validSnapBody());
  });
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`cook_snaps/cs-self-del`).delete()
  );
});

// admin can read AND delete any snap (moderation override).
//  Proves both halves of the `allow read, delete: if isAdmin();` rule.
test("cook_snaps: admin can read and delete any snap (moderation)", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`cook_snaps/cs-mod`)
      .set(validSnapBody());
  });
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc(`cook_snaps/cs-mod`).get());
  await assertSucceeds(ctx.firestore().doc(`cook_snaps/cs-mod`).delete());
});

// ============================================================================
// MESSAGES — admin-read moderation override (the new clause)
// ============================================================================

// Helper: seed a conversation with two participants and one message.
async function seedMessage(
  msgId: string,
  conversationId: string,
  participants: string[]
): Promise<void> {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`conversations/${conversationId}`)
      .set({ participantIds: participants, createdAt: new Date() });
    await admin
      .firestore()
      .doc(`messages/${msgId}`)
      .set({
        senderId: participants[0],
        conversationId,
        content: "Hej!",
        sentAt: new Date(),
      });
  });
}

// admin who is NOT a conversation participant can read a message.
//     Proves the new `allow read: if isAdmin();` clause works — the base
//     read rule restricts to participants only.
test("messages: admin (non-participant) can read any message", async () => {
  await seedMessage("m-mod", "conv-mod", [OWNER_UID, FRIEND_UID]);
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc(`messages/m-mod`).get());
});

// regression: non-admin non-participant still denied.
test("messages: non-admin non-participant cannot read a message", async () => {
  await seedMessage("m-private", "conv-private", [OWNER_UID, FRIEND_UID]);
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(ctx.firestore().doc(`messages/m-private`).get());
});

// regression: admin can still delete (moderation
// pipeline expects both read + delete to work).
test("messages: admin can delete any message (moderation)", async () => {
  await seedMessage("m-del", "conv-del", [OWNER_UID, FRIEND_UID]);
  const ctx = env.authenticatedContext(ADMIN_UID);
  await assertSucceeds(ctx.firestore().doc(`messages/m-del`).delete());
});

// BUT-1904. The duplicate guard empties a message and stamps it
// `duplicateBlocked` instead of deleting it. The sender's own update branch
// otherwise places no constraint on `type` and lets `content` become anything,
// so without the new conjunct the sender could write the duplicate text back
// in and hand it to the other participants after all — undoing the guard from
// the client, with no server involvement.
//
// Seeded with rules DISABLED, which is how the guard writes it too (the Admin
// SDK bypasses rules); these cases are about what the CLIENT may then do.
async function seedBlockedMessage(
  msgId: string,
  conversationId: string,
  participants: string[],
  type: string,
): Promise<void> {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`conversations/${conversationId}`)
      .set({ participantIds: participants, createdAt: new Date() });
    await admin
      .firestore()
      .doc(`messages/${msgId}`)
      .set({
        senderId: participants[0],
        conversationId,
        content: type === "duplicateBlocked" ? "" : "Hej!",
        type,
        sentAt: new Date(),
      });
  });
}

test("messages: the sender cannot edit a message the duplicate guard blocked", async () => {
  await seedBlockedMessage(
    "m-blocked",
    "conv-blocked",
    [OWNER_UID, FRIEND_UID],
    "duplicateBlocked",
  );
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/m-blocked`)
      .update({ content: "Jag kommer klockan sju ikvall" }),
  );
});

// THE CONTROL for the case above: same author, same conversation, same update
// payload, an ordinary message. (`seedBlockedMessage` also varies the STORED
// content, so this is not literally single-variable — but no conjunct in the
// update rule reads stored content, which is the argument the phrase would
// otherwise have replaced.) Without
// it the deny above proves nothing — every rules denial prints an
// interchangeable PERMISSION_DENIED that names a rule line rather than a
// reason, so a test that denied for the wrong reason (say, the author not
// matching) would read identically.
test("messages: the same sender CAN edit an ordinary message (control)", async () => {
  await seedBlockedMessage(
    "m-editable",
    "conv-editable",
    [OWNER_UID, FRIEND_UID],
    "text",
  );
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/m-editable`)
      .update({ content: "Jag kommer klockan sju ikvall" }),
  );
});

// The sender can still get rid of the row — the delete RULE is untouched. A
// change that closed editing by closing the whole document would pass the deny
// above and break this.
//
// Says nothing about DISMISSING the notice — this test pins what the RULE
// allows and can pin nothing about screens. See ADR-0009.
test("messages: the sender can still delete a blocked message", async () => {
  await seedBlockedMessage(
    "m-blocked-del",
    "conv-blocked-del",
    [OWNER_UID, FRIEND_UID],
    "duplicateBlocked",
  );
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx.firestore().doc(`messages/m-blocked-del`).delete(),
  );
});

// ============================================================================
// MESSAGES — BUT-1904 freeze, the branches the cases above do not reach
// ============================================================================

// `seedBlockedMessage` takes `type` as a STRING, so it cannot express the three
// stored states the defaulting expression treats separately — absent, present
// and null, present and not a string. Those are the states legacy rows and
// hand-rolled clients actually produce, and each is its own branch of
// `resource.data.get('type', 'text')`.
async function seedMessageBody(
  msgId: string,
  conversationId: string,
  participants: string[],
  body: Record<string, unknown>,
): Promise<void> {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`conversations/${conversationId}`)
      .set({ participantIds: participants, createdAt: new Date() });
    await admin
      .firestore()
      .doc(`messages/${msgId}`)
      .set({
        senderId: participants[0],
        conversationId,
        content: "Hej!",
        sentAt: new Date(),
        ...body,
      });
  });
}

// B4: the RECEIPTS branch is a second, OR'd `allow update` on this collection,
// and the freeze conjunct is not on it. It stays open on a blocked row, which
// is the intended reading of the split — a receipt is not an edit — and this
// is the allow half that makes the denies below mean something.
test("messages: a recipient can still mark a blocked message delivered", async () => {
  await seedBlockedMessage(
    "m-blocked-receipt",
    "conv-blocked-receipt",
    [OWNER_UID, FRIEND_UID],
    "duplicateBlocked",
  );
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/m-blocked-receipt`)
      .update({ status: "delivered", deliveredAt: new Date() }),
  );
});

// B5: the route the freeze would have to be re-proved on. `affectedKeys()`
// is TOP-LEVEL and `content` is a top-level key, so adding it to a receipt
// payload drops out of the receipts allow-list — and the sender branch is
// already refusing the row. Both `allow update` statements have to say no or
// the guard is undone through the other one.
test("messages: a recipient cannot smuggle content into a blocked message with a receipt", async () => {
  await seedBlockedMessage(
    "m-blocked-smuggle",
    "conv-blocked-smuggle",
    [OWNER_UID, FRIEND_UID],
    "duplicateBlocked",
  );
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/m-blocked-smuggle`)
      .update({ status: "read", content: "Jag kommer klockan sju ikvall" }),
  );
});

// B6: same route, taken by the person who has a motive for it. The sender is
// also a participant, so the receipts branch is open to them too.
test("messages: the sender cannot smuggle content into a blocked message with a receipt", async () => {
  await seedBlockedMessage(
    "m-blocked-smuggle-self",
    "conv-blocked-smuggle-self",
    [OWNER_UID, FRIEND_UID],
    "duplicateBlocked",
  );
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/m-blocked-smuggle-self`)
      .update({ status: "read", content: "Jag kommer klockan sju ikvall" }),
  );
});

// B7: the freeze reads the STORED type, so the obvious escape is to unstamp
// the row first and edit it afterwards. The pre-state is what the conjunct
// tests, so the first write of that pair never lands.
test("messages: the sender cannot unstamp a blocked message", async () => {
  await seedBlockedMessage(
    "m-blocked-unstamp",
    "conv-blocked-unstamp",
    [OWNER_UID, FRIEND_UID],
    "duplicateBlocked",
  );
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx.firestore().doc(`messages/m-blocked-unstamp`).update({ type: "text" }),
  );
});

// B8: and not in one write either.
test("messages: the sender cannot unstamp and refill a blocked message in one update", async () => {
  await seedBlockedMessage(
    "m-blocked-refill",
    "conv-blocked-refill",
    [OWNER_UID, FRIEND_UID],
    "duplicateBlocked",
  );
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/m-blocked-refill`)
      .update({ type: "text", content: "Jag kommer klockan sju ikvall" }),
  );
});

// B9: unstamping through the receipts branch instead. `type` is not in its
// allow-list, so a recipient cannot launder the row back into an editable one
// for the sender.
test("messages: a recipient cannot unstamp a blocked message with a receipt", async () => {
  await seedBlockedMessage(
    "m-blocked-launder",
    "conv-blocked-launder",
    [OWNER_UID, FRIEND_UID],
    "duplicateBlocked",
  );
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/m-blocked-launder`)
      .update({ status: "read", type: "text" }),
  );
});

// B10: the DEFAULT in `get('type', 'text')` is the whole compatibility story
// for rows written before the field existed. A default of anything else would
// have frozen every one of them, silently and forever.
test("messages: the sender can edit a legacy message that has no type field", async () => {
  await seedMessageBody("m-legacy-notype", "conv-legacy-notype", [
    OWNER_UID,
    FRIEND_UID,
  ], {});
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/m-legacy-notype`)
      .update({ content: "Jag kommer klockan sju ikvall" }),
  );
});

// B11: PRESENT-AND-NULL is a fourth state, not a spelling of absent — a
// `.get()` on it returns null rather than the default. Measured: the
// comparison against the literal still answers, so the row stays editable
// rather than CEL-erroring into a blanket deny.
test("messages: the sender can edit a message whose type is null", async () => {
  await seedMessageBody(
    "m-null-type",
    "conv-null-type",
    [OWNER_UID, FRIEND_UID],
    { type: null },
  );
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/m-null-type`)
      .update({ content: "Jag kommer klockan sju ikvall" }),
  );
});

// B12: nothing in the rules constrains what `type` may hold, so a hand-rolled
// client can store a number there. Comparing it against the literal must not
// error either — an error here denies the write, which would freeze an
// ordinary message on a malformed field nobody validates.
test("messages: the sender can edit a message whose type is not a string", async () => {
  await seedMessageBody(
    "m-number-type",
    "conv-number-type",
    [OWNER_UID, FRIEND_UID],
    { type: 42 },
  );
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/m-number-type`)
      .update({ content: "Jag kommer klockan sju ikvall" }),
  );
});

// B13: the freeze is not what stops an outsider — membership already did, and
// it still has to. A conjunct added to this branch could have been written in
// a way that made the branch pass for somebody it never passed for before.
test("messages: a non-participant cannot edit a blocked message", async () => {
  await seedBlockedMessage(
    "m-blocked-stranger",
    "conv-blocked-stranger",
    [OWNER_UID, FRIEND_UID],
    "duplicateBlocked",
  );
  const ctx = env.authenticatedContext(STRANGER_UID);
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/m-blocked-stranger`)
      .update({ content: "Jag kommer klockan sju ikvall" }),
  );
});

// B14: and neither can a client with no identity at all.
test("messages: an unauthenticated client cannot edit a blocked message", async () => {
  await seedBlockedMessage(
    "m-blocked-anon",
    "conv-blocked-anon",
    [OWNER_UID, FRIEND_UID],
    "duplicateBlocked",
  );
  const ctx = env.unauthenticatedContext();
  await assertFails(
    ctx
      .firestore()
      .doc(`messages/m-blocked-anon`)
      .update({ content: "Jag kommer klockan sju ikvall" }),
  );
});

// B15: the deny half of "the sender can still delete a blocked message".
// The delete belongs to the row's own sender; the freeze must not read as a
// licence for anyone else in the conversation to clear the row away.
test("messages: a recipient cannot delete a blocked message", async () => {
  await seedBlockedMessage(
    "m-blocked-otherdel",
    "conv-blocked-otherdel",
    [OWNER_UID, FRIEND_UID],
    "duplicateBlocked",
  );
  const ctx = env.authenticatedContext(FRIEND_UID);
  await assertFails(
    ctx.firestore().doc(`messages/m-blocked-otherdel`).delete(),
  );
});

// B16: `type` is absent from `cannotModify` and absent from the create rule,
// so a client can put the guard's own value on a message of its own — on an
// existing one here, and B17 does it at create time. Both are pinned as they
// BEHAVE rather than as anyone would wish them: the row a client stamps this
// way becomes frozen by the same conjunct, and the only person who can reach
// it is its own sender, who could already delete it. A later ticket that
// constrains `type` will flip these two, and flipping them is the signal.
test("messages: the sender can stamp their own ordinary message as blocked", async () => {
  await seedBlockedMessage(
    "m-selfstamp",
    "conv-selfstamp",
    [OWNER_UID, FRIEND_UID],
    "text",
  );
  const ctx = env.authenticatedContext(OWNER_UID);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/m-selfstamp`)
      .update({ type: "duplicateBlocked" }),
  );
  // ...and having done so, it can no longer edit its own row.
  await assertFails(
    ctx.firestore().doc(`messages/m-selfstamp`).update({ content: "igen" }),
  );
});

// B17: the create rule places no constraint on `type` (see B16). `email_verified`
// stands in for the account-maturity window and `ageCompliant` for the age gate,
// so this case isolates `type` rather than re-testing either of those.
test("messages: a client can create a message already stamped as blocked", async () => {
  await env.withSecurityRulesDisabled(async (admin) => {
    await admin
      .firestore()
      .doc(`conversations/conv-create-blocked`)
      .set({ participantIds: [OWNER_UID, FRIEND_UID], createdAt: new Date() });
  });
  const ctx = env.authenticatedContext(OWNER_UID, {
    email_verified: true,
    ageCompliant: true,
  });
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`messages/m-create-blocked-${RUN_TOKEN}`)
      .set({
        senderId: OWNER_UID,
        conversationId: "conv-create-blocked",
        content: "Jag kommer klockan sju ikvall",
        type: "duplicateBlocked",
        sentAt: new Date(),
      }),
  );
});

async function run(): Promise<void> {
  console.log("cook_snaps + messages admin-read rules tests\n");
  console.log("============================================\n");
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
