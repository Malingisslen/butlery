/**
 * Admin-vy step D: decides, for every queued word-list proposal
 * (`kind: occasionList`), whether it goes into the rolling word-list PR, is a
 * conflict with `occasions.json` on main, or is rejected, and produces both
 * files the PR commits. Pure: no Firestore, no GitHub.
 *
 * Proposals are taken oldest first, and each is compared with the list as
 * the proposals before it in the same run left it, so two proposals on one
 * list cannot both claim the same old words.
 */

import {
  assertReproducible,
  OCCASION_LIST_KEYS,
  OccasionData,
  OccasionFileError,
  parseOccasions,
  readList,
  renderVocabulary,
  serializeOccasions,
  validateOccasions,
  withList,
} from "./occasion-vocabulary";
import { SelfCheckError } from "./ingredient-change-plan";

export const OCCASION_LIST_KIND = "occasionList";

// The same bounds are in firestore.rules (`occasionWordsOk`).
export const MAX_WORDS = 200;
export const MAX_WORD_LENGTH = 60;

// Letters, digits, apostrophe and hyphen, with single spaces between parts:
// every word the file holds today has this shape ("all'arrabbiata", "go-to",
// "20 min"). Nothing here can break the JSON, the Dart literal or a PR line.
const WORD = /^[\p{L}\p{N}'-]+( [\p{L}\p{N}'-]+)*$/u;

export type OccasionRejectReason =
  | "unknown-list"
  | "wrong-type"
  | "empty-list"
  | "too-many-words"
  | "too-long"
  | "invalid-word"
  | "not-lower-case"
  | "not-normalized"
  | "duplicate-word"
  | "no-change";

export interface QueuedOccasionProposal {
  id: string;
  listKey: unknown;
  oldWords: unknown;
  newWords: unknown;
  status: "pending" | "inReview";
  createdAtMs: number;
}

export type OccasionOutcome =
  | { kind: "apply"; listKey: string; old: string[]; new: string[] }
  | { kind: "conflict"; listKey: string; old: string[]; new: string[]; current: string[] }
  | { kind: "rejected"; reason: OccasionRejectReason; listKey: string | null };

export interface OccasionPlan {
  outcomes: Map<string, OccasionOutcome>;
  // Ids in the order they were decided.
  order: string[];
  appliedIds: string[];
  jsonText: string;
  dartText: string;
}

const asWords = (v: unknown): string[] | null =>
  Array.isArray(v) && v.every((w) => typeof w === "string") ? [...(v as string[])] : null;

/** Server-side check of a proposed list, independent of the rules. */
export function validateNewWords(words: unknown): OccasionRejectReason | null {
  const list = asWords(words);
  if (list === null) return "wrong-type";
  if (list.length === 0) return "empty-list";
  if (list.length > MAX_WORDS) return "too-many-words";
  const seen = new Set<string>();
  for (const w of list) {
    if (w.length > MAX_WORD_LENGTH) return "too-long";
    if (w !== w.normalize("NFC")) return "not-normalized";
    if (!WORD.test(w)) return "invalid-word";
    if (w !== w.toLowerCase()) return "not-lower-case";
    if (seen.has(w)) return "duplicate-word";
    seen.add(w);
  }
  return null;
}

const sameWords = (a: readonly string[], b: readonly string[]) =>
  a.length === b.length && a.every((w, i) => w === b[i]);

