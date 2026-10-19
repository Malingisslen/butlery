import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { hashUid } from "../../shared/hash-uid";

/**
 * Keys a menu dish does not keep: the blocks that name people and the owner's
 * personal tags. Mirrors `RecipeSerialization.toMenuDish` in the app.
 */
const NON_DISH_KEYS = new Set([
  "socialData",
  "realtimeData",
  "offlineData",
  "type",
  "personalTagIds",
  "personalTags",
]);

/** A map as Firestore hands it over, not a Timestamp or other SDK value. */
function isPlainMap(node: unknown): node is Record<string, unknown> {
  return (
    !!node &&
    typeof node === "object" &&
    Object.getPrototypeOf(node) === Object.prototype
  );
}

/** True when [uid] is a string value or a map key anywhere under [node]. */
function mentionsUid(node: unknown, uid: string): boolean {
  if (node === uid) return true;
  if (Array.isArray(node)) return node.some((v) => mentionsUid(v, uid));
  if (isPlainMap(node)) {
    return Object.entries(node).some(
      ([k, v]) => k === uid || mentionsUid(v, uid),
    );
  }
  return false;
}

/**
 * [node] with every string equal to [uid] as "deleted" and every map key equal
 * to it removed.
 */
function withoutUid(node: unknown, uid: string): unknown {
  if (node === uid) return "deleted";
  if (Array.isArray(node)) return node.map((v) => withoutUid(v, uid));
  if (isPlainMap(node)) {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(node)) {
      if (k !== uid) out[k] = withoutUid(v, uid);
    }
    return out;
  }
  return node;
}

/**
 * BUT-2214: a dish that mentions the deleted user is rewritten as a menu dish
 * — the recipe's core, flat, without the keys in [NON_DISH_KEYS] — with the uid
 * replaced by "deleted" wherever it is a value and removed wherever it is a
 * key. Menus written by a client before BUT-2214 store whole recipes, whose
 * `socialData` / `realtimeData` blocks carry display names beside the ids, so
 * the projection is what removes the names. A dish that does not mention the
 * user is left as it is.
 *
 * Only the menus a caller already found can be scrubbed: a uid inside an
 * array element cannot be queried, so a dish of theirs on a menu they never
 * joined is out of reach, and no probe leg can see what is left.
 *
 * Per-doc transaction: the menu is live, and the
 * whole `menuSnapshot` is rewritten, so it must be rewritten from a fresh read.
 */
export async function scrubDishCreator(
  db: admin.firestore.Firestore,
  docs: admin.firestore.QueryDocumentSnapshot[],
  uid: string,
  label: string,
): Promise<void> {
  // A document with no menu in the query snapshot (a shared recipe or list)
  // costs no transaction read.
  const menus = docs.filter((d) => d.data().menuSnapshot);
  const chunkSize = 10;
  for (let i = 0; i < menus.length; i += chunkSize) {
    await Promise.all(
      menus.slice(i, i + chunkSize).map(async (doc) => {
        try {
          await db.runTransaction(async (tx) => {
            const fresh = await tx.get(doc.ref);
            const snapshot = fresh.data()?.menuSnapshot;
            if (!isPlainMap(snapshot)) return;
            let changed = false;
            const scrubbed: Record<string, unknown> = {};
            for (const [category, dishes] of Object.entries(snapshot)) {
              if (!Array.isArray(dishes)) {
                scrubbed[category] = dishes;
                continue;
              }
              scrubbed[category] = dishes.map((dish) => {
                if (!isPlainMap(dish) || !mentionsUid(dish, uid)) return dish;
                changed = true;
                const base = isPlainMap(dish.core) ? dish.core : dish;
                const projected: Record<string, unknown> = {};
                for (const [k, v] of Object.entries(base)) {
                  if (!NON_DISH_KEYS.has(k)) projected[k] = v;
                }
                return withoutUid(projected, uid);
              });
            }
            if (changed) tx.update(doc.ref, { menuSnapshot: scrubbed });
          });
        } catch (err) {
          logger.warn(`scrubDishCreator:${label}: doc write failed`, {
            uid_prefix: uid.slice(0, 6),
            // A live menu's id starts with its owner's uid.
            docIdHash: hashUid(doc.id),
            errName: err instanceof Error ? err.name : typeof err,
          });
        }
      }),
    );
  }
}
