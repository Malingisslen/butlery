/**
 * BUT-2316 one-time backfill: give accounts that predate BUT-1386 the
 * `ageCompliant` custom claim, from the birth year they already stored.
 *
 * Why: `firestore.rules` gates friend requests, comments, ratings and chat on
 * `isAgeCompliant()`, and only `verifySignupAge` sets that claim. It runs in
 * onboarding, so an account that finished onboarding before the age question
 * existed has no claim and every one of those writes is refused.
 *
 * Malin's call (2026-10-09, decision card on BUT-2316): grant the claim from
 * the birth year the old client stored, rather than asking those accounts
 * again. That year was written by the client, which is what ADR-0002 stopped
 * trusting; the audit row records that it came from this backfill.
 *
 * Only an adult year (18+) is granted. A stored year that makes the account a
 * minor, under 15, two locations that disagree, or no stored year at all is
 * left untouched and counted: a minor also needs `isMinor` and search
 * suppression, which onboarding applies and this script does not.
 *
 * An account with no stored year can be given one in DECLARED_BIRTH_YEARS as
 * `emailprefix:year` pairs, each prefix matching exactly one account. Malin's
 * call (2026-10-09, second decision card on BUT-2316) for the two accounts
 * that existed and had no stored year; the audit row says the year was
 * declared.
 *
 * Prints counts only, never a uid or an email. Dry run unless `--apply`.
 * Idempotent: an account that already carries the claim is skipped.
 *
 * Usage (from functions/):
 *   GOOGLE_APPLICATION_CREDENTIALS=<service-account.json> \
 *     DECLARED_BIRTH_YEARS="prefix:1980" node scripts/backfill-age-claim.js [--apply]
 */

const crypto = require("crypto");

const MIN_AGE_YEARS = 15;
const AGE_OF_MAJORITY_YEARS = 18;
const MIN_PLAUSIBLE_BIRTH_YEAR = 1900;

// Same derivation as functions/src/shared/hash-uid.ts, so the audit row lands
// on the id `verifySignupAge` would use for this account.
function hashUid(uid) {
  return crypto.createHash("sha256").update(uid).digest("hex").substring(0, 12);
}

function parseYear(value) {
  if (typeof value === "number" && Number.isInteger(value)) return value;
  if (typeof value === "string" && /^\d{4}$/.test(value.trim())) {
    return Number(value.trim());
  }
  return null;
}

/**
 * Decides one account from every birth year known for it: the two places the
 * old client stored one, plus a declared year when one was given. Returns
 * `{ outcome, birthYear? }`; only `grant` carries a year.
 */
function classify(years, currentYear) {
  const present = years.filter(
    (v) => v !== undefined && v !== null,
  );
  if (present.length === 0) return { outcome: "noStoredYear" };

  const parsed = present.map(parseYear);
  if (parsed.some((y) => y === null)) return { outcome: "invalidYear" };
  if (new Set(parsed).size > 1) return { outcome: "conflictingYears" };

  const birthYear = parsed[0];
  if (birthYear < MIN_PLAUSIBLE_BIRTH_YEAR || birthYear > currentYear) {
    return { outcome: "invalidYear" };
  }
  const age = currentYear - birthYear;
  if (age < MIN_AGE_YEARS) return { outcome: "under15" };
  if (age < AGE_OF_MAJORITY_YEARS) return { outcome: "minor" };
  return { outcome: "grant", birthYear };
}

async function grant(deps, user, birthYear, source) {
  const { auth, db, serverTimestamp } = deps;
  await Promise.all([
    db.doc(`users/${user.uid}`).set({ birthYear, isMinor: false }, { merge: true }),
    db
      .doc(`users/${user.uid}/settings/preferences`)
      .set({ birthYear, isMinor: false }, { merge: true }),
  ]);
  await db
    .collection("audit_logs")
    .doc(`consent_age_verification_${hashUid(user.uid)}`)
    .set(
      {
        operation: "consent_age_verification",
        userIdHash: hashUid(user.uid),
        isAgeCompliant: true,
        birthDecade: `${Math.floor(birthYear / 10) * 10}s`,
        source,
        timestamp: serverTimestamp(),
      },
      { merge: true },
    );
  // The claim is the marker a rerun skips on, so it is written last: a run
  // that stops partway leaves the account unmarked and the next run redoes it.
  // Claims are re-read here because the page may be minutes old.
  const fresh = await auth.getUser(user.uid);
  if (fresh.customClaims && fresh.customClaims.ageCompliant === true) return;
  await auth.setCustomUserClaims(user.uid, {
    ...(fresh.customClaims || {}),
    ageCompliant: true,
  });
}