export function planOccasionChanges(
  jsonText: string,
  dartText: string,
  proposals: readonly QueuedOccasionProposal[],
): OccasionPlan {
  let data: OccasionData = assertReproducible(jsonText, dartText);
  const sorted = [...proposals].sort((a, b) => a.createdAtMs - b.createdAtMs || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  const outcomes = new Map<string, OccasionOutcome>();
  const order: string[] = [];
  const appliedIds: string[] = [];

  for (const p of sorted) {
    order.push(p.id);
    const listKey = typeof p.listKey === "string" && OCCASION_LIST_KEYS.includes(p.listKey) ? p.listKey : null;
    if (listKey === null) {
      outcomes.set(p.id, { kind: "rejected", reason: "unknown-list", listKey: null });
      continue;
    }
    const oldWords = asWords(p.oldWords);
    const invalid = oldWords === null ? "wrong-type" : validateNewWords(p.newWords);
    if (invalid) {
      outcomes.set(p.id, { kind: "rejected", reason: invalid, listKey });
      continue;
    }
    const newWords = asWords(p.newWords)!;
    const current = readList(data, listKey);
    if (current === null) {
      outcomes.set(p.id, { kind: "rejected", reason: "unknown-list", listKey });
      continue;
    }
    // Checked first: a proposal whose words are already in the file (its PR
    // merged before its status was written) is not a conflict.
    if (sameWords(newWords, current)) {
      outcomes.set(p.id, { kind: "rejected", reason: "no-change", listKey });
      continue;
    }
    if (!sameWords(oldWords!, current)) {
      outcomes.set(p.id, { kind: "conflict", listKey, old: oldWords!, new: newWords, current });
      continue;
    }
    // Decided per proposal, so a word the generated Dart file cannot lay
    // out (an escaped apostrophe doubles its length) rejects only its own
    // proposal instead of stopping every queued one.
    const next = withList(data, listKey, newWords);
    try {
      renderVocabulary(next);
    } catch (err) {
      if (err instanceof OccasionFileError && err.code === "unrenderable") {
        outcomes.set(p.id, { kind: "rejected", reason: "too-long", listKey });
        continue;
      }
      throw err;
    }
    data = next;
    appliedIds.push(p.id);
    outcomes.set(p.id, { kind: "apply", listKey, old: oldWords!, new: newWords });
  }

  if (appliedIds.length === 0) return { outcomes, order, appliedIds, jsonText, dartText };
  const nextJson = serializeOccasions(data);
  const nextDart = renderVocabulary(data);
  selfCheck(jsonText, nextJson, nextDart, outcomes, appliedIds);
  return { outcomes, order, appliedIds, jsonText: nextJson, dartText: nextDart };
}

/**
 * The written JSON must parse back, pass the generator's validation, hold
 * every list as the last applied proposal left it and every other list as
 * main had it, and round-trip through both writers unchanged.
 */
export function selfCheck(
  before: string,
  afterJson: string,
  afterDart: string,
  outcomes: ReadonlyMap<string, OccasionOutcome>,
  appliedIds: readonly string[],
): void {
  let after: OccasionData;
  try {
    after = assertReproducible(afterJson, afterDart);
  } catch (err) {
    throw new SelfCheckError("occasion-reparse", err instanceof OccasionFileError ? err.code : "reparse");
  }
  if (validateOccasions(after).length > 0) throw new SelfCheckError("occasion-invalid", "Generator validation fails");
  const original = parseOccasions(before);
  if (JSON.stringify(Object.keys(original)) !== JSON.stringify(Object.keys(after))) {
    throw new SelfCheckError("occasion-groups", "Groups changed");
  }
  const intended = new Map<string, string[]>();
  for (const id of appliedIds) {
    const o = outcomes.get(id);
    if (o?.kind === "apply") intended.set(o.listKey, o.new);
  }
  for (const [group, fields] of Object.entries(original)) {
    if (group.startsWith("_")) {
      if (JSON.stringify(fields) !== JSON.stringify(after[group])) throw new SelfCheckError("occasion-readme", "Readme changed");
      continue;
    }
    const a = fields as Record<string, unknown>;
    const b = after[group] as Record<string, unknown>;
    if (JSON.stringify(Object.keys(a)) !== JSON.stringify(Object.keys(b))) {
      throw new SelfCheckError("occasion-fields", `${group} fields changed`);
    }
    for (const field of Object.keys(a)) {
      const key = `${group}.${field}`;
      const want = intended.get(key) ?? a[field];
      if (JSON.stringify(b[field]) !== JSON.stringify(want)) {
        throw new SelfCheckError("occasion-value", `${key} does not read back as intended`);
      }
    }
  }
}
