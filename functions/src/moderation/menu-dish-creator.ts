/**
 * BUT-2352: which creator names a write put on dishes in a shared menu, and
 * how to take them off again. Pure: `on-menu-dish-creator.ts` decides which of
 * them stand.
 *
 * A credit is the triple (dish id, `createdBy`, title).
 */

import * as admin from "firebase-admin";

type Data = admin.firestore.DocumentData;

export interface DishCredit {
  dishId: string | null;
  createdBy: string;
  title: string | null;
}

/**
 * Checks per write. Each one costs a recipe read, so a write naming more
 * people than this has the rest removed unchecked rather than read.
 */
export const MAX_CREDIT_CHECKS = 40;

function dishesOf(snapshot: unknown): Data[] {
  if (typeof snapshot !== "object" || snapshot === null || Array.isArray(snapshot)) return [];
  return Object.values(snapshot as Data)
    .filter(Array.isArray)
    .flat()
    .filter((dish): dish is Data => typeof dish === "object" && dish !== null && !Array.isArray(dish));
}

function creditOf(dish: Data): DishCredit | null {
  if (typeof dish.createdBy !== "string" || dish.createdBy.length === 0) return null;
  return {
    dishId: typeof dish.id === "string" ? dish.id : null,
    createdBy: dish.createdBy,
    title: typeof dish.title === "string" ? dish.title : null,
  };
}

export function creditKey(credit: DishCredit): string {
  return JSON.stringify([credit.dishId, credit.createdBy, credit.title]);
}

/**
 * The credits in [after] that [before] did not hold at all, one entry per
 * distinct triple, leaving out [writerUid]'s own name. Presence, not count:
 * copying a credit already on the menu must not strip the original with it.
 */
export function introducedCredits(
  before: unknown,
  after: unknown,
  writerUid: string,
): DishCredit[] {
  const had = new Set<string>();
  for (const dish of dishesOf(before)) {
    const credit = creditOf(dish);
    if (credit) had.add(creditKey(credit));
  }
  const introduced = new Map<string, DishCredit>();
  for (const dish of dishesOf(after)) {
    const credit = creditOf(dish);
    if (!credit || credit.createdBy === writerUid) continue;
    const key = creditKey(credit);
    if (!had.has(key)) introduced.set(key, credit);
  }
  return [...introduced.values()];
}

/**
 * [snapshot] with `createdBy` removed from every dish whose triple is in
 * [offending]; null when no dish carries one. Read from the menu as it is
 * now, so a dish changed since the write that named it is left alone.
 */
export function stripCredits(snapshot: unknown, offending: DishCredit[]): Data | null {
  if (typeof snapshot !== "object" || snapshot === null || Array.isArray(snapshot)) return null;
  const keys = new Set(offending.map(creditKey));
  let changed = false;
  const next: Data = {};
  for (const [category, dishes] of Object.entries(snapshot as Data)) {
    if (!Array.isArray(dishes)) {
      next[category] = dishes;
      continue;
    }
    next[category] = dishes.map((dish) => {
      if (typeof dish !== "object" || dish === null || Array.isArray(dish)) return dish;
      const credit = creditOf(dish as Data);
      if (!credit || !keys.has(creditKey(credit))) return dish;
      changed = true;
      const rest: Data = { ...(dish as Data) };
      delete rest.createdBy;
      return rest;
    });
  }
  return changed ? next : null;
}
