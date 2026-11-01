/**
 * Keeps `users/{uid}/public_recipes/{recipeId}` in step with the owner's
 * choice "Visa på min profil" (kärnflöde steg 10E).
 *
 * Firestore triggers are delivered at least once and in no fixed order, so the
 * event's snapshots only decide whether there is work to do. The decision
 * itself is taken on the documents as they are now, read in one transaction:
 * a late "publish" event after an unpublish finds the recipe unpublished and
 * removes the copy instead of bringing it back, and a duplicate delivery finds
 * the copy already in the state it wants and moves the counter by nothing.
 */

import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import { Collections } from "../shared/collections";
import { ACCOUNT_MATURITY_MS } from "../shared/caller-eligibility";
import { erasureUnderway } from "../social/hold-shares-on-block";
import {
  PublicImageStore,
  parseDownloadUrl,
  publicImagePath,
  storageImageStore,
} from "./public-recipe-images";
import {
  MAX_PUBLIC_RECIPES_PER_USER,
  PUBLIC_RECIPES,
  buildPublicCopy,
  copyInputsChanged,
  isSharedWithOthers,
  wantsProfile,
} from "./public-recipe-copy";

type Data = admin.firestore.DocumentData;

/** What the owner's account allows, read once per event outside the transaction. */
export interface OwnerStanding {
  ageCompliant: boolean;
  guest: boolean;
  emailVerified: boolean;
}

export type SyncAction = "written" | "deleted" | "unchanged";

/** Why a recipe that asks for the profile is not shown there. Logged, never stored. */
export type Refusal =
  | "not-requested"
  | "recipe-gone"
  | "shared"
  | "age"
  | "guest"
  | "minor"
  | "not-matured"
  | "erasure"
  | "account-gone"
  | "profile-gone"
  | "limit";

export interface SyncResult {
  action: SyncAction;
  refusal?: Refusal;
}

export async function readOwnerStanding(uid: string): Promise<OwnerStanding | null> {
  try {
    const user = await admin.auth().getUser(uid);
    return {
      ageCompliant: user.customClaims?.ageCompliant === true,
      guest: user.providerData.length === 0 && !user.email,
      emailVerified: user.emailVerified === true,
    };
  } catch (err) {
    const code = (err as { code?: string })?.code;
    if (code === "auth/user-not-found" || code === "auth/invalid-uid") return null;
    throw err;
  }
}

function matured(userDoc: admin.firestore.DocumentSnapshot, standing: OwnerStanding, nowMs: number) {
  if (standing.emailVerified) return true;
  const createdAt = userDoc.get("createdAt");
  return (
    createdAt instanceof admin.firestore.Timestamp &&
    nowMs - createdAt.toMillis() >= ACCOUNT_MATURITY_MS
  );
}

/**
 * Thrown when the recipe changed between preparing the photos and the
 * transaction. The trigger runs with retry:true, so the redelivery prepares
 * from the recipe as it is then instead of writing a copy without its photos.
 */
export class StalePhotosError extends Error {
  constructor() {
    super("recipe photos changed while the public copies were made");
    this.name = "StalePhotosError";
  }
}

/**
 * Thrown when a public photo the copy no longer shows was too young to prune.
 * The redelivery prunes it once it is old enough, so unpublishing right after
 * publishing still stops its link working.
 */
export class PublicPhotosPendingError extends Error {
  constructor() {
    super("public photos left to prune");
    this.name = "PublicPhotosPendingError";
  }
}

function refusalFor(
  data: Data | null,
  standing: OwnerStanding | null,
  userDoc: admin.firestore.DocumentSnapshot,
  profile: admin.firestore.DocumentSnapshot,
  marker: admin.firestore.DocumentSnapshot,
  nowMs: number,
): Refusal | undefined {
  if (!data) return "recipe-gone";
  if (!wantsProfile(data)) return "not-requested";
  if (erasureUnderway(marker, nowMs)) return "erasure";
  if (!userDoc.exists || standing === null) return "account-gone";
  // Without the profile the counter cannot move, so the cap would not hold.
  if (!profile.exists) return "profile-gone";
  if (standing.guest) return "guest";
  if (!standing.ageCompliant) return "age";
  if (userDoc.get("isMinor") === true) return "minor";
  if (!matured(userDoc, standing, nowMs)) return "not-matured";
  if (isSharedWithOthers(data)) return "shared";
  return undefined;
}

