/**
 * BUT-920: guests (Firebase anonymous sign-in) are refused by the social
 * callables' eligibility gates in `shared/caller-eligibility.ts`.
 *
 * The age refusal and the guest refusal share the `permission-denied` code, so
 * every refusal here is identified by its message: an anonymous caller holding
 * `ageCompliant: true` can only be refused by the guest branch.
 *
 * Run: npx ts-node src/__tests__/caller-eligibility-guest.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import {
  assertNotGuest,
  assertAgeCompliant,
  CallerAuth,
} from "../shared/caller-eligibility";

/**
 * Source with comments removed, so a commented-out call is not counted. Naive
 * about comment markers inside string literals.
 */
function stripComments(src: string): string {
  return src.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/[^\n]*/g, "");
}

function refusal(fn: () => void): { code?: string; message?: string } | null {
  try {
    fn();
    return null;
  } catch (err) {
    return err as { code?: string; message?: string };
  }
}

const anonymousWithClaim: CallerAuth = {
  uid: "guest",
  token: { ageCompliant: true, firebase: { sign_in_provider: "anonymous" } },
};
const passwordWithClaim: CallerAuth = {
  uid: "full",
  token: { ageCompliant: true, firebase: { sign_in_provider: "password" } },
};

const cases: UnitCase[] = [
  {
    name: "assertNotGuest refuses an anonymous token with permission-denied guest-not-allowed",
    fn: () => {
      const e = refusal(() =>
        assertNotGuest({ uid: "g", token: { firebase: { sign_in_provider: "anonymous" } } }),
      );
      assertEqual(e?.code, "permission-denied", "code");
      assertEqual(e?.message, "guest-not-allowed", "message");
    },
  },
  {
    name: "assertAgeCompliant refuses an anonymous token even with ageCompliant:true, via the guest branch",
    fn: () => {
      const e = refusal(() => assertAgeCompliant(anonymousWithClaim));
      assertEqual(e?.code, "permission-denied", "code");
      assertEqual(e?.message, "guest-not-allowed", "message");
    },
  },
  {
    name: "a password-provider token with the claim passes both gates",
    fn: () => {
      assertEqual(refusal(() => assertNotGuest(passwordWithClaim)), null, "assertNotGuest");
      assertEqual(refusal(() => assertAgeCompliant(passwordWithClaim)), null, "assertAgeCompliant");
    },
  },
  {
    name: "assertNotGuest allows a token with no firebase field, and no auth at all",
    fn: () => {
      assertEqual(refusal(() => assertNotGuest({ uid: "u", token: {} })), null, "empty token");
      assertEqual(refusal(() => assertNotGuest({ uid: "u" })), null, "no token");
      assertEqual(refusal(() => assertNotGuest(undefined)), null, "no auth");
    },
  },
  {
    name: "control: a non-guest without the claim is still refused by the AGE branch",
    fn: () => {
      const e = refusal(() =>
        assertAgeCompliant({ uid: "u", token: { firebase: { sign_in_provider: "password" } } }),
      );
      assertEqual(e?.code, "permission-denied", "code");
      assertEqual(
        e?.message,
        "Account is not age-verified for social features.",
        "message",
      );
    },
  },
  {
    // Both callables build a module-level `admin.firestore()` and cannot be
    // imported without an app, so the call site is pinned on source: present,
    // and ahead of the first read of the request payload.
    name: "acceptFriendRequest and acceptGroupInvitation call assertNotGuest before reading request.data",
    fn: () => {
      for (const file of ["accept-friend-request.ts", "accept-group-invitation.ts"]) {
        const src = stripComments(
          fs.readFileSync(path.resolve(__dirname, "..", "social", file), "utf8"),
        );
        const calls = src.split("assertNotGuest(request.auth);").length - 1;
        assertEqual(calls, 1, `${file}: assertNotGuest(request.auth) call count`);
        const at = src.indexOf("assertNotGuest(request.auth);");
        const dataAt = src.indexOf("request.data");
        if (dataAt < 0 || at > dataAt) {
          throw new Error(`${file}: assertNotGuest must run before request.data is read`);
        }
      }
    },
  },
];

runTests("BUT-920 caller eligibility: guests", cases).catch((err) => {
  console.error(err);
  process.exit(1);
});
