/**
 * Admin-vy step D: the server's copy of the tagging word lists' two files.
 *
 * `occasions.json` is the source and `occasion_vocabulary.g.dart` is what
 * `tools/gen_tag_vocabulary.dart` generates from it, run through
 * `dart format`. The callable writes both in one commit, so this module ports
 * the generator, including the formatter's line breaking for the only shapes
 * the generator emits. Each writer refuses to work from a file it cannot
 * reproduce byte for byte, instead of guessing at a layout it does not know.
 *
 * Pure: no Firestore, no GitHub.
 */

export const OCCASIONS_PATH = "lib/services/tagging/config/data/occasions.json";
export const VOCABULARY_PATH = "lib/services/tagging/config/generated/occasion_vocabulary.g.dart";

// Every editable list, as "<group>.<field>". A group's `tag` and the
// christmas `titleStem` are single words, not lists, and stay out: the tag is
// a reserved tag name that recipes and filters already carry. The same list
// is in firestore.rules (`occasionListKeyOk`) and the admin app
// (`kOccasionListKeys`); tests pin all three to occasions.json.
export const OCCASION_LIST_KEYS: readonly string[] = [
  "christmas.titleStemFalsePositives",
  "christmas.titleWords",
  "christmas.mainIngredients",
  "christmas.sideIngredients",
  "lucia.titleWords",
  "lucia.saffronIngredients",
  "lucia.bakeTitleWords",
  "easter.titleWords",
  "easter.lambIngredients",
  "easter.eggIngredients",
  "easter.herringIngredients",
  "midsummer.titleWords",
  "midsummer.herringIngredients",
  "midsummer.newPotatoIngredients",
  "midsummer.strawberryIngredients",
  "midsummer.creamIngredients",
  "crayfish.titleWords",
  "crayfish.ingredients",
  "crayfish.dillIngredients",
  "newYear.titleWords",
  "newYear.ingredients",
  "spring.ingredients",
  "summer.ingredients",
  "autumn.ingredients",
  "winter.ingredients",
  "luxury.ingredients",
  "titleKeywords.starkSet",
  "titleKeywords.starkBoost",
  "titleKeywords.lyxigSet",
  "titleKeywords.lyxigBoost",
  "titleKeywords.comfortFoodSet",
  "titleKeywords.comfortFoodBoost",
  "titleKeywords.barnvanligConfirm",
  "titleKeywords.barnvanligBoost",
  "titleKeywords.snabblagatBoost",
  "titleKeywords.snabblagatSet",
];

export type OccasionData = Record<string, unknown>;

export class OccasionFileError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
    this.name = "OccasionFileError";
  }
}

const isRecord = (v: unknown): v is Record<string, unknown> =>
  v !== null && typeof v === "object" && !Array.isArray(v);

export function parseOccasions(text: string): OccasionData {
  let data: unknown;
  try {
    data = JSON.parse(text);
  } catch {
    throw new OccasionFileError("unreadable", "occasions.json is not JSON");
  }
  if (!isRecord(data)) throw new OccasionFileError("unreadable", "occasions.json is not an object");
  return data;
}

/**
 * The file's own layout: two-space indent, one key per line, every list on
 * one line with ", " between words, and a final newline.
 */
export function serializeOccasions(data: OccasionData): string {
  const inline = (v: unknown): string =>
    Array.isArray(v) ? `[${v.map((w) => JSON.stringify(w)).join(", ")}]` : JSON.stringify(v);
  const groups = Object.entries(data).map(([key, value]) => {
    if (!isRecord(value)) return `  ${JSON.stringify(key)}: ${inline(value)}`;
    const fields = Object.entries(value).map(([f, v]) => `    ${JSON.stringify(f)}: ${inline(v)}`);
    return `  ${JSON.stringify(key)}: {\n${fields.join(",\n")}\n  }`;
  });
  return `{\n${groups.join(",\n")}\n}\n`;
}

function splitKey(listKey: string): [string, string] {
  const dot = listKey.indexOf(".");
  return [listKey.slice(0, dot), listKey.slice(dot + 1)];
}

/** The words of [listKey], or null when the key is not editable or the file has no such list. */
export function readList(data: OccasionData, listKey: string): string[] | null {
  if (!OCCASION_LIST_KEYS.includes(listKey)) return null;
  const [group, field] = splitKey(listKey);
  const g = data[group];
  if (!isRecord(g)) return null;
  const words = g[field];
  if (!Array.isArray(words) || words.some((w) => typeof w !== "string")) return null;
  return [...(words as string[])];
}

/** A copy of [data] with [listKey] replaced; key order is kept. */
export function withList(data: OccasionData, listKey: string, words: readonly string[]): OccasionData {
  if (readList(data, listKey) === null) throw new OccasionFileError("unknown-list", "No such list");
  const [group, field] = splitKey(listKey);
  const out: OccasionData = {};
  for (const [k, v] of Object.entries(data)) {
    out[k] = k === group && isRecord(v) ? { ...v, [field]: [...words] } : v;
  }
  return out;
}

const CAMEL = /^[a-z][a-zA-Z]*$/;
const capitalize = (s: string) => s[0].toUpperCase() + s.substring(1);

