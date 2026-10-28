/**
 * BUT-2463: deleting `deep_links` documents, shared by the account-deletion
 * cascade and the retention sweep.
 *
 * Firestore does not delete a subcollection with its parent, so each link's
 * `clicks` rows go first: rows written while the rules let clients create
 * them can still be there.
 */

import * as admin from "firebase-admin";

/** The subcollection under each link (`reset-collection-lists.ts` names it too). */
const CLICKS = "clicks";

/** One page of links, and of a link's clicks; also one write batch. */
export const DEEP_LINK_PAGE = 500;

/**
 * Deletes `links` (at most one batch) and every `clicks` row beneath them. A
 * failed commit throws, so a caller never reports a link deleted that is not.
 */
export async function deleteDeepLinkDocs(
  db: admin.firestore.Firestore,
  links: admin.firestore.QueryDocumentSnapshot[],
): Promise<void> {
  if (links.length === 0) return;
  if (links.length > DEEP_LINK_PAGE) {
    throw new Error(`deleteDeepLinkDocs: ${links.length} links exceed one batch`);
  }
  for (const link of links) {
    for (;;) {
      const clicks = await link.ref
        .collection(CLICKS)
        .limit(DEEP_LINK_PAGE)
        .get();
      if (clicks.empty) break;
      const batch = db.batch();
      for (const click of clicks.docs) batch.delete(click.ref);
      await batch.commit();
      if (clicks.size < DEEP_LINK_PAGE) break;
    }
  }
  const batch = db.batch();
  for (const link of links) batch.delete(link.ref);
  await batch.commit();
}