/**
 * Walks every Auth account. `deps` is `{ auth, db, serverTimestamp }` with the
 * Admin SDK's shapes, injected so the test can run it over fakes.
 */
async function runBackfill(deps, { apply, currentYear, declared = {} }) {
  const declaredKeys = Object.keys(declared);
  const counts = {
    total: 0,
    alreadyCompliant: 0,
    grant: 0,
    minor: 0,
    under15: 0,
    noStoredYear: 0,
    conflictingYears: 0,
    invalidYear: 0,
    failed: 0,
    declaredUsed: 0,
  };

  // A declared year is matched by email prefix; refuse before any write if a
  // prefix matches no account or more than one.
  if (declaredKeys.length > 0) {
    const matches = Object.fromEntries(declaredKeys.map((k) => [k, 0]));
    let token;
    do {
      const page = await deps.auth.listUsers(1000, token);
      for (const u of page.users) {
        for (const k of declaredKeys) {
          if ((u.email || "").startsWith(k)) matches[k]++;
        }
      }
      token = page.pageToken;
    } while (token);
    const bad = declaredKeys.filter((k) => matches[k] !== 1);
    if (bad.length > 0) {
      throw Object.assign(
        new Error("declared prefix must match exactly one account"),
        { code: "DECLARED_PREFIX_MISMATCH" },
      );
    }
  }

  let pageToken;
  do {
    const page = await deps.auth.listUsers(1000, pageToken);
    for (const user of page.users) {
      counts.total++;
      if (user.customClaims && user.customClaims.ageCompliant === true) {
        counts.alreadyCompliant++;
        continue;
      }
      const [profile, preferences] = await deps.db.getAll(
        deps.db.doc(`users/${user.uid}`),
        deps.db.doc(`users/${user.uid}/settings/preferences`),
      );
      const keys = declaredKeys.filter((k) => (user.email || "").startsWith(k));
      const years = [
        profile.exists ? profile.get("birthYear") : undefined,
        preferences.exists ? preferences.get("birthYear") : undefined,
      ];
      // A declared year is one more location: it fills a gap, and disagreeing
      // with a stored year is a conflict like any other.
      for (const k of keys) years.push(declared[k]);
      const { outcome, birthYear } = classify(years, currentYear);
      if (keys.length > 0) counts.declaredUsed++;
      if (outcome !== "grant" || !apply) {
        counts[outcome]++;
        continue;
      }
      try {
        await grant(
          deps,
          user,
          birthYear,
          keys.length === 0
            ? "backfill_stored_birth_year"
            : "backfill_declared_birth_year",
        );
        counts.grant++;
      } catch (err) {
        counts.failed++;
        console.error(`grant failed for ${hashUid(user.uid)}: ${err.code || err.name}`);
      }
    }
    pageToken = page.pageToken;
  } while (pageToken);

  return counts;
}

/** `"prefix:1980,other:1990"` → `{ prefix: 1980, other: 1990 }`. */
function parseDeclared(text) {
  const out = {};
  for (const pair of text.split(",").map((p) => p.trim()).filter(Boolean)) {
    const i = pair.lastIndexOf(":");
    const key = pair.slice(0, i).trim();
    const year = parseYear(pair.slice(i + 1));
    if (i < 1 || !key || year === null) {
      throw Object.assign(
        new Error("DECLARED_BIRTH_YEARS must be prefix:year pairs"),
        { code: "DECLARED_FORMAT" },
      );
    }
    out[key] = year;
  }
  return out;
}

async function main() {
  const admin = require("firebase-admin");
  admin.initializeApp();
  const apply = process.argv.includes("--apply");
  const declared = parseDeclared(process.env.DECLARED_BIRTH_YEARS || "");
  const counts = await runBackfill(
    {
      auth: admin.auth(),
      db: admin.firestore(),
      serverTimestamp: () => admin.firestore.FieldValue.serverTimestamp(),
    },
    { apply, currentYear: new Date().getFullYear(), declared },
  );
  console.log(apply ? "Mode: apply" : "Mode: dry run (no writes)");
  for (const [key, value] of Object.entries(counts)) {
    console.log(`${key}=${value}`);
  }
  if (counts.failed > 0) process.exit(1);
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err.code || err.name || "unknown");
    process.exit(1);
  });
}

module.exports = { classify, runBackfill, hashUid, parseDeclared };
