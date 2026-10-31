/**
 * The profile copy's own photos (kärnflöde steg 10E, Malin 2026-10-31:
 * "Ja, egen publik bildkopia").
 *
 * A recipe photo is a Storage download URL whose token never expires, so a
 * copy pointing at it would keep working for anyone who saw it after the owner
 * chose "Sluta visa på profilen". The copy therefore points at a separate
 * object with a token of its own, under
 * `users/{uid}/public_recipes/{recipeId}/`, and deleting that prefix is what
 * makes the photo stop working. The prefix sits under `users/{uid}/`, which
 * the account erasure's Storage prefix delete already covers.
 */

import { createHash, randomUUID } from "crypto";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";

/** Where an owner's Storage download URL points. */
export interface StorageObject {
  bucket: string;
  path: string;
}

/** Bucket and object path of a Firebase Storage download URL, or null. */
export function parseDownloadUrl(url: string): StorageObject | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  if (parsed.protocol !== "https:" || parsed.hostname !== "firebasestorage.googleapis.com") return null;
  const match = /^\/v0\/b\/([^/]+)\/o\/([^/]+)$/.exec(parsed.pathname);
  if (!match) return null;
  try {
    return { bucket: decodeURIComponent(match[1]), path: decodeURIComponent(match[2]) };
  } catch {
    return null;
  }
}

export function publicImagePrefix(uid: string, recipeId: string): string {
  return `${Collections.users}/${uid}/${Collections.publicRecipes}/${recipeId}/`;
}

/** One object per source photo, so a re-run finds the copy it already made. */
export function publicImagePath(uid: string, recipeId: string, sourcePath: string): string {
  const digest = createHash("sha256").update(sourcePath).digest("hex").slice(0, 24);
  return `${publicImagePrefix(uid, recipeId)}${digest}`;
}

function downloadUrl(bucket: string, path: string, token: string): string {
  return (
    `https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(bucket)}` +
    `/o/${encodeURIComponent(path)}?alt=media&token=${token}`
  );
}

/** The slice of Storage the sync needs, so the transaction is testable without it. */
export interface PublicImageStore {
  /** The public copy's URL for [sourceUrl], making the copy if it is missing. Null if the source is gone. */
  ensure(uid: string, recipeId: string, sourceUrl: string): Promise<string | null>;
  /**
   * Deletes every public photo of the recipe whose object path is not in
   * [keep] and that was created before [createdBeforeMs]. Resolves to how many
   * it left only because they were younger than that.
   */
  prune(uid: string, recipeId: string, keep: ReadonlySet<string>, createdBeforeMs: number): Promise<number>;
}

const TOKEN_KEY = "firebaseStorageDownloadTokens";

export const storageImageStore: PublicImageStore = {
  async ensure(uid, recipeId, sourceUrl) {
    const source = parseDownloadUrl(sourceUrl);
    const bucket = admin.storage().bucket();
    // The app's own bucket only: the URL is owner-written, and the function's
    // service account can read buckets the owner cannot.
    if (!source || source.bucket !== bucket.name) return null;
    const destPath = publicImagePath(uid, recipeId, source.path);
    const dest = bucket.file(destPath);
    const [exists] = await dest.exists();
    if (!exists) {
      const src = bucket.file(source.path);
      const [srcExists] = await src.exists();
      if (!srcExists) return null;
      try {
        // Only if nothing is there yet: a second delivery copying over the
        // first would give the object a new token and break the URL the first
        // one wrote into the copy.
        await src.copy(dest, {
          metadata: { [TOKEN_KEY]: randomUUID() },
          preconditionOpts: { ifGenerationMatch: 0 },
        });
      } catch (err) {
        if ((err as { code?: number })?.code !== 412) throw err;
      }
    }
    const [meta] = await dest.getMetadata();
    let token = String(meta.metadata?.[TOKEN_KEY] ?? "").split(",")[0];
    if (!token) {
      token = randomUUID();
      await dest.setMetadata({ metadata: { [TOKEN_KEY]: token } });
    }
    return downloadUrl(source.bucket, destPath, token);
  },

  async prune(uid, recipeId, keep, createdBeforeMs) {
    const bucket = admin.storage().bucket();
    const [files] = await bucket.getFiles({ prefix: publicImagePrefix(uid, recipeId) });
    const unwanted = files.filter((f) => !keep.has(f.name));
    const old = unwanted.filter((f) => {
      const created = Date.parse(String(f.metadata?.timeCreated ?? ""));
      return Number.isFinite(created) && created < createdBeforeMs;
    });
    await Promise.all(old.map((f) => f.delete({ ignoreNotFound: true })));
    return unwanted.length - old.length;
  },
};