/** Port of `validate` in tools/gen_tag_vocabulary.dart. */
export function validateOccasions(data: OccasionData): string[] {
  const errors: string[] = [];
  const tags = new Set<string>();
  const constNames = new Set<string>();
  for (const [groupKey, fields] of Object.entries(data)) {
    if (groupKey.startsWith("_")) continue;
    if (!CAMEL.test(groupKey)) errors.push(`group "${groupKey}" is not a camelCase name`);
    if (!isRecord(fields)) {
      errors.push(`${groupKey} is not an object`);
      continue;
    }
    for (const [fieldKey, value] of Object.entries(fields)) {
      const where = `${groupKey}.${fieldKey}`;
      if (!CAMEL.test(fieldKey)) {
        errors.push(`${where}: the field name is not camelCase`);
        continue;
      }
      const constName = `${groupKey}${capitalize(fieldKey)}`;
      if (constNames.has(constName)) errors.push(`${where}: the name ${constName} is generated twice`);
      constNames.add(constName);
      const words = typeof value === "string" ? [value] : value;
      if (!Array.isArray(words) || words.some((w) => typeof w !== "string")) {
        errors.push(`${where} is neither a word nor a list of words`);
        continue;
      }
      for (const w of words as string[]) {
        if (w.trim() === "") errors.push(`${where} holds an empty word`);
        if (w !== w.toLowerCase()) errors.push(`${where}: "${w}" is not lower case`);
        if (w !== w.trim()) errors.push(`${where}: "${w}" has outer spaces`);
      }
      if (fieldKey === "tag" && typeof value === "string") {
        if (tags.has(value)) errors.push(`${where}: tag "${value}" is used by two groups`);
        tags.add(value);
      }
    }
  }
  return errors;
}

// `dart format`'s default page width; analysis_options.yaml sets no other.
const PAGE_WIDTH = 80;
const MEMBER_INDENT = "  ";
const ELEMENT_INDENT = "    ";

/** Port of `_quote` in the generator. */
function dartQuote(s: string): string {
  return `'${s.replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\$/g, "\\$")}'`;
}

// Dart measures a line in UTF-16 code units, as `String.length` in JS does.
const fits = (line: string) => line.length <= PAGE_WIDTH;

/**
 * `static const <name> = <open><elements><close>;` as the tall-style
 * formatter lays it out: on one line without the trailing comma when it fits,
 * otherwise one element per line, each with a trailing comma.
 */
function collectionMember(name: string, open: string, close: string, elements: string[]): string {
  const head = `${MEMBER_INDENT}static const ${name} = ${open}`;
  const flat = `${head}${elements.join(", ")}${close};`;
  if (fits(flat)) return `${flat}\n`;
  if (!fits(head)) throw new OccasionFileError("unrenderable", `${name} has a name too long to lay out`);
  const lines = elements.map((e) => {
    const line = `${ELEMENT_INDENT}${e},`;
    if (!fits(line)) throw new OccasionFileError("unrenderable", `${name} holds a word too long to lay out`);
    return `${line}\n`;
  });
  return `${head}\n${lines.join("")}${MEMBER_INDENT}${close};\n`;
}

function stringMember(name: string, value: string): string {
  const flat = `${MEMBER_INDENT}static const ${name} = ${dartQuote(value)};`;
  if (fits(flat)) return `${flat}\n`;
  // The formatter would split after `=`; no data needs that, so it is
  // refused rather than guessed.
  throw new OccasionFileError("unrenderable", `${name} is too long for one line`);
}

/**
 * Port of `render` in tools/gen_tag_vocabulary.dart followed by
 * `dart format`. Pinned against the committed file and against the real
 * generator by occasion-vocabulary.test.ts.
 */
export function renderVocabulary(data: OccasionData): string {
  let out = "";
  out += "// GENERATED by tools/gen_tag_vocabulary.dart from\n";
  out += `// ${OCCASIONS_PATH}. Edit that file, not this one.\n`;
  out += "\n";
  out += "abstract final class OccasionVocabulary {\n";
  const tags: string[] = [];
  for (const [groupKey, fields] of Object.entries(data)) {
    if (groupKey.startsWith("_")) continue;
    if (!isRecord(fields)) throw new OccasionFileError("invalid", `${groupKey} is not an object`);
    for (const [fieldKey, value] of Object.entries(fields)) {
      const name = `${groupKey}${capitalize(fieldKey)}`;
      if (typeof value === "string") {
        out += stringMember(name, value);
        if (fieldKey === "tag") tags.push(name);
      } else if (Array.isArray(value)) {
        out += collectionMember(name, "<String>[", "]", value.map((w) => dartQuote(String(w))));
      } else {
        throw new OccasionFileError("invalid", `${groupKey}.${fieldKey} is neither a word nor a list`);
      }
    }
  }
  out += "\n";
  out += `${MEMBER_INDENT}/// Every tag name the data file gives Phase 4.\n`;
  out += collectionMember("allTags", "<String>{", "}", tags);
  out += "}\n";
  return out;
}

/**
 * Checks that this module reproduces [jsonText] and [dartText] exactly
 * before it is trusted to write either. A layout it does not know (a list
 * broken over lines, a different indent, a hand edit of the generated file)
 * stops the run instead of reformatting the whole file in a review PR.
 */
export function assertReproducible(jsonText: string, dartText: string): OccasionData {
  const data = parseOccasions(jsonText);
  if (serializeOccasions(data) !== jsonText) {
    throw new OccasionFileError("json-layout", "occasions.json is not in the layout this writer reproduces");
  }
  if (validateOccasions(data).length > 0) {
    throw new OccasionFileError("invalid", "occasions.json fails the generator's validation");
  }
  if (renderVocabulary(data) !== dartText) {
    throw new OccasionFileError("dart-drift", "occasion_vocabulary.g.dart does not match occasions.json");
  }
  return data;
}
