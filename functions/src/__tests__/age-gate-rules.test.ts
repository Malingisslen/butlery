/**
 * Firestore rules tests for the BUT-1386 (ADR-0002) server-authoritative
 * age gate.
 *
 * WHAT CHANGED vs the old self-declared birthYear contract:
 *   1. NEW helper `isAgeCompliant()` = authed AND custom claim
 *      `request.auth.token.ageCompliant == true`. Fails CLOSED — a missing
 *      or false claim (or a stale token issued before the claim was set)
 *      denies. The `verifySignupAge` Cloud Function is the sole writer of
 *      the claim and of `birthYear`.
 *   2. `birthYear` is now CF-ONLY-written. Clients may no longer create or
 *      mutate it on either of its two homes:
 *        - users/{uid}/settings/{settingId}: create requires birthYear ABSENT;
 *          update requires birthYear UNCHANGED vs existing.
 *        - users/{uid} profile doc: same create-absent / update-unchanged split;
 *          delete stays owner-only.
 *      (The old "create REQUIRES a valid birthYear" contract is GONE.)
 *   3. The four UGC create paths now also require `&& isAgeCompliant()`:
 *      recipe_comments, messages, social_requests, recipe_ratings.
 *
 * The rules-unit-testing lib seeds custom claims via the second arg of
 * `env.authenticatedContext(uid, { ageCompliant: true })`.
 *
 * Prerequisite: Firestore emulator must be running locally
 *   (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/age-gate-rules.test.ts
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
import { serverTimestamp } from "firebase/firestore";

const PROJECT_ID = "butlery-age-gate-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const USER_UID = "user-a";
const OTHER_UID = "user-b";

// Per-run path suffix. The emulator persists documents across separate
// `npm run` invocations (env.cleanup() only closes clients), so a create-allow
// against a FIXED doc id becomes an UPDATE on the 2nd+ run and can fail for the
// wrong reason. A fixed literal (NOT Date.now()) keeps the run reproducible; the
// namespace is also DELETEd in setup() so re-runs start clean either way.
// (See firestore-rules-tester knowledge file, 2026-06-03 + 2026-06-27 entries.)
const RUN = "but1386";

// Custom-claim presets. `ageCompliant:true` is the gate; `email_verified:true`
// additionally satisfies isAccountMatured() (anti-spam cooldown) for the
// messages + social_requests paths, isolating isAgeCompliant() as the variable.
const AGE_OK = { ageCompliant: true };
const AGE_OK_MATURED = { ageCompliant: true, email_verified: true };
const AGE_FALSE_MATURED = { ageCompliant: false, email_verified: true };
const MATURED_ONLY = { email_verified: true };

let env: RulesTestEnvironment;

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
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

// ----------------------------------------------------------------------------
// Body builders
// ----------------------------------------------------------------------------

function commentBody(authorUid: string): Record<string, unknown> {
  return {
    recipeId: "recipe-1",
    authorId: authorUid,
    text: "ser gott ut!",
    createdAt: serverTimestamp(),
  };
}

function messageBody(senderUid: string): Record<string, unknown> {
  return {
    senderId: senderUid,
    conversationId: "conv-1",
    content: "Hej!",
    sentAt: serverTimestamp(),
  };
}

function socialRequestBody(
  fromUid: string,
  toUid: string
): Record<string, unknown> {
  return {
    type: "friend_request",
    fromUserId: fromUid,
    toUserId: toUid,
    status: "pending",
    sentAt: serverTimestamp(),
  };
}

function ratingBody(raterUid: string): Record<string, unknown> {
  return {
    recipeId: "recipe-1",
    userId: raterUid,
    rating: 5,
    createdAt: serverTimestamp(),
  };
}

async function seedDoc(
  docPath: string,
  body: Record<string, unknown>
): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(docPath).set(body);
  });
}

// ============================================================================
// SETTINGS — users/{uid}/settings/{settingId} birthYear immutability
// (7 assertions across 7 tests)
//
// birthYear is CF-only-written. Client CREATE must omit it; client UPDATE must
// leave it exactly as-is (add/change/remove all denied). All OTHER settings
// edits remain freely writable by the owner.
// ============================================================================

// S1: create WITHOUT birthYear -> allowed (owner).
test(
  "settings: owner can create preferences WITHOUT birthYear",
  async () => {
    const ctx = env.authenticatedContext(USER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${USER_UID}/settings/s-create-ok-${RUN}`)
        .set({ notificationsEnabled: true, hasCompletedOnboarding: true })
    );
  }
);

// S2: create WITH birthYear from the client -> DENIED (CF-only field).
test(
  "settings: owner CANNOT create preferences carrying birthYear",
  async () => {
    const ctx = env.authenticatedContext(USER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${USER_UID}/settings/s-create-bday-${RUN}`)
        .set({
          notificationsEnabled: true,
          birthYear: new Date().getFullYear() - 30,
        })
    );
  }
);

// S3: update OTHER fields while birthYear stays ABSENT -> allowed.
test(
  "settings: owner can edit other fields while birthYear stays absent",
  async () => {
    const docPath = `users/${USER_UID}/settings/s-upd-nobday-${RUN}`;
    await seedDoc(docPath, {
      notificationsEnabled: true,
      hasCompletedOnboarding: false,
    });
    const ctx = env.authenticatedContext(USER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(docPath)
        .set({ notificationsEnabled: false }, { merge: true })
    );
  }
);

// S4: update that ADDS birthYear (absent -> present) -> DENIED.
test(
  "settings: owner CANNOT add birthYear via update",
  async () => {
    const docPath = `users/${USER_UID}/settings/s-upd-addbday-${RUN}`;
    await seedDoc(docPath, { notificationsEnabled: true });
    const ctx = env.authenticatedContext(USER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(docPath)
        .set(
          { birthYear: new Date().getFullYear() - 20 },
          { merge: true }
        )
    );
  }
);

// S5: update that CHANGES an existing (CF-set) birthYear -> DENIED.
test(
  "settings: owner CANNOT change an existing CF-set birthYear",
  async () => {
    const docPath = `users/${USER_UID}/settings/s-upd-chgbday-${RUN}`;
    await seedDoc(docPath, {
      notificationsEnabled: true,
      birthYear: 1990,
    });
    const ctx = env.authenticatedContext(USER_UID);
    await assertFails(
      ctx.firestore().doc(docPath).set({ birthYear: 1991 }, { merge: true })
    );
  }
);

// S6: update OTHER fields while a CF-set birthYear is PRESERVED -> allowed.
//     Proves the immutability clause permits unrelated edits when the field is
//     present and unchanged (not just when it is absent).
test(
  "settings: owner can edit other fields while CF-set birthYear is preserved",
  async () => {
    const docPath = `users/${USER_UID}/settings/s-upd-keepbday-${RUN}`;
    await seedDoc(docPath, {
      notificationsEnabled: true,
      birthYear: 1990,
    });
    const ctx = env.authenticatedContext(USER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(docPath)
        .set({ notificationsEnabled: false }, { merge: true })
    );
  }
);

// S7: a different user cannot write your settings at all (isOwner gate).
test(
  "settings: cross-user write to another user's settings is denied",
  async () => {
    const ctx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${USER_UID}/settings/s-cross-${RUN}`)
        .set({ notificationsEnabled: true })
    );
  }
);

// ============================================================================
// SETTINGS — users/{uid}/settings/{settingId} isMinor immutability (BUT-674)
// (4 assertions across 4 tests)
//
// `isMinor` is CF-only-written here too — the CF mirrors it into
// users/{uid}/settings/preferences so the client can read it for analytics
// minimization. A client that could forge isMinor:false there would defeat that
// minimization, so the client CREATE must omit it and client UPDATE must leave
// it exactly as-is. Mirrors S1/S2/S5/S6. The last test proves the protection is
// isMinor-SPECIFIC: unrelated settings edits still succeed while isMinor holds.
// ============================================================================

// SM1: create settings WITH isMinor from the client -> DENIED (CF-only field).
test(
  "settings: owner CANNOT create preferences carrying isMinor",
  async () => {
    const ctx = env.authenticatedContext(USER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${USER_UID}/settings/s-create-minor-${RUN}`)
        .set({ notificationsEnabled: true, isMinor: false })
    );
  }
);

// SM2: create settings WITHOUT isMinor (normal settings write) -> allowed.
//      Proves the isMinor clause does not block a legitimate settings create.
test(
  "settings: owner can create preferences WITHOUT isMinor",
  async () => {
    const ctx = env.authenticatedContext(USER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${USER_UID}/settings/s-create-nominor-${RUN}`)
        .set({ notificationsEnabled: true, hasCompletedOnboarding: true })
    );
  }
);

// SM3: update that CHANGES an existing (CF-set) isMinor -> DENIED.
//      Seed isMinor:true via withSecurityRulesDisabled, then the client tries to
//      flip it to false (the exact un-gating attack the rule blocks).
test(
  "settings: owner CANNOT change a seeded isMinor via update",
  async () => {
    const docPath = `users/${USER_UID}/settings/s-upd-minor-chg-${RUN}`;
    await seedDoc(docPath, {
      notificationsEnabled: true,
      isMinor: true,
    });
    const ctx = env.authenticatedContext(USER_UID);
    await assertFails(
      ctx.firestore().doc(docPath).set({ isMinor: false }, { merge: true })
    );
  }
);

// SM4: update OTHER fields while a CF-set isMinor is PRESERVED -> allowed.
//      Load-bearing: proves the immutability clause permits unrelated settings
//      edits when isMinor is present and unchanged (not a blanket update block).
test(
  "settings: owner can edit other fields while CF-set isMinor is preserved",
  async () => {
    const docPath = `users/${USER_UID}/settings/s-upd-minor-keep-${RUN}`;
    await seedDoc(docPath, {
      notificationsEnabled: true,
      isMinor: true,
    });
    const ctx = env.authenticatedContext(USER_UID);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(docPath)
        .set({ notificationsEnabled: false }, { merge: true })
    );
  }
);

// ============================================================================
// PROFILE DOC — users/{uid} birthYear immutability
// (6 assertions across 6 tests)
//
// Same CF-only-birthYear split as settings, on the profile doc itself.
// delete stays owner-only.
// ============================================================================

// P1: create profile WITHOUT birthYear -> allowed (owner).
test(
  "profile: owner can create their profile doc WITHOUT birthYear",
  async () => {
    const uid = `prof-create-ok-${RUN}`;
    const ctx = env.authenticatedContext(uid);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${uid}`)
        .set({ uid, displayName: "Anna" })
    );
  }
);

// P2: create profile WITH birthYear from the client -> DENIED.
test(
  "profile: owner CANNOT create their profile doc carrying birthYear",
  async () => {
    const uid = `prof-create-bday-${RUN}`;
    const ctx = env.authenticatedContext(uid);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${uid}`)
        .set({ uid, displayName: "Anna", birthYear: 1990 })
    );
  }
);

// P3: update that CHANGES an existing (CF-set) birthYear -> DENIED.
test(
  "profile: owner CANNOT change birthYear on their profile doc",
  async () => {
    const uid = `prof-upd-chg-${RUN}`;
    await seedDoc(`users/${uid}`, {
      uid,
      displayName: "Anna",
      birthYear: 1990,
    });
    const ctx = env.authenticatedContext(uid);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${uid}`)
        .set({ birthYear: 1991 }, { merge: true })
    );
  }
);

// P4: update OTHER fields while a CF-set birthYear is PRESERVED -> allowed.
test(
  "profile: owner can edit other profile fields while birthYear is preserved",
  async () => {
    const uid = `prof-upd-keep-${RUN}`;
    await seedDoc(`users/${uid}`, {
      uid,
      displayName: "Anna",
      birthYear: 1990,
    });
    const ctx = env.authenticatedContext(uid);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${uid}`)
        .set({ displayName: "Anna B" }, { merge: true })
    );
  }
);

// P5: owner can delete their own profile doc (delete stays owner-only).
test(
  "profile: owner can delete their own profile doc",
  async () => {
    const uid = `prof-del-${RUN}`;
    await seedDoc(`users/${uid}`, { uid, displayName: "Anna", birthYear: 1990 });
    const ctx = env.authenticatedContext(uid);
    await assertSucceeds(ctx.firestore().doc(`users/${uid}`).delete());
  }
);

// P6: a different user cannot create another user's profile doc (isOwner gate).
test(
  "profile: cross-user create of another user's profile doc is denied",
  async () => {
    const targetUid = `prof-victim-${RUN}`;
    const ctx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${targetUid}`)
        .set({ uid: targetUid, displayName: "Mallory" })
    );
  }
);

// ============================================================================
// PROFILE DOC — users/{uid} isMinor immutability (BUT-674)
// (4 assertions across 4 tests)
//
// `isMinor` is server-authoritative — set ONLY by the verifySignupAge Cloud
// Function (Admin SDK bypasses rules). It gates DMs to a minor, so a client that
// could write `isMinor:false` would un-gate itself. Mirrors birthYear's
// create-absent + update-immutable split. The last test proves the protection is
// isMinor-SPECIFIC: a minor may still flip `isSearchable` (the Q1 discovery
// opt-in) while isMinor stays unchanged.
// ============================================================================

// IM1: create profile WITH isMinor from the client -> DENIED (CF-only field).
test(
  "profile: owner CANNOT create their profile doc carrying isMinor",
  async () => {
    const uid = `prof-create-minor-${RUN}`;
    const ctx = env.authenticatedContext(uid);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${uid}`)
        .set({ uid, displayName: "Anna", isMinor: false })
    );
  }
);

// IM2: create profile WITHOUT isMinor -> allowed (owner).
//      Same birthYear-absent condition as P1; proves the isMinor clause does not
//      block a legitimate client-created profile doc.
test(
  "profile: owner can create their profile doc WITHOUT isMinor",
  async () => {
    const uid = `prof-create-nominor-${RUN}`;
    const ctx = env.authenticatedContext(uid);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${uid}`)
        .set({ uid, displayName: "Anna" })
    );
  }
);

// IM3: update that CHANGES an existing (CF-set) isMinor -> DENIED.
//      Seed isMinor:true via withSecurityRulesDisabled, then the client tries to
//      flip it to false (the exact un-gating attack the rule blocks).
test(
  "profile: owner CANNOT change isMinor on their profile doc",
  async () => {
    const uid = `prof-upd-minor-chg-${RUN}`;
    await seedDoc(`users/${uid}`, {
      uid,
      displayName: "Anna",
      isMinor: true,
    });
    const ctx = env.authenticatedContext(uid);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${uid}`)
        .set({ isMinor: false }, { merge: true })
    );
  }
);

// IM4: update OTHER fields (isSearchable) while a CF-set isMinor is PRESERVED
//      -> allowed. Load-bearing: proves the protection is isMinor-specific and
//      does NOT block a minor opting into discovery (Q1 searchable opt-in).
test(
  "profile: minor can toggle isSearchable while isMinor is preserved",
  async () => {
    const uid = `prof-upd-minor-keep-${RUN}`;
    await seedDoc(`users/${uid}`, {
      uid,
      displayName: "Anna",
      isMinor: true,
      isSearchable: false,
    });
    const ctx = env.authenticatedContext(uid);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${uid}`)
        .set({ isSearchable: true }, { merge: true })
    );
  }
);

// ============================================================================
// PUBLIC_PROFILES — BUT-1626 minor searchability hard-deny
// (5 assertions across 5 tests)
//
// A compliant 15–17-year-old (users/{uid}.isMinor:true) must never write a
// searchable public profile from the client. The rule reads users/{uid}.isMinor
// via get() and denies any client create/update that SETS isSearchable:true for
// a minor. Adults are unaffected; a minor's non-searchable writes still pass.
// ============================================================================

function publicProfileBody(
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    displayName: "Anna",
    email: "anna@example.com",
    isSearchable: false,
    ...extra,
  };
}

// PP1: an ADULT can create a searchable public profile.
test("public_profiles: adult can create isSearchable:true", async () => {
  const uid = `pp-adult-${RUN}`;
  const ctx = env.authenticatedContext(uid);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`public_profiles/${uid}`)
      .set(publicProfileBody({ isSearchable: true }))
  );
});

// PP2: a MINOR cannot create a searchable public profile (hard-deny).
test("public_profiles: minor CANNOT create isSearchable:true", async () => {
  const uid = `pp-minor-create-${RUN}`;
  await seedDoc(`users/${uid}`, { uid, isMinor: true });
  const ctx = env.authenticatedContext(uid);
  await assertFails(
    ctx
      .firestore()
      .doc(`public_profiles/${uid}`)
      .set(publicProfileBody({ isSearchable: true }))
  );
});

// PP3: a MINOR CAN create a non-searchable public profile (default-private).
test("public_profiles: minor can create isSearchable:false", async () => {
  const uid = `pp-minor-create-false-${RUN}`;
  await seedDoc(`users/${uid}`, { uid, isMinor: true });
  const ctx = env.authenticatedContext(uid);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`public_profiles/${uid}`)
      .set(publicProfileBody({ isSearchable: false }))
  );
});

// PP4: a MINOR cannot flip an existing profile to searchable via update.
test("public_profiles: minor CANNOT update to isSearchable:true", async () => {
  const uid = `pp-minor-update-${RUN}`;
  await seedDoc(`users/${uid}`, { uid, isMinor: true });
  await seedDoc(`public_profiles/${uid}`, publicProfileBody());
  const ctx = env.authenticatedContext(uid);
  await assertFails(
    ctx
      .firestore()
      .doc(`public_profiles/${uid}`)
      .set({ isSearchable: true }, { merge: true })
  );
});

// PP5: a MINOR can still edit other fields (isSearchable untouched, stays false).
test("public_profiles: minor can edit displayName while non-searchable", async () => {
  const uid = `pp-minor-edit-${RUN}`;
  await seedDoc(`users/${uid}`, { uid, isMinor: true });
  await seedDoc(`public_profiles/${uid}`, publicProfileBody());
  const ctx = env.authenticatedContext(uid);
  await assertSucceeds(
    ctx
      .firestore()
      .doc(`public_profiles/${uid}`)
      .set({ displayName: "Anna B" }, { merge: true })
  );
});

// PP6 (BUT-1629): the deliberate opt-in path. A privileged (Admin-SDK) write
// of isSearchable:true for a minor SURVIVES — that is exactly what the
// `setProfileSearchability` callable does — while the minor's own CLIENT can
// only ever move the flag back to false. This is the pair that proves the
// hard-deny constrains clients only, not the audited server path.
test("public_profiles: server write of minor isSearchable:true survives; client may opt out but not back in", async () => {
  const uid = `pp-minor-optin-${RUN}`;
  await seedDoc(`users/${uid}`, { uid, isMinor: true });
  await seedDoc(`public_profiles/${uid}`, publicProfileBody());

  // The callable's write, modelled by a rules-bypassing (Admin-SDK) context.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`public_profiles/${uid}`)
      .set({ isSearchable: true }, { merge: true });
  });

  // It stuck.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const snap = await ctx.firestore().doc(`public_profiles/${uid}`).get();
    if (snap.data()?.isSearchable !== true) {
      throw new Error(
        "server-written isSearchable:true did not persist for the minor"
      );
    }
  });

  // The client can still opt back OUT — that is the safe direction, and the
  // rule only constrains writes that CHANGE isSearchable to true.
  const clientCtx = env.authenticatedContext(uid);
  await assertSucceeds(
    clientCtx
      .firestore()
      .doc(`public_profiles/${uid}`)
      .set({ isSearchable: false }, { merge: true })
  );

  // But the minor cannot opt themselves back IN from the client — only the
  // callable can. Note the rule is DIFF-gated: it fires on the false->true
  // transition, so a no-op re-write of an already-true value would not be
  // denied (nothing lands in affectedKeys). That is why this assertion has to
  // follow the opt-out above rather than re-writing true on top of true.
  await assertFails(
    clientCtx
      .firestore()
      .doc(`public_profiles/${uid}`)
      .set({ isSearchable: true }, { merge: true })
  );
});

// ============================================================================
// isAgeCompliant() MATRIX on the four UGC create paths
// (12 assertions across 12 tests)
//
// For each collection: ageCompliant:true -> create ALLOWED; no claim -> DENIED;
// ageCompliant:false -> DENIED. messages + social_requests also require
// isAccountMatured(), satisfied with email_verified:true so the age claim is
// the sole variable.
// ============================================================================

// --- recipe_comments ---

// C1: age-compliant AND matured author can create a comment. BUT-1419 added
// isAccountMatured() to the recipe_comments create rule, so the age-only AGE_OK
// context no longer suffices — the happy path needs email_verified (or a
// ≥60-min-old account doc), same as messages/social_requests.
test(
  "recipe_comments: age-compliant matured author can create a comment",
  async () => {
    const ctx = env.authenticatedContext(USER_UID, AGE_OK_MATURED);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`recipe_comments/rc-allow-${RUN}`)
        .set(commentBody(USER_UID))
    );
  }
);

// C2/C3 carry the MATURED presets on purpose. `recipe_comments` create gates on
// `isAgeCompliant()` and, since BUT-1419, `isAccountMatured()`. Neither test used to
// carry a MATURITY claim — C2 passed no claims at all, C3 passed only
// `ageCompliant: false` — so the deny was OVER-DETERMINED. Not an ordering
// story: `isAgeCompliant()` is the EARLIER conjunct here and did fire. But
// `isAccountMatured()` failed as well, so deleting the age gate left the deny
// standing. Measured: with `isAgeCompliant()` removed from that rule, both
// still passed, and the suite reported green over a removed age gate on public
// comments. Satisfying `email_verified` leaves the age claim as the only
// variable, which is the whole point of a deny test. Re-measured after the fix:
// the same deletion now reddens both.
//
// Do not carry this paragraph's wording to the messages block below. These two
// collections gate on the same two helpers in OPPOSITE order — comments read
// age then maturity, messages read membership, then maturity, then age — so a
// sentence about which of THOSE conjuncts denied first is true for one and
// false for the other. That substitution is what an earlier draft of this
// comment got wrong.
//
// C2: NO ageCompliant claim -> comment create DENIED (fails closed).
test(
  "recipe_comments: author without ageCompliant claim cannot create a comment",
  async () => {
    const ctx = env.authenticatedContext(USER_UID, MATURED_ONLY);
    await assertFails(
      ctx
        .firestore()
        .doc(`recipe_comments/rc-noclaim-${RUN}`)
        .set(commentBody(USER_UID))
    );
  }
);

// C3: ageCompliant:false -> comment create DENIED.
test(
  "recipe_comments: author with ageCompliant=false cannot create a comment",
  async () => {
    const ctx = env.authenticatedContext(USER_UID, AGE_FALSE_MATURED);
    await assertFails(
      ctx
        .firestore()
        .doc(`recipe_comments/rc-false-${RUN}`)
        .set(commentBody(USER_UID))
    );
  }
);

// --- messages ---

// Seat the sender in the conversation `messageBody` posts into.
//
// Not optional scaffolding, and not only for the ALLOW case. BUT-1838
// (d627daf25) added
// `request.auth.uid in convOf(conversationId).data.participantIds` to message
// create. Before it, `conversations/conv-1` never had to exist and this suite
// never seeded it; afterwards the rule `get()`s a document that is not there,
// so M1 flipped to DENY. That commit predates the first RED rules run, which is
// 2026-08-15, with no rules run in between — so the commit date and the date
// the suite went red are two different facts, and the commit's own date moves
// by a day between local time and UTC. Cite the sha, not the arithmetic.
//
// M2 and M3 call it too, so each test states its own precondition instead of
// inheriting one. Measured, because the emulator makes this easy to get wrong:
// the seed PERSISTS across tests in a run, so deleting M2's call alone changes
// nothing while M1 runs first and seeds it.
//
// What the seed buys them is non-vacuity, and that was measured too. With the
// seed removed EVERYWHERE and M2 handed a valid `ageCompliant` claim, M2 still
// PASSES — it was being denied on membership before the age gate was ever
// consulted, so it proved nothing about the thing it is named for. With the
// seed in place the same mutation reddens it. M3 behaves the same way.
// The three calls are what keeps that true under REORDERING. M1 seeds first
// today, so M2 and M3 would inherit it — but a reorder, or M1 being deleted,
// would hollow them out silently. Their own calls remove that dependency.
// (Taking the seed out of all three does not hide anything: M1 fails, which
// is the red this commit repairs.)
//
// If you re-run that probe: deleting the three CALLS does not work. tsconfig
// sets `noUnusedLocals`, so ts-node aborts on TS6133 before a single test
// runs, and an exit code read on its own looks exactly like a red assertion.
// Delete the declaration too, or mutate the seeded `participantIds`.
async function seatSenderInConversation(): Promise<void> {
  await seedDoc("conversations/conv-1", { participantIds: [USER_UID] });
}

// M1: age-compliant (and matured) sender can create a message.
test(
  "messages: age-compliant matured sender can create a message",
  async () => {
    await seatSenderInConversation();
    const ctx = env.authenticatedContext(USER_UID, AGE_OK_MATURED);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`messages/msg-allow-${RUN}`)
        .set(messageBody(USER_UID))
    );
  }
);

// M2: matured but NO ageCompliant claim -> message create DENIED.
test(
  "messages: matured sender without ageCompliant claim cannot create a message",
  async () => {
    await seatSenderInConversation();
    const ctx = env.authenticatedContext(USER_UID, MATURED_ONLY);
    await assertFails(
      ctx
        .firestore()
        .doc(`messages/msg-noclaim-${RUN}`)
        .set(messageBody(USER_UID))
    );
  }
);

// M3: matured with ageCompliant:false -> message create DENIED.
test(
  "messages: matured sender with ageCompliant=false cannot create a message",
  async () => {
    await seatSenderInConversation();
    const ctx = env.authenticatedContext(USER_UID, AGE_FALSE_MATURED);
    await assertFails(
      ctx
        .firestore()
        .doc(`messages/msg-false-${RUN}`)
        .set(messageBody(USER_UID))
    );
  }
);

// --- social_requests ---

// SR1: age-compliant (and matured) user can create a friend request.
test(
  "social_requests: age-compliant matured user can create a friend request",
  async () => {
    const ctx = env.authenticatedContext(USER_UID, AGE_OK_MATURED);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`social_requests/sr-allow-${RUN}`)
        .set(socialRequestBody(USER_UID, OTHER_UID))
    );
  }
);

// SR2: matured but NO ageCompliant claim -> friend request DENIED.
test(
  "social_requests: matured user without ageCompliant claim cannot create a request",
  async () => {
    const ctx = env.authenticatedContext(USER_UID, MATURED_ONLY);
    await assertFails(
      ctx
        .firestore()
        .doc(`social_requests/sr-noclaim-${RUN}`)
        .set(socialRequestBody(USER_UID, OTHER_UID))
    );
  }
);

// SR3: matured with ageCompliant:false -> friend request DENIED.
test(
  "social_requests: matured user with ageCompliant=false cannot create a request",
  async () => {
    const ctx = env.authenticatedContext(USER_UID, AGE_FALSE_MATURED);
    await assertFails(
      ctx
        .firestore()
        .doc(`social_requests/sr-false-${RUN}`)
        .set(socialRequestBody(USER_UID, OTHER_UID))
    );
  }
);

// --- recipe_ratings ---

// RR1: age-compliant rater can create a rating.
test(
  "recipe_ratings: age-compliant rater can create a rating",
  async () => {
    const ctx = env.authenticatedContext(USER_UID, AGE_OK);
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`recipe_ratings/recipe-1_${USER_UID}_${RUN}`)
        .set(ratingBody(USER_UID))
    );
  }
);

// RR2: NO ageCompliant claim -> rating create DENIED.
test(
  "recipe_ratings: rater without ageCompliant claim cannot create a rating",
  async () => {
    const ctx = env.authenticatedContext(USER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`recipe_ratings/recipe-1_${USER_UID}_noclaim_${RUN}`)
        .set(ratingBody(USER_UID))
    );
  }
);

// RR3: ageCompliant:false -> rating create DENIED.
test(
  "recipe_ratings: rater with ageCompliant=false cannot create a rating",
  async () => {
    const ctx = env.authenticatedContext(USER_UID, { ageCompliant: false });
    await assertFails(
      ctx
        .firestore()
        .doc(`recipe_ratings/recipe-1_${USER_UID}_false_${RUN}`)
        .set(ratingBody(USER_UID))
    );
  }
);

async function run(): Promise<void> {
  console.log("BUT-1386 (ADR-0002): age-gate rules tests\n");
  console.log("=============================\n");
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
