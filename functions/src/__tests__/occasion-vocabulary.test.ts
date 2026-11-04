/**
 * Admin-vy step D: the server's writers for `occasions.json` and the
 * generated `occasion_vocabulary.g.dart`. Both must reproduce the committed
 * files byte for byte, the editable list keys must be exactly the file's
 * lists (and the same in firestore.rules), and a layout the writers do not
 * know must stop them. When `dart` is on PATH the TS port is also compared
 * with the real generator (`tools/gen_tag_vocabulary.dart` + `dart format`).
 *
 * Run with: npx ts-node src/__tests__/occasion-vocabulary.test.ts
 */

import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { execFileSync } from "child_process";
import {
  assertReproducible,
  OCCASION_LIST_KEYS,
  OccasionFileError,
  OCCASIONS_PATH,
  parseOccasions,
  readList,
  renderVocabulary,
  serializeOccasions,
  validateOccasions,
  VOCABULARY_PATH,
  withList,
} from "../admin/occasion-vocabulary";
import { MAX_WORD_LENGTH, MAX_WORDS, validateNewWords } from "../admin/occasion-change-plan";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const ROOT = path.resolve(__dirname, "../../..");
const JSON_TEXT = fs.readFileSync(path.join(ROOT, OCCASIONS_PATH), "utf-8");
const DART_TEXT = fs.readFileSync(path.join(ROOT, VOCABULARY_PATH), "utf-8");
const RULES = fs.readFileSync(path.join(ROOT, "firestore.rules"), "utf-8");

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

function throwsCode(fn: () => unknown, code: string): void {
  try {
    fn();
  } catch (err) {
    assert(err instanceof OccasionFileError, `expected OccasionFileError, got ${err}`);
    assertEqual((err as OccasionFileError).code, code, "code");
    return;
  }
  throw new Error(`expected ${code}`);
}

function dartAvailable(): boolean {
  try {
    execFileSync("dart", ["--version"], { stdio: "pipe" });
    return true;
  } catch {
    return false;
  }
}

