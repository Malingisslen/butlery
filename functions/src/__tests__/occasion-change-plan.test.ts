/**
 * Admin-vy step D: which word-list proposals go into the PR, which conflict
 * with main's file and which are rejected; both written files; and the PR
 * text, which carries list names and words only.
 *
 * Run with: npx ts-node src/__tests__/occasion-change-plan.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import { planOccasionChanges, QueuedOccasionProposal, validateNewWords } from "../admin/occasion-change-plan";
import { buildOccasionPrBody } from "../admin/occasion-pr-body";
import {
  assertReproducible,
  OCCASIONS_PATH,
  parseOccasions,
  readList,
  VOCABULARY_PATH,
} from "../admin/occasion-vocabulary";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const ROOT = path.resolve(__dirname, "../../..");
const JSON_TEXT = fs.readFileSync(path.join(ROOT, OCCASIONS_PATH), "utf-8");
const DART_TEXT = fs.readFileSync(path.join(ROOT, VOCABULARY_PATH), "utf-8");
const MAIN = parseOccasions(JSON_TEXT);
const TITLE = "christmas.titleWords";
const TITLE_NOW = readList(MAIN, TITLE)!;

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

let seq = 0;
function q(listKey: unknown, oldWords: unknown, newWords: unknown, extra: Partial<QueuedOccasionProposal> = {}) {
  seq++;
  return { id: `p${seq}`, listKey, oldWords, newWords, status: "pending", createdAtMs: seq, ...extra } as QueuedOccasionProposal;
}

const cases: UnitCase[] = [
  {
    name: "a proposal whose old words match main is applied to both files",
    fn: () => {
      const p = q(TITLE, TITLE_NOW, [...TITLE_NOW, "skinka"]);
      const plan = planOccasionChanges(JSON_TEXT, DART_TEXT, [p]);
      assertEqual(plan.appliedIds.join(), p.id, "applied");
      const data = assertReproducible(plan.jsonText, plan.dartText);
      assertEqual(JSON.stringify(readList(data, TITLE)), JSON.stringify([...TITLE_NOW, "skinka"]), "json");
      assert(plan.dartText.includes("'skinka'"), "dart holds the word");
      assertEqual(plan.jsonText.split("\n").filter((l, i) => l !== JSON_TEXT.split("\n")[i]).length, 1, "one json line");
    },
  },
  {
    name: "old words that differ from main, also only in order, are a conflict with main's words",
    fn: () => {
      const p = q(TITLE, [...TITLE_NOW].reverse(), ["x"]);
      const plan = planOccasionChanges(JSON_TEXT, DART_TEXT, [p]);
      const o = plan.outcomes.get(p.id)!;
      assertEqual(o.kind, "conflict", "kind");
      assertEqual(JSON.stringify(o.kind === "conflict" && o.current), JSON.stringify(TITLE_NOW), "current");
      assertEqual(plan.jsonText, JSON_TEXT, "file untouched");
      assertEqual(plan.dartText, DART_TEXT, "dart untouched");
    },
  },
  {
    name: "two proposals on one list chain oldest first; the second must start from the first's result",
    fn: () => {
      const a = q(TITLE, TITLE_NOW, ["a"]);
      const b = q(TITLE, ["a"], ["b"]);
      const c = q(TITLE, TITLE_NOW, ["c"]);
      const plan = planOccasionChanges(JSON_TEXT, DART_TEXT, [c, b, a]);
      assertEqual(plan.order.join(), [a.id, b.id, c.id].join(), "oldest first");
      assertEqual(plan.appliedIds.join(), [a.id, b.id].join(), "applied");
      assertEqual(plan.outcomes.get(c.id)!.kind, "conflict", "stale old words");
      assertEqual(JSON.stringify(readList(parseOccasions(plan.jsonText), TITLE)), JSON.stringify(["b"]), "final");
    },
  },
  {
    name: "a proposal whose words main already holds is no-change, even when its old words no longer match",
    fn: () => {
      const p = q(TITLE, ["fel"], TITLE_NOW);
      const o = planOccasionChanges(JSON_TEXT, DART_TEXT, [p]).outcomes.get(p.id)!;
      assert(o.kind === "rejected" && o.reason === "no-change", JSON.stringify(o));
    },
  },
  {
    name: "a list key outside the editable lists is rejected",
    fn: () => {
      for (const key of ["christmas.tag", "christmas.titleStem", "_readme", "nope.words", 7, null]) {
        const p = q(key, ["jul"], ["jul"]);
        const o = planOccasionChanges(JSON_TEXT, DART_TEXT, [p]).outcomes.get(p.id)!;
        assert(o.kind === "rejected" && o.reason === "unknown-list", `${String(key)}: ${JSON.stringify(o)}`);
      }
    },
  },
  {
    name: "a new list the generator or the PR could choke on is rejected, never written",
    fn: () => {
      const bad: Array<[unknown, string]> = [
        [[], "empty-list"],
        ["sill", "wrong-type"],
        [["sill", 7], "wrong-type"],
        [Array.from({ length: 201 }, (_, i) => `o${i}`), "too-many-words"],
        [["a".repeat(61)], "too-long"],
        [["Jul"], "not-lower-case"],
        [["jul", "jul"], "duplicate-word"],
        [["jul\nskinka"], "invalid-word"],
        [[" jul"], "invalid-word"],
        [["jul  skinka"], "invalid-word"],
        [["@malin"], "invalid-word"],
        [["`x`"], "invalid-word"],
        [["[a](b)"], "invalid-word"],
        [["<b>"], "invalid-word"],
        [["a|b"], "invalid-word"],
        [["$x"], "invalid-word"],
        [["a\\b"], "invalid-word"],
        [["=1+1"], "invalid-word"],
        [["jul\u202e"], "invalid-word"],
        [["e\u0301"], "not-normalized"],
      ];
      for (const [words, reason] of bad) {
        assertEqual(validateNewWords(words), reason, JSON.stringify(words));
        const p = q(TITLE, TITLE_NOW, words);
        const plan = planOccasionChanges(JSON_TEXT, DART_TEXT, [p]);
        assertEqual(plan.outcomes.get(p.id)!.kind, "rejected", JSON.stringify(words));
        assertEqual(plan.jsonText, JSON_TEXT, "untouched");
      }
      const notOld = q(TITLE, "jul", ["x"]);
      assertEqual(planOccasionChanges(JSON_TEXT, DART_TEXT, [notOld]).outcomes.get(notOld.id)!.kind, "rejected", "old");
    },
  },
  {
    name: "a word the Dart file cannot lay out rejects only its own proposal",
    fn: () => {
      const bad = q("luxury.ingredients", readList(MAIN, "luxury.ingredients"), ["'".repeat(60)]);
      const good = q(TITLE, TITLE_NOW, [...TITLE_NOW, "skinka"]);
      const plan = planOccasionChanges(JSON_TEXT, DART_TEXT, [bad, good]);
      const o = plan.outcomes.get(bad.id)!;
      assert(o.kind === "rejected" && o.reason === "too-long", JSON.stringify(o));
      assertEqual(plan.appliedIds.join(), good.id, "the other proposal still applies");
    },
  },
  {
    name: "a proposal that leaves the list as main has it is rejected as no-change",
    fn: () => {
      const p = q(TITLE, TITLE_NOW, TITLE_NOW);
      const plan = planOccasionChanges(JSON_TEXT, DART_TEXT, [p]);
      const o = plan.outcomes.get(p.id)!;
      assert(o.kind === "rejected" && o.reason === "no-change", JSON.stringify(o));
      assertEqual(plan.appliedIds.length, 0, "nothing applied");
    },
  },
  {
    name: "a word already in another list may be added: duplicates across lists are kept",
    fn: () => {
      const key = "midsummer.herringIngredients";
      const p = q(key, readList(MAIN, key), ["sill", "lax"]);
      const plan = planOccasionChanges(JSON_TEXT, DART_TEXT, [p]);
      assertEqual(plan.appliedIds.length, 1, "applied");
      assertEqual(JSON.stringify(readList(parseOccasions(plan.jsonText), "easter.herringIngredients")), JSON.stringify(["sill"]), "easter kept");
    },
  },
  {
    name: "the PR text names lists and words only, neutralized, and carries the version checklist",
    fn: () => {
      const a = q(TITLE, TITLE_NOW, [...TITLE_NOW.slice(1), "skinka"]);
      const c = q("lucia.titleWords", ["x"], ["y"]);
      const r = q("christmas.tag", ["x"], ["y"]);
      const plan = planOccasionChanges(JSON_TEXT, DART_TEXT, [a, c, r]);
      const body = buildOccasionPrBody(plan.order.map((id) => plan.outcomes.get(id)!));
      assert(body.includes("- [ ] Höj `kTagGeneratorVersion`"), "checklist");
      assert(body.includes("Tillagda: `skinka`"), "added");
      assert(body.includes(`Borttagna: \`${TITLE_NOW[0]}\``), "removed");
      assert(body.includes("## Konflikter"), "conflict section");
      assert(body.includes("`unknown-list`"), "rejected reason");
      assert(!/uid|createdBy|note/i.test(body), "no identity or note fields");
      const odd = buildOccasionPrBody([{ kind: "apply", listKey: "a`@b", old: [], new: ["@x", "`y`", "[z](w)"] }]);
      assert(!odd.includes("@x") && !odd.includes("[z]") && !/`y`/.test(odd), "neutralized");
    },
  },
];

void runTests("occasion-change-plan (admin-vy D)", cases);
