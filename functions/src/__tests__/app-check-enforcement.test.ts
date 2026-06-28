/**
 * BUT-760 (server half): CI guard for App Check enforcement on user-facing
 * `onCall` callables.
 *
 * Why a source-scanning guard rather than a runtime test:
 *   `enforceAppCheck` is a deploy-time option baked into the function
 *   definition by the Firebase Functions SDK; there's no public runtime API to
 *   read it back off an exported callable. A grep-style guard over the source
 *   is the cheapest reliable way to keep the policy from silently regressing
 *   when someone adds a new callable.
 *
 * The contract this enforces:
 *   1. Every callable classified USER_FACING must declare
 *      `enforceAppCheck: true`.
 *   2. ADMIN / internal callables are explicitly exempt (admin custom-claim
 *      gated, scheduled-trigger siblings, or one-shot migrations). They are
 *      listed so the exemption is a conscious decision, not an oversight.
 *   3. Any `export const X = onCall(...)` in `functions/src` that is in NEITHER
 *      list fails the guard — forcing whoever adds a new callable to classify
 *      it. This is the "new unflagged user-facing onCall" trip-wire the ticket
 *      asks for.
 *
 * App Check is "Unenforced" in the console today, so the flag is inert (no live
 * blocking) until the mobile-attestation roll-out flips it to Enforce. The
 * guard keeps the server half correct ahead of that flip.
 *
 * Run with: npx ts-node src/__tests__/app-check-enforcement.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";

const SRC_ROOT = path.resolve(__dirname, "..");

/**
 * User-facing callables: reachable from the Flutter/web client by an ordinary
 * authenticated user. These MUST carry `enforceAppCheck: true`.
 */
const USER_FACING: ReadonlySet<string> = new Set([
  "structureRecipe", // llm/structure-recipe.ts — recipe parse/enhance
  "ocrRecipeImage", // llm/ocr-recipe-image.ts — image OCR
  "logWebError", // events/log-web-error.ts — web error reporter
  "logParseEvent", // events/log-parse-event.ts — import telemetry
  "logParseCorrection", // events/log-parse-correction.ts — import telemetry
  "requestAccountDeletion", // account/request-account-deletion.ts
  "exportAuditLogs", // exports/audit-logs.ts — GDPR Article 15 export
  "recordNotificationOpened", // notifications/record-notification-opened.ts
  "sendNotification", // notifications/send-notification.ts
  "sendNotificationBatch", // notifications/send-notification.ts
  "verifySignupAge", // account/verify-signup-age.ts — signup age gate (enforceAppCheck: true)
  "acceptFriendRequest", // social/accept-friend-request.ts — friend accept (enforceAppCheck: true)
]);

/**
 * Admin / internal callables: gated behind an admin custom claim
 * (`requireAdmin` / `token.admin`) or a one-shot migration. Not reachable by
 * ordinary users; App Check would add friction for the admin console / ops
 * scripts without a matching threat reduction. Exempt by design — but listed
 * so the exemption is explicit.
 */
const ADMIN_EXEMPT: ReadonlySet<string> = new Set([
  "bulkMarkForRetagging", // admin/bulk-retag.ts — admin claim
  "getRetagStatus", // admin/bulk-retag.ts — admin claim
  "seedSiteConfigs", // admin/seed-site-configs.ts — admin claim
  "getSiteConfigStats", // admin/seed-site-configs.ts — admin claim
  "getCorrectionStats", // analytics/analyze-corrections.ts — requireAdmin
  "getUnmatchedIngredientStats", // analytics/track-unmatched-ingredients.ts
  "getAuditLogStats", // cleanup/cleanup-audit-logs.ts — requireAdmin
  "getDeletedIngredientStats", // cleanup/cleanup-deleted-ingredients.ts
  "backfillRecipeCommentsDenorm", // migrations/ — one-shot admin migration
]);

interface CallableDecl {
  name: string;
  file: string;
  /** Source slice from `onCall(` to the start of the handler body. */
  optionsSlice: string;
}

