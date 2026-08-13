/**
 * Uid safety for BOTH uses: as a document id (`users/${uid}`) AND as a
 * FIELD-PATH segment (`participantDisplayNames.${uid}`).
 *
 * Moved out of `messaging/enforce-group-minor-membership.ts` by BUT-1838, which
 * gave it importers in `groups/` while that file needed to import FROM `groups/`
 * — a require cycle that resolves at module-init time in CommonJS and is exactly
 * the kind of thing that works locally and throws on a cold start. Neutral home,
 * no cycle. The reasoning below is unchanged.
 */

/**
 * True only for a uid this repo can safely use BOTH ways: as a document id
 * (`users/${uid}`) AND as a FIELD-PATH segment
 * (`participantDisplayNames.${uid}`). Those are different constraint sets, and
 * the field-path one is stricter — that is the trap this guards.
 *
 * Why it must be strict: a uid containing a dot or a field-path metacharacter
 * is a legal document id but an ILLEGAL field path. `update()` then rejects it
 * with INVALID_ARGUMENT (grpc 3, NOT the NOT_FOUND 5 handled below), which
 * `retry: true` replays deterministically forever while the minor is never
 * removed — the child-safety gate fails OPEN, in exactly the tampered-client
 * threat model this trigger exists for. A dotted uid is dangerous even when it
 * does NOT throw: `participantDisplayNames.a.b` addresses a NESTED map rather
 * than the literal key "a.b", so the removed minor's name and avatar would
 * survive the cut.
 *
 * Real Firebase Auth uids are alphanumeric, so rejecting these forms drops only
 * entries that cannot correspond to a real account (and which therefore confer
 * no membership — the rules test `uid in participantIds`).
 */
export function isValidDocId(v: unknown): v is string {
  return (
    typeof v === "string" &&
    v.length > 0 &&
    v !== "." &&
    v !== ".." &&
    !/^__.*__$/.test(v) &&
    // "/" breaks the doc path; ".[]*`" break the field path. Rejecting the
    // union keeps the uid safe for both uses.
    !/[/.[\]*`]/.test(v) &&
    // Bytes, not characters: the 1500-byte doc-id cap is busted by a multibyte
    // uid at ~500 chars. Only "" and "/" throw client-side; the rest of these
    // forms are rejected by the BACKEND when getAll() runs, which under
    // retry:true is a deterministic error that repeats forever.
    Buffer.byteLength(v, "utf8") <= 1500
  );
}
