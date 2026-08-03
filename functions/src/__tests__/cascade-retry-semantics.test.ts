/**
 * BUT-1781 — the two ingredient cascades must actually HAVE the retry
 * semantics their code claims.
 *
 * `on-ingredient-soft-deleted.ts` and `on-ingredient-properties-changed.ts`
 * both end with `throw error; // Re-throw to trigger Cloud Functions retry`,
 * and `with-timeout.ts` documents the 500s guard as producing "a logged error
 * the platform can hand back for a retry". None of that is true on its own:
 * firebase-functions v2 `EventHandlerOptions.retry` is optional and defaults
 * OFF, so without an explicit `retry: true` the throw is logged and DROPPED.
 * The repo already states this at `functions/src/index.ts` and sets it in three
 * other places — these two were the exceptions.
 *
 * Why it matters more here than almost anywhere else: a timeout or transient
 * Firestore error at page N of a collection-group fan-out leaves every
 * remaining recipe carrying a `tagResult` computed from the ingredient's
 * PREVIOUS properties — a silently under-reported ALLERGEN. Nothing recovers it
 * automatically: `cleanupDeletedIngredients` only counts, and
 * `bulkMarkForRetagging` is a manual admin callable capped at 5/day.
 *
 * The retry itself needs a bound: v2 event retries persist for up to 7 DAYS, so
 * a deterministically failing cascade would re-write pages all week. Hence the
 * `isCascadeEventExpired` guard at the top of each handler.
 *
 * WHAT THIS SUITE PROVES: the configuration is present in the deployed source,
 * the two settings stay paired, and the age guard's arithmetic is right. It does
 * not exercise a real retry — that needs the platform.
 *
 * Run: `npm run test:cascade-retry-semantics` (from functions/).
 */

import * as fs from "fs";
import * as path from "path";
import { runTests, UnitCase } from "./_unit-runner";
import {
  isCascadeEventExpired,
  CASCADE_MAX_EVENT_AGE_MS,
  CASCADE_TIMEOUT_MS,
  CASCADE_TIMEOUT_SECONDS,
} from "../shared/with-timeout";

const REPO_ROOT = path.resolve(__dirname, "..", "..", "..");

const CASCADES = [
  "functions/src/ingredients/on-ingredient-soft-deleted.ts",
  "functions/src/ingredients/on-ingredient-properties-changed.ts",
];

/**
 * Source with every comment removed.
 *
 * Non-negotiable here: each of these files EXPLAINS `retry: true` in prose
 * right next to the code that sets it, so a bare `src.includes("retry: true")`
 * stays green after the real setting is deleted. Caught by mutation — the first
 * version of this suite reported 11/11 with `retry: true` removed from
 * on-ingredient-soft-deleted.ts, because the handler's own comment mentions it.
 */
function readCode(relative: string): string {
  return fs
    .readFileSync(path.resolve(REPO_ROOT, relative), "utf8")
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/(^|[^:])\/\/.*$/gm, "$1");
}

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

const cases: UnitCase[] = [];

for (const cascade of CASCADES) {
  const name = path.basename(cascade);

  cases.push({
    name: `${name} declares retry: true`,
    fn: () => {
      const src = readCode(cascade);
      assert(
        /\bretry:\s*true\b/.test(src),
        "no `retry: true` in the options object — v2 event triggers do NOT " +
          "retry by default, so the `throw` at the bottom of this handler is " +
          "logged and dropped and a half-finished allergen cascade is permanent",
      );
    },
  });

  cases.push({
    name: `${name} still declares the paired timeoutSeconds`,
    fn: () => {
      const src = readCode(cascade);
      assert(
        /timeoutSeconds:\s*CASCADE_TIMEOUT_SECONDS/.test(src),
        "no `timeoutSeconds: CASCADE_TIMEOUT_SECONDS` — the handler falls back " +
          "to the 60s v2 event default, which is SHORTER than its own " +
          "CASCADE_TIMEOUT_MS guard, so the guard can never fire and the " +
          "platform kill produces no error for `retry` to act on",
      );
    },
  });

  cases.push({
    name: `${name} bounds the retry window with isCascadeEventExpired`,
    fn: () => {
      const src = readCode(cascade);
      assert(
        /isCascadeEventExpired\(\s*event\.time\s*\)/.test(src),
        "no `isCascadeEventExpired(event.time)` guard — with `retry: true` a " +
          "deterministically failing cascade re-delivers for up to 7 days, " +
          "re-writing 500 recipes a page the whole time",
      );
    },
  });
}

cases.push({
  name: "the guard fires below the declared platform timeout",
  fn: () => {
    assert(
      CASCADE_TIMEOUT_MS < CASCADE_TIMEOUT_SECONDS * 1000,
      `CASCADE_TIMEOUT_MS (${CASCADE_TIMEOUT_MS}) must stay under ` +
        `timeoutSeconds (${CASCADE_TIMEOUT_SECONDS}s) or the platform kills ` +
        "the instance first and there is no error to retry",
    );
  },
});

cases.push({
  name: "a fresh event is not expired",
  fn: () => {
    assert(
      !isCascadeEventExpired(new Date().toISOString()),
      "a just-emitted event was treated as abandoned",
    );
  },
});

cases.push({
  name: "an event older than the window is expired",
  fn: () => {
    const old = new Date(
      Date.now() - CASCADE_MAX_EVENT_AGE_MS - 60_000,
    ).toISOString();
    assert(
      isCascadeEventExpired(old),
      "a day-old redelivery would keep re-writing pages forever",
    );
  },
});

cases.push({
  name: "an event exactly at the boundary is NOT expired",
  fn: () => {
    const boundary = new Date(
      Date.now() - CASCADE_MAX_EVENT_AGE_MS + 5_000,
    ).toISOString();
    assert(
      !isCascadeEventExpired(boundary),
      "the comparison is strictly greater-than; a still-in-window event must run",
    );
  },
});

cases.push({
  name: "an absent or unparseable event.time never abandons the work",
  fn: () => {
    assert(
      !isCascadeEventExpired(undefined),
      "a missing timestamp must fail OPEN — never drop an allergen cascade " +
        "because a clock field could not be read",
    );
    assert(
      !isCascadeEventExpired("not-a-date"),
      "an unparseable timestamp must fail OPEN for the same reason",
    );
  },
});

void runTests("BUT-1781 cascade retry semantics", cases);
