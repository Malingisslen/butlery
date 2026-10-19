import * as admin from "firebase-admin";
import { commitInChunks } from "../../shared/batch-update";
import { batchDeleteAll } from "./core";

/**
 * BUT family Phase 5 item 15 — family-rating data, with the §5b edge cases.
 *
 * A household is shared, so deletion is not a blanket wipe:
 *  - **Last member leaves** (no one remains after the user departs): delete the
 *    whole household — its diner profiles, ALL family ratings, and the household
 *    doc. Nothing is left orphaned.
 *  - **Other members remain:** remove the departing user from the household
 *    membership, delete only THEIR own verdicts (`memberId == uid`), **re-home**
 *    any diner profiles they created to a remaining member (never orphan a
 *    child profile — §5b), reassign `createdBy` if it was theirs, and scrub the
 *    proxy attribution (`enteredByUid`) on verdicts they entered for others so
 *    no rating points at a deleted user.
 *
 * The guardian-consent record on a re-homed profile is left historical (it
 * attests who actually consented). Parent-vs-parent custody disputes are out of
 * scope (§5b Condition 8 — Butlery is not the arbiter).
 *
 * Idempotent: re-running deletes the same own-verdicts, re-applies the same
 * membership scrub (arrayRemove/field delete), and re-homes already-re-homed
 * profiles to the same remaining member.
 */
export async function deleteFamilyData(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const households = await db
    .collection("households")
    .where("memberUserIds", "array-contains", uid)
    .get();

  for (const hhDoc of households.docs) {
    const data = hhDoc.data();
    const hid = hhDoc.id;
    const memberUserIds = Array.isArray(data.memberUserIds)
      ? (data.memberUserIds as unknown[]).filter((id) => typeof id === "string")
      : [];
    const remaining = (memberUserIds as string[]).filter((id) => id !== uid);
    // BUT-2267: a household linked to the erased user's own group ends the way
    // `onHouseholdGroupWritten` ends it when that group is deleted — the
    // others removed, their shares deleted — and the erased owner was its
    // last member, so it is torn down. Same end state whichever runs first;
    // never re-pointed to a joined `view` member.
    const ownsGroupLink = data.createdBy === uid &&
      data.sourceGroupOwnerId === uid;

    if (remaining.length === 0 || ownsGroupLink) {
      // Shares first, and awaited: once the household doc is gone a retry
      // cannot find these rows again.
      for (let i = 0; ownsGroupLink && i < remaining.length; i += 400) {
        const batch = db.batch();
        for (const id of remaining.slice(i, i + 400)) {
          batch.delete(db.collection("household_allergen_shares")
            .doc(`${hid}_${id}`));
        }
        await batch.commit();
      }
      // Sole member → tear the whole household down. Delete children with
      // strict:true so a failed chunk THROWS (→ family_data marked failed →
      // household doc NOT deleted → uid stays in memberUserIds → the retry
      // re-matches and re-attempts). Losing the household handle would strand
      // unreachable child PII, so here failing loudly beats partial cleanup.
      const [diners, allRatings] = await Promise.all([
        db.collection("diner_profiles").where("householdId", "==", hid).get(),
        db.collection("family_ratings").where("householdId", "==", hid).get(),
      ]);
      const childDocs = [...diners.docs, ...allRatings.docs];
      if (childDocs.length > 0) {
        await commitInChunks(
          db,
          childDocs,
          (batch, doc) => batch.delete(doc.ref),
          { label: "deleteFamilyHousehold", strict: true },
        );
      }
      await hhDoc.ref.delete();
      continue;
    }

    // Others remain. RETRY-SAFETY ORDERING: every child mutation below is keyed
    // on householdId + field equality (independent of uid's array membership),
    // so it re-runs cleanly on retry — AS LONG AS the household membership scrub
    // (which removes uid from the re-entry query) is the LAST mutation. Do not
    // reorder the household update above the child cleanup.

    // 1. Delete only the departing user's own verdicts.
    const ownRatings = await db
      .collection("family_ratings")
      .where("householdId", "==", hid)
      .where("memberId", "==", uid)
      .get();
    await batchDeleteAll(db, ownRatings.docs);

    // 2. Re-home diner profiles the departing user created (never orphan — §5b).
    const myDiners = await db
      .collection("diner_profiles")
      .where("householdId", "==", hid)
      .where("createdBy", "==", uid)
      .get();
    if (myDiners.docs.length > 0) {
      await commitInChunks(
        db,
        myDiners.docs,
        (batch, doc) => batch.update(doc.ref, { createdBy: remaining[0] }),
        { label: "rehomeDinerProfiles", strict: false },
      );
    }

    // 3. Scrub proxy attribution on verdicts they entered FOR OTHER members so
    // no rating is left pointing at a deleted user (own verdicts already gone).
    const enteredByMe = await db
      .collection("family_ratings")
      .where("householdId", "==", hid)
      .where("enteredByUid", "==", uid)
      .get();
    const proxyForOthers = enteredByMe.docs.filter(
      (d) => d.data().memberId !== uid,
    );
    if (proxyForOthers.length > 0) {
      await commitInChunks(
        db,
        proxyForOthers,
        (batch, doc) => batch.update(doc.ref, { enteredByUid: "deleted" }),
        { label: "scrubProxyAttribution", strict: false },
      );
    }

    // 4. LAST: remove them from the household; re-point createdBy if theirs.
    // This is the only mutation that changes the re-entry query, so it runs claim-lint:ok moved unchanged, BUT-2113
    // after all child cleanup — a transient failure above leaves uid in
    // memberUserIds and the retry re-discovers everything.
    const members = Array.isArray(data.members)
      ? (data.members as unknown[])
          .filter((m) => m && typeof m === "object")
          .map((m) => ({ ...(m as Record<string, unknown>) }))
          .filter((m) => m.userId !== uid)
      : [];
    const newCreatedBy = data.createdBy === uid ? remaining[0] : data.createdBy;
    // BUT-2267: a household linked to the erased user's group names them in
    // `sourceGroupOwnerId`. The group goes with them, so the link does too.
    const ownGroupLink = data.sourceGroupOwnerId === uid ? {
      sourceGroupId: admin.firestore.FieldValue.delete(),
      sourceGroupOwnerId: admin.firestore.FieldValue.delete(),
    } : {};
    await hhDoc.ref.update({
      members,
      memberUserIds: admin.firestore.FieldValue.arrayRemove(uid),
      [`memberPermissions.${uid}`]: admin.firestore.FieldValue.delete(),
      createdBy: newCreatedBy,
      ...ownGroupLink,
    });
  }
  return true;
}
