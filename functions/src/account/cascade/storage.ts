/**
 * The Storage folder account deletion empties, shared with the Art. 15
 * listing of it (`exports/erasure-residue/storage-section.ts`) so the two
 * cannot drift apart. The trailing `/` keeps `users/abc/` from matching
 * `users/abcd/`.
 */
export function userStoragePrefix(uid: string): string {
  // A uid holding "/" would name a folder inside another user's.
  if (uid === "" || uid.includes("/")) {
    throw new Error("uid not usable as a Storage folder");
  }
  return `users/${uid}/`;
}

/**
 * BUT-818: where `moderateUpload` moves a user's explicit images. It mirrors
 * the user's folder, so the same uid check guards it.
 */
export const QUARANTINE_PREFIX = "quarantine/";

export function quarantineStoragePrefix(uid: string): string {
  return QUARANTINE_PREFIX + userStoragePrefix(uid);
}

/** Every folder account deletion empties, in the order it empties them. */
export function userStoragePrefixes(uid: string): string[] {
  return [userStoragePrefix(uid), quarantineStoragePrefix(uid)];
}
