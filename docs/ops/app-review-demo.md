# App Review — Reviewer Demo Account & Notes

**Status:** ACTIVE — required for every App Store and Play Store submission (BUT-416).

**Cross-references:**
- `docs/ops/age-rating-runbook.md` — content rating defense Reviewer is verifying.
- `docs/ops/moderation-runbook.md` — UGC moderation pipeline Reviewer must be able to exercise.
- `docs/ops/play-data-safety-runbook.md` — data-collection declarations Reviewer cross-checks.
- `assets/legal/community_guidelines_en.md` — guidelines Reviewer must be able to view pre-login.
- `assets/legal/privacy_policy_en.md` — privacy policy Reviewer must be able to view pre-login.

This document tells the founder exactly what to seed and what to paste into the App Review Information field at every submission. **Read it before every submission.**

---

## 1. Why this matters

Apple and Google reviewers test **social features end-to-end**. Without seeded data, the reviewer logs in, sees an empty Friends list, an empty Groups list, no comments, no ratings, no shared menus, and rejects the submission as **"Guideline 2.1 — Unable to evaluate functionality"** (Apple) or **"App not in compliance — moderation tools could not be tested"** (Play).

Both stores have UGC + messaging policies requiring proof that report, block, and admin-action flows work. The reviewer cannot prove any of that against an empty account.

The fix is a pre-seeded reviewer account with a friend graph, a shared menu, sample comments and ratings, a sample group, and a sample report — enough surface area for the reviewer to walk every UGC path in 5–10 minutes.

A rejection on this basis costs **3–7 days** of the launch timeline (re-submission + re-review). Seeding takes 30 minutes.

---

## 2. Demo account spec

### Primary reviewer accounts

| Store | Email | Password | Display name | birthYear |
|---|---|---|---|---|
| App Store | `reviewer-apple@butlery.app` | `<REPLACE_WITH_GENERATED_PASSWORD_AT_SUBMISSION>` | `App Reviewer` | `1990` |
| Play Store | `reviewer-google@butlery.app` | `<REPLACE_WITH_GENERATED_PASSWORD_AT_SUBMISSION>` | `Play Reviewer` | `1990` |

Generate fresh 24-char passwords (e.g. `openssl rand -base64 18 | tr -d '/+='`) at submission time. **Do not commit real passwords to this repo.** Store the generated values in 1Password / Bitwarden under `butlery-reviewer-credentials` and rotate after each review cycle completes.

### Seeded friend accounts (NOT given to reviewers)

These accounts exist solely to populate the reviewer's friend graph. They never log in during review.

| Email | Display name | Role |
|---|---|---|
| `demo-friend-1@butlery.app` | `Anna Demo` | Friend (pre-accepted), member of Demo Group |
| `demo-friend-2@butlery.app` | `Ben Demo` | Friend (pre-accepted), member of Demo Group |
| `demo-admin@butlery.app` | `Demo Admin` | Optional moderator account for verifying admin flow — only seed if reviewer notes ask to demonstrate moderation actions |

**Naming convention:** the `@butlery.app` suffix marks every demo account as non-production, makes them easy to grep in Firestore Auth, and isolates them from real-user emails (which live under `@gmail.com`, `@hotmail.com`, etc., per beta cohort).

### Lifecycle rules

- **Reset before each submission.** Delete and re-seed demo data ahead of every Apple / Play submission so the reviewer never sees stale state from the previous review (e.g., already-resolved reports, already-cooked menus).
- **Lock down between reviews.** When no review is active, force-sign-out the reviewer accounts (set a fresh password) so a leaked credential can't be used against the live product.
- **No real PII.** Demo content is synthetic — no real recipes from beta users, no real photos, no real names beyond `Anna Demo` / `Ben Demo`.

---

## 3. Pre-population checklist

Run this before each submission. Total time: ~30 minutes the first time, ~10 minutes on subsequent runs once the seed script exists.

### 3.1 Auth setup (Firebase Console → Authentication → Users)

- [ ] Create / re-enable `reviewer-apple@butlery.app` with the freshly generated password.
- [ ] Create / re-enable `reviewer-google@butlery.app` with the freshly generated password.
- [ ] Create `demo-friend-1@butlery.app` and `demo-friend-2@butlery.app` if they don't exist (any password — they are not used for login).
- [ ] For each, set Firestore `users/{uid}` document with `displayName`, `birthYear: 1990`, `acceptedTermsVersion: <current>`, `acceptedCommunityGuidelinesVersion: <current>`.

### 3.2 Friend graph

For each reviewer account (`reviewer-apple@…` and `reviewer-google@…`):

- [ ] Friend relationship with `demo-friend-1@butlery.app` — pre-accepted (status `accepted`, both directions).
- [ ] Friend relationship with `demo-friend-2@butlery.app` — pre-accepted.
- [ ] No pending friend requests (so the reviewer sees a clean state and can manually trigger one if needed).

### 3.3 Recipes

