# Family Rating Data — Retention Policy (BUT family Phase 5 item 16)

GDPR Article 30 record covering the `diner_profiles` and `family_ratings`
collections (the household family-rating feature). Mirrors the structure of
[`audit-logs-retention.md`](./audit-logs-retention.md).

## Status

⚠️ **PROPOSED — pending DPO/Legal confirmation.** This feature is launch-gated
on the family-rating DPIA (see project memory and the spec's §8 conditions).
The retention window below is a *defensible proposal* for the DPO to confirm or
adjust; the **active dormancy sweep is intentionally NOT yet deployed** (no
guessed-threshold deleter runs against children's data before Legal signs off,
and there is no production family data pre-launch). The erasure mechanism it
would reuse already exists and is tested: `deleteFamilyData` in
`functions/src/account/account-deletion-cascade.ts` (Phase 5 item 15).

Account **deletion** (right to erasure) is already fully handled by that cascade
— this document covers **storage limitation** (Art. 5(1)(e)): purging family
data for *dormant* households that were never explicitly deleted.

## Retention window (PROPOSED)

| Data | Trigger | Proposed retention | Justification |
|---|---|---|---|
| `diner_profiles` + `family_ratings` for a household | Household dormancy — no cook event, no rating, and no member sign-in | **24 months** of inactivity, then purge the household's family data | Art. 5(1)(e) storage limitation. Aligns with the 24-month consent-retention precedent in `audit-logs-retention.md` (Art. 7(1)). Family ratings only have value while the household is actively cooking; 24 months covers a long gap (e.g. a season abroad) without retaining a child's special-category allergen data indefinitely. DPO may shorten (stronger minimisation) or lengthen (if a longer legitimate-use horizon is argued). |

**Dormancy signal (proposed):** the most recent of — the household's newest
`recipe_cook_events` entry, newest `family_ratings.lastUpdatedAt`, and any
member account's last sign-in. A household is dormant when that max is older
than the retention window. The exact signal is part of what the DPO confirms.

## Per-field record (Art. 30) — `diner_profiles`

| Field | Purpose | Lawful basis | Special category? |
|---|---|---|---|
| `name` | Identify the non-account diner (child/guest) within the household | Art. 6(1)(a) — guardian consent | No |
| `ageBand` | Coarse age band (toddler/child/teen/adult); drives the minor-consent gate | Art. 6(1)(a); Art. 8 (children) | No |
| `avatarColor` | UI personalisation only | Art. 6(1)(a) | No |
| `allergenPreferences.trackedAllergens` | Present-aware allergen filtering / safety | **Art. 9(2)(a) — explicit consent** (health data) | **YES (Art. 9)** |
| `guardianConsent.byUid` | Which adult granted consent (consent demonstrability) | Art. 7(1) — demonstrate consent | No (a UID) |
| `guardianConsent.at` / `consentVersion` / `includesAllergenConsent` | Versioned, timestamped consent record | Art. 7(1) | No |
| `householdId` / `createdBy` | Scope the profile to its household + custodian | Art. 6(1)(a) | No |
| `createdAt` / `updatedAt` | Lifecycle; `updatedAt` contributes to the dormancy signal | Art. 6(1)(c) | N/A (housekeeping) |

## Per-field record (Art. 30) — `family_ratings`

| Field | Purpose | Lawful basis | Special category? |
|---|---|---|---|
| `recipeId` / `householdId` | Scope the verdict to a recipe + household | Art. 6(1)(f) — legitimate interest (household meal planning) | No |
| `memberId` / `memberType` | Whose verdict it is (account uid or diner-profile id) | Art. 6(1)(f) | No |
| `stars` (1–5) | The private household verdict | Art. 6(1)(f) | No |
| `enteredByUid` | Who physically entered the verdict ("inmatat av {name}") | Art. 6(1)(f) | No |
| `createdAt` / `lastUpdatedAt` | Lifecycle; `lastUpdatedAt` contributes to the dormancy signal | Art. 6(1)(c) | N/A |

## Disclosure / portability note

Per Art. 15/20, a co-controlling adult's data export
(`FamilyExportManager`, Phase 5 item 14) includes the household's diner profiles
— **including a child's Art. 9 allergen data and the guardian-consent record**.
This third-party-special-category disclosure to a joint controller is a
documented condition the DPIA must explicitly cover (it surfaces only
already-consented stored data; it introduces no new consent collection).

## Sweep design (to implement once the window is DPO-confirmed)

A weekly `onSchedule` Cloud Function (region `europe-west1`, mirroring
`cleanupOldAuditLogs`):
1. Find households whose dormancy signal is older than the confirmed window.
2. For each, run the existing `deleteFamilyData`-style teardown (diner profiles +
   family ratings + the household doc), reusing the strict/idempotent batch
   logic already proven by the item-15 integration tests.
3. Emit one `system_events` observability row per run.

Do not deploy this sweep until the retention window is confirmed — an
incorrect threshold would erase a real household's children's data.
