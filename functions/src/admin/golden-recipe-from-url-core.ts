/**
 * Pure scoring for the nightly `recipe_from_url` AI corpus (BUT-2239).
 *
 * Split from golden-recipe-from-url.ts because that script
 * cannot be imported by a unit test.
 */

/**
 * The uid hash the nightly corpus calls the server with. Its sample rows are
 * not users' imports, so the sample export drops them.
 */
export const GOLDEN_CI_UID_HASH = "golden-ci";

/** One page as the app would send it: the stripped text, already cut. */
export interface GoldenInput {
  id: string;
  url: string;
  text: string;
  goldTitle: string;
  goldIngredientKeys: string[];
}

/** What one call returned, or why it did not. */
export interface GoldenOutcome {
  id: string;
  title?: string;
  ingredientNames?: string[];
  estimatedCost: number;
  error?: string;
}

export interface GoldenPageScore {
  id: string;
  titleMatches: boolean;
  ingredientsFound: number;
  goldIngredients: number;
  costUsd: number;
  error?: string;
}

export interface GoldenSummary {
  corpus: "recipe_from_url";
  skipped: boolean;
  reason?: string;
  calls: number;
  total_cost_usd: number;
  cost_cap_usd: number;
  over_cap: boolean;
  pages: GoldenPageScore[];
}

const norm = (s: string): string => s.trim().toLowerCase();

/** A gold ingredient key counts as found when some extracted name contains it. */
export function scorePage(input: GoldenInput, outcome: GoldenOutcome): GoldenPageScore {
  const names = (outcome.ingredientNames ?? []).map(norm);
  const found = input.goldIngredientKeys.filter((key) =>
    names.some((name) => name.includes(norm(key)))
  ).length;
  return {
    id: input.id,
    titleMatches: outcome.title !== undefined && norm(outcome.title) === norm(input.goldTitle),
    ingredientsFound: found,
    goldIngredients: input.goldIngredientKeys.length,
    costUsd: outcome.estimatedCost,
    ...(outcome.error !== undefined ? { error: outcome.error } : {}),
  };
}

export function summariseRun(
  inputs: GoldenInput[],
  outcomes: GoldenOutcome[],
  capUsd: number
): GoldenSummary {
  const byId = new Map(outcomes.map((o) => [o.id, o]));
  const pages = inputs.map((input) =>
    scorePage(input, byId.get(input.id) ?? { id: input.id, estimatedCost: 0, error: "not run" })
  );
  const total = outcomes.reduce((sum, o) => sum + o.estimatedCost, 0);
  return {
    corpus: "recipe_from_url",
    skipped: false,
    calls: outcomes.length,
    total_cost_usd: total,
    cost_cap_usd: capUsd,
    over_cap: total > capUsd,
    pages,
  };
}

export function skippedSummary(reason: string, capUsd: number): GoldenSummary {
  return {
    corpus: "recipe_from_url",
    skipped: true,
    reason,
    calls: 0,
    total_cost_usd: 0,
    cost_cap_usd: capUsd,
    over_cap: false,
    pages: [],
  };
}

/**
 * Whether the next call could still fit under the cap.
 */
export function mayCall(spentUsd: number, perCallCeilingUsd: number, capUsd: number): boolean {
  return spentUsd + perCallCeilingUsd <= capUsd;
}
