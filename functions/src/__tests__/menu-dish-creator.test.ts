/**
 * BUT-2352: the pure half of the dish-creator check
 * (`moderation/menu-dish-creator.ts`).
 *
 * Run: npx ts-node src/__tests__/menu-dish-creator.test.ts
 */

import { assertEqual, runTests, UnitCase } from "./_unit-runner";
import {
  DishCredit,
  MAX_CREDIT_CHECKS,
  creditKey,
  introducedCredits,
  stripCredits,
} from "../moderation/menu-dish-creator";

const WRITER = "writer";
const dish = (id: unknown, createdBy: unknown, title: unknown, extra: Record<string, unknown> = {}) =>
  ({ id, createdBy, title, ...extra });

const keys = (credits: DishCredit[]) => credits.map(creditKey).sort().join("|");
const key = (dishId: string | null, createdBy: string, title: string | null) =>
  creditKey({ dishId, createdBy, title });

const cases: UnitCase[] = [
  {
    name: "an unchanged menu introduces nothing",
    fn: () => {
      const menu = { Middag: [dish("r1", "alice", "Soppa")] };
      assertEqual(introducedCredits(menu, structuredClone(menu), WRITER).length, 0, "count");
    },
  },
  {
    name: "a dish moved to another category introduces nothing",
    fn: () => {
      const before = { Lunch: [dish("r1", "alice", "Soppa")], Middag: [] };
      const after = { Lunch: [], Middag: [dish("r1", "alice", "Soppa")] };
      assertEqual(introducedCredits(before, after, WRITER).length, 0, "count");
    },
  },
  {
    name: "a second copy of a credit already on the menu is not introduced",
    fn: () => {
      const before = { Middag: [dish("r1", "alice", "Soppa")] };
      const after = { Middag: [dish("r1", "alice", "Soppa")], Lunch: [dish("r1", "alice", "Soppa")] };
      assertEqual(introducedCredits(before, after, WRITER).length, 0, "count");
    },
  },
  {
    name: "two new copies of one credit are one entry",
    fn: () => {
      const after = { Middag: [dish("r1", "alice", "Soppa"), dish("r1", "alice", "Soppa")] };
      assertEqual(introducedCredits({}, after, WRITER).length, 1, "count");
    },
  },
  {
    name: "the writer's own uid is never introduced",
    fn: () => {
      const after = { Middag: [dish("r1", WRITER, "Soppa")] };
      assertEqual(introducedCredits({}, after, WRITER).length, 0, "count");
    },
  },
  {
    name: "a forged uid on an existing dish is introduced",
    fn: () => {
      const before = { Middag: [dish("r1", undefined, "Soppa")] };
      const after = { Middag: [dish("r1", "mallory", "Soppa")] };
      assertEqual(keys(introducedCredits(before, after, WRITER)), key("r1", "mallory", "Soppa"), "keys");
    },
  },
  {
    name: "a retitled credited dish is introduced",
    fn: () => {
      const before = { Middag: [dish("r1", "alice", "Soppa")] };
      const after = { Middag: [dish("r1", "alice", "Annan soppa")] };
      assertEqual(keys(introducedCredits(before, after, WRITER)), key("r1", "alice", "Annan soppa"), "keys");
    },
  },
  {
    name: "a credited dish without an id is introduced with a null id",
    fn: () => {
      const after = { Middag: [dish(undefined, "alice", "Soppa")] };
      assertEqual(keys(introducedCredits({}, after, WRITER)), key(null, "alice", "Soppa"), "keys");
    },
  },
  {
    name: "a create (no before) introduces every other person's credit",
    fn: () => {
      const after = {
        Lunch: [dish("r1", "alice", "Soppa"), dish("r2", WRITER, "Gryta")],
        Middag: [dish("r3", "bob", "Paj"), dish("r4", undefined, "Sallad")],
      };
      assertEqual(
        keys(introducedCredits(undefined, after, WRITER)),
        [key("r1", "alice", "Soppa"), key("r3", "bob", "Paj")].sort().join("|"),
        "keys",
      );
    },
  },
  {
    name: "garbage shapes are ignored, not thrown on",
    fn: () => {
      for (const bad of [null, 42, "x", [], [dish("r1", "alice", "S")], { Middag: "x" }, { Middag: [null, 3, ["a"]] }]) {
        assertEqual(introducedCredits(bad, bad, WRITER).length, 0, `introduced ${JSON.stringify(bad)}`);
        assertEqual(introducedCredits({}, bad, WRITER).length, 0, `create ${JSON.stringify(bad)}`);
        assertEqual(stripCredits(bad, [{ dishId: "r1", createdBy: "alice", title: "S" }]), null, "strip");
      }
      const after = { Middag: [dish("r1", 7, "Soppa"), dish("r2", "", "Soppa"), dish("r3", "alice", 5)] };
      assertEqual(keys(introducedCredits({}, after, WRITER)), key("r3", "alice", null), "non-string fields");
    },
  },
  {
    name: "strip removes only createdBy on dishes carrying the triple",
    fn: () => {
      const menu = {
        Middag: [dish("r1", "mallory", "Soppa", { servings: 4 }), dish("r1", "mallory", "Annan")],
        Lunch: [dish("r2", "alice", "Gryta")],
        Note: "kept",
      };
      const next = stripCredits(menu, [{ dishId: "r1", createdBy: "mallory", title: "Soppa" }]);
      assertEqual(
        JSON.stringify(next),
        JSON.stringify({
          Middag: [{ id: "r1", title: "Soppa", servings: 4 }, dish("r1", "mallory", "Annan")],
          Lunch: [dish("r2", "alice", "Gryta")],
          Note: "kept",
        }),
        "next",
      );
    },
  },
  {
    name: "strip is idempotent",
    fn: () => {
      const offending = [{ dishId: "r1", createdBy: "mallory", title: "Soppa" }];
      const once = stripCredits({ Middag: [dish("r1", "mallory", "Soppa")] }, offending);
      assertEqual(stripCredits(once, offending), null, "second strip");
    },
  },
  {
    name: "strip leaves a dish changed since the write alone",
    fn: () => {
      const offending = [{ dishId: "r1", createdBy: "mallory", title: "Soppa" }];
      const now = { Middag: [dish("r1", "alice", "Soppa"), dish("r1", "mallory", "Ny titel")] };
      assertEqual(stripCredits(now, offending), null, "concurrent change");
    },
  },
  {
    name: "the cap is 40",
    fn: () => {
      assertEqual(MAX_CREDIT_CHECKS, 40, "cap");
      const after = { Middag: Array.from({ length: 45 }, (_, i) => dish(`r${i}`, `u${i}`, "T")) };
      assertEqual(introducedCredits({}, after, WRITER).length, 45, "all introduced; the handler caps");
    },
  },
];

runTests("menu-dish-creator", cases);