- [ ] Reviewer account has **5 imported recipes** spanning 3 cuisines (e.g. Swedish, Italian, Asian) — provides material for the share / comment / rate flows.
- [ ] Each demo-friend account has **3 imported recipes** of its own (so reviewer can browse a friend's profile and see content).
- [ ] At least one recipe per account has a photo (Storage upload), at least one has no photo (tests the no-image gradient state).

### 3.4 Shared menu

- [ ] One **weekly menu plan** authored by `demo-friend-1@butlery.app`, shared with the reviewer account. Plan contains **5+ recipes** spread across the week (mix of weekday dinners + weekend lunches). This exercises the menu-template + sharing flow without forcing the reviewer to author one from scratch.

### 3.5 Comments and ratings

- [ ] **3 sample comments** on the reviewer's most recently shared recipe — each from a different demo-friend account, in Swedish (matches app UI) with one English fallback to test mixed-locale rendering. Examples: `"Lagade igår, fantastiskt!"`, `"Funkar bra med havremjölk."`, `"Tip: skip the salt if you use salted butter."`
- [ ] **1 sample rating** (4 or 5 stars) on a shared recipe from a demo-friend account.

### 3.6 Group

- [ ] **One group** named `Demo Family` with the reviewer account + `demo-friend-1@butlery.app` + `demo-friend-2@butlery.app` as members.
- [ ] **3 sample messages** in the group chat (Swedish, recipe-related, friendly). Examples: `"Vad lagar ni på lördag?"`, `"Kan ni testa den nya pastan?"`, `"Jag lägger till en lunch."`
- [ ] One shared menu attached to the group (re-use §3.4 menu).

### 3.7 Report (lets reviewer verify the report flow without producing offensive content)

- [ ] **One sample report** already submitted by the reviewer account against a demo-friend message. Use a benign reason (`"Spam — duplicate post"`) so the reviewer sees a legitimate report in `Settings → Review reports` (admin view) or in their own report-status view, depending on which flow Apple/Google asks to see.
- [ ] If the reviewer needs the **admin-side** review flow, grant the reviewer account temporary admin status by seeding `admins/{reviewerUid}` per `docs/ops/moderation-runbook.md`. **Revoke immediately after the review cycle ends** — admins can hard-delete content.

### 3.8 Seed-script stub (TODO)

<!-- TODO(BUT-416-followup): Replace this manual checklist with a `functions/src/admin/seed-reviewer-data.ts` callable Cloud Function that idempotently creates §3.1–§3.7 for any email passed in. Until then, the founder runs this checklist by hand. The function should: (1) accept `{ reviewerEmail }` in payload; (2) verify caller is in `admins/{uid}`; (3) reset friend graph + content + group + report to a known state; (4) return summary of what was seeded. -->

---

## 4. Reviewer notes template

Paste the block below into:
- **App Store Connect:** App Review Information → **Notes** field.
- **Play Console:** Store listing → **App access** field, then re-paste in **Release notes for reviewers** when filing the release.

```
================================================================
BUTLERY — APP REVIEW NOTES
================================================================

SIGN-IN CREDENTIALS

  Email:    reviewer-apple@butlery.app          (Apple)
  Email:    reviewer-google@butlery.app         (Play)
  Password: <PASTE GENERATED PASSWORD HERE>

The account is pre-populated with friends, a shared menu, sample
comments, a sample rating, a group, and a sample report so all
social features are exercisable without seeding from scratch.

----------------------------------------------------------------
DEMO FLOW (5–10 MINUTES)
----------------------------------------------------------------

1. Sign in with the credentials above.
2. Tap "Mina recept" to view 5 pre-loaded recipes.
3. Tap "Importera recept": paste any recipe URL (e.g. ICA, Coop,
   Köket.se) to test our recipe-parsing flow. Parsing runs on
   Vertex AI in europe-west1 (data residency: EU).
4. Open any imported recipe → tap "Dela" → choose the "Demo Family"
   group. The recipe appears in the group's shared menu.
5. Open "Vänner" → tap "Anna Demo" → tap a recipe in her profile
   → leave a comment ("Tack för delningen!") → leave a 5-star
   rating. This exercises the comment + rating UGC surfaces.
6. Open "Vänner" → tap "Ben Demo" → tap the three-dot menu →
   tap "Blockera" to test block, then "Avblockera" to revert.
   This is the user-blocking flow required by Apple Guideline 1.2.
7. Open "Veckomeny" to view the pre-seeded weekly menu.
8. Open "Inställningar" → "Hantera konto" → review the data
   export and delete-account flows (do not delete; the next
   reviewer needs the account intact).
9. (Optional moderator demo) Long-press any group message → tap
   "Rapportera" → choose "Spam" and submit. The report appears
   in Firestore `reports/` and triggers the moderation SLA pipeline
   documented at:
   https://github.com/<repo>/blob/main/docs/ops/moderation-runbook.md

----------------------------------------------------------------
FEATURES GATED BEHIND CONSENT
----------------------------------------------------------------

  - Firebase Analytics: opt-in at first launch. The demo account
    has analytics OFF by default; toggle in
    Inställningar → Sekretess → Analys to test the consent flow.

  - FCM push notifications: opt-in at first launch.
    Toggle in Inställningar → Aviseringar.

  - Crashlytics + Performance Monitoring: also consent-gated;
    same screen.

These match our App Privacy / Data Safety declarations.

----------------------------------------------------------------
PRIVACY POLICY + TERMS (PRE-LOGIN)
----------------------------------------------------------------

  - Sign-in screen → bottom row → "Sekretesspolicy"  / "Privacy
    Policy" → renders the Markdown from
    assets/legal/privacy_policy_{sv,en}.md.
  - Sign-in screen → bottom row → "Användarvillkor" / "Terms" →
    renders assets/legal/terms_{sv,en}.md.
  - Sign-in screen → bottom row → "Community Guidelines" →
    renders assets/legal/community_guidelines_{sv,en}.md.
  - Public hosted copies:
      https://butlery.app/privacy
      https://butlery.app/terms
      https://butlery.app/community-guidelines

----------------------------------------------------------------
LANGUAGE
----------------------------------------------------------------

The app's UI is in SWEDISH. The reviewer account locale is set to
sv-SE. English fallback strings exist for diagnostic / error
surfaces and for the legal documents (toggle device language to
en-US to view them). All ratings claims, age-gate, and moderation
flows behave identically in both locales.

----------------------------------------------------------------
DATA RESIDENCY
----------------------------------------------------------------

  - Firestore + Cloud Storage: EU multi-region (eur3).
  - Vertex AI (recipe parsing + OCR): europe-west1.
  - Cloud Functions: europe-west1.

No data leaves the EU. Firebase Authentication is globally
managed by Google under the Google Cloud DPA.

----------------------------------------------------------------
MODERATION SLA
----------------------------------------------------------------

24-hour action SLA on UGC reports. Pipeline documented in:
docs/ops/moderation-runbook.md (admin runbook, includes the
Settings → "Granska rapporter" admin screen).

----------------------------------------------------------------
CONTACT FOR REVIEWER QUESTIONS
----------------------------------------------------------------

  Privacy:    integritet@butlery.se
  Support:    support@butlery.se
  Appeals:    overklagande@butlery.se

================================================================
```

---

## 5. Pre-submission checklist (per submission cycle)

Run **immediately before** clicking Submit on Apple / Play.

- [ ] Reviewer account password rotated and stored in 1Password under `butlery-reviewer-credentials`.
- [ ] Reviewer account is **not locked** (sign in once on a real device or simulator to prove it).
- [ ] Friend graph has 2 accepted friends, no pending requests.
- [ ] Recipe count on reviewer account: 5 (no more, no less — a long list of test data looks unprofessional).
- [ ] Demo-friend accounts have 3 recipes each, friend status `accepted`.
- [ ] Demo Family group exists with 3 messages, the shared weekly menu attached, and the reviewer account as a member.
- [ ] At least one comment + one rating visible on the reviewer's recently shared recipe.
- [ ] One sample report exists in `reports/` collection from the reviewer account.
- [ ] **No production beta user data** has leaked into the reviewer account (search Firestore for any document referencing the reviewer UID with non-demo email addresses; should be zero).
- [ ] Privacy policy URL (`https://butlery.app/privacy`) returns 200 and matches `assets/legal/privacy_policy_en.md` v1.2.0 or later.
- [ ] Community Guidelines URL (`https://butlery.app/community-guidelines`) returns 200 and matches `assets/legal/community_guidelines_en.md`.
- [ ] Terms URL (`https://butlery.app/terms`) returns 200 and matches `assets/legal/terms_of_service_en.md`.
- [ ] Reviewer notes block (§4) pasted into both stores' fields, with the freshly generated password.
- [ ] If admin-side moderation demo is requested: `admins/{reviewerUid}` doc created in Firestore. **Calendar reminder set to revoke admin within 7 days.**
- [ ] Test sign-in with the reviewer credentials on a clean device or simulator one final time. Verify all six demo-flow steps work end-to-end.

---

## 6. Post-review cleanup (per submission cycle)

Run **immediately after** review verdict (approved or rejected) lands.

- [ ] If admin status was granted to reviewer account: delete `admins/{reviewerUid}` per `docs/ops/moderation-runbook.md`.
- [ ] Rotate reviewer-account password (force sign-out across all sessions).
- [ ] If approved: keep demo data in place for the next review (re-seed lightly per §3 to refresh timestamps).
- [ ] If rejected: read the rejection note, fix the cited issue, refresh demo data per §3, regenerate password, re-paste reviewer notes, re-submit.

---

## 7. Submission history

| Date | Store | Reviewer email | Verdict | Notes |
|---|---|---|---|---|
| _(not yet submitted)_ | — | — | — | First submission pending. |
