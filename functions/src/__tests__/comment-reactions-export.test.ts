/**
 * BUT-2318: `exportCommentReactions` — the Art. 15 export of the requester's
 * own emoji reactions on comments.
 *
 * What this file cannot prove: `_fake-firestore` answers queries without
 * indexes, so the `reactions.<key>` array-contains queries are known to be
 * served in production only because the erasure cascade runs the same shape.
 *
 * Run: npx ts-node src/__tests__/comment-reactions-export.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-comment-reactions" });
}

import { HttpsError } from "firebase-functions/v2/https";
import { FakeFirestore } from "./_fake-firestore";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const reactions = require("../exports/comment-reactions") as typeof import("../exports/comment-reactions");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const cascade = require("../account/account-deletion-cascade") as typeof import("../account/account-deletion-cascade");

const UID = "requester-uid";
const OTHER = "other-uid";

function assertTrue(condition: boolean, msg: string): void {
  if (!condition) throw new Error(msg);
}

/** Records the field each query filters on and what each `select` names. */
interface QuerySpy {
  filters: string[];
  selects: string[][];
  limits: number[];
}

function spied(fake: FakeFirestore): { db: admin.firestore.Firestore; spy: QuerySpy } {
  const spy: QuerySpy = { filters: [], selects: [], limits: [] };
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const wrap = (q: any): any => ({
    where: (field: string, op: string, value: unknown) => {
      spy.filters.push(field);
      return wrap(q.where(field, op, value));
    },
    select: (...fields: string[]) => {
      spy.selects.push(fields);
      return wrap(q.select(...fields));
    },
    limit: (n: number) => {
      spy.limits.push(n);
      return wrap(q.limit(n));
    },
    get: () => q.get(),
  });
  const db = { collection: (name: string) => wrap(fake.db.collection(name)) };
  return { db: db as unknown as admin.firestore.Firestore, spy };
}

function seedComment(db: FakeFirestore, id: string, r: Record<string, string[]>): void {
  db.seed(`recipe_comments/${id}`, {
    recipeId: "recipe-1",
    userId: OTHER,
    text: "Någon annans kommentar",
    reactions: r,
  });
}

async function expectDecline(p: Promise<unknown>): Promise<void> {
  try {
    await p;
  } catch (err) {
    assertTrue(err instanceof HttpsError, `expected HttpsError, got ${String(err)}`);
    const e = err as HttpsError;
    assertEqual(e.code, "failed-precondition", "decline code");
    assertEqual(
      (e.details as { error_code?: string } | undefined)?.error_code,
      reactions.TOO_LARGE_ERROR_CODE,
      "decline error_code",
    );
    assertTrue(!/\d/.test(e.message), "the decline message carries no count");
    return;
  }
  throw new Error("expected a decline, the export succeeded");
}

