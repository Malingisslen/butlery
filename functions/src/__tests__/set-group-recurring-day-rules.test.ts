/**
 * BUT-2490: `setGroupRecurringDayRulesWithDeps`, the core of the callable a
 * group admin saves the group's recurring-day rules through.
 *
 * Every assertion reads the STORE (`_fake-firestore.ts` applies writes), so
 * "nothing written" and "only this field changed" are facts about the
 * document, not about a recorded payload.
 *
 * Run with: npx ts-node src/__tests__/set-group-recurring-day-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import { Timestamp } from "firebase-admin/firestore";
import { getApps, initializeApp } from "firebase-admin/app";
import { runTests, assertEqual, UnitCase } from "./_unit-runner";
import { FakeFirestore } from "./_fake-firestore";
import { setGroupRecurringDayRulesWithDeps } from "../groups/set-group-recurring-day-rules";
import { MAX_RECURRING_DAY_RULES } from "../groups/recurring-day-rules";
import { RATE_LIMIT_CONFIGS } from "../middleware/rate_limiter";

if (!getApps().length) {
  initializeApp({ projectId: "butlery-test-set-group-recurring-day-rules" });
}

const EARLIER = Timestamp.fromMillis(1_500_000_000_000);

function seedGroup(fake: FakeFirestore, id: string, members: string[], admins: string[]): void {
  fake.seed(`chat_groups/${id}`, {
    name: "Familjen",
    memberIds: members,
    adminIds: admins,
    memberAddedBy: Object.fromEntries(members.map((u) => [u, members[0]])),
    conversationId: `c-${id}`,
    createdBy: members[0],
    createdAt: EARLIER,
    updatedAt: EARLIER,
  });
}

function fixture(): FakeFirestore {
  const fake = new FakeFirestore();
  seedGroup(fake, "g1", ["admin", "member"], ["admin"]);
  seedGroup(fake, "g2", ["other", "admin2"], ["other", "admin2"]);
  return fake;
}

const allowRateLimit = { rateLimit: async () => undefined };

/** A canonical row, as `RecurringDayRule.toFirestore` writes it. */
function row(
  weekday: number,
  meal: string,
  kind: string,
  value: string,
  extra: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    id: `${weekday}-${meal}`,
    weekday,
    meal,
    kind,
    value,
    quick: kind === "quick",
    paused: false,
    ...extra,
  };
}

const FISH_MONDAY = row(1, "middag", "proteinCategory", "fish");
const TACO_FRIDAY = row(5, "middag", "tag", "taco");

async function captureError(
  fn: () => Promise<unknown>,
): Promise<{ code: string; reason: unknown }> {
  try {
    await fn();
    return { code: "(no error thrown)", reason: undefined };
  } catch (e) {
    const err = e as { code?: string; details?: { reason?: unknown } };
    return { code: err.code ?? String(e), reason: err.details?.reason };
  }
}

async function capture(fn: () => Promise<unknown>): Promise<string> {
  return (await captureError(fn)).code;
}

function stored(fake: FakeFirestore, id = "g1"): unknown {
  return fake.read(`chat_groups/${id}`)?.recurringDayRules;
}

function save(
  fake: FakeFirestore,
  caller: string | undefined,
  data: unknown,
): Promise<unknown> {
  return setGroupRecurringDayRulesWithDeps(fake.db, caller, data, allowRateLimit);
}

/** Every refusal must leave the store exactly as seeded. */
async function expectRefused(
  data: unknown,
  code: string,
  caller: string | undefined = "admin",
  reason?: string,
): Promise<void> {
  const fake = fixture();
  const before = JSON.stringify([...fake.docs.entries()]);
  const err = await captureError(() => save(fake, caller, data));
  assertEqual(err.code, code, "error code");
  if (reason !== undefined) assertEqual(err.reason, reason, "refusal reason");
  assertEqual(fake.writes.length, 0, "no write applied");
  assertEqual(JSON.stringify([...fake.docs.entries()]), before, "store unchanged");
}

