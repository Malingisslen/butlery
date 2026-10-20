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
