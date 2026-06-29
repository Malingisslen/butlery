# Family Rating Data — Retention Policy (BUT family Phase 5 item 16)

GDPR Article 30 record covering the `diner_profiles` and `family_ratings`
collections (the household family-rating feature). Mirrors the structure of
[`audit-logs-retention.md`](./audit-logs-retention.md).

## Status

✅ **DPO-CONFIRMED (2026-06-29): 24 months, warn-before-purge.** The dormancy
sweep is **built and tested**: `purgeDormantFamilyData`
(`functions/src/family/purge-dormant-family-data.ts`), a weekly scheduled Cloud
Function (europe-west1) that warns dormant households (in-app notification +
`familyDataPurgeScheduledAt` grace stamp) and, after the 30-day grace window,
purges their `diner_profiles` + `family_ratings` (strict batch). Verified by
`purge-dormant-family-data.integration.test.ts` on the emulator. Account
**deletion** (right to erasure) is handled separately by `deleteFamilyData` in
the account-deletion cascade.

Account **deletion** (right to erasure) is already fully handled by that cascade
— this document covers **storage limitation** (Art. 5(1)(e)): purging family
data for *dormant* households that were never explicitly deleted.

## Retention window (PROPOSED)

| Data | Trigger | Recommended retention | Justification |
|---|---|---|---|
| `diner_profiles` + `family_ratings` for a household | Household dormancy — no cook event, no rating, and no member sign-in | **24 months** of inactivity → **notify, then purge** unless reactivated | Art. 5(1)(e) storage limitation. **24 months matches the widely-cited industry best practice for dormant accounts** (dormant 2 years → notify the user → delete unless they reactivate) — see research below. The **notify-before-purge** step is part of that best practice and is added here. Aligns with our own 24-month consent-retention precedent (`audit-logs-retention.md`, Art. 7(1)). Family ratings only have value while the household is actively cooking. |

### Research backing (web, 2026-06; DPO to confirm — not legal advice)
- **GDPR Art. 5(1)(e)** sets no fixed number — retention is purpose-driven and
  must be justified, documented, and reviewed (Recital 39). So 24 months is a
  *justified* period, not a statutory one.
- **Industry best practice (multiple GDPR guidance sources):** a dormant account
  at **2 years** is notified and then deleted unless reactivated. Our 24-month +
  notify design matches this directly.
- **Children's data (IMY / Swedish regulator):** children's personal data is
  *särskilt skyddsvärt* (especially protected), must be erasable promptly, and
  the **retention length is itself a factor** in whether processing children's
  data is justified. This argues **against anything longer than 24 months**, and
  the DPO may reasonably set a **shorter** window for the Art. 9 allergen data
  specifically (stronger minimisation for the most sensitive field).
- **Statutory carve-outs** (bokföringslagen etc.) don't apply — family ratings
  and diner profiles are not accounting/tax records, so no legal-hold extends them.

**DPO decision (the one number to confirm):** 24 months for the whole household
record, OR a split (e.g. 24 months for profiles/ratings, shorter for the Art. 9
allergen field). The sweep mechanism handles either.

**Dormancy signal (proposed):** the most recent of — the household's newest
`recipe_cook_events` entry, newest `family_ratings.lastUpdatedAt`, and any
member account's last sign-in. A household is dormant when that max is older
than the retention window. A **reminder notification** is sent before the purge
(e.g. 30 days prior) so an active-but-quiet household can reactivate. The exact
signal + notice lead-time are part of what the DPO confirms.

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

## Sweep (BUILT — `purgeDormantFamilyData`)

Weekly `onSchedule` Cloud Function (region `europe-west1`), two-pass so data is
never purged the instant it becomes eligible:
1. **Dormancy signal** = newest of the household's `updatedAt`, its diner
   profiles' `updatedAt`, and its family ratings' `lastUpdatedAt`.
2. **Warn pass** — a household crossing the 24-month line gets an in-app
   notification to each member and a `familyDataPurgeScheduledAt = now + 30d`
   stamp. (In-app is the recorded warning; email is a stronger channel for
   truly-dormant users — a sensible future enhancement.)
3. **Purge pass** — once the grace window elapses and the household is still
   dormant, its `diner_profiles` + `family_ratings` are deleted (strict batch:
   a failed chunk throws → run recorded failed + retried, never a silent partial
   purge). The household doc + member accounts are **not** deleted here.
4. **Reactivation** at any point clears the scheduled purge.

Scope note: only the household's family data is purged (storage limitation for
this feature); account-level lifecycle is separate.
