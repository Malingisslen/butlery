/**
 * The text of the admin-vy's rolling word-list PR. The repository is public,
 * so the body carries list names and words only: never a uid, an admin's
 * name or a proposal's `note`. Words go through the ingredient PR's
 * `neutralize` inside inline code, so none can form a mention, link, image,
 * HTML tag or table break.
 */

import { neutralize } from "./ingredient-pr-body";
import type { OccasionOutcome } from "./occasion-change-plan";

export const OCCASION_PR_TITLE = "Ordlistor för högtider och titelord från admin-vyn";

// A GitHub PR body is capped at 65536 characters; the rest is in the diff.
const MAX_BODY_CHARS = 60000;

const code = (text: string) => "`" + neutralize(text) + "`";
const words = (list: readonly string[]) => (list.length ? list.map(code).join(", ") : "*(inga)*");

function diffLines(listKey: string, oldWords: readonly string[], newWords: readonly string[]): string[] {
  const before = new Set(oldWords);
  const after = new Set(newWords);
  const added = newWords.filter((w) => !before.has(w));
  const removed = oldWords.filter((w) => !after.has(w));
  const lines = [`- ${code(listKey)}`];
  if (added.length) lines.push(`  - Tillagda: ${words(added)}`);
  if (removed.length) lines.push(`  - Borttagna: ${words(removed)}`);
  if (!added.length && !removed.length) lines.push("  - Samma ord i ny ordning");
  return lines;
}

function capped(items: string[][], budget: { left: number }, noun: string): string[] {
  const out: string[] = [];
  let shown = 0;
  for (const lines of items) {
    const size = lines.reduce((n, l) => n + l.length + 1, 0);
    if (size > budget.left) break;
    out.push(...lines);
    budget.left -= size;
    shown++;
  }
  if (shown < items.length) out.push(`- … och ${items.length - shown} ${noun} till, se diffen.`);
  return out;
}

export function buildOccasionPrBody(outcomes: readonly OccasionOutcome[]): string {
  const applied = outcomes.filter((o): o is Extract<OccasionOutcome, { kind: "apply" }> => o.kind === "apply");
  const conflicts = outcomes.filter((o): o is Extract<OccasionOutcome, { kind: "conflict" }> => o.kind === "conflict");
  const rejected = outcomes.filter((o): o is Extract<OccasionOutcome, { kind: "rejected" }> => o.kind === "rejected");
  const out: string[] = [
    "Förslag från admin-vyn som ändrar ordlistorna i " +
      "`lib/services/tagging/config/data/occasions.json` och den genererade " +
      "`occasion_vocabulary.g.dart`: " +
      `${applied.length} förslag med, ${conflicts.length} konflikter, ${rejected.length} nekade.`,
    "",
    "Ordlistorna kompileras in i appen. Ändringen märks för användarna först i nästa appversion, " +
      "och befintliga recept taggas om först när taggversionen höjs.",
    "",
    "- [ ] Höj `kTagGeneratorVersion` i `lib/services/tagging/tag_generator.dart` och släpp en ny " +
      "appversion. Appsläppet stoppas tills versionen är höjd.",
    "",
    "Om testet `phase4_equivalence_test` blir rött visar testloggen vilka facitfall som får andra " +
      "taggar. Boten ändrar aldrig facit: det avgör Malin.",
    "",
  ];
  const budget = { left: MAX_BODY_CHARS - out.join("\n").length - 2000 };
  if (applied.length) {
    out.push("## Ändringar", "", ...capped(applied.map((o) => diffLines(o.listKey, o.old, o.new)), budget, "förslag"), "");
  }
  if (conflicts.length) {
    const items = conflicts.map((o) => [
      `- ${code(o.listKey)}: listan på main har ändrats sedan förslaget gjordes.`,
      `  - På main nu: ${words(o.current)}`,
      `  - Förslagets nya lista: ${words(o.new)}`,
    ]);
    out.push("## Konflikter (inte med i ändringen)", "", ...capped(items, budget, "konflikter"), "");
  }
  if (rejected.length) {
    const items = rejected.map((o) => [`- ${o.listKey ? code(o.listKey) : "*(okänd lista)*"}: ${code(o.reason)}`]);
    out.push("## Nekade av servern (inte med i ändringen)", "", ...capped(items, budget, "nekade"), "");
  }
  return out.join("\n");
}