const cases: UnitCase[] = [
  {
    name: "returns the requester's reactions as {commentId, key} only, sorted",
    fn: async () => {
      const fake = new FakeFirestore();
      seedComment(fake, "c2", { heart: [UID, OTHER], fire: [OTHER] });
      seedComment(fake, "c1", { thumbs_up: [UID], yum: [UID] });
      seedComment(fake, "c3", { laughing: [OTHER] });
      const out = await reactions.runExportCommentReactionsWithDb(fake.db, UID);
      assertEqual(
        JSON.stringify(out.reactions),
        JSON.stringify([
          { commentId: "c1", key: "thumbs_up" },
          { commentId: "c1", key: "yum" },
          { commentId: "c2", key: "heart" },
        ]),
        "own reactions only",
      );
      const json = JSON.stringify(out);
      assertTrue(!json.includes("Någon annans"), "no comment text");
      assertTrue(!json.includes(OTHER), "no other reactor's uid");
      assertTrue(!json.includes("recipe-1"), "no recipe id");
      assertEqual(out.gdprArticle, "Article 15 - Right of Access", "article");
    },
  },
  {
    name: "no reactions gives an empty list, not an error",
    fn: async () => {
      const out = await reactions.runExportCommentReactionsWithDb(new FakeFirestore().db, UID);
      assertEqual(out.reactions.length, 0, "empty");
    },
  },
  {
    name: "queries every key the erasure scrubs, each selecting no field",
    fn: async () => {
      const { db, spy } = spied(new FakeFirestore());
      await reactions.runExportCommentReactionsWithDb(db, UID);
      assertEqual(
        [...spy.filters].sort().join(","),
        cascade.COMMENT_REACTION_KEYS.map((k) => `reactions.${k}`).sort().join(","),
        "one query per COMMENT_REACTION_KEYS entry",
      );
      assertEqual(spy.selects.length, cascade.COMMENT_REACTION_KEYS.length, "select per query");
      assertTrue(
        spy.selects.every((fields) => fields.length === 0),
        "select() names no field, so comment content is never read",
      );
      assertTrue(
        spy.limits.length === cascade.COMMENT_REACTION_KEYS.length &&
          spy.limits.every((n) => n === reactions.MAX_REACTIONS_PER_KEY + 1),
        "every query reads at most cap + 1 rows",
      );
    },
  },
  {
    name: "the cap is the erasure sweep's cap",
    fn: async () => {
      assertEqual(
        reactions.MAX_REACTIONS_PER_KEY,
        cascade.MAX_COMMENT_REACTION_SWEEP_ROWS,
        "per-key cap",
      );
    },
  },
  {
    name: "declines above the cap on one key instead of truncating",
    fn: async () => {
      const fake = new FakeFirestore();
      for (let i = 0; i <= reactions.MAX_REACTIONS_PER_KEY; i++) {
        seedComment(fake, `c${i}`, { heart: [UID] });
      }
      await expectDecline(reactions.runExportCommentReactionsWithDb(fake.db, UID));
    },
  },
  {
    name: "exactly at the cap still answers",
    fn: async () => {
      const fake = new FakeFirestore();
      for (let i = 0; i < reactions.MAX_REACTIONS_PER_KEY; i++) {
        seedComment(fake, `c${i}`, { heart: [UID] });
      }
      const out = await reactions.runExportCommentReactionsWithDb(fake.db, UID);
      assertEqual(out.reactions.length, reactions.MAX_REACTIONS_PER_KEY, "all rows");
    },
  },
  {
    name: "unauthenticated is refused before anything runs",
    fn: async () => {
      const calls: string[] = [];
      try {
        await reactions.handleExportCommentReactions(
          { auth: null },
          {
            rateLimit: async () => void calls.push("rateLimit"),
            run: async () => {
              calls.push("run");
              throw new Error("must not run");
            },
          },
        );
        throw new Error("expected unauthenticated");
      } catch (err) {
        assertTrue(err instanceof HttpsError, `got ${String(err)}`);
        assertEqual((err as HttpsError).code, "unauthenticated", "code");
      }
      assertEqual(calls.join(","), "", "nothing called");
    },
  },
  {
    name: "a forged payload uid is ignored; the rate limit runs first, on its own key",
    fn: async () => {
      const calls: string[] = [];
      const request = { auth: { uid: UID }, data: { uid: OTHER, userId: OTHER } };
      await reactions.handleExportCommentReactions(request, {
        rateLimit: async (uid, op) => void calls.push(`rateLimit:${uid}:${op}`),
        run: async (uid) => {
          calls.push(`run:${uid}`);
          return reactions.runExportCommentReactionsWithDb(new FakeFirestore().db, uid);
        },
      });
      assertEqual(
        calls.join(","),
        `rateLimit:${UID}:exportCommentReactions,run:${UID}`,
        "uid from auth, rate limit before the run",
      );
    },
  },
  {
    name: "a rate-limit refusal stops the export",
    fn: async () => {
      let ran = false;
      try {
        await reactions.handleExportCommentReactions(
          { auth: { uid: UID } },
          {
            rateLimit: async () => {
              throw new HttpsError("resource-exhausted", "slow down");
            },
            run: async () => {
              ran = true;
              return { reactions: [], gdprArticle: "Article 15 - Right of Access" };
            },
          },
        );
        throw new Error("expected resource-exhausted");
      } catch (err) {
        assertEqual((err as HttpsError).code, "resource-exhausted", "code");
      }
      assertTrue(!ran, "run never called");
    },
  },
];

runTests("BUT-2318 exportCommentReactions", cases);
