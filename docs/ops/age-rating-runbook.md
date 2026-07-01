# App Store / Play Console — Age Rating Runbook

**Status:** ACTIVE — copy-paste-ready answers for the App Store Connect age-rating questionnaire and the Google Play IARC questionnaire (BUT-624, BUT-590).

**Cross-references:**
- `docs/ops/play-data-safety-runbook.md` — data-collection inventory (must stay consistent with answers below).
- `docs/ops/moderation-runbook.md` — UGC moderation pipeline that defends "infrequent/mild" UGC ratings under Apple 1.2 / Google Play UGC policy.
- `assets/legal/community_guidelines_en.md` — content rules cited by reviewers when probing UGC defense.
- `assets/legal/privacy_policy_{en,sv}.md` — age-gate language (`birthYear` GDPR Art. 8 compliance).
- `lib/widgets/social/report_content_dialog.dart`, `lib/views/social/friend_profile_view.dart` — in-app report + block surfaces.

This document is the authoritative answer set. If app capabilities change (new feature, new UGC surface, new sharing pattern), update this file *before* re-submitting.

---

## 1. Decision: 12+ (Apple) / Teen (Google Play)

**Final ratings:**

| Store | Rating | Numerical floor |
|---|---|---|
| App Store Connect | **12+** | iOS minimum age 12 |
| Google Play (IARC) | **Teen** (ESRB), **PEGI 12**, **USK 12**, **IARC 3+** content but **Teen** floor due to UGC + messaging | minimum age 13 (Play Families policy) |

**Justification — the UGC + messaging + moderation triad:**

1. **UGC exists.** Users post free-text recipe titles, ingredient names, instructions, comments on shared recipes, ratings, and chat-style messages in groups and 1:1 friend pings. This is "user-generated content unrestricted" under Apple's questionnaire and pushes the floor to 12+.
2. **In-app messaging exists.** Group chat (`groups/{id}/messages`) and friend pings (`pings/`) allow user-to-user free-text contact. This is "users can communicate" and pushes the Play rating to Teen.
3. **Moderation is in place.** A 24-hour SLA report-and-action pipeline (see `docs/ops/moderation-runbook.md`) defends the "infrequent / mild" UGC severity rating. Without that pipeline, both stores would force a higher (17+/Mature) rating.

**No higher-rating triggers are present:**

- No alcohol / tobacco / drug content (recipe ingredients excluded — see §2 "References to alcohol" handling).
- No realistic or cartoon violence.
- No sexual content or nudity.
- No gambling, simulated or real.
- No horror / mature themes.
- No location sharing in user-to-user surfaces. Family presence (`lib/widgets/social/family_presence_bar.dart`) is online/offline only — no GPS, no "last seen city/region" — and is scoped to family/friend groups, never public.
- No unrestricted web access. The app does not embed a general-purpose browser. Outbound links go via the OS to Privacy Policy / Community Guidelines / support email only.

The 12+ / Teen choice is the **lowest defensible rating** given the UGC + messaging surface area.

---

## 2. App Store Connect — age-rating questionnaire

App Store Connect → My Apps → Butlery → **App Information** → **Age Rating** → **Edit**. Apple presents the questionnaire as "frequency" radio buttons (None / Infrequent or Mild / Frequent or Intense) per category. Answer as below.

