import * as admin from "firebase-admin";
import { commitInChunks } from "../../shared/batch-update";
import { Collections } from "../../shared/collections";
import { batchDeleteAll } from "./core";

export async function deleteWeeklyMenuPlans(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const owned = await db
    .collection("weekly_menu_plans")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, owned.docs);

  // Scrub uid from group plans. If a plan ends up empty, delete it.
  //
  // The deleter must be a superset of every probe leg, and of every field the
  // EXPORT discovers on. `firestore.rules` puts
  // no conjunct on `lastModifiedBy`, and its update limb lets an admin rewrite
  // the roster, so a document can name this uid as its last writer while the
  // roster query cannot reach it. One handle would leave that document
  // un-erasable AND leave the audit reporting `gdprCompliant: false` forever,
  // with no code path able to clear it.
  const [byRoster, byWriter, byPermission, byContributor] = await Promise.all([
    db
      .collection(Collections.groupWeeklyMenuPlans)
      .where("participantUserIds", "array-contains", uid)
      .get(),
    db
      .collection(Collections.groupWeeklyMenuPlans)
      .where("lastModifiedBy", "==", uid)
      .get(),
    // The ACL key itself. `exportPlansForParticipant` discovers on THIS field,
    // and the export must never reach a document the erasure cannot: an admin
    // may update `memberPermissions` alone, so a uid can sit here as a map key
    // — which is what grants read access — while the roster array does not
    // name them.
    db
      .collection(Collections.groupWeeklyMenuPlans)
      .where(new admin.firestore.FieldPath("memberPermissions", uid), "!=", null)
      .get(),
    // The contributor trail. `removeChatGroupMember` takes a leaving member out
    // of `participants` and therefore out of both projections above, while
    // their uid stays on the dishes and in the trail (Malin, 2026-08-30).
    // Leaving a group is the ordinary case, so this leg is what reaches such a
    // document.
    db
      .collection(Collections.groupWeeklyMenuPlans)
      .where("contributorUserIds", "array-contains", uid)
      .get(),
  ]);
  const byPath = new Map<string, admin.firestore.QueryDocumentSnapshot>();
  for (const doc of [
    ...byRoster.docs,
    ...byWriter.docs,
    ...byPermission.docs,
    ...byContributor.docs,
  ]) {
    byPath.set(doc.ref.path, doc);
  }
  const groupPlanDocs = [...byPath.values()];
  if (groupPlanDocs.length > 0) {
    await commitInChunks(
      db,
      groupPlanDocs,
      (batch, doc) => {
        const data = doc.data();
        const participantsRaw = data.participants;
        const participants = Array.isArray(participantsRaw)
          ? participantsRaw
              .filter((m) => m && typeof m === "object")
              .map((m) => ({ ...(m as Record<string, unknown>) }))
              .filter((m) => m.userId !== uid)
          : [];
        const participantsLength = Array.isArray(participantsRaw)
          ? participantsRaw.filter((m) => m && typeof m === "object").length
          : 0;
        const userIdsRaw = data.participantUserIds;
        // Falls back to the SURVIVORS, not to empty: if the queryable mirror
        // is missing or malformed while `participants` still holds the other
        // members, an empty fallback would drop them. A shape `toFirestore`
        // cannot produce, closed rather than accepted because the cost is one
        // expression.
        // True whenever `participants` NAMED this uid — the ordinary case for a
        // real participant, not an exception. Named for what it measures: an
        // earlier version called it `rostersDisagree`, which read as rare and
        // hid that the derive branch below is the default path.
        const participantsNamedUid = participants.length !== participantsLength;
        // The RAW mirror's survivors, kept separate and never derived. It is
        // the second, independent witness the destructive gate below needs: the
        // moment `userIds` becomes a function of `participants`, that gate
        // collapses to one check and a mirror-only survivor stops protecting
        // the document.
        const mirrorSurvivors = Array.isArray(userIdsRaw)
          ? (userIdsRaw as unknown[]).filter((id) => id !== uid)
          : [];
        // `contributorUserIds` is a DISCOVERY handle only, and deliberately not
        // a witness on the destructive gate below. It was one for part of this
        // build, and that was wrong: a contributor is not a READER. Every limb
        // of this collection gates on `memberPermissions`, so blocking the
        // delete on a departed contributor leaves a document with an empty
        // permission map — one nobody can read, write, re-plan or delete, on a
        // deterministic id that poll-close will mint again. Reachable by
        // ordinary churn once leaving cuts the roster: B leaves, then A deletes claim-lint:ok moved unchanged, BUT-2113
        // their account, and B is the only contributor left. claim-lint:ok moved unchanged, BUT-2113
        //
        // `cutGroupMenuPlanAccess` already decided this shape: a week no one
        // can open is deleted rather than left standing, because the provenance
        // it preserves is unreachable by everyone. The two files must not give
        // opposite answers about the same document.
        //
        // The three witnesses that remain are the ones that name READERS.
        const userIds =
          Array.isArray(userIdsRaw) && !participantsNamedUid
            ? mirrorSurvivors
            : participants
              .map((m) => m.userId)
              // `userId` is `unknown` here, and `WriteBatch.update()` validates
              // synchronously — `commitInChunks` calls its mutator OUTSIDE the
              // chunk's try, so an undefined element would abort the whole step
              // rather than one chunk.
              .filter((id): id is string => typeof id === "string");
        // `wasParticipant` gates the delete: a document reached only by the
        // writer handle has a roster this user was never on, and an empty
        // result there means "malformed", not "nobody left".
        const wasParticipant =
          Array.isArray(userIdsRaw) && (userIdsRaw as unknown[]).includes(uid);
        // Both rosters must be empty, not just the queryable one. The mirror
        // can name only this uid while `participants` still holds another
        // member — the same desync as the rescue limb below, seen from the
        // other side — and deleting then loses that member's week. A shape
        // `toFirestore` cannot produce, closed because the failure is
        // destructive rather than a leftover.
        if (
          userIds.length === 0 &&
          mirrorSurvivors.length === 0 &&
          participants.length === 0 &&
          wasParticipant
        ) {
          batch.delete(doc.ref);
        } else {
          // BUT-1971: the participant lists are not the only place this uid claim-lint:ok moved unchanged, BUT-2113
          // sits on a group plan. Provenance on each dish
          // (`proposedBy`/`votedInBy`), the edit trail, and the document-level
          // `lastModifiedBy` all carry it, and the interactive screen stamps
          // that last one on every remove and undo — so a departing member is
          // routinely the last writer. Enumerate `toFirestore` when this model
          // grows a field rather than trusting this list.
          //
          // All of them are scrubbed from the SAME `data` snapshot and in the
          // SAME batch.update as the rosters: a second query or a second pass
          // would read a document this batch is already rewriting.
          //
          // Only this branch needs it; the other deletes the whole document.
          const entriesRaw = data.entries;
          const entries = Array.isArray(entriesRaw)
            ? entriesRaw
                .filter((e) => e && typeof e === "object")
                .map((e) => {
                  const entry = { ...(e as Record<string, unknown>) };
                  if (entry.proposedBy === uid) delete entry.proposedBy;
                  const voted = entry.votedInBy;
                  if (Array.isArray(voted)) {
                    const kept = (voted as unknown[]).filter((v) => v !== uid);
                    if (kept.length === 0) {
                      delete entry.votedInBy;
                    } else {
                      entry.votedInBy = kept;
                    }
                  }
                  return entry;
                })
            : [];
          // Two positions, two different answers, because a row can be about
          // TWO people. A row the departing user WROTE is theirs and goes. A row
          // somebody else wrote ABOUT their dish is that other member's own
          // attribution — the thing ADR-0010 restored the trail for — so it
          // stays and only the departing uid is stripped out of it.
          const entriesChanged =
            JSON.stringify(entries) !== JSON.stringify(entriesRaw ?? []);
          const trailRaw = data.editTrail;
          const editTrail = Array.isArray(trailRaw)
            ? trailRaw
                .filter((r) => r && typeof r === "object")
                .filter((r) => (r as Record<string, unknown>).actorId !== uid)
                .map((r) => {
                  const row = { ...(r as Record<string, unknown>) };
                  if (row.subjectId === uid) delete row.subjectId;
                  return row;
                })
            : [];
          const trailChanged =
            JSON.stringify(editTrail) !== JSON.stringify(trailRaw ?? []);
          batch.update(doc.ref, {
            // Scoped to the handle that found this document, for the same
            // reason the arrays below are: a plan reached only by the writer
            // handle has a roster this user was never on, and rewriting it from
            // a deletion-time snapshot can blank it or lose a concurrent edit.
            // Also when `participants` named this uid while the queryable
            // mirror did not: such a document is found by the ACL handle, and
            // no probe leg can see inside an array of maps.
            ...(wasParticipant || participantsNamedUid
              ? { participants, participantUserIds: userIds }
              : {}),
            // Only when the document already had them, and only when this uid
            // was actually in them: `toFirestore` omits both when empty, so
            // writing `[]` unconditionally would invent a shape no writer
            // produces, and rewriting an untouched array widens the
            // read-modify-write window over plans this user never edited.
            ...(Array.isArray(entriesRaw) && entriesChanged ? { entries } : {}),
            ...(Array.isArray(trailRaw) && trailChanged ? { editTrail } : {}),
            // A non-list value is skipped by the scrub above, so a uid inside
            // one would never be erased. The rules cap is `.size()`, which is
            // polymorphic — a 50-key map is accepted — so the shape is
            // reachable. Deleted outright: no writer produces it.
            ...(trailRaw !== undefined && !Array.isArray(trailRaw)
              ? { editTrail: admin.firestore.FieldValue.delete() }
              : {}),
            ...(entriesRaw !== undefined && !Array.isArray(entriesRaw)
              ? { entries: admin.firestore.FieldValue.delete() }
              : {}),
            // Tombstoned, not deleted: every sibling attribution field in
            // this file uses "deleted", and the Dart reader takes it as a
            // nullable string either way.
            ...(data.lastModifiedBy === uid ? { lastModifiedBy: "deleted" } : {}),
            [`memberPermissions.${uid}`]: admin.firestore.FieldValue.delete(),
            // The contributor trail is a list of uids, so it is erasable data
            // in its own right, not just a handle. `arrayRemove` rather than a
            // rewritten array: the client-facing rule refuses a write that
            // drops an entry, and only the Admin SDK — which bypasses rules —
            // may take one out. Unconditional, like the ACL key above.
            contributorUserIds:
              admin.firestore.FieldValue.arrayRemove(uid),
          });
        }
      },
      { label: "scrubGroupWeeklyMenuPlans", strict: false },
    );
  }
  return true;
}

export async function deletePantryItems(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db.collection("users").doc(uid).collection("pantry").get();
  await batchDeleteAll(db, snap.docs);
  return true;
}
