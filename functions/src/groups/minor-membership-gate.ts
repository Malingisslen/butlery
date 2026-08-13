/**
 * BUT-1838: the ONE place a minor-membership decision is made.
 *
 * Before this module the decision existed once, as an `onDocumentCreated`
 * trigger on `conversations/{id}` — so it ran in the instant a group chat was
 * born and never again. Anyone added later was checked by nobody, and there was
 * no "was invited" moment to move the check to, because the chat WAS the list.
 *
 * `chat_groups` gives that moment. Membership is writable only by the Admin SDK,
 * through callables that ask this module first, so the check now runs once per
 * PERSON per INVITE instead of once per CHAT — and it covers every chat the
 * group ever gets, not just the one it was created with.
 *
 * **The rule is unchanged**, deliberately: a minor may be added only by someone
 * who is already their friend. It is the same condition `computeMinorsToRemove`
 * enforced after the fact and the same one `passesMinorDmGate` enforces for 1:1
 * DMs in `firestore.rules`. What changed is WHEN it runs, not WHAT it decides.
 * The residual it does not cover — an existing group member who is a stranger to
 * a newly added minor can still message them — is Malin's explicit call of
 * 2026-08-13 and is recorded in ACCEPTED_DEVIATIONS.md; do not silently widen it
 * here.
 *
 * **Why the decision core is pure.** It is the only part that must be provable
 * without an emulator, and it is shared by three callers with different I/O
 * shapes (create, add, and the belt-and-braces trigger). Reads live in the two
 * helpers below; the verdict lives in `computeBlockedMembers`.
 */

import * as admin from "firebase-admin";
import { isValidDocId } from "../shared/valid-doc-id";

export interface MinorAdmissionInput {
  /**
   * Uids whose membership is being judged. A candidate who is their own inviter
   * is never blocked, mirroring the creator skip the old trigger had.
   */
  candidates: string[];
  /**
   * Who seated each candidate. A function rather than a single uid because the
   * two callers ask the same question about different shapes: a callable knows
   * one inviter for the whole batch, while the backstop trigger re-judges a
   * whole roster whose members were seated by different people at different
   * times. One policy, two lookups — not two policies.
   *
   * Returning null means "no identifiable inviter", which fails SAFE.
   */
  inviterOf: (uid: string) => string | null;
  /** uid -> whether that account is a compliant minor (`isMinor: true`). */
  isMinor: Record<string, boolean>;
  /** candidate uid -> whether THEIR inviter is one of their friends. */
  inviterIsFriendOf: Record<string, boolean>;
}

/**
 * Pure decision core (unit-tested): which candidates must be refused.
 *
 * A candidate is blocked when they are a minor, did not seat themselves, and
 * either (a) their inviter is unknown — no friendship can be proven, so fail
 * SAFE for the child — or (b) the inviter is not one of their friends. Adults
 * are never blocked.
 *
 * Same three clauses, same order and same fail-safe as the `computeMinorsToRemove`
 * this replaces. It is now the ONLY copy of the policy: the callables ask it
 * before writing, and the backstop trigger asks it after, so the two can no
 * longer disagree about what the rule is.
 */
export function computeBlockedMembers(input: MinorAdmissionInput): string[] {
  const { candidates, inviterOf, isMinor, inviterIsFriendOf } = input;
  const blocked: string[] = [];
  for (const uid of candidates) {
    const inviter = inviterOf(uid);
    if (inviter === uid) continue; // you are not "adding" yourself
    if (!isMinor[uid]) continue; // only minors are protected
    if (!inviter) {
      blocked.push(uid);
      continue;
    }
    if (!inviterIsFriendOf[uid]) blocked.push(uid);
  }
  return blocked;
}

/**
 * Upper bound on group membership, enforced server-side because nothing else
 * does.
 *
 * Two independent reasons, either sufficient. (1) It bounds this module's
 * `getAll` fan-out, the same job `MAX_GROUP_PARTICIPANTS` does for the trigger —
 * and the value is deliberately the same number so the two cannot drift into a
 * state where a group is creatable but un-checkable. (2) The conversation
 * document carries FIVE uid-keyed maps (`participantDisplayNames`,
 * `participantAvatarUrls`, `lastReadTimestamps`, `perUserSettings` and, since
 * BUT-1838, `memberSince`) plus `participantIds`; unbounded membership walks that
 * document toward Firestore's 1 MiB ceiling, at which point the group stops
 * working in a way no error message explains.
 */