| Apple question | Answer | Justification |
|---|---|---|
| Cartoon or Fantasy Violence | **None** | No violence in any form. |
| Realistic Violence | **None** | No violence. |
| Prolonged Graphic or Sadistic Realistic Violence | **None** | No violence. |
| Profanity or Crude Humor | **Infrequent / Mild** | UGC free-text fields could contain mild profanity; moderation pipeline removes within 24 h. Community Guidelines §4 prohibits coarse language. |
| Mature / Suggestive Themes | **None** | No mature themes in app content. UGC is recipe-focused; off-topic content is removed under Community Guidelines §4. |
| Horror / Fear Themes | **None** | None. |
| Medical / Treatment Information | **None** | Allergen flags are dietary preferences, not medical advice. Privacy policy and in-app surfaces explicitly disclaim medical use. |
| Sexual Content or Nudity | **None** | None. UGC moderation removes any such content within 24 h per Community Guidelines §4 and `docs/ops/moderation-runbook.md`. |
| Graphic Sexual Content and Nudity | **None** | None. |
| Alcohol, Tobacco, or Drug Use or References | **Infrequent / Mild** | Recipes may mention wine, beer, or spirits as ingredients (e.g., coq au vin, glögg). No promotion, no purchase flow, no content targeted at minors. |
| Simulated Gambling | **None** | No gambling mechanics. |
| Contests | **None** | No contests / sweepstakes / prizes. |
| Unrestricted Web Access | **No** | App does not embed a web browser. External links open in OS browser and point only to `butlery.app`, `support@butlery.se`, privacy policy, community guidelines. |
| Gambling and Contests | **No** | None. |
| User-Generated Content | **Yes** | Recipes (titles, ingredients, instructions, photos), comments, ratings, group messages, 1:1 pings. **Moderation:** report flow on every UGC surface; 24-h SLA; admin review screen at Settings → Review reports. **Block:** `lib/views/social/friend_profile_view.dart` exposes block on friend profiles. **Filter:** Community Guidelines + automated heuristics. This combination satisfies App Store Review Guideline 1.2. |
| Made for Kids | **No** | App is 12+, not in the Kids category. Sign-up enforces `birthYear ≤ 2013` (i.e., user is at least 13) at Firestore-rules layer. |
| Social media capabilities (declaration, from ~Sept 2026) | **Yes** | Friend graph, recipe sharing, comments, group chat and 1:1 pings meet Apple's "redistribute / amplify / interact with UGC via a social feed or similar" definition — not a close call. Declaring Yes carries a minimum **13+** rating (BUT-1382). |

**Resulting Apple rating:** 12+ today (driven by Profanity/Crude Humor "Infrequent/Mild" + Alcohol References "Infrequent/Mild" + Unrestricted UGC = Yes). Moves to **13+** once the social-media declaration below applies.

> **⚠️ Upcoming — social-media declaration (BUT-1382).** From ~July 2026 the App Store Connect age-rating questionnaire adds a "social media capabilities" question; answering it becomes **mandatory** for any new submission/update from ~Sept 2026. **Decision (Malin-approved, 2026-07-01): declare _Yes_ and accept the resulting 13+ rating.** Rationale: Butlery's friend-graph + sharing + comments + group chat clearly qualifies; the shift from 12+ to 13+ is effectively cosmetic — Apple's revised scale retires the 12+ tier (new tiers 4+/9+/13+/16+/18+), and Butlery's own age gate already blocks under-15s, so the store rating and the in-app gate stack in the same direction. **Action before the first submission on/after the deadline:** answer the declaration _Yes_, re-validate the resulting Apple rating in App Store Connect, and confirm it. The Apple _Declared Age Range API_ route (to avoid the social-media classification for under-13s) is **not** needed — the age gate already blocks that cohort entirely. Verify the exact Apple dates/wording at the source before submitting: developer.apple.com/news/upcoming-requirements/.

---

## 3. Google Play content rating (IARC) — first-pass answers

Play Console → Butlery → **Policy** → **App content** → **Content rating** → **Start questionnaire**. Category: **Reference, News, or Educational** (Butlery is a recipe/lifestyle reference app, not a game).

First-pass quick answers — full-question detail in §5 below.

| IARC top-level question | First-pass answer |
|---|---|
| Does the app contain violence? | **No** |
| Does the app contain sexuality or nudity? | **No** |
| Does the app contain controlled substances (alcohol/tobacco/drugs)? | **Yes — references only** (recipe ingredients) |
| Does the app contain gambling? | **No** |
| Does the app contain crude humour or profanity? | **Yes — UGC may contain mild profanity** |
| Does the app contain horror / fear-inducing content? | **No** |
| Does the app allow users to interact (UGC, messaging)? | **Yes** |
| Does the app share user location with other users? | **No** (presence is online/offline only, never location) |
| Does the app facilitate digital purchases? | **No** (no IAP, no subscriptions yet) |
| Does the app collect personal info? | **Yes** — see `docs/ops/play-data-safety-runbook.md` |

**Expected resulting ratings (IARC):**

