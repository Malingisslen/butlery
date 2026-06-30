# Moderation Runbook

Operational guide for Butlery admins actioning user-submitted reports.
Meets Apple App Store guideline 1.2 and Google Play UGC policy, both of
which require a 24-hour SLA for acting on reported content.

## Seeding an admin UID

Admins are identified by the presence of a document at `admins/{uid}`.
The collection is write-locked at the rules layer; entries must be seeded
server-side.

1. Open Firebase Console -> Firestore -> `admins` collection (create if
   absent).
2. Click "Add document". Document ID is the admin's Firebase Auth UID
   (find it under Authentication -> Users).
3. Body can be empty `{}`, or include bookkeeping fields:
   - `addedBy` (string, optional) - UID of the founder seeding the doc.
   - `addedAt` (timestamp, optional) - when the grant was made.
4. Save. The new admin will see the "Review reports" tile appear in
   Settings within seconds (stream-driven).

To revoke admin rights, delete the document. All admin powers lapse
immediately because every rule re-evaluates `exists(admins/{uid})` on
each request.

## Actioning a report

1. Open the app, go to Settings -> "Review reports" (the tile only
   renders for admins).
2. You will see the list of open reports (status != `closed`), newest
   first. Each card shows:
   - Content type and target content ID.
   - Status pill (`new`, `in_review`, `actioned`).
   - Reporter UID and free-text reason.
3. Decide per report:
   - **Advance** - moves the status one step forward along
     `new -> in_review -> actioned -> closed`. Transitions are
     forward-only; rules reject backward moves.
   - **Delete content** - calls the collection-appropriate delete.
     Admin-override rules permit delete on `recipes` (under
     `users/{ownerId}/recipes`), `recipe_comments`, `messages`,
     `recipe_ratings` and `cook_snaps`.
   - **Close report** - skips to `closed` without touching the target
     (used for spam/duplicate reports).
4. Once a report is `closed` it leaves the list.

Typical turnaround: under 24 hours from report creation to action.

## SLA notes (Apple 1.2 / Google Play UGC)

- Apple guideline 1.2 requires "a method for filtering objectionable
  material" and "the ability to block abusive users", and expects
  moderation within 24 hours.
- Google Play's UGC policy requires "a user-accessible in-app system
  for reporting" and "action against users or UGC that violates the
  app's terms".

Both are satisfied by this flow:
- In-app report entry points exist for recipes, comments, messages,
  cook snaps, profiles and ratings.
- This runbook plus the in-app moderator screen closes the 24-hour
  action loop.
- The `Settings -> Appeal a removal` mailto (and ToS section 6.1)
  satisfies Google Play's appeal requirement.

## Rollback procedure

Content deletes via the admin review screen are hard deletes at the
Firestore layer - no soft-delete flag today. Before using **Delete
content** on anything high-risk, consider:

1. **Recipes** - the owner's local Hive cache may still hold a copy;
   they can re-import from backup until it syncs.
2. **Messages / comments / ratings** - no recovery once deleted.
   Prefer **Advance** then manual contact via support@butlery.se if the
   admin is unsure.
3. **Cook snaps** - the Storage image is garbage-collected by the
   `cleanup-recipe-storage` Cloud Function shortly after. Deletions in
   the first minutes may still be recoverable by an ops engineer with
   Storage console access.

There is no "undo" button. If a content deletion was made in error:

1. Ask the affected user (via overklagande@butlery.se) to re-submit the
   content.
2. If re-submission is not possible, file an incident in Linear tagged
   `moderation-rollback` describing the mistake and the user.
3. For recipes specifically, check Firestore's PITR (point-in-time
   recovery) snapshots - retention window is seven days once PITR
   lands in production (see BUT-608 / BUT-546).

## Audit trail

Every report creation triggers a `system_events` document of type
`content_report`. If the reported user passes the five-reports
threshold, a `moderation_threshold_reached` event is also written.
Admin actions (status transitions, deletes) currently rely on
Firestore's built-in audit logs only; a richer moderator-action log is
tracked in a follow-up ticket.

## Email notifications

The `onReportCreated` Cloud Function reads `MODERATOR_EMAIL` from the
function environment. Until the email-delivery infra lands, it logs the
payload at `info` level - set a Cloud Logging alert on the log filter
`resource.type="cloud_function" AND jsonPayload.message:"moderation-email:TODO"`
to page the on-call admin.