/** Runs the real generator on [data] in a scratch tree and returns its output. */
function realGenerator(data: Record<string, unknown>): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "occasion-gen-"));
  try {
    const src = path.join(dir, OCCASIONS_PATH);
    fs.mkdirSync(path.dirname(src), { recursive: true });
    fs.writeFileSync(src, serializeOccasions(data));
    execFileSync("dart", ["run", path.join(ROOT, "tools/gen_tag_vocabulary.dart")], { cwd: dir, stdio: "pipe" });
    return fs.readFileSync(path.join(dir, VOCABULARY_PATH), "utf-8");
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

const cases: UnitCase[] = [
  {
    name: "both committed files round-trip byte-identical",
    fn: () => {
      const data = assertReproducible(JSON_TEXT, DART_TEXT);
      assertEqual(serializeOccasions(data), JSON_TEXT, "json");
      assertEqual(renderVocabulary(data), DART_TEXT, "dart");
      assertEqual(validateOccasions(data).length, 0, "generator validation");
    },
  },
  {
    name: "the editable keys are exactly the file's lists, in file order",
    fn: () => {
      const data = parseOccasions(JSON_TEXT);
      const lists: string[] = [];
      for (const [group, fields] of Object.entries(data)) {
        if (group.startsWith("_")) continue;
        for (const [field, value] of Object.entries(fields as Record<string, unknown>)) {
          if (Array.isArray(value)) lists.push(`${group}.${field}`);
        }
      }
      assertEqual(OCCASION_LIST_KEYS.join("\n"), lists.join("\n"), "keys");
      assert(readList(data, "christmas.tag") === null, "a tag is not an editable list");
      assert(readList(data, "christmas.titleStem") === null, "the stem is not an editable list");
    },
  },
  {
    name: "firestore.rules accepts exactly the same list keys",
    fn: () => {
      const block = RULES.match(/function occasionListKeyOk\(k\) \{([\s\S]*?)\}/);
      assert(block !== null, "occasionListKeyOk not found in firestore.rules");
      const keys = [...block![1].matchAll(/'([a-zA-Z]+\.[a-zA-Z]+)'/g)].map((m) => m[1]);
      assertEqual(keys.join("\n"), OCCASION_LIST_KEYS.join("\n"), "rules keys");
    },
  },
  {
    name: "firestore.rules bounds word lists with the server's limits",
    fn: () => {
      const block = RULES.match(/function occasionWordsOk\(w, min\) \{([\s\S]*?)\n {6}\}/);
      assert(block !== null, "occasionWordsOk not found in firestore.rules");
      assert(block![1].includes(`w.size() <= ${MAX_WORDS}`), "word count");
      assert(block![1].includes(`[^,]{1,${MAX_WORD_LENGTH}}(,[^,]{1,${MAX_WORD_LENGTH}})*`), "word length");
    },
  },
  {
    name: "every list in the file passes the proposal check, so an admin can edit any of them",
    fn: () => {
      const data = parseOccasions(JSON_TEXT);
      for (const key of OCCASION_LIST_KEYS) {
        assertEqual(validateNewWords(readList(data, key)), null, key);
      }
    },
  },
  {
    name: "replacing one list keeps every other list, the order and the duplicates across lists",
    fn: () => {
      const data = parseOccasions(JSON_TEXT);
      const next = withList(data, "lucia.bakeTitleWords", ["kaka", "bulle"]);
      assertEqual(JSON.stringify(readList(next, "lucia.bakeTitleWords")), JSON.stringify(["kaka", "bulle"]), "edited");
      assertEqual(JSON.stringify(readList(next, "easter.herringIngredients")), JSON.stringify(["sill"]), "easter sill");
      assertEqual(JSON.stringify(readList(next, "midsummer.herringIngredients")), JSON.stringify(["sill"]), "midsummer sill");
      assertEqual(Object.keys(next).join(","), Object.keys(data).join(","), "group order");
      const text = serializeOccasions(next);
      const changed = text.split("\n").filter((l, i) => l !== JSON_TEXT.split("\n")[i]);
      assertEqual(changed.length, 1, "exactly one line differs");
    },
  },
  {
    name: "a long list is laid out one word per line, a short one on one line",
    fn: () => {
      const data = withList(parseOccasions(JSON_TEXT), "christmas.titleStemFalsePositives", ["a", "b"]);
      assert(renderVocabulary(data).includes("static const christmasTitleStemFalsePositives = <String>['a', 'b'];"), "flat");
      const long = withList(data, "christmas.titleStemFalsePositives", Array.from({ length: 12 }, (_, i) => `ord${i}`));
      assert(
        renderVocabulary(long).includes("  static const christmasTitleStemFalsePositives = <String>[\n    'ord0',\n"),
        "split",
      );
    },
  },
  {
    name: "an apostrophe is escaped as the generator escapes it",
    fn: () => {
      assert(DART_TEXT.includes("'all\\'arrabbiata'"), "fixture holds the escaped word");
    },
  },
  {
    name: "a layout the writers do not know stops them",
    fn: () => {
      throwsCode(() => assertReproducible(JSON_TEXT.replace('"tag": "jul",', '"tag":  "jul",'), DART_TEXT), "json-layout");
      throwsCode(() => assertReproducible(JSON_TEXT, DART_TEXT.replace("'julienne'", "'julienner'")), "dart-drift");
      throwsCode(() => assertReproducible("{", DART_TEXT), "unreadable");
      throwsCode(() => withList(parseOccasions(JSON_TEXT), "christmas.tag", ["x"]), "unknown-list");
    },
  },
  {
    name: "the port matches the real generator on edited lists (skipped without dart on PATH)",
    fn: () => {
      if (!dartAvailable()) {
        console.log("    dart not on PATH: differential check skipped");
        return;
      }
      const base = parseOccasions(JSON_TEXT);
      const variants = [
        withList(base, "titleKeywords.starkSet", Array.from({ length: 200 }, (_, i) => `ord nummer ${i}`)),
        withList(base, "luxury.ingredients", ["x".repeat(60), "all'arrabbiata", "é-ñ 1"]),
        withList(base, "christmas.titleStemFalsePositives", ["julienne", "julia"]),
      ];
      for (const v of variants) assertEqual(renderVocabulary(v), realGenerator(v), "port vs generator");
    },
  },
];

void runTests("occasion-vocabulary", cases);
