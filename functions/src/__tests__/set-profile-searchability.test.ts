/**
 * BUT-1629 — `setProfileSearchability` DI-core tests.
 *
 * Exercises `setProfileSearchabilityWithDeps(db, callerUid, searchable)`
 * against a hand-rolled fake Firestore (mirrors `verify-signup-age.test.ts` —
 * no emulator, no real Firebase). This callable is the ONLY path by which a
 * minor can become discoverable, so the contract worth pinning is narrow and
 * safety-shaped:
 *
 *   1. Opt-in writes `isSearchable:true` — merged onto the caller's OWN
 *      public_profiles doc and nothing else (never `isMinor`/`birthYear`).
 *   2. Opt-out writes `isSearchable:false` through the same path, so a minor
 *      can always leave as easily as they joined.
 *   3. A missing profile fails closed (`failed-precondition`) and writes
 *      nothing — a merge-set would otherwise mint a nameless half-profile that
 *      people-search would surface.
 *   4. The target is always `callerUid`: no argument can aim the write at
 *      another account.
 *   5. Idempotent — re-running with the same value is a harmless re-write.
 *
 * Run: npx ts-node src/__tests__/set-profile-searchability.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-set-searchability" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  setProfileSearchabilityWithDeps,
} = require("../social/set-profile-searchability");

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { runTests, assertEqual } = require("./_unit-runner");

interface RecordedWrite {
  path: string;
  data: Record<string, unknown>;
  merge: boolean;
}

/**
 * Minimal Firestore double: one collection of docs keyed by path, plus a log of
 * every write so a test can assert both "what landed" and "nothing else did".
 */
function makeFakeDb(existingDocs: Record<string, Record<string, unknown>>) {
  const writes: RecordedWrite[] = [];

  const docRef = (path: string) => ({
    get: async () => ({
      exists: Object.prototype.hasOwnProperty.call(existingDocs, path),
      data: () => existingDocs[path],
    }),
    set: async (
      data: Record<string, unknown>,
      options?: { merge?: boolean }
    ) => {
      writes.push({ path, data, merge: options?.merge === true });
      existingDocs[path] = { ...(existingDocs[path] ?? {}), ...data };
    },
  });

  return {
    writes,
    docs: existingDocs,
    db: {
      collection: (name: string) => ({
        doc: (id: string) => docRef(`${name}/${id}`),
      }),
    } as unknown as admin.firestore.Firestore,
  };
}

const MINOR = "minor-uid";
const OTHER = "someone-else-uid";

function profileDocs(): Record<string, Record<string, unknown>> {
  return {
    [`public_profiles/${MINOR}`]: {
      displayName: "Anna",
      isSearchable: false,
    },
    [`public_profiles/${OTHER}`]: {
      displayName: "Bertil",
      isSearchable: false,
    },
  };
}

void runTests("setProfileSearchability DI core", [
  {
    name: "opt-in merges isSearchable:true onto the caller's own profile",
    fn: async () => {
      const fake = makeFakeDb(profileDocs());
      const result = await setProfileSearchabilityWithDeps(
        fake.db,
        MINOR,
        true
      );

      assertEqual(result.success, true, "success");
      assertEqual(result.searchable, true, "returned value");
      assertEqual(fake.writes.length, 1, "write count");
      assertEqual(fake.writes[0].path, `public_profiles/${MINOR}`, "path");
      assertEqual(fake.writes[0].merge, true, "merge flag");
      assertEqual(fake.writes[0].data.isSearchable, true, "written value");
      // The safety-critical negative: the callable must never touch the
      // server-authoritative age fields, or a client could un-gate itself.
      assertEqual(
        "isMinor" in fake.writes[0].data,
        false,
        "isMinor must not be written"
      );
      assertEqual(
        "birthYear" in fake.writes[0].data,
        false,
        "birthYear must not be written"
      );
    },
  },
  {
    name: "opt-out writes isSearchable:false through the same path",
    fn: async () => {
      const docs = profileDocs();
      docs[`public_profiles/${MINOR}`].isSearchable = true;
      const fake = makeFakeDb(docs);

      const result = await setProfileSearchabilityWithDeps(
        fake.db,
        MINOR,
        false
      );

      assertEqual(result.searchable, false, "returned value");
      assertEqual(fake.writes.length, 1, "write count");
      assertEqual(fake.writes[0].data.isSearchable, false, "written value");
    },
  },
  {
    name: "a missing profile fails closed and writes nothing",
    fn: async () => {
      const fake = makeFakeDb({});
      let code = "";
      try {
        await setProfileSearchabilityWithDeps(fake.db, MINOR, true);
      } catch (e) {
        code = (e as { code?: string }).code ?? "";
      }
      assertEqual(
        code.includes("failed-precondition"),
        true,
        `expected failed-precondition, got "${code}"`
      );
      assertEqual(fake.writes.length, 0, "no write on the failure path");
    },
  },
  {
    name: "never writes another user's profile",
    fn: async () => {
      const fake = makeFakeDb(profileDocs());
      await setProfileSearchabilityWithDeps(fake.db, MINOR, true);

      assertEqual(
        fake.writes.some((w) => w.path.includes(OTHER)),
        false,
        "no write outside the caller's own doc"
      );
      assertEqual(
        fake.docs[`public_profiles/${OTHER}`].isSearchable,
        false,
        "the other user's searchability is untouched"
      );
    },
  },
  {
    name: "idempotent — re-running with the same value converges",
    fn: async () => {
      const fake = makeFakeDb(profileDocs());
      await setProfileSearchabilityWithDeps(fake.db, MINOR, true);
      const second = await setProfileSearchabilityWithDeps(
        fake.db,
        MINOR,
        true
      );

      assertEqual(second.searchable, true, "second call result");
      assertEqual(
        fake.docs[`public_profiles/${MINOR}`].isSearchable,
        true,
        "stored value after re-run"
      );
    },
  },
]);
