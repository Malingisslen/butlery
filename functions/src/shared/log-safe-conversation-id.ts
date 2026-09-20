import { hashUid } from "./hash-uid";

/**
 * A conversation id that is safe to put in Cloud Logging.
 *
 * A GROUP id is server-minted and discloses nothing: it is either a Firestore
 * auto-id or, for a meal-vote chat, a hash — never a value derived readably
 * from a uid. A DIRECT id is `direct_<uidA>_<uidB>` — two raw uids, one of
 * which may belong to someone who just had their account erased. This helper exists because BUT-1822 gave
 * `tryClearRoster` a second caller (the account-deletion cascade) that hands it
 * direct ids for the first time: the helper's code did not change, but the key
 * space it logs did. Hashing keeps a greppable handle that correlates across
 * lines without carrying the uids.
 */
export function logSafeConversationId(conversationId: string): string {
  return conversationId.startsWith("direct_")
    ? `direct_#${hashUid(conversationId)}`
    : conversationId;
}