- **ESRB (US/CA): Teen**
- **PEGI (EU): 12**
- **USK (DE): 12**
- **ClassInd (BR): 10**
- **GRAC (KR): 12**
- **IARC default: 12+**

These map to a Play Console minimum age of **13** (Play Families threshold), which aligns with the in-app age gate (`birthYear ≤ 2013`).

---

## 4. Submission checklist

### App Store Connect

- [ ] Sign in to App Store Connect → My Apps → Butlery.
- [ ] **App Information** → **Age Rating** → **Edit**. Fill the questionnaire using §2 above.
- [ ] Verify the resulting rating shown in the modal is **12+**. If higher, re-check the answer table — most likely cause: Profanity set to "Frequent" instead of "Infrequent".
- [ ] Save.
- [ ] **App Privacy** section: confirm cross-consistency with `docs/ops/play-data-safety-runbook.md` (the iOS PrivacyInfo manifest should already align — see `docs/ops/ios-privacy-manifest-audit.md`).
- [ ] Attach **Community Guidelines URL** in **App Review Information** → **Notes** field as moderation policy reference: `https://butlery.app/community-guidelines` (or current hosting URL — confirm before submission).
- [ ] Attach **Privacy Policy URL** in **App Privacy** → `https://butlery.app/privacy`.
- [ ] In **App Review Information** → **Notes**, paste the reviewer notes from `docs/ops/app-review-demo.md` §4.

### Google Play Console

- [ ] Sign in to Play Console → Butlery → **Policy** → **App content** → **Content rating**.
- [ ] Click **Start questionnaire**. Choose category: **Reference, News, or Educational**.
- [ ] Fill answers using §5 below (verbatim per IARC question).
- [ ] Submit. Play returns the rating set automatically (ESRB / PEGI / USK / ClassInd / GRAC / IARC).
- [ ] Verify resulting Play floor is **Teen** (ESRB) and minimum age **13**.
- [ ] **App content** → **Target audience and content** → set age groups: **13–15, 16–17, 18+**. Confirm "Does your app unintentionally appeal to children?" → **No** (recipe app, neutral artwork, no child-targeted gamification).
- [ ] **App content** → **News app** → **No**.
- [ ] **App content** → **COVID-19 contact tracing** → **No**.
- [ ] **App content** → **Data safety** → confirm submission per `docs/ops/play-data-safety-runbook.md`.
- [ ] In **Store listing** → **App access** → declare reviewer demo account from `docs/ops/app-review-demo.md` §2.
- [ ] **Moderation policy URL** for UGC declaration: in **App content** → **User-generated content** declaration, link `https://butlery.app/community-guidelines` and reference `docs/ops/moderation-runbook.md` (host at a public URL or paste an excerpt — Play accepts either).

### Submission history log

| Date | Submitter | Apple rating | Play rating | Notes |
|---|---|---|---|---|
| _(not yet submitted)_ | — | 12+ (planned) | Teen / PEGI 12 (planned) | First submission pending. |

---

## 5. IARC + Apple full questionnaire answer set

This section is the long-form answer pack: every IARC category, the question Play paraphrases, the verbatim Butlery answer with one-sentence justification, and the Apple equivalent question/answer where it differs.

### 5.1 Violence

- **IARC question (paraphrase):** "Does the app depict violence, blood, gore, or combat?"
- **Answer:** **No.** Butlery is a recipe and meal-planning app; no violent or combat content exists in app-controlled assets, and Community Guidelines §4 + the moderation pipeline remove any UGC that introduces such content.
- **Apple equivalent:** "Cartoon or Fantasy Violence" / "Realistic Violence" / "Prolonged Graphic or Sadistic Realistic Violence" → **None** for all three.

### 5.2 Sexual content

- **IARC question (paraphrase):** "Does the app contain sexual content, nudity, or suggestive material?"
- **Answer:** **No.** No sexual or suggestive content in app-controlled assets. UGC violating this is removed within 24 h per `docs/ops/moderation-runbook.md`.
- **Apple equivalent:** "Sexual Content or Nudity" / "Graphic Sexual Content and Nudity" → **None** for both.

### 5.3 Simulated gambling

