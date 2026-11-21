/**
 * Firestore rules tests that send a writer's REAL payload.
 *
 *   - `notification_history`: `recordNotification` (create),
 *     `markNotificationDelivered` and `markNotificationOpened` (updates). Its
 *     allowlist drifted on 2026-08-12 (BUT-1482) and was then guarded only by a
 *     text comparison (`rules_allowlist_drift_test.dart`) — which proves an
 *     allowlist's content matches its writer, not that the allowlist is
 *     evaluated.
 *   - `deep_links`: `createShortUrl`'s create, and the BUT-2463 limbs: a get
 *     by code, no list, no update, delete by the creator, no `clicks` access.
 *   - `public_profiles` and `users/{uid}/settings/preferences`: the partial
 *     merges `saveProfile` sends since BUT-2513.
 *
 * The `users/{uid}/counters` writer has its own suite
 * (`shared-content-counters-rules.test.ts`).
 *
 * Each allow case has a deny control that differs from it by exactly one
 * thing, so a deny cannot pass for a second reason: the allowlist is what is
 * being exercised, not an auth or ownership check beside it.
 *
 * Prerequisite: Firestore emulator on 127.0.0.1:8080.
 * Run with: npm run test:rules:writer-payloads
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
import { deleteField, serverTimestamp, Timestamp } from "firebase/firestore";

// MUTATION-PROBE SEAM (same contract as poll-votes-rules.test.ts).
const PROJECT_ID = process.env.PROBE_PROJECT_ID ?? "butlery-rules-writer-payloads";
const RULES_PATH =
  process.env.PROBE_RULES_PATH ??
  path.resolve(__dirname, "../../../firestore.rules");

const UID = "wp-user-uid";
const OTHER_UID = "wp-other-uid";
const NOTIFICATION_ID = "wp-notification";
const LINK_ID = "wp-link";

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

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

const historyDoc = () =>
  env
    .authenticatedContext(UID)
    .firestore()
    .doc(`notification_history/${NOTIFICATION_ID}`);

/** `recordNotification` verbatim: the nine keys it sets, no more. */
function recordedPayload(): Record<string, unknown> {
  return {
    userId: UID,
    notificationId: NOTIFICATION_ID,
    category: "social",
    type: "friendRequest",
    data: { a: "b" },
    sentAt: serverTimestamp(),
    expireAt: Timestamp.fromDate(new Date(Date.now() + 90 * 24 * 3600 * 1000)),
    delivered: false,
    opened: false,
  };
}

async function seedHistory(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`notification_history/${NOTIFICATION_ID}`).set({
      ...recordedPayload(),
      sentAt: Timestamp.now(),
    });
  });
}

test("notification_history: recordNotification's real payload is ALLOWED", async () => {
  await assertSucceeds(historyDoc().set(recordedPayload()));
});

test("notification_history: the same payload plus one unknown key is DENIED", async () => {
  await assertFails(historyDoc().set({ ...recordedPayload(), surprise: 1 }));
});

test("notification_history: markNotificationDelivered's update is ALLOWED", async () => {
  await seedHistory();
  await assertSucceeds(
    historyDoc().update({ delivered: true, deliveredAt: serverTimestamp() })
  );
});

test("notification_history: markNotificationOpened's update is ALLOWED", async () => {
  await seedHistory();
  await assertSucceeds(
    historyDoc().update({ opened: true, openedAt: serverTimestamp() })
  );
});

test("notification_history: the delivered update plus one unknown key is DENIED", async () => {
  await seedHistory();
  await assertFails(
    historyDoc().update({
      delivered: true,
      deliveredAt: serverTimestamp(),
      surprise: 1,
    })
  );
});

const linkDoc = (actor: string) =>
  env.authenticatedContext(actor).firestore().doc(`deep_links/${LINK_ID}`);

/** `createShortUrl`'s `linkData` map verbatim, with the metadata the app passes. */
function shortUrlPayload(createdBy: string): Record<string, unknown> {
  return {
    id: LINK_ID,
    longUrl: `https://butlery.se/recipe/r1?from=${createdBy}&timestamp=1`,
    metadata: { isActive: true, expiresAt: "2026-11-27T10:00:00.000" },
    createdAt: serverTimestamp(),
    createdBy,
    clickCount: 0,
  };
}

async function seedLink(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`deep_links/${LINK_ID}`).set({
      ...shortUrlPayload(UID),
      createdAt: Timestamp.now(),
    });
  });
}

test("deep_links: createShortUrl's real payload is ALLOWED", async () => {
  await assertSucceeds(linkDoc(UID).set(shortUrlPayload(UID)));
});

test("deep_links: the same payload naming SOMEONE ELSE as creator is DENIED", async () => {
  await assertFails(linkDoc(UID).set(shortUrlPayload(OTHER_UID)));
});

test("deep_links: any signed-in account can GET a link by its code", async () => {
  await seedLink();
  await assertSucceeds(linkDoc(OTHER_UID).get());
});

test("deep_links: a signed-out GET is DENIED", async () => {
  await seedLink();
  await assertFails(env.unauthenticatedContext().firestore().doc(`deep_links/${LINK_ID}`).get());
});

test("deep_links: the same account's LIST is DENIED", async () => {
  await seedLink();
  await assertFails(
    env.authenticatedContext(OTHER_UID).firestore().collection("deep_links").get()
  );
});

test("deep_links: a LIST filtered on the caller's own links is DENIED too", async () => {
  await seedLink();
  await assertFails(
    env
      .authenticatedContext(UID)
      .firestore()
      .collection("deep_links")
      .where("createdBy", "==", UID)
      .get()
  );
});

