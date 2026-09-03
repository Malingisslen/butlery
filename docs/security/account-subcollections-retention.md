# `users/{uid}` subcollections — Art. 30 Record & Export Treatment

GDPR Article 30 record of processing for the personal `users/{uid}` subcollections the
account-deletion cascade erases, and their data-subject-access (Art. 15) export treatment.
Companion to `notification-analytics-retention.md`, `family-data-retention.md` and
`audit-logs-retention.md`. Sources: BUT-1957 (2026-09-02), BUT-1992 (2026-09-03).

Art. 30 records PROCESSING, not export status, so every collection below has a row here
whether or not it is exported.

## Collections with a live writer

| Collection | Contents | Purpose | Written by | Art. 15 |
|---|---|---|---|---|
| `ingredients` | The user's own ingredient entries | Their personal ingredient library | `firebase_user_ingredient_repository.dart` | **Exported** |
| `onboarding` | Progress flags through first-run setup | Resume onboarding where the user left off | `onboarding_progress_service.dart` | **Exported** |
| `acquisition` | Install attribution: source, medium, campaign, first-seen stamp | Growth measurement (BUT-612) | `firebase_acquisition_repository.dart` | **Exported, unprojected** |
| `rate_limits` | One timestamp per rate-limited action | Anti-abuse throttling | `firebase_activity_event_repository.dart` and others | **Exempt** |
| `counters` | Unread-badge totals over shared content | Render unread badges | `base_shared_content_repository.dart` | **Exempt** |
| `report_throttle` | Cooldown between abuse reports | Anti-abuse throttling | `firebase_report_repository.dart` | **Exempt** |

## Collections with no live writer

`category_memberships`, `connection_tests`, `unified_recipes`, the `users/{uid}/conversations`
SUBCOLLECTION, `users/{uid}/fcm_tokens`, `users/{uid}/user_shared_menus` and
`users/{uid}/user_shared_shopping_lists`.

Nothing in `lib/` or `functions/src` writes these paths today. They stay in the cascade's
`subs` list because an account predating their removal can still hold rows, and by the
superset rule those rows would otherwise be reported as residual forever with no step able to
clear them.

Several are named after a live TOP-LEVEL collection holding different data —
`conversations` and `user_shared_menus` exactly, `fcm_tokens` one word off `user_fcm_tokens`.
Those top-level collections have their own export sections. Do not read the similar name as
the same data; that confusion is what BUT-1990 cost a round on.

## Lawful basis

Contract (Art. 6(1)(b)) for `ingredients` and `onboarding`: they are the service the user
signed up for. Legitimate interests (Art. 6(1)(f)) for `rate_limits`, `counters`,
`report_throttle` and `acquisition` — service integrity and growth measurement respectively.

## Retention

Erased on account deletion by `deleteUserSubcollections` in
`functions/src/account/account-deletion-cascade.ts`. No TTL policy applies.

⚠ `firestore.indexes.json` declares `expireAt` collection-group TTLs whose ids collide with
`ingredients` and `rate_limits`. Whether user-scoped documents carry that field is unmeasured
and tracked as BUT-1996 — a TTL armed over a user's own ingredient library would delete
content this register says is retained until account deletion.

## Art. 15 export treatment

The three exported collections ship as the `account_subcollections` bundle section
(`PreferencesExportManager.exportAccountSubcollections`), each with an explicit row cap and
ownership-scoped through `FirebaseDataExportRepository._guardSelfExport`.

`acquisition` is exported UNPROJECTED, including the campaign name. That was Malin's explicit
call on 2026-09-03 against a product objection that it reads as surprising; the campaign name
must not be stripped later without reopening ADR-0011.

Each exempt collection is named in that section's own `data_minimisation` text, so the
data subject can see that it is held. An exemption the subject cannot see is an undisclosed
gap rather than a minimisation decision (Art. 12(1), the BUT-1971 precedent).

`report_throttle` was **not** put to Malin — it was not among the three questions she was
asked. Nor is it the same shape as `rate_limits`, despite sitting beside it: its doc id is the
REPORTED user's uid (`contentOwnerId`), where `rate_limits` ids are operation names. What
makes it exempt is that the reports themselves ARE exported (`reports` where
`reporterId == uid`, each already carrying `contentOwnerId`), so the throttle adds only a
derived recency stamp on top of rows the subject already receives.

## The invariant, and what holds it

EXPORT ⊇ DELETION: anything in the cascade's `subs` list must have been obtainable by its
subject first. Collections erased by their own tier steps are outside what this ranges over —
the sibling guard proves those have a DELETER, not an export. Held by `scenario_exportCoversEveryDeletedSubcollection` in
`functions/src/__tests__/account-deletion-cascade.test.ts`, which derives both halves from
source — the cascade's `subs` list and the export repository's
`.collection(users).doc(uid).collection(X)` chains — and reddens on any name that is neither
exported nor listed in `EXPORT_EXEMPT` with a written reason.

Its counterpart, `scenario_everyUserSubcollectionHasADeleter`, holds DELETION ⊇ WRITERS.

**Named residual:** that suite runs on a `functions/src` diff, while the change most likely to
break the invariant is Dart-only — a repository starting to write a new subcollection, or an
export section being deleted. Until the commit gate runs it on a `lib/` diff too, the guard is
asleep for exactly that case (BUT-2002).