- **IARC question (paraphrase):** "Does the app simulate or facilitate gambling, or contain gambling-style mechanics (loot boxes, chance-based rewards)?"
- **Answer:** **No.** No gambling, no chance mechanics, no loot boxes, no in-game currency, no contests with prizes.
- **Apple equivalent:** "Simulated Gambling" → **None**. "Gambling and Contests" → **No**.

### 5.4 User-Generated Content (UGC)

- **IARC question (paraphrase):** "Can users post content (text, images, audio, video) that is visible to other users?"
- **Answer:** **Yes.** Users post recipes (text + photos), recipe comments, ratings, group chat messages, and 1:1 friend pings. **Moderation defense:** in-app report on every UGC surface (recipe / comment / message / cook snap / profile / rating), 24 h admin action SLA, block on friend profile, hard-delete capability for admins, mandatory Community Guidelines acceptance at sign-up. This satisfies Apple Review Guideline 1.2 and Play UGC Policy.
- **Apple equivalent:** "Unrestricted Web Access" → **No**; "User-Generated Content" → **Yes**. App Store Connect requires "Yes" to UGC to push the rating to 12+ when combined with messaging.

### 5.5 Location sharing

- **IARC question (paraphrase):** "Does the app share the user's physical location with other users?"
- **Answer:** **No.** Family presence (`lib/widgets/social/family_presence_bar.dart`) is online/offline status only — no GPS, no city, no region, no "last active near …". The presence signal is scoped to family/friend groups, never public, and contains no geographic data. Friends are added by username/email lookup (no contact-book scanning, no proximity matching).
- **Apple equivalent:** Apple does not have a separate "location sharing with users" question; the App Privacy section (separate from age rating) declares Location = **Not Collected**.

### 5.6 Digital purchases

- **IARC question (paraphrase):** "Does the app facilitate digital purchases or in-app spending?"
- **Answer:** **No.** No in-app purchases, no subscriptions, no digital goods, no virtual currency. Monetization decisions are deferred per `MEMORY.md` ("No monetization decisions yet — just build the app").
- **Apple equivalent:** Not part of the age-rating questionnaire; declared instead in App Store Connect → **Pricing and Availability** (Free, no IAP).

### 5.7 Drug, alcohol, and tobacco references

- **IARC question (paraphrase):** "Does the app contain references to alcohol, tobacco, or drugs?"
- **Answer:** **Yes — references only, infrequent/mild.** Recipes may include wine, beer, or spirits as ingredients (e.g., coq au vin uses red wine, glögg uses fortified wine, beer-battered fish). No promotion of consumption, no purchase flow, no targeting of minors, no tobacco or illegal-drug content. Community Guidelines §4 prohibits glamourization.
- **Apple equivalent:** "Alcohol, Tobacco, or Drug Use or References" → **Infrequent / Mild**. This is the same answer; both stores converge on the recipe-ingredient justification.

### 5.8 Profanity and crude humor

- **IARC question (paraphrase):** "Does the app contain profanity, crude humor, or offensive language?"
- **Answer:** **Yes — infrequent/mild, in UGC only.** App-controlled strings (Swedish + English) contain no profanity. UGC free-text fields (recipe titles, comments, group messages) may incidentally contain mild profanity; the moderation pipeline (`docs/ops/moderation-runbook.md`) removes flagged content within 24 h. Community Guidelines §4 prohibits coarse language.
- **Apple equivalent:** "Profanity or Crude Humor" → **Infrequent / Mild**. Same answer.

### 5.9 Horror and fear

- **IARC question (paraphrase):** "Does the app contain horror, fear-inducing imagery, or psychologically intense content?"
- **Answer:** **No.** Recipe app; no horror imagery, no jump scares, no psychological intensity. App art direction is warm/domestic.
- **Apple equivalent:** "Horror / Fear Themes" → **None**.

### 5.10 Mature themes

- **IARC question (paraphrase):** "Does the app contain mature, suggestive, or controversial themes (politics, sensitive topics, discrimination)?"
- **Answer:** **No.** Recipe content is non-political. UGC involving harassment, discrimination, or impersonation is prohibited by Community Guidelines §2 and §6 and removed within 24 h per the moderation pipeline.
- **Apple equivalent:** "Mature / Suggestive Themes" → **None**.