test("deep_links: a stranger's click-counter update is DENIED", async () => {
  await seedLink();
  await assertFails(
    linkDoc(OTHER_UID).update({ clickCount: 1, lastClickedAt: serverTimestamp() })
  );
});

test("deep_links: the creator's own update is DENIED", async () => {
  await seedLink();
  await assertFails(linkDoc(UID).update({ metadata: { isActive: false } }));
});

test("deep_links: the creator can DELETE their link", async () => {
  await seedLink();
  await assertSucceeds(linkDoc(UID).delete());
});

test("deep_links: a stranger's DELETE is DENIED", async () => {
  await seedLink();
  await assertFails(linkDoc(OTHER_UID).delete());
});

const clicksCol = (actor: string) =>
  env
    .authenticatedContext(actor)
    .firestore()
    .collection(`deep_links/${LINK_ID}/clicks`);

test("deep_links clicks: the old trackUrlClick payload is DENIED", async () => {
  await seedLink();
  await assertFails(
    clicksCol(UID).add({ timestamp: serverTimestamp(), userId: UID })
  );
});

test("deep_links clicks: a READ is DENIED, even to the link's creator", async () => {
  await seedLink();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`deep_links/${LINK_ID}/clicks/c1`)
      .set({ timestamp: Timestamp.now(), userId: OTHER_UID });
  });
  await assertFails(clicksCol(UID).get());
  await assertFails(clicksCol(UID).doc("c1").get());
});

// BUT-2513: `FirebaseUserRepository.saveProfile` merge-writes only the keys of
// the fields a save names (`ProfileField.publicPart` / `settingsPart`), plus
// `lastActiveAt` and `schemaVersion` on the profile and the `email` and `bio`
// cleanup deletes. These are the two maps a rename and "klar med
// introduktionen" send.
const profileDoc = (uid = UID) =>
  env.authenticatedContext(uid).firestore().doc(`public_profiles/${uid}`);
const settingsDoc = (uid = UID) =>
  env
    .authenticatedContext(uid)
    .firestore()
    .doc(`users/${uid}/settings/preferences`);

function renamePayload(): Record<string, unknown> {
  return {
    displayName: "Anna Ny",
    displayNameLower: "anna ny",
    lastActiveAt: Timestamp.now(),
    schemaVersion: 1,
    email: deleteField(),
  };
}

function onboardingSettingsPayload(): Record<string, unknown> {
  return { hasCompletedOnboarding: true, bio: deleteField() };
}

async function seedProfile(
  isMinor: boolean,
  isSearchable = !isMinor
): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`users/${UID}`).set({ uid: UID, isMinor });
    await db.doc(`public_profiles/${UID}`).set({
      displayName: "Anna",
      displayNameLower: "anna",
      isSearchable,
      allowEmailSearch: false,
      bio: "Om mig från en annan telefon",
      cookingSkillLevel: "advanced",
      schemaVersion: 1,
    });
    await db.doc(`users/${UID}/settings/preferences`).set({
      allergenPreferences: { trackedAllergens: ["milk"], trackedDietary: [] },
      notificationsEnabled: false,
      isMinor,
    });
  });
}

test("public_profiles: a rename's partial merge is ALLOWED and keeps the other fields", async () => {
  await seedProfile(false);
  await assertSucceeds(profileDoc().set(renamePayload(), { merge: true }));
  const stored = (await profileDoc().get()).data();
  if (stored?.bio !== "Om mig från en annan telefon" ||
      stored?.cookingSkillLevel !== "advanced" ||
      stored?.displayName !== "Anna Ny") {
    throw new Error(`unexpected profile after rename: ${JSON.stringify(stored)}`);
  }
});

test("public_profiles: a minor's rename, which leaves isSearchable out, is ALLOWED", async () => {
  await seedProfile(true);
  await assertSucceeds(profileDoc().set(renamePayload(), { merge: true }));
});

// A rename leaves isSearchable out, so a minor whose stored value is a legacy
// true can rename only because the BUT-1626 check reads the diff.
test("public_profiles: a minor's rename over a stored isSearchable true is ALLOWED", async () => {
  await seedProfile(true, true);
  await assertSucceeds(profileDoc().set(renamePayload(), { merge: true }));
});

test("public_profiles: the same minor rename setting isSearchable true is DENIED", async () => {
  await seedProfile(true);
  await assertFails(
    profileDoc().set({ ...renamePayload(), isSearchable: true }, { merge: true })
  );
});

test("public_profiles: the same rename carrying allergenPreferences is DENIED", async () => {
  await seedProfile(false);
  await assertFails(
    profileDoc().set(
      { ...renamePayload(), allergenPreferences: { trackedAllergens: [] } },
      { merge: true }
    )
  );
});

test("settings: the introduction's partial merge is ALLOWED and keeps the allergens", async () => {
  await seedProfile(true);
  await assertSucceeds(
    settingsDoc().set(onboardingSettingsPayload(), { merge: true })
  );
  const stored = (await settingsDoc().get()).data();
  if (JSON.stringify(stored?.allergenPreferences?.trackedAllergens) !== '["milk"]' ||
      stored?.notificationsEnabled !== false) {
    throw new Error(`unexpected settings after merge: ${JSON.stringify(stored)}`);
  }
});

test("settings: the same merge changing isMinor is DENIED", async () => {
  await seedProfile(true);
  await assertFails(
    settingsDoc().set(
      { ...onboardingSettingsPayload(), isMinor: false },
      { merge: true }
    )
  );
});

async function run(): Promise<void> {
  console.log("writer-payload rules tests (BUT-1823)\n");
  console.log("========================================\n");
  await setup();
  let failed = 0;
  for (const t of tests) {
    await clearFirestore();
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