/**
 * Recursively collect every `.ts` file under `dir`, skipping the test
 * directory and `node_modules`.
 */
function collectSourceFiles(dir: string): string[] {
  const out: string[] = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === "__tests__" || entry.name === "node_modules") continue;
      out.push(...collectSourceFiles(full));
    } else if (entry.name.endsWith(".ts")) {
      out.push(full);
    }
  }
  return out;
}

/**
 * Extract every `export const NAME = onCall(...)` declaration and the source
 * slice spanning its options object (from `onCall(` up to the first `async`,
 * which begins the handler — options always precede the handler arg).
 */
function extractCallables(source: string, file: string): CallableDecl[] {
  const decls: CallableDecl[] = [];
  const re = /export\s+const\s+(\w+)\s*=\s*onCall\b/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(source)) !== null) {
    const name = m[1];
    const start = m.index;
    // The handler is always an `async (...)`; the options object (if any) is
    // everything between `onCall(` and that `async`. Single-arg form has no
    // `enforceAppCheck` and will (correctly) fail the user-facing check.
    const asyncIdx = source.indexOf("async", start);
    const slice =
      asyncIdx > start ? source.slice(start, asyncIdx) : source.slice(start, start + 200);
    decls.push({ name, file, optionsSlice: slice });
  }
  return decls;
}

function declares(slice: string): boolean {
  // Tolerate whitespace variations: `enforceAppCheck:true`, `: true`, etc.
  return /enforceAppCheck\s*:\s*true/.test(slice);
}

const sourceFiles = collectSourceFiles(SRC_ROOT).filter(
  (f) => !f.includes("rate_limiter") // middleware: docs an example onCall in a comment
);

/**
 * Strip block (`/* *​/`) and line (`//`) comments so a doc-comment example
 * like the one in `rate_limiter.ts` can't be mistaken for a real declaration.
 * Crude but sufficient — we only need it to not match `onCall` inside prose;
 * string literals containing `//` are not a realistic source of false onCall
 * matches.
 */
function stripComments(source: string): string {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/^\s*\/\/.*$/gm, "");
}

const allDecls: CallableDecl[] = [];
for (const file of sourceFiles) {
  const source = stripComments(fs.readFileSync(file, "utf8"));
  allDecls.push(...extractCallables(source, file));
}

const cases: UnitCase[] = [];

// 1. Every user-facing callable carries the flag.
for (const decl of allDecls) {
  if (!USER_FACING.has(decl.name)) continue;
  cases.push({
    name: `user-facing ${decl.name} declares enforceAppCheck: true`,
    fn: () => {
      assertEqual(
        declares(decl.optionsSlice),
        true,
        `${decl.name} (${path.relative(SRC_ROOT, decl.file)}) is user-facing but missing enforceAppCheck: true`
      );
    },
  });
}

// 2. Every discovered callable is classified (the new-onCall trip-wire).
cases.push({
  name: "every onCall callable is classified (user-facing or admin-exempt)",
  fn: () => {
    const unclassified = allDecls
      .filter((d) => !USER_FACING.has(d.name) && !ADMIN_EXEMPT.has(d.name))
      .map((d) => `${d.name} (${path.relative(SRC_ROOT, d.file)})`);
    assertEqual(
      unclassified.length,
      0,
      `Unclassified onCall callable(s) found — add to USER_FACING (with enforceAppCheck: true) or ADMIN_EXEMPT in this guard: ${unclassified.join(", ")}`
    );
  },
});

// 3. Sanity: every name we declared user-facing was actually found in source
//    (catches a rename that would otherwise silently drop a callable from the
//    guard while leaving a stale entry here).
cases.push({
  name: "every USER_FACING entry maps to a real onCall declaration",
  fn: () => {
    const found = new Set(allDecls.map((d) => d.name));
    const missing = [...USER_FACING].filter((n) => !found.has(n));
    assertEqual(
      missing.length,
      0,
      `USER_FACING lists name(s) with no matching onCall in source (renamed/removed?): ${missing.join(", ")}`
    );
  },
});

void runTests("BUT-760 App Check enforcement guard", cases);