/** The owner's photos the copy of [data] would show. */
function photoSources(uid: string, recipeId: string, data: Data): string[] {
  const draft = buildPublicCopy(uid, recipeId, data);
  return [
    ...new Set(
      [...(draft.imageUrls as string[]), draft.thumbnailUrl].filter(
        (u): u is string => typeof u === "string",
      ),
    ),
  ];
}

/**
 * A public photo younger than this is never pruned: it may belong to a
 * delivery whose transaction has not committed yet, and that delivery's own
 * prune decides it. The margin covers clock skew between Storage and here.
 */
const PRUNE_GRACE_MS = 10_000;

/**
 * The transaction behind the trigger. [standing] is null when the Auth account
 * no longer exists, which refuses like an erased account.
 */
export async function reconcilePublicRecipe(
  db: admin.firestore.Firestore,
  uid: string,
  recipeId: string,
  standing: OwnerStanding | null,
  images: PublicImageStore = storageImageStore,
  nowMs: number = Date.now(),
): Promise<SyncResult> {
  const userRef = db.collection(Collections.users).doc(uid);
  const recipeRef = userRef.collection(Collections.recipes).doc(recipeId);
  const copyRef = userRef.collection(PUBLIC_RECIPES).doc(recipeId);
  const profileRef = db.collection(Collections.publicProfiles).doc(uid);
  const markerRef = db.collection(Collections.erasuresInProgress).doc(uid);

  // Storage cannot join a Firestore transaction, so the public photos are
  // made first, from the recipe as read now, and only when nothing already
  // refuses it. The transaction re-reads the recipe and refuses to write if it
  // names a photo that was not prepared here (StalePhotosError).
  const prepared = new Map<string, string | null>();
  const [before, userBefore, profileBefore, markerBefore] = await Promise.all([
    recipeRef.get(),
    userRef.get(),
    profileRef.get(),
    markerRef.get(),
  ]);
  const beforeData = before.exists ? (before.data() as Data) : null;
  if (!refusalFor(beforeData, standing, userBefore, profileBefore, markerBefore, nowMs)) {
    for (const url of photoSources(uid, recipeId, beforeData as Data)) {
      prepared.set(url, await images.ensure(uid, recipeId, url));
    }
  }

  const result = await db.runTransaction(async (tx): Promise<SyncResult> => {
    const [recipe, copy, userDoc, profile, marker] = await Promise.all([
      tx.get(recipeRef),
      tx.get(copyRef),
      tx.get(userRef),
      tx.get(profileRef),
      tx.get(markerRef),
    ]);
    const data = recipe.exists ? (recipe.data() as Data) : null;

    let refusal = refusalFor(data, standing, userDoc, profile, marker, nowMs);
    if (
      !refusal &&
      !copy.exists &&
      (profile.get("publicRecipeCount") ?? 0) >= MAX_PUBLIC_RECIPES_PER_USER
    ) {
      refusal = "limit";
    }

    if (refusal) {
      // Co-owners never agreed to publish, and unsharing later must not put
      // the recipe back on the profile without the owner choosing it again.
      if (
        data !== null &&
        wantsProfile(data) &&
        isSharedWithOthers(data) &&
        refusal !== "erasure" &&
        refusal !== "account-gone"
      ) {
        tx.update(recipeRef, {
          "core.showOnProfile": false,
          "core.showOnProfileChangedAt": admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      if (!copy.exists) return { action: "unchanged", refusal };
      tx.delete(copyRef);
      // update() never creates: an erasure that already removed the profile
      // must not get it back from a late event.
      if (profile.exists) {
        const current = profile.get("publicRecipeCount");
        if (typeof current === "number" && current > 0) {
          tx.update(profileRef, {
            publicRecipeCount: admin.firestore.FieldValue.increment(-1),
          });
        }
      }
      return { action: "deleted", refusal };
    }

    if (photoSources(uid, recipeId, data as Data).some((u) => !prepared.has(u))) {
      throw new StalePhotosError();
    }
    const built = buildPublicCopy(uid, recipeId, data as Data);
    const imageUrls = (built.imageUrls as string[])
      .map((u) => prepared.get(u))
      .filter((u): u is string => typeof u === "string");
    const thumbnailUrl =
      typeof built.thumbnailUrl === "string" ? prepared.get(built.thumbnailUrl) ?? null : null;
    tx.set(copyRef, {
      ...built,
      imageUrls,
      thumbnailUrl,
      syncedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    if (!copy.exists) {
      tx.update(profileRef, {
        publicRecipeCount: admin.firestore.FieldValue.increment(1),
      });
    }
    return { action: "written" };
  });

  await prunePublicPhotos(db, uid, recipeId, images);
  return result;
}

/**
 * Deletes the public photos the copy does not show any more. The keep set is
 * read fresh rather than taken from this delivery's transaction, so an older
 * delivery that prunes last cannot delete the photos a newer one wrote.
 */
async function prunePublicPhotos(
  db: admin.firestore.Firestore,
  uid: string,
  recipeId: string,
  images: PublicImageStore,
): Promise<void> {
  // Storage's clock, not the injected test clock, stamps the objects.
  const readAtMs = Date.now();
  const userRef = db.collection(Collections.users).doc(uid);
  const [recipe, copy] = await Promise.all([
    userRef.collection(Collections.recipes).doc(recipeId).get(),
    userRef.collection(PUBLIC_RECIPES).doc(recipeId).get(),
  ]);
  const keep = new Set<string>();
  if (copy.exists && recipe.exists && wantsProfile(recipe.data())) {
    for (const url of photoSources(uid, recipeId, recipe.data() as Data)) {
      const source = parseDownloadUrl(url);
      if (source) keep.add(publicImagePath(uid, recipeId, source.path));
    }
  }
  const pending = await images.prune(uid, recipeId, keep, readAtMs - PRUNE_GRACE_MS);
  if (pending > 0) throw new PublicPhotosPendingError();
}

export const syncPublicRecipe = onDocumentWritten(
  // retry:true: v2 event triggers drop a thrown error otherwise. The handler
  // re-reads current state, so a re-run converges on the same result.
  { document: `${Collections.users}/{uid}/${Collections.recipes}/{recipeId}`, retry: true },
  async (event) => {
    const before = event.data?.before?.exists ? (event.data.before.data() as Data) : null;
    const after = event.data?.after?.exists ? (event.data.after.data() as Data) : null;
    // Neither side asks for the profile: a copy cannot exist that this write
    // should change, so the ordinary recipe save costs no reads.
    if (!wantsProfile(before) && !wantsProfile(after)) return;
    if (before && after && !copyInputsChanged(before, after)) return;

    const { uid, recipeId } = event.params;
    try {
      const standing = await readOwnerStanding(uid);
      const result = await reconcilePublicRecipe(admin.firestore(), uid, recipeId, standing);
      logger.info("public_recipe.sync", { event: "public_recipe.sync", recipeId, ...result });
    } catch (err) {
      // Code and name only: a Storage error's message names the object path,
      // which carries the uid.
      const e = err as { code?: unknown; name?: unknown };
      logger.error("public_recipe.sync_failed", {
        event: "public_recipe.sync_failed",
        recipeId,
        errCode: typeof e?.code === "string" || typeof e?.code === "number" ? e.code : null,
        errName: typeof e?.name === "string" ? e.name : null,
      });
      throw err;
    }
  },
);