### 5.11 Re-submission triggers

Re-fill **both** questionnaires (Apple + IARC) and re-submit if any of the following lands. These changes invalidate the answers above and risk store-policy violations if not declared.

| Trigger | Why it forces re-submission | Likely new rating |
|---|---|---|
| Adding **GPS / location sharing** between users (e.g., "find friends nearby", "share my cooking spot") | Changes §5.5 from No to Yes; both stores require explicit declaration. | Apple 12+ (unchanged) but App Privacy must add Location; Play minimum age unchanged but new declaration. |
| Opening **direct messages to non-friends** (e.g., DM any user from search results) | Changes UGC severity — open DM to strangers is a much higher abuse vector and pushes Apple to 17+ unless backed by stricter moderation (chat filtering, age gating between adults/minors). | Apple **17+**, Play **Mature 17+**. |
| Adding **payments / IAP / subscriptions** | Changes §5.6 from No to Yes. Apple requires declaration in App Store Connect Pricing; Play requires Billing Library + restricted-content disclosure. | Rating itself unchanged, but new App Privacy + Play Data Safety declarations required. |
| Adding **video** UGC (cook videos, story-style content) | Significantly higher moderation burden; both stores expect upgraded moderation tooling for video. | Apple 12+ likely unchanged if moderation upgraded; without upgrade, 17+ risk. |
| Adding a **public feed / discovery** of strangers' UGC | Changes UGC visibility from friend-graph to public, which raises the moderation bar (visible content from any account, not just friends). | Apple 17+ likely; Play Mature unless real-time moderation added. |
| Adding **alcohol promotion** (cocktail-of-the-week feature, alcohol-only recipe section, partnership content) | Moves §5.7 from "references only" to "promotion". | Apple 17+, Play Mature 17+. |
| Adding **third-party ads** | Forces declaration of advertising ID, may add in-app browser, changes data-safety form. | Rating unchanged unless ad targeting includes mature content. |
| Adding **a general web browser / WebView with arbitrary URL input** | Changes "Unrestricted Web Access" from No to Yes. | Apple 17+. |
| Removing the **age gate at sign-up** (`birthYear ≤ 2013`) | Both stores require the gate when UGC + messaging are present. Removal forces Made-for-Kids re-classification and stricter content rules. | Either Made-for-Kids (Play Families) with much stricter rules, or rejection. |
| **Lowering moderation SLA below 24 h response** or removing the report flow | Apple Guideline 1.2 explicitly requires both. | Outright rejection on next review. |

When any trigger lands: update this runbook → re-fill both questionnaires → re-submit → update the §4 history log.

---

## COPPA target audience

**Status:** Butlery is **not directed at children under 13** (BUT-720).

This section is the authoritative answer for both stores' "is this app
made for kids" questionnaires. Cross-references:

- **Apple App Store Connect:** "Made for Kids" = **NO**.
- **Google Play Console:** "Target audience and content" → primary audience
  is **adults**; "Does your app unintentionally appeal to children?" =
  **No**; appeal questionnaire = **No**.

### Evidence supporting the not-directed-at-children determination

