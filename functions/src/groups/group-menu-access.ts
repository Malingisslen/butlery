/**
 * BUT-2005: cutting a departing member's access to a group's weekly menu plans.
 *
 * Extracted from `remove-chat-group-member.ts`, which was its only caller until
 * now. Two more paths remove somebody from a chat group and left this untouched:
 * the child-safety backstop (`messaging/enforce-group-minor-membership.ts`) and
 * the category sync's eviction loop (`ensure-category-chat.ts`). A minor evicted
 * for their own protection kept read AND write access to the group's menu.
 *
 * Extraction alone does not stop a FUTURE removal path from forgetting to call
 * this — each call site remembering an import is the same shape that
 * produced this ticket. What it buys is one implementation to fix and one place
 * to read.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";

/**
 * Not a
 * capacity estimate: the create rule ties a writer only to their own submitted
 * `memberPermissions`, so any signed-in account can plant rows carrying another
 * group's `groupId`, and the row count is therefore chosen by a hostile writer
 * rather than by us.
 */
export const MAX_GROUP_MENU_PLANS = 500;

/** The same 50 the client prunes to and `firestore.rules` bounds. */
export const MAX_TRAIL_ROWS = 50;

/** The same 200 `groupMenuContributorsWithinCap` bounds. */
export const MAX_CONTRIBUTOR_UIDS = 200;

/**
 * BUT-1971 follow-up: a member who LEAVES a group that still has other members
 * keeps read AND write access to every week that existed while they were in it,
 * because `firestore.rules` gates `group_weekly_menu_plans` on
 * `memberPermissions` alone and nothing ever took them out of it. Malin's call,
 * 2026-08-31: cut both.
 *
 * The cut is "remove them from `participants`", because the two fields the
 * rules actually read — `participantUserIds` and `memberPermissions` — are
 * PROJECTIONS the Dart model recomputes from `participants` on every client
 * write. Editing only the projections would work until the next `save()`
 * regenerated them from the untouched roster and handed the access back.
 *
 * Their uid stays on the dishes and in the trail — Malin's call, 2026-08-30 —
 * so `contributorUserIds` is unioned here in the same write. That array is what
 * account erasure finds the document by once the roster no longer names the
 * person.
 *
 * [groupKey] is the CONVERSATION id, not the `chat_groups` document id:
 * `group_weekly_menu_plans.groupId` stores `conversation.id` (minted by
 * `MessagingService.closePoll`), a misleading field name that
 * `weekly-menu-plans-rules.test.ts` pins.
 *
 * Takes a LIST of departing uids and does one scan and one update per plan
 * document for all of them together. Calling this per uid would multiply an
 * up-to-501-row read plus 500 writes by N against the same group.
 *
 * Must be called OUTSIDE any `db.runTransaction`: it does its own
 * non-transactional reads and chunked writes, so a transaction retry would
 * re-run them.
 *
 * [actorUid] — pass `null` as the actor when there is no human to name — the child-safety
 * backstop is a Firestore trigger with no caller at all. The promotion still
 * happens; only the `editTrail` row is skipped, and the promotion is logged
 * instead so the grant is not unrecorded.
 *
 * **Malin's explicit call, 2026-09-09.** She was shown the alternative — a
 * `"system"` sentinel in `actorId`, keeping the trail complete — and what it
 * costs: that value would be written ONLY by the backstop, on a document every
 * plan participant can read, in the same update that removes the evicted uid
 * from `participants`, with no `memberLeft` row beside it. A member reading a
 * system-actor promotion next to a uid that just vanished has the same durable
 * inference BUT-1856 refused a tombstone to prevent — that this person was
 * evicted automatically, which on this path means protected as a minor.
 *
 * Not exotic: `creatorId` is the plan's sole admin participant and the creator
 * is whoever closed the poll, so an evicted minor who closed it reaches the
 * promotion branch every time.
 *
 * This deviates knowingly, and on this path only, from the rule BUT-1971 set on
 * 2026-08-31: a privilege grant this code makes silently belongs in the trail.
 *
 * A second reason the sentinel was the wrong shape, found by the
 * `integration-reviewer` gate: `GroupWeeklyMenuPlan.contributorUserIdsForWrite`
 * unions every trail row's `actorId` into the erasure handle, which
 * `firestore.rules` makes append-only and caps at 200 — so a non-uid there is
 * permanent, unclearable by any `arrayRemove(uid)`, and consumes a slot for the
 * life of the document. The model already excludes the `'deleted'` tombstone
 * for exactly that reason; a sentinel here would have been a second literal
 * needing the same guard in a fourth language.
 *
 * Never throws, like every other cleanup on these paths: the access cut that
 * matters already happened in the caller's transaction, and failing a removal
 * because this stumbled would be the wrong answer.
 */
