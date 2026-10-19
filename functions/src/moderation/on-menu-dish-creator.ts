/**
 * BUT-2352: the rules let the sharer and any member write any `createdBy` into
 * a shared menu's dishes, so this removes a creator name the writer could not
 * have taken from the named person's own recipe. Malin's call, 2026-10-19:
 * checked on the server after every write, so a forged name shows until this
 * has run.
 *
 * A new name stays when `users/{createdBy}/recipes/{dish id}` exists with the
 * same creator and title, the writer may read that recipe, and the named person
 * has not said "Det här är inte min rätt" about that dish on that menu (ADR-0029);
 * otherwise this removes it.
 */

import { onDocumentWrittenWithAuthContext } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { isValidDocId } from "../shared/valid-doc-id";
import { isPersonAuth } from "./report-decision";
import { REPORTS } from "./report-status";
import {
  DishCredit,
  MAX_CREDIT_CHECKS,
  introducedCredits,
  stripCredits,
} from "./menu-dish-creator";

type Data = admin.firestore.DocumentData;

/** The part of the trigger event the handler reads. */
export interface MenuDishCreatorEvent {
  data?: {
    before: { data(): Data | undefined };
    after: { data(): Data | undefined };
  };
  params: { contentId: string };
  authType?: string;
  authId?: string;
}

export interface MenuDishCreatorDeps {
  db: admin.firestore.Firestore;
}

export type MenuDishCreatorOutcome =
  | "skipped"
  | "nothing_new"
  | "kept"
  | "removed"
  | "already_gone";

/** Older recipes are stored flat, without `core`; the app reads both. */
function recipeCore(recipe: Data): Data {
  const core = recipe.core;
  return typeof core === "object" && core !== null && !Array.isArray(core) ? core : recipe;
}

function writerMayRead(recipe: Data, writerUid: string): boolean {
  const members = recipe.socialData?.memberPermissions;
  return typeof members === "object" && members !== null && !Array.isArray(members) &&
    Object.prototype.hasOwnProperty.call(members, writerUid);
}

/** The credits among [credits] that the named person's own recipe does not back. */
async function unbacked(
  db: admin.firestore.Firestore,
  menuId: string,
  writerUid: string,
  credits: DishCredit[],
): Promise<DishCredit[]> {
  const checkable: Array<DishCredit & { dishId: string }> = [];
  const offending: DishCredit[] = [];
  for (const credit of credits) {
    if (isValidDocId(credit.dishId) && isValidDocId(credit.createdBy)) {
      checkable.push({ ...credit, dishId: credit.dishId });
    } else {
      offending.push(credit);
    }
  }
  if (checkable.length === 0) return offending;

  const recipes = await db.getAll(
    ...checkable.map((c) => db.collection("users").doc(c.createdBy).collection("recipes").doc(c.dishId)),
  );
  const backedByRecipe: Array<DishCredit & { dishId: string }> = [];
  checkable.forEach((credit, i) => {
    const recipe = recipes[i].data();
    const core = recipe ? recipeCore(recipe) : undefined;
    if (
      recipe && core &&
      core.createdBy === credit.createdBy &&
      core.title === credit.title &&
      writerMayRead(recipe, writerUid)
    ) {
      backedByRecipe.push(credit);
    } else {
      offending.push(credit);
    }
  });

  // One query per named person; the dish is matched here, so no composite
  // index is needed.
  const people = [...new Set(backedByRecipe.map((c) => c.createdBy))];
  const disowned = new Set<string>();
  await Promise.all(people.map(async (uid) => {
    const reports = await db.collection(REPORTS)
      .where("reporterId", "==", uid)
      .where("contentId", "==", menuId)
      .get();
    for (const report of reports.docs) {
      if (report.get("contentType") === "menu_dish" && report.get("reason") === "misattribution") {
        disowned.add(JSON.stringify([uid, report.get("dishId")]));
      }
    }
  }));
  for (const credit of backedByRecipe) {
    if (disowned.has(JSON.stringify([credit.createdBy, credit.dishId]))) offending.push(credit);
  }
  return offending;
}

/** Test seam — the trigger body with Firestore injected. */
export async function handleMenuDishCreator(
  event: MenuDishCreatorEvent,
  deps: MenuDishCreatorDeps,
): Promise<MenuDishCreatorOutcome> {
  const after = event.data?.after.data();
  const writerUid = event.authId;
  if (
    !after ||
    after.contentType !== "menu" ||
    !isPersonAuth(event.authType) ||
    typeof writerUid !== "string" || writerUid.length === 0
  ) {
    return "skipped";
  }

  const menuId = event.params.contentId;
  const introduced = introducedCredits(
    event.data?.before.data()?.menuSnapshot,
    after.menuSnapshot,
    writerUid,
  );
  if (introduced.length === 0) return "nothing_new";

  const unchecked = introduced.slice(MAX_CREDIT_CHECKS);
  const offending = [
    ...unchecked,
    ...await unbacked(deps.db, menuId, writerUid, introduced.slice(0, MAX_CREDIT_CHECKS)),
  ];

  let outcome: MenuDishCreatorOutcome = "kept";
  if (offending.length > 0) {
    const menuRef = deps.db.collection("shared_content").doc(menuId);
    outcome = await deps.db.runTransaction(async (tx) => {
      const menu = await tx.get(menuRef);
      const next = menu.exists ? stripCredits(menu.get("menuSnapshot"), offending) : null;
      if (!next) return "already_gone";
      tx.update(menuRef, { menuSnapshot: next });
      return "removed";
    });
  }
  logger.info("menu_dish_creator", {
    content_prefix: menuId.slice(0, 6),
    outcome,
    introduced: introduced.length,
    offending: offending.length,
    unchecked: unchecked.length,
  });
  return outcome;
}

// retry:true — a rerun re-reads the menu and writes only what is still
// there, so a redelivery is harmless, and without a retry a transient failure
// would leave a forged name up for good. The removal is an Admin SDK write,
// so the run it triggers stops at `isPersonAuth`.
export const onMenuDishCreatorWrite = onDocumentWrittenWithAuthContext(
  { document: "shared_content/{contentId}", retry: true },
  async (event) => {
    await handleMenuDishCreator(event, { db: admin.firestore() });
  },
);
