# `users/{uid}` subcollections — Art. 30 Record & Export Treatment

GDPR Article 30 record of processing for the personal `users/{uid}` subcollections the
account-deletion cascade erases, and their data-subject-access (Art. 15) export treatment.
Companion to `notification-analytics-retention.md`, `family-data-retention.md` and
`audit-logs-retention.md`. Sources: BUT-1957 (2026-09-02), BUT-1992 (2026-09-03), BUT-1917/BUT-2018 (2026-09-09).

Art. 30 records PROCESSING, not export status, so every collection below has a row here
whether or not it is exported.

## Collections with a live writer

| Collection | Contents | Purpose | Written by | Art. 15 |
|---|---|---|---|---|
| `ingredients` | The user's own ingredient entries | Their personal ingredient library | `firebase_user_ingredient_repository.dart` | **Exported** |
| `onboarding` | Progress flags through first-run setup | Resume onboarding where the user left off | `onboarding_progress_service.dart` | **Exported** |
| `acquisition` | Install attribution: source, medium, campaign, first-seen stamp | Growth measurement (BUT-612) | `firebase_acquisition_repository.dart` | **Exported, unprojected** |
| `rate_limits` | Burst stamps (a timestamp and the key of the guarded write, bounded by the rules to expire within 4 days, ADR-0020), import usage counters, a one-time migration flag | Anti-abuse throttling | `firebase_activity_event_repository.dart` and others | **Exempt** |
| `counters` | Unread-badge totals over shared content | Render unread badges | `base_shared_content_repository.dart` | **Exempt** |
| `report_throttle` | Cooldown between abuse reports | Anti-abuse throttling | `firebase_report_repository.dart` | **Exempt** |
| `block_mirror` | The uids of everyone who has blocked this user, in one `current` document | Let `firestore.rules` refuse a blocked person's poll vote without a per-participant read of `blocks` | `sync-block-mirror.ts` (Admin SDK only; every client write is denied) | **Exempt** |

## Collections with no live writer

`category_memberships`, `connection_tests`, `unified_recipes`, the `users/{uid}/conversations`
SUBCOLLECTION, `users/{uid}/fcm_tokens`, `users/{uid}/rateLimits` (the pre-rename spelling of
`rate_limits`, exempt by inheritance — ADR-0011, BUT-2040), `users/{uid}/user_shared_menus` and
`users/{uid}/user_shared_shopping_lists`.

Nothing in `lib/` or `functions/src` writes these paths today. They stay in the cascade's
`subs` list because an account predating their removal can still hold rows, and by the
superset rule those rows would otherwise be reported as residual forever with no step able to
clear them.

Several are named after a live TOP-LEVEL collection holding different data —
`conversations` and `user_shared_menus` exactly, `fcm_tokens` one word off `user_fcm_tokens`.
Those top-level collections have their own export sections. Do not read the similar name as
the same data; that confusion is what BUT-1990 cost a round on.

## Removed collection

`conversation_memberships` — an inverse index of a user's conversations, written on every
participant-add. Removed 2026-09-17 (BUT-1850, Malin's call):
the client writer, the model and the `firestore.rules` block are gone, so no new row can be
created and no client could read one if it were.

It is listed separately from the section above on purpose. Those collections are still
readable and merely have no writer; this one has no rules block at all, so a row surviving the
deploy is reachable by the Admin SDK only. Its `EXPORT_EXEMPT` entry says so in those terms
and deliberately does not use the `NO LIVE WRITER` prefix, which would assert the weaker
state.

It stays in the cascade's `subs` list for one release because that entry is then the only
erasure handle left — `probeResidualData` enumerates, so removing it would leave any row
written in the deploy window counted as residual forever with nothing able to clear it.
**BUT-2109** removes the `subs` entry and the `EXPORT_EXEMPT` entry in the same edit; taking
either alone reddens `scenario_exportCoversEveryDeletedSubcollection`.

Art. 15: no section, and no `data_minimisation` line names it — nothing is withheld, so there
is nothing to disclose. Scoped residual: an account still holding rows written before the
rules deploy has rows that are erasable.

## Lawful basis

Contract (Art. 6(1)(b)) for `ingredients` and `onboarding`: they are the service the user
signed up for. Legitimate interests (Art. 6(1)(f)) for `rate_limits`, `counters`,
`report_throttle` and `acquisition` — service integrity and growth measurement respectively.
Legitimate interests (Art. 6(1)(f)) for `block_mirror` too, on a different interest: the
safety of the person who placed the block, whose choice it enforces.

## Retention

Erased on account deletion by `deleteUserSubcollections` in
`functions/src/account/account-deletion-cascade.ts`.

`block_mirror` takes TWO legs, because the uid appears in two places. Its own row is in
`deleteUserSubcollections`' list, which erases the leaving user's mirror — the list of who
blocked THEM. Their uid inside OTHER people's mirrors is a cross-user sweep,
`deleteBlockMirrors`, which is capped and DECLINES rather than truncating above
`MAX_MIRROR_SWEEP_ROWS`. Deleting only the first leg would leave the uid behind in every
mirror naming it.

⚠ `firestore.indexes.json` declares `expireAt` collection-group TTLs whose ids collide with
`ingredients`. Whether user-scoped documents carry that field is unmeasured
and tracked as BUT-1996 — a TTL armed over a user's own ingredient library would delete
content this register says is retained until account deletion.

## Art. 15 export treatment

The three exported collections ship as the `account_subcollections` bundle section
(`PreferencesExportManager.exportAccountSubcollections`), each with an explicit row cap and
ownership-scoped through `FirebaseDataExportRepository._guardSelfExport`.

`acquisition` is exported UNPROJECTED, including the campaign name. That was Malin's explicit
call on 2026-09-03 against a product objection that it reads as surprising; the campaign name
must not be stripped later without reopening ADR-0011.

An exemption the subject cannot see is an undisclosed gap rather than a minimisation
decision (Art. 12(1), the BUT-1971 precedent), so each exempt collection names where its own
omission is disclosed.

`rate_limits`, `counters` and `report_throttle` are named in that section's own
`data_minimisation` text.

`block_mirror` is not, and that is a decision rather than an oversight. Its omission is
disclosed instead by the BLOCKS section's `data_minimisation` line, which tells the subject
that who has blocked them is left out and why (Art. 15(4)). **Malin's explicit call,
2026-09-09**, over the alternative of naming the mirror in the bundle: the bundle already
withholds that fact and says so, and enumerating our internal copies of it would tell the
subject we keep a list of who blocked whom — a disclosure nobody asked for, on the same fact
BUT-2018 exists to withhold.

`report_throttle` is exempt by **Malin's explicit call, 2026-09-17**, taken over exporting it.
It was not among the three questions ADR-0011 put to her on 2026-09-03 and was decided
separately; that ADR's 2026-09-17 section records what she was shown and what she was not.
Nor is it the same shape as `rate_limits`, despite sitting beside it: its doc id is the
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