export async function cutGroupMenuPlanAccess(
  db: admin.firestore.Firestore,
  groupKey: string,
  departingUids: string[],
  actorUid: string | null,
  logTag: string,
): Promise<void> {
  const departing = [...new Set(departingUids)].filter(
    (u): u is string => typeof u === "string" && u.length > 0,
  );
  if (departing.length === 0) return;
  const departingSet = new Set(departing);

  try {
    // Named fields rather than a field-LESS `.select()`. A bare `.get()` would
    // pull up to 1 MB per row for `entries` it never reads, which is the
    // exposure that makes the cap of 500 safe here. The trail is itself capped
    // at 50 rows by `firestore.rules`.
    //
    // The trail is rewritten WHOLE rather than `arrayUnion`ed, which is a
    // durability choice, not an oversight: a concurrent writer's row can be
    // lost, and that is exactly the contract the trail already ships under
    // (ADR-0010 — the audit row is the reliable record, the trail is the
    // reading aid). `contributorUserIds` gets the opposite treatment below
    // because losing an entry there costs erasability, not legibility.
    const snap = await db
      .collection(Collections.groupWeeklyMenuPlans)
      .where("groupId", "==", groupKey)
      .select(
        "participants",
        "participantUserIds",
        "memberPermissions",
        "editTrail",
        "contributorUserIds",
      )
      .limit(MAX_GROUP_MENU_PLANS + 1)
      .get();
    if (snap.empty) return;
    // Over the cap this CUTS what it read instead of declining, which is the
    // opposite of the sibling sweep's verdict and deliberately so. Declining a
    // DELETE is safe: truncating would half-erase a group. Declining a CUT is
    // not — every row is independent, a partial cut is strictly better than
    // none, and refusing lets anyone plant rows past the cap against this
    // group's id and keep their access after leaving. Nothing retries this
    // step, so a decline is permanent.
    const overflow = snap.size > MAX_GROUP_MENU_PLANS;
    const docs = overflow ? snap.docs.slice(0, MAX_GROUP_MENU_PLANS) : snap.docs;
    if (overflow) {
      logger.error(
        `[${logTag}] implausible group menu plan count; cutting the capped page only`,
        { groupKey, planRows: snap.size, cutting: docs.length },
      );
    }

    const CHUNK = 50;
    let failed = 0;
    let touched = 0;
    let promoted = 0;
    let emptied = 0;
    for (let i = 0; i < docs.length; i += CHUNK) {
      const results = await Promise.allSettled(
        docs.slice(i, i + CHUNK).map(async (d) => {
          const raw = d.get("participants");
          if (!Array.isArray(raw)) return "skipped" as const;
          const rows = raw as Record<string, unknown>[];
          const remaining = rows.filter(
            (r) => r && !departingSet.has(r.userId as string),
          );
          if (remaining.length === rows.length) return "skipped" as const;

          // No admin is left. Promote the lowest remaining uid,
          // deterministically: nothing in the document ranks members, and
          // leaving the plan with no admin means nobody can ever change its
          // membership again. Silent to the promoted member.
          let promotedUid: string | null = null;
          const hasAdmin = remaining.some((r) => r.permission === "admin");
          if (remaining.length > 0 && !hasAdmin) {
            const ids = remaining
              .map((r) => r.userId)
              .filter((u): u is string => typeof u === "string")
              .sort();
            promotedUid = ids[0] ?? null;
            if (promotedUid !== null) {
              for (const r of remaining) {
                if (r.userId === promotedUid) r.permission = "admin";
              }
            }
          }

          const update: Record<string, unknown> = {
            participants: remaining,
            participantUserIds: remaining
              .map((r) => r.userId)
              .filter((u): u is string => typeof u === "string"),
            memberPermissions: Object.fromEntries(
              remaining
                .filter((r) => typeof r.userId === "string")
                .map((r) => [r.userId as string, r.permission ?? "view"]),
            ),
          };

          // Bounded, for the same reason the trail is pruned one branch below:
          // the Admin SDK bypasses `firestore.rules`, so a union past the
          // 200-uid cap would be accepted here and would then refuse every
          // subsequent CLIENT save of that week — the same bricking the emptied
          // roster caused, one field over.
          //
          // At the cap the uid is NOT recorded, and that is the lesser harm
          // rather than a free choice: it costs erasability on one exceptional
          // document, against certainly freezing the week for everyone. Logged
          // at ERROR because nothing retries this step, and that stream is the
          // only signal anywhere that erasability was lost on a document — so
          // the already-present arm is there to keep it from firing about a uid
          // that IS recorded.
          //
          // Measured against the WHOLE departing set rather than one uid: the
          // cap must hold after the union, not before it.
          const knownRaw = d.get("contributorUserIds");
          const known = Array.isArray(knownRaw) ? (knownRaw as unknown[]) : [];
          const unrecorded = departing.filter((u) => !known.includes(u));
          if (
            unrecorded.length === 0 ||
            known.length + unrecorded.length <= MAX_CONTRIBUTOR_UIDS
          ) {
            // The whole departing set, not just the unrecorded part: an
            // `arrayUnion` of a value already present is a no-op, and sending
            // it keeps this branch identical to the one-uid version the
            // "already in a capped array" case pins.
            update.contributorUserIds =
              admin.firestore.FieldValue.arrayUnion(...departing);
          } else {
            logger.error(
              `[${logTag}] contributor trail at cap; uids not recorded`,
              {
                groupKey,
                contributors: known.length,
                unrecorded: unrecorded.length,
              },
            );
          }

          if (promotedUid !== null && actorUid === null) {
            // Promoted, but no trail row: see [cutGroupMenuPlanAccess]'s actor
            // note. Logged so the grant is recorded somewhere, on a stream no
            // group member can read.
            logger.info(`[${logTag}] admin promoted without a trail row`, {
              groupKey,
              planId: d.id,
            });
          }
          if (promotedUid !== null && actorUid !== null) {
            const trailRaw = d.get("editTrail");
            const trail = Array.isArray(trailRaw) ? [...trailRaw] : [];
            trail.push({
              // The ACTOR, not the person leaving. They are the same on a
              // self-leave and different on an admin eviction, where stamping
              // the departing uid would say the person who was removed did the
              // promoting. The accepted risk that a trail row names the wrong
              // person (BUT-1971, 2026-08-30) is about CLIENT forgery and does
              // not cover the server writing a wrong actor — which is why the
              // backstop passes null.
              actorId: actorUid,
              subjectId: promotedUid,
              at: admin.firestore.Timestamp.now(),
              action: "adminPromoted",
            });
            // Pruned to the same 50 the client prunes to and the rules bound.
            // The Admin SDK bypasses rules, so an over-cap array written here
            // would be accepted — and would then refuse every subsequent CLIENT
            // save of that week.
            update.editTrail =
              trail.length > MAX_TRAIL_ROWS
                ? trail.slice(trail.length - MAX_TRAIL_ROWS)
                : trail;
          }

          // An emptied roster is DELETED, not left standing. The plan's roster
          // is a snapshot taken when the week was built and is never re-synced,
          // so a departing member can be the sole participant of an OLD week
          // while the chat group still has members — `remaining === 0` in the
          // caller never fires and no sweep cleans up.
          //
          // Leaving the shell does not merely make the week unreadable: it
          // BRICKS it. `save()` is a whole-document `set()` on the
          // deterministic `{groupId}_{ISO week}` id, which evaluates the UPDATE
          // limb, and every limb of this collection gates on
          // `memberPermissions` — so with an empty map nobody can read, write,
          // re-plan or delete that ISO week ever again, including the
          // poll-close path, which mints the same id.
          //
          // Every roster, not just the one the cut is computed from: a plan
          // whose `participants` names only the leavers while a projection
          // still names somebody else is a desync, and deleting on the one
          // field is destructive.
          const mirrorRaw = d.get("participantUserIds");
          const mirrorSurvivors = Array.isArray(mirrorRaw)
            ? (mirrorRaw as unknown[]).filter(
                (id) => !departingSet.has(id as string),
              )
            : [];
          const permsRaw = d.get("memberPermissions");
          const permSurvivors =
            permsRaw && typeof permsRaw === "object"
              ? Object.keys(permsRaw as Record<string, unknown>).filter(
                  (id) => !departingSet.has(id),
                )
              : [];
          if (
            remaining.length === 0 &&
            mirrorSurvivors.length === 0 &&
            permSurvivors.length === 0
          ) {
            // Preconditioned on the version this step READ. The roster came
            // from a query snapshot, and poll-close mints the same
            // deterministic id — so without this a week re-planned between the
            // read and the delete is destroyed. A lost race throws
            // FAILED_PRECONDITION, which lands in the `failed` counter and the
            // ERROR log below, and the week survives.
            await d.ref.delete({ lastUpdateTime: d.updateTime });
            return "emptied" as const;
          }

          if (remaining.length === 0) {
            // The gate refused the delete, so a projection still names someone.
            // Falling through with `update` as built would rewrite the rosters
            // from an EMPTY `remaining`, and an empty `memberPermissions` fails
            // every limb of this collection — turning a recoverable document
            // into one nobody can read, write, re-plan or delete, on a
            // deterministic id. That is worse than what the gate prevented.
            //
            // Cut the departing uids per key instead, the way the account
            // cascade does, and leave whatever the projections disagree about
            // for a human.
            //
            // The cut is REVOCABLE here, unlike everywhere else in this
            // function: the leavers stay in `participants`, and a client save
            // recomputes both projections from it. Emptying `participants`
            // instead is the brick.
            delete update.participants;
            delete update.participantUserIds;
            delete update.memberPermissions;
            for (const uid of departing) {
              update[`memberPermissions.${uid}`] =
                admin.firestore.FieldValue.delete();
            }
            update.participantUserIds =
              admin.firestore.FieldValue.arrayRemove(...departing);
            logger.error(`[${logTag}] desynced plan rosters; cut per key`, {
              // The doc id, so the human this asks for can find the week
              // without scanning the group. `{groupId}_{ISO week}`, not PII.
              groupKey,
              planId: d.id,
            });
          }
          await d.ref.update(update);
          return promotedUid !== null ? "promoted" : ("updated" as const);
        }),
      );
      for (const r of results) {
        if (r.status === "rejected") {
          failed += 1;
          continue;
        }
        if (r.value === "skipped") continue;
        touched += 1;
        if (r.value === "promoted") promoted += 1;
        if (r.value === "emptied") emptied += 1;
      }
    }

    const payload = {
      groupKey,
      departing: departing.length,
      touched,
      promoted,
      emptied,
      failed,
    };
    if (failed > 0) {
      logger.error(`[${logTag}] group menu access partially cut`, payload);
    } else {
      logger.info(`[${logTag}] group menu access cut`, payload);
    }
  } catch (e) {
    logger.error(`[${logTag}] group menu access cut failed`, {
      groupKey,
      errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
      errName: (e as Error | null)?.name,
    });
  }
}