function fullWeek(): Record<string, unknown>[] {
  const rows: Record<string, unknown>[] = [];
  for (let day = 1; day <= 7; day++) {
    rows.push(row(day, "lunch", "tag", "soppa"));
    rows.push(row(day, "middag", "quick", ""));
  }
  return rows;
}

const cases: UnitCase[] = [
  {
    name: "an admin saves two rows; the stored rows equal the canonical rows",
    fn: async () => {
      const fake = fixture();
      await save(fake, "admin", { groupId: "g1", rules: [FISH_MONDAY, TACO_FRIDAY] });
      assertEqual(
        JSON.stringify(stored(fake)),
        JSON.stringify([FISH_MONDAY, TACO_FRIDAY]),
        "stored rules",
      );
    },
  },
  {
    // The stored row is rebuilt from the checked fields, never the raw input.
    // Absent flags are written as false, and the key order is the server's.
    name: "the stored row is the rebuild, not the request's object",
    fn: async () => {
      const fake = fixture();
      const sparse = {
        paused: false,
        value: "fish",
        kind: "proteinCategory",
        meal: "middag",
        weekday: 1,
        id: "1-middag",
      };
      await save(fake, "admin", { groupId: "g1", rules: [sparse] });
      assertEqual(
        JSON.stringify(stored(fake)),
        JSON.stringify([FISH_MONDAY]),
        "stored as the canonical seven keys",
      );
    },
  },
  {
    name: "an empty list is saved (the admin removed every rule)",
    fn: async () => {
      const fake = fixture();
      fake.seed("chat_groups/g1", { ...fake.read("chat_groups/g1"), recurringDayRules: [FISH_MONDAY] });
      await save(fake, "admin", { groupId: "g1", rules: [] });
      assertEqual(JSON.stringify(stored(fake)), "[]", "stored rules");
    },
  },
  {
    name: "fourteen rows are saved",
    fn: async () => {
      const fake = fixture();
      const rules = fullWeek();
      assertEqual(rules.length, MAX_RECURRING_DAY_RULES, "premise: a full week");
      assertEqual(MAX_RECURRING_DAY_RULES, 14, "the bound is 14");
      await save(fake, "admin", { groupId: "g1", rules });
      assertEqual((stored(fake) as unknown[]).length, 14, "stored count");
    },
  },
  {
    name: "fifteen rows are refused by the count",
    fn: async () => {
      // Fourteen ids exist, so a fifteenth row always repeats one and the
      // duplicate check would refuse it too. The reason is asserted so the
      // count check itself is what this case measures.
      const rules = [...fullWeek(), row(1, "middag", "tag", "taco")];
      await expectRefused({ groupId: "g1", rules }, "invalid-argument", "admin", "too many rules");
    },
  },
  {
    name: "only recurringDayRules changes on the group document",
    fn: async () => {
      const fake = fixture();
      const before = fake.read("chat_groups/g1") ?? {};
      await save(fake, "admin", { groupId: "g1", rules: [TACO_FRIDAY] });
      const after = fake.read("chat_groups/g1") ?? {};
      const changed = [...new Set([...Object.keys(before), ...Object.keys(after)])]
        .filter((k) => JSON.stringify(before[k]) !== JSON.stringify(after[k]))
        .sort();
      assertEqual(JSON.stringify(changed), JSON.stringify(["recurringDayRules"]), "changed keys");
      assertEqual(fake.writes.length, 1, "one write");
      assertEqual(fake.writes[0].path, "chat_groups/g1", "the group document only");
      assertEqual(
        JSON.stringify(Object.keys(fake.writes[0].data ?? {})),
        JSON.stringify(["recurringDayRules"]),
        "the update names one field (no updatedAt)",
      );
      assertEqual(stored(fake, "g2"), undefined, "the other group is untouched");
    },
  },

  // --- who may save: one indistinguishable refusal ------------------------
  {
    name: "an ordinary member is refused",
    fn: () => expectRefused({ groupId: "g1", rules: [FISH_MONDAY] }, "permission-denied", "member"),
  },
  {
    name: "a non-member is refused",
    fn: () => expectRefused({ groupId: "g1", rules: [FISH_MONDAY] }, "permission-denied", "stranger"),
  },
  {
    name: "an admin of ANOTHER group is refused",
    fn: () => expectRefused({ groupId: "g1", rules: [FISH_MONDAY] }, "permission-denied", "admin2"),
  },
  {
    name: "a missing group is refused with the same code",
    fn: () => expectRefused({ groupId: "nope", rules: [FISH_MONDAY] }, "permission-denied", "admin"),
  },
  {
    // An id left in adminIds after its owner left the member list.
    name: "an admin id that is no longer a member is refused",
    fn: async () => {
      const fake = new FakeFirestore();
      seedGroup(fake, "g1", ["member"], ["gone"]);
      assertEqual(
        await capture(() => save(fake, "gone", { groupId: "g1", rules: [FISH_MONDAY] })),
        "permission-denied",
        "error code",
      );
      assertEqual(fake.writes.length, 0, "no write applied");
    },
  },
  {
    name: "a signed-out caller is refused before the rate limit",
    fn: async () => {
      const fake = fixture();
      let spent = 0;
      const err = await capture(() =>
        setGroupRecurringDayRulesWithDeps(
          fake.db,
          undefined,
          { groupId: "g1", rules: [] },
          { rateLimit: async () => void spent++ },
        ),
      );
      assertEqual(err, "unauthenticated", "error code");
      assertEqual(spent, 0, "no bucket spent");
      assertEqual(fake.writes.length, 0, "no write applied");
    },
  },
  {
    name: "a refused rate limit stops the call",
    fn: async () => {
      const fake = fixture();
      const err = await capture(() =>
        setGroupRecurringDayRulesWithDeps(
          fake.db,
          "admin",
          { groupId: "g1", rules: [FISH_MONDAY] },
          {
            rateLimit: async () => {
              throw Object.assign(new Error("limited"), { code: "resource-exhausted" });
            },
          },
        ),
      );
      assertEqual(err, "resource-exhausted", "error code");
      assertEqual(stored(fake), undefined, "nothing stored");
    },
  },
  {
    name: "a malformed groupId is refused",
    fn: async () => {
      for (const groupId of ["", "a/b", 42, undefined]) {
        await expectRefused({ groupId, rules: [] }, "invalid-argument");
      }
    },
  },
  {
    name: "no request body at all is refused",
    fn: () => expectRefused(undefined, "invalid-argument"),
  },

  // --- row validation -------------------------------------------------------
  {
    name: "rules that are not a list are refused",
    fn: async () => {
      for (const rules of [undefined, null, "[]", { 0: FISH_MONDAY }]) {
        await expectRefused({ groupId: "g1", rules }, "invalid-argument", "admin", "not a list");
      }
    },
  },
  {
    name: "a row that is not a plain object is refused",
    fn: async () => {
      for (const bad of [null, "1-middag", 3, [FISH_MONDAY]]) {
        await expectRefused({ groupId: "g1", rules: [bad] }, "invalid-argument", "admin", "row 0: not an object");
      }
    },
  },
  {
    name: "an extra key is refused (author, uid, timestamp or anything else)",
    fn: async () => {
      for (const key of ["createdBy", "uid", "updatedAt", "note"]) {
        await expectRefused(
          { groupId: "g1", rules: [{ ...FISH_MONDAY, [key]: "x" }] },
          "invalid-argument",
          "admin",
          "row 0: unknown key",
        );
      }
    },
  },
  {
    name: "weekday 0, 8, 1.5 and '1' are refused",
    fn: async () => {
      for (const weekday of [0, 8, 1.5, "1"]) {
        await expectRefused(
          { groupId: "g1", rules: [{ ...FISH_MONDAY, weekday, id: `${weekday}-middag` }] },
          "invalid-argument",
          "admin",
          "row 0: weekday",
        );
      }
    },
  },
  {
    name: "meal 'ovrigt' is refused",
    fn: () =>
      expectRefused(
        { groupId: "g1", rules: [row(1, "ovrigt", "proteinCategory", "fish")] },
        "invalid-argument",
        "admin",
        "row 0: meal",
      ),
  },
  {
    name: "an unknown kind is refused",
    fn: () =>
      expectRefused(
        { groupId: "g1", rules: [row(1, "middag", "ingredient", "fish")] },
        "invalid-argument",
        "admin",
        "row 0: kind",
      ),
  },
  {
    name: "a value outside the table, or under the wrong kind, is refused",
    fn: async () => {
      for (const [kind, value] of [
        ["tag", "pizza"],
        ["tag", "fish"],
        ["proteinCategory", "taco"],
        ["dietary", "poultry"],
        ["tag", ""],
      ]) {
        await expectRefused(
          { groupId: "g1", rules: [row(1, "middag", kind, value)] },
          "invalid-argument",
          "admin",
          "row 0: value",
        );
      }
    },
  },
  {
    name: "a quick rule with a value, or without quick: true, is refused",
    fn: async () => {
      await expectRefused(
        { groupId: "g1", rules: [row(1, "middag", "quick", "fish")] },
        "invalid-argument",
        "admin",
        "row 0: quick rule",
      );
      await expectRefused(
        { groupId: "g1", rules: [row(1, "middag", "quick", "", { quick: false })] },
        "invalid-argument",
        "admin",
        "row 0: quick rule",
      );
    },
  },
  {
    name: "a non-boolean paused or quick is refused",
    fn: async () => {
      await expectRefused(
        { groupId: "g1", rules: [{ ...FISH_MONDAY, paused: "false" }] },
        "invalid-argument",
        "admin",
        "row 0: flag",
      );
      await expectRefused(
        { groupId: "g1", rules: [{ ...FISH_MONDAY, quick: 1 }] },
        "invalid-argument",
        "admin",
        "row 0: flag",
      );
    },
  },
  {
    name: "an id that does not match weekday and meal is refused",
    fn: async () => {
      for (const id of ["2-middag", "1-lunch", "fish", undefined]) {
        await expectRefused(
          { groupId: "g1", rules: [{ ...FISH_MONDAY, id }] },
          "invalid-argument",
          "admin",
          "row 0: id",
        );
      }
    },
  },
  {
    name: "a duplicate id is refused",
    fn: () =>
      expectRefused(
        { groupId: "g1", rules: [FISH_MONDAY, row(1, "middag", "tag", "taco")] },
        "invalid-argument",
        "admin",
        "row 1: duplicate id",
      ),
  },
  {
    name: "a 10 kB value string is refused",
    fn: () =>
      expectRefused(
        { groupId: "g1", rules: [row(1, "middag", "tag", "x".repeat(10_000))] },
        "invalid-argument",
        "admin",
        "row 0: value",
      ),
  },
  {
    name: "a paused food rule and a quick food rule are accepted as stored",
    fn: async () => {
      const fake = fixture();
      const rules = [
        row(2, "lunch", "dietary", "vegetarisk", { paused: true }),
        row(3, "middag", "tag", "pasta-dish", { quick: true }),
      ];
      await save(fake, "admin", { groupId: "g1", rules });
      assertEqual(JSON.stringify(stored(fake)), JSON.stringify(rules), "stored rules");
    },
  },

  {
    name: "the callable spends its own rate-limit bucket",
    fn: () => {
      const src = fs.readFileSync(
        path.join(__dirname, "../groups/set-group-recurring-day-rules.ts"),
        "utf8",
      );
      assertEqual(
        /enforceRateLimit\(uid, "setGroupRecurringDayRules"\)/.test(src),
        true,
        "literal key",
      );
    },
  },
  {
    name: "RATE_LIMIT_CONFIGS defines a setGroupRecurringDayRules bucket",
    fn: () => {
      const cfg = RATE_LIMIT_CONFIGS.setGroupRecurringDayRules;
      assertEqual(typeof cfg?.maxTokens, "number", "maxTokens");
      assertEqual(typeof cfg?.refillRate, "number", "refillRate");
    },
  },
];

void runTests("setGroupRecurringDayRules — BUT-2490", cases);