1. **13+ age gate at sign-up (BUT-413).** `OnboardingAgeGatePage` enforces
   `birthYear ≤ 2013` before account creation succeeds; users who fail the
   gate are routed to `OnboardingAgeGateBlockedView` and cannot proceed.
   The same constraint is enforced server-side via Firestore rules on
   `users/{uid}/settings/preferences` (`birthYear` required, range
   [1900, 2013]). This satisfies COPPA §312.5 ("verifiable parental
   consent") by structurally excluding children under 13.
2. **No child-friendly UI motifs.** Visual identity targets adult home
   cooks: cream / forest-green / rust palette, Swedish bistro idiom,
   monochrome line illustrations. No bright primary colors, cartoon
   mascots, gamification, badges, sticker rewards, animal characters,
   "kid mode", or any of the GAFAM-toy iconography Apple/Play reviewers
   flag as child-targeted in their guidance docs.
3. **Marketing copy in `store_assets/` is aimed at adult home cooks.**
   Phrases such as "veckomeny", "matplanering", "samla familjens
   favoriter" position the app as a household meal-planning tool — adult
   household manager as primary persona. No "fun for kids", "perfect for
   the family kitchen" with kid imagery, no school-lunch framing.
4. **No child-targeted features.** No sticker books, no virtual rewards,
   no homework helpers, no parent dashboards aimed at supervising kids,
   no "kids' recipes" category that would make it appealing-to-children
   under Play's "primary OR appealing" two-prong test.
5. **UGC + messaging surface targets adult-to-adult communication.**
   Friend graph, group chat, comments, and pings are scoped to people
   who passed the 13+ age gate. Block + report flow on every UGC surface
   (cross-ref §2 / §5.4 above).

### Apple App Store Connect — Made for Kids workflow

- App Store Connect → My Apps → Butlery → **App Information** → **Made
  for Kids** → **No**.
- This is consistent with the **12+** age rating from §1 (Apple's
  Made-for-Kids program is separate from the age-rating questionnaire).
- If reviewers ask follow-up: cite the four evidence points above and
  the existing `birthYear` age-gate enforcement at the Firestore-rules
  layer.

### Google Play Console — Target audience and content workflow

- Play Console → Butlery → **Policy** → **App content** → **Target
  audience and content** → **Manage**.
- **Target age groups:** select **13–15, 16–17, 18 and over**. Do NOT
  tick **Ages 5 and under**, **Ages 6–8**, or **Ages 9–12** — those would
  invoke Play Families policy (Designed for Families program) and force
  COPPA compliance burdens that don't apply here.
- **Does your app unintentionally appeal to children?** → **No**.
  Justification text (paste verbatim into Play's free-text field if
  required): "Butlery is a meal-planning and recipe app for adult home
  cooks. The visual identity uses a muted bistro palette and adult
  typographic style; no cartoon mascots, gamification, or child-targeted
  artwork. Sign-up enforces a 13+ age gate (`birthYear ≤ 2013`) at the
  Firestore-rules layer and rejects under-13 users before any data is
  collected."
- **Designed for Families program:** **Do not opt in.** This program is
  for apps explicitly targeting children, which Butlery is not.
- **Appeal questionnaire (Play "Does your app appeal to children?"):**
  every sub-question answered **No** based on the evidence above.

### Cross-references

- **§2 (Apple) → "Made for Kids" row** — already says **No**; this
  section is the long-form justification.
- **§4 (Submission checklist) → Play Console** — already includes
  "Target audience and content" with the same age-group selection;
  this section adds the COPPA-specific evidence pack.
- **BUT-590** (IARC + Apple equivalents) — closed; the IARC answer set
  in §5 implicitly defends the not-directed-at-children determination
  via §5.10 (Mature themes = None) + §5.4 (UGC moderation).
- **BUT-624** (App Store / Play Console age rating) — closed; the
  resulting 12+ / Teen rating is consistent with this COPPA stance.
- **`OnboardingAgeGatePage`** + **`OnboardingAgeGateBlockedView`** —
  in-app structural enforcement of the 13+ floor.

### When to revisit

Re-read this section if any of the following lands:

- New feature targeting children (kids' recipes section, sticker book,
  parent-supervised mode, school-lunch planner).
- Removal or weakening of the 13+ age gate.
- Visual rebrand toward child-friendly motifs.
- Marketing campaign aimed at the under-13 demographic.
- New SDK that collects data from children (e.g., a kids-content network).

Any of those would invalidate the "not directed at children" stance and
trigger COPPA compliance work (Designed for Families program enrollment
on Play; Made-for-Kids = Yes on Apple with the associated kid-data
restrictions).

---

## 6. Maintenance triggers (parallel to play-data-safety-runbook.md §9)

Re-read this file when any of the following lands:

- New UGC surface (any new free-text user input or media upload).
- New messaging surface (DM, public feed, public comments without friend gating).
- Change to age gate at sign-up.
- Change to moderation SLA or report-flow coverage.
- New third-party SDK that introduces ads, location, or content (e.g., RevenueCat, AdMob, Mapbox).
- Privacy policy version bump (`assets/legal/privacy_policy_{en,sv}.md`).
- Community Guidelines update.

If any of those land without a corresponding update here, treat the age-rating declarations as drift and reconcile before the next release.