export const MAX_CHAT_GROUP_MEMBERS = 100;

/** Reads `isMinor` for each candidate uid via a single batched getAll. */
export async function readIsMinor(
  db: admin.firestore.Firestore,
  uids: string[],
): Promise<Record<string, boolean>> {
  const out: Record<string, boolean> = {};
  if (uids.length === 0) return out;
  const refs = uids.map((u) => db.doc(`users/${u}`));
  const snaps = await db.getAll(...refs);
  snaps.forEach((snap, i) => {
    out[uids[i]] = snap.exists && snap.get("isMinor") === true;
  });
  return out;
}

/**
 * Reads, for each minor uid, whether `inviterUid` is their friend.
 *
 * Directional on purpose: a friend edge A->B lives at `users/{B}/friends/{A}`,
 * and this asks the same question, the same way round, as `creatorIsFriendOf()`
 * in `firestore.rules`. Asking it the other way round would test whether the
 * CHILD has added the adult, which is not the protection.
 */
export async function readInviterFriendships(
  db: admin.firestore.Firestore,
  minorUids: string[],
  inviterUid: string | null,
): Promise<Record<string, boolean>> {
  const out: Record<string, boolean> = {};
  if (!inviterUid || minorUids.length === 0) return out;
  const refs = minorUids.map((u) => db.doc(`users/${u}/friends/${inviterUid}`));
  const snaps = await db.getAll(...refs);
  snaps.forEach((snap, i) => {
    out[minorUids[i]] = snap.exists;
  });
  return out;
}

/**
 * The per-member variant, for the backstop trigger: each minor is checked
 * against whoever actually seated THEM, not against one shared inviter.
 *
 * A minor whose recorded adder is missing or malformed gets no entry, which
 * `computeBlockedMembers` reads as "no identifiable inviter" and fails safe on.
 */
export async function readAdderFriendships(
  db: admin.firestore.Firestore,
  minorUids: string[],
  adderOf: (uid: string) => string | null,
): Promise<Record<string, boolean>> {
  const out: Record<string, boolean> = {};
  const pairs = minorUids
    .map((uid) => ({ uid, adder: adderOf(uid) }))
    .filter((p): p is { uid: string; adder: string } => isValidDocId(p.adder));
  if (pairs.length === 0) return out;
  const snaps = await db.getAll(
    ...pairs.map((p) => db.doc(`users/${p.uid}/friends/${p.adder}`)),
  );
  snaps.forEach((snap, i) => {
    out[pairs[i].uid] = snap.exists;
  });
  return out;
}

/**
 * The gate itself: reads what it needs and returns the uids that may NOT be
 * added. An empty array means every candidate is admissible.
 *
 * Callers must treat a non-empty result as a refusal of the WHOLE operation, not
 * as a list to quietly drop. Dropping silently is what the old trigger did — it
 * had no choice, running after the write — and it is why a minor could be added
 * and evicted without anyone being told. At invite time we can answer the person
 * doing the inviting instead.
 *
 * Malformed candidate uids are refused rather than filtered: at invite time
 * there is a human waiting for an answer, so a payload we cannot reason about is
 * a client bug worth surfacing, not something to silently shrink. (The trigger
 * filters instead, because by then the write has already happened and dropping
 * a junk entry is the only move that keeps it from stranding.)
 */
export async function findInadmissibleMembers(
  db: admin.firestore.Firestore,
  inviterUid: string | null,
  candidates: string[],
): Promise<string[]> {
  const targets = candidates.filter((u) => u !== inviterUid);
  if (targets.length === 0) return [];
  const malformed = targets.filter((u) => !isValidDocId(u));
  if (malformed.length > 0) return malformed;
  const isMinor = await readIsMinor(db, targets);
  const minorUids = targets.filter((u) => isMinor[u]);
  const inviterIsFriendOf = await readInviterFriendships(
    db,
    minorUids,
    inviterUid,
  );
  return computeBlockedMembers({
    candidates: targets,
    inviterOf: () => inviterUid,
    isMinor,
    inviterIsFriendOf,
  });
}
