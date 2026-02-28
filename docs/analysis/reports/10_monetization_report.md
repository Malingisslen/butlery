# BUTLERY MONETIZATION READINESS & COMPETITIVE POSITIONING — PHASE 1 FINDINGS

```
Analysis Date: 2026-02-28
Analyst: Claude (Opus 4.6) — 3 parallel investigation agents
Codebase: 1,044 non-generated .dart files in lib/, ~564k LOC (hand-written)
Focus: Outward-facing readiness — monetization infrastructure, feature completeness,
       competitive positioning, and app store submission risk

OVERALL SCORE: 56/100

+-- D1  Entitlement Architecture:      10 /20
+-- D2  Schema Extensibility:          10 /15
+-- D3  Feature Completeness:          14 /20
+-- D4  Differentiation & Moat:        11 /15
+-- D5  App Store Submission Risk:       4 /15
+-- D6  Revenue Infrastructure:          5 /10
+-- D7  Market Positioning:              2 /5

STATUS: Preparation Needed (strong product, significant infrastructure gaps)

CRITICAL ISSUES: 2 found
HIGH PRIORITY:   7 found
MEDIUM PRIORITY: 7 found
LOW PRIORITY:    4 found
```

---

## Top 10 Issues Quick Reference

| # | Sev | Issue | Location | Effort | Impact |
|---|-----|-------|----------|--------|--------|
| 1 | CRIT | Bundle ID `com.example.butlery` blocks all store submissions | `build.gradle.kts:9,24`, `project.pbxproj:371,550` | 1h | Submission |
| 2 | CRIT | Android release build uses debug signing | `build.gradle.kts:38` | 2h | Submission |
| 3 | HIGH | Firestore rules: blanket `allow write` on user doc — tier field client-manipulable | `firestore.rules:114` | 4h | Security |
| 4 | HIGH | No IAP packages in pubspec.yaml — zero subscription infrastructure | `pubspec.yaml` | 2d | Revenue |
| 5 | HIGH | Orphan `NSFaceIDUsageDescription` in Info.plist — Apple will reject | `Info.plist:58-59` | 15m | Submission |
| 6 | HIGH | No Terms of Service — required by both stores | — | 2h | Submission |
| 7 | HIGH | Rate limits hardcoded as `static const` — not tier-parameterizable | `rate_limit_models.dart:287-303` | 4h | Architecture |
| 8 | HIGH | No subscription/purchase analytics events | analytics trackers | 4h | Revenue |
| 9 | HIGH | Apple Sign-In required for apps with social login | — | 1d | Submission |
| 10 | MED | `runZonedGuarded` is a no-op — async errors bypass Crashlytics | `main.dart:152-162` | 1h | Reliability |

---

## Dimension 1: Entitlement Architecture (10/20)

### Summary
The app has zero subscription or tier concepts anywhere in the codebase. However, two key pieces of infrastructure — FeatureFlagService and the modular DI system — are architecturally ready to support tiered access with minimal modification. The gap is entirely in the "last mile": no entitlement model, no IAP integration, no paywall UI, and PermissionService is auth-only with 71 files depending on its current binary model.

### What Exists

**FeatureFlagService — Tier-ready with zero changes**
- `lib/services/feature_flags/feature_flag_service.dart:16-51` — Firebase Remote Config with 15 flags across scalability, operational, safety, and rollout categories.
- `feature_flag_service.dart:144-152` — `isInRollout(flag, userId)` uses stable per-user hashing. This is the exact mechanism needed for gradual tier rollout.
- Kill switches (`enable_social_features`, `enable_sharing`, `enable_messaging`) at lines 45-47 already demonstrate the pattern for gating features.
- **Assessment**: Adding tier-specific flags (e.g., `max_recipes_free`, `enable_ai_import_pro`) requires only new entries in `_defaults` map. No architectural changes needed.

**DI System — Clean module slot available**
- 9 modules in `lib/core/di/modules/` with priority ordering.
- A `BillingModule` at priority 5 (between content and social) fits the existing registration pattern cleanly.
- No circular dependency risk — billing would depend on auth (priority 1) and provide to UI (priority 9).

**PermissionService — Auth-only binary model**
- `lib/services/permission_service.dart:22` — extends `BaseService`, provides authentication checks only.
- Lines 113-132: `currentUserId` and `currentUser` are pure auth lookups. Zero tier/subscription concepts.
- 71 files reference `PermissionService` — any tier-aware permission change has wide blast radius.
- **Assessment**: Would need a `SubscriptionService` (separate from PermissionService) to check tier. PermissionService should remain auth-focused; tier checks should compose on top.

### What's Missing

**No IAP packages**: `pubspec.yaml` contains zero references to `in_app_purchase`, `revenue_cat`, `purchases_flutter`, `adapty`, or `qonversion`.

**No entitlement model**: No `SubscriptionTier` enum, no `UserEntitlement` class, no tier field on `UserProfile`.

**No paywall UI**: No gating dialogs, upgrade prompts, or "Pro" badges anywhere in the widget tree.

**No receipt validation**: Cloud Functions (`functions/src/`) handle LLM, OCR, FCM, and analytics but have no payment verification endpoint.

### Issues

**H1.1: Rate limiters hardcoded as `static const` — not tier-parameterizable**
- `lib/services/import/models/rate_limit_models.dart:283-303` — `ImportRateLimits` class uses 10 `static const` values.
- `lib/services/ocr/ocr_usage_tracker.dart:21` — `static const int freeMonthlyLimit = 25000`.
- These cannot vary by user tier without refactoring to instance-based configuration.
- **Fix**: Replace `static const` with factory that reads from a `TierConfiguration` provider. **Effort**: 4h

**H1.2: No subscription/purchase analytics events**
- 6 analytics tracker modules exist and are GDPR-gated, but none track purchase/paywall/subscription events.
- **Fix**: Add `PaywallAnalyticsTracker` module to existing analytics infrastructure. **Effort**: 4h

---

## Dimension 2: Schema Extensibility (10/15)

### Summary
The data layer is well-structured for extension. `UserProfile` uses `SerializationUtils` for all deserialization, making new field additions backward-compatible by default. However, Firestore security rules have a critical gap: the user document has a blanket write rule that would allow clients to self-assign subscription tiers.

### What Exists

**UserProfile — Backward-compatible additions**
- `lib/models/user_profile.dart:10-47` — 17 fields, all with defaults in constructor.
- `user_profile.dart:222` — `fromMap` factory uses `SerializationUtils.safeString`, `safeBool`, `safeInt`, etc. New fields with defaults will deserialize gracefully from old documents.
- `user_profile.dart:167-191` — `toFirestore()` serializes all fields. New fields would appear on next write.
- **Assessment**: Adding `subscriptionTier`, `subscriptionExpiresAt`, `stripeCustomerId` requires only: (1) new fields with defaults, (2) new `SerializationUtils` entries in `fromMap`, (3) new entries in `toFirestore`. Zero migration needed for existing users — defaults handle it.

**Cloud Functions — Infrastructure ready for server-side validation**
- `functions/src/index.ts` — Existing Cloud Functions handle LLM orchestration, OCR, FCM, and analytics.
- Receipt validation / webhook handler would be a new module in the same infrastructure.
- Rate limiting already exists server-side (`enable_server_rate_limiting` flag).

### Issues

**H2.1: Firestore rules allow client-side tier manipulation (SECURITY)**
- `firestore.rules:114` — `allow read, write: if isOwner(userId);`
- If a `subscriptionTier` field is added to the user document, any authenticated user could set their own tier to "premium" via a direct Firestore write.
- **Fix**: Either (a) store subscription tier in a server-only subcollection, (b) use Firestore rules to deny writes to specific fields, or (c) use a Cloud Function as the sole writer for tier changes. **Effort**: 4h
- **Cross-reference**: Report 02 (Security) should evaluate this rule more broadly.

**M2.1: OCR usage tracker not in DI — standalone instantiation**
- `lib/services/ocr/ocr_usage_tracker.dart:5` — `OCRUsageTracker` is instantiated directly, not via ServiceLocator.
- For tier-aware usage tracking, it would need DI injection to access the user's tier configuration.
- **Fix**: Register in ContentModule, inject tier config. **Effort**: 2h

---

## Dimension 3: Feature Completeness (14/20)

### Summary
Butlery has comprehensive recipe management, a rare social layer, and deep Swedish NLP — exceeding most competitors on personal recipe management. The primary gap vs. table-stakes expectations is the absence of cooking timers, which every major competitor includes. Nutritional information and voice control are nice-to-haves that competitors increasingly offer.

### Feature Matrix: Butlery vs. Table-Stakes

| Feature | Table-Stakes? | Butlery Status | Notes |
|---------|:------------:|:--------------:|-------|
| Manual recipe creation | Yes | ✅ Complete | Full-featured editor |
| URL import | Yes | ✅ Complete | Multi-source with LLM enhancement |
| OCR/camera import | Yes | ✅ Complete | OCR.space + Google Vision pipeline |
| Archive/CSV import | No | ✅ Complete | Competitive advantage |
| Text paste import | No | ✅ Complete | Swedish NLP parsing |
| Ingredient scaling | Yes | ✅ Complete | — |
| Shopping list | Yes | ✅ Complete | Collaborative + real-time sync |
| Meal planning | Yes | ✅ Complete | Calendar-based with generation |
| Cloud sync | Yes | ✅ Complete | Firebase real-time |
| Offline access | Yes | ✅ Complete | Full offline support |
| Search & filtering | Yes | ✅ Complete | Multi-dimensional with personal tags |
| Photo support | Yes | ✅ Complete | Multi-photo per recipe |
| Collections/categories | Yes | ✅ Complete | Personal tags + auto-tags |
| Favorites | Yes | ✅ Complete | Boolean `isFavorite` on Recipe |
| Cook mode | Yes | ✅ Complete | Landscape split-view |
| **Cooking timer** | **Yes** | **❌ Missing** | **Every major competitor has this** |
| Social sharing | No | ✅ Complete | Friends, groups, comments, ratings |
| Allergen tracking | No | ✅ Complete | Auto-detection across library |
| Nutritional info | Emerging | ❌ Missing | Planned with Livsmedelsverket API |
| Voice control | Emerging | ❌ Missing | No hands-free cooking support |
| Grocery delivery integration | No | ❌ Missing | ICA integration would be transformative |
| Apple/Google Sign-In | Yes (if social) | ❌ Missing | Required for App Store if social login exists |
| Drag-and-drop menu editing | No | ❌ Missing | Calendar-based only |
| Imperial unit toggle | Regional | ❌ Missing | Metric-only (acceptable for Swedish market) |

### Issues

**M3.1: No cooking timer — table-stakes gap**
- Every major competitor (Paprika, Crouton, Mela, BigOven) includes step-by-step timers.
- Butlery's cook mode exists but has no timer integration.
- **Fix**: Embedded timer widget in cook mode, parse time mentions from instructions. **Effort**: 1-2d

**M3.2: No nutritional information**
- Planned for post-beta using Livsmedelsverket API.
- Competitors increasingly offer this (BigOven, Yummly).
- **Effort**: 3-5d (API integration + UI)

**L3.1: No voice control**
- "Hey Siri, next step" / voice-activated timer is emerging in Crouton and Yummly.
- Not table-stakes yet but trending toward expectation.
- **Effort**: 2-3d

**L3.2: No grocery delivery integration**
- ICA Handla dominates this space in Sweden. Direct integration would be transformative but complex.
- Requires ICA partnership/API access.
- **Effort**: Unknown (depends on API availability)

---

## Dimension 4: Differentiation & Moat (11/15)

### Summary
Butlery has a genuine technical moat in Swedish NLP and a rare feature combination (personal management + social + allergen tracking). The social layer creates emerging network effects. However, individual features are replicable by well-funded competitors, and ICA's distribution advantage represents an existential risk if they ever build proper recipe management.

### Competitive Matrix

| Capability | Butlery | Paprika 3 | Crouton | Mela | BigOven | Yummly | Köket.se | ICA Handla |
|-----------|:-------:|:---------:|:-------:|:----:|:-------:|:------:|:--------:|:----------:|
| Swedish UI | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Personal recipe library | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| AI/LLM import pipeline | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Swedish NLP parsing | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| OCR cookbook scanning | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Social (friends/sharing) | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Comments & ratings | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Groups | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Allergen auto-tracking | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Personal tags/rules | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Meal planning | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Collaborative shopping | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Real-time sync | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Cooking timer | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Nutritional info | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Grocery delivery | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Cross-platform | ✅* | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| GDPR compliance | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| One-time pricing | TBD | ✅ | ✅ | ✅ | ❌ | ❌ | Free | Free |

*Butlery: Flutter supports iOS, Android, Web. Desktop not yet targeted.

### Moat Assessment

**Strong moats:**
- **Swedish NLP pipeline**: Compound word splitting, genitive-s handling, ingredient normalization, context-aware line classification. This is 6+ months of specialized work that no English-first competitor will replicate for the Swedish market.
- **AI import pipeline**: URL → LLM → structured recipe with auto-tagging, allergen detection, and correction feedback loop. More sophisticated than any competitor's import.
- **GDPR Phase 1 complete**: Articles 7, 15, 17, 30 implemented. Rare for indie apps, legally required in EU, creates compliance cost barrier for non-EU competitors entering the market.

**Moderate moats:**
- **Social layer**: Friends, sharing, comments, ratings, groups — present but replicable. The value is in the network, not the code.
- **Personal tag rules engine**: Rule-based auto-tagging with TriState conditions. Unique feature but niche appeal.
- **Allergen auto-detection**: Integrated with tagging pipeline. Useful for families with allergies — a real pain point.

**Weak moats:**
- **Feature parity**: Recipe management, meal planning, shopping lists — these are table-stakes and do not differentiate.

### Ecosystem Risks

**ICA Handla** (HIGH risk): 33-36% Swedish grocery market share, ~5M+ Stammis members. If ICA adds personal recipe import with library management, they have distribution no indie app can match. Their recipe features today are content-only (no personal management), but the infrastructure to add it exists.

**Köket.se** (LOW risk): Media brand, not a product. Would need a complete product pivot to compete on personal management. TV4's focus is ad revenue from content, not SaaS.

**Paprika** (LOW risk): No Swedish localization, no social layer, no AI pipeline. One-time pricing model limits R&D investment. Loyal but aging user base.

---

## Dimension 5: App Store Submission Risk (4/15)

### Summary
Two critical blockers prevent submission to either store today. Beyond those, missing metadata, legal documents, and an orphan plist key would cause review rejection. The app's technical quality is high, but store-readiness infrastructure has received zero attention.

### CRITICAL

**C5.1: Bundle ID `com.example.butlery` — both stores will reject**
- `android/app/build.gradle.kts:9` — `namespace = "com.example.butlery"`
- `android/app/build.gradle.kts:24` — `applicationId = "com.example.butlery"`
- `ios/Runner.xcodeproj/project.pbxproj:371,550` — `PRODUCT_BUNDLE_IDENTIFIER = com.example.butlery`
- Google Play and Apple App Store both reject `com.example.*` bundle IDs.
- **Fix**: Register a domain, update to `com.butlery.app` or `se.butlery.app` across all platform configs. Must be done before first submission — cannot be changed after. **Effort**: 1h

**C5.2: Android release build uses debug signing**
- `android/app/build.gradle.kts:38` — `signingConfig = signingConfigs.getByName("debug")`
- Comment on line 36-37: "TODO: Add your own signing config for the release build."
- Google Play will reject apps signed with debug keys. Production keystore must be generated and configured.
- **Fix**: Generate production keystore, configure `key.properties`, update `build.gradle.kts` release block. **Effort**: 2h

### HIGH

**H5.1: Orphan `NSFaceIDUsageDescription` in Info.plist**
- `ios/Runner/Info.plist:58-59` — `NSFaceIDUsageDescription` is declared but biometric/app lock feature was deleted from the codebase (per beta UX decisions).
- Apple reviews will flag this: declaring a permission usage description without actually using the corresponding API is a rejection reason.
- **Fix**: Remove the key-value pair from Info.plist. **Effort**: 15m

**H5.2: No Terms of Service document**
- Both stores require a Terms of Service URL during submission.
- Privacy policy exists but ToS does not.
- **Fix**: Draft and host ToS. **Effort**: 2h (legal review adds more)

**H5.3: Apple Sign-In required for apps with third-party social login**
- App has social features but no Apple Sign-In. If Google Sign-In or other third-party auth is added, Apple requires "Sign in with Apple" as well.
- **Fix**: Add `sign_in_with_apple` package + backend support. **Effort**: 1d

### MEDIUM

**M5.1: `runZonedGuarded` is a no-op — Crashlytics gap**
- `lib/main.dart:152-162` — `runZonedGuarded` creates a zone with error handler, but the zone body is `() async {}` (empty). The actual `runApp()` call happens at line 165, outside the zone.
- Async errors in the widget tree will not reach Crashlytics.
- **Fix**: Move `runApp(const ButleryApp())` inside the `runZonedGuarded` body. **Effort**: 1h
- **Cross-reference**: Also flagged in Report 01 (Code Quality) as issue H1.10.

**M5.2: No demo account for App Store review**
- Apple requires a demo account with pre-populated data for review.
- **Fix**: Create demo account provisioning in Cloud Functions. **Effort**: 4h

**M5.3: Missing store metadata**
- No screenshots, app descriptions, or keywords prepared for either store.
- No content rating questionnaire completed.
- No data safety form (Google) or App Privacy labels (Apple).
- **Fix**: Prepare store listing assets. **Effort**: 1-2d

### LOW

**L5.1: Web SEO defaults not configured**
- `web/index.html` has default Flutter template meta tags.
- For web platform discoverability, proper meta tags, Open Graph, and structured data are needed.
- **Effort**: 2h

---

## Dimension 6: Revenue Infrastructure (5/10)

### Summary
The app has strong general infrastructure that can be repurposed for monetization — Cloud Functions, analytics, modal/dialog UI patterns, and Remote Config. But there is zero monetization-specific infrastructure: no payment SDK, no paywall components, no subscription state management, no receipt validation.

### What Can Be Repurposed

| Existing Infrastructure | Monetization Use | Readiness |
|------------------------|------------------|-----------|
| FeatureFlagService + Remote Config | Feature gating by tier | Ready — add flag entries only |
| Cloud Functions (Node.js) | Receipt validation, webhook handling | Ready — add new module |
| Analytics trackers (6 modules) | Purchase/paywall/conversion tracking | Ready — add new tracker module |
| DI system (9 modules) | BillingModule at priority 5 | Ready — clean slot available |
| Dialog/modal patterns | Paywall/upgrade prompts | Patterns exist, build new UI |
| BaseService + error handling | Subscription state management | Ready — extend pattern |
| SerializationUtils | Subscription data deserialization | Ready — add field types |

### What Must Be Built

| Component | Description | Estimated Effort |
|-----------|-------------|-----------------|
| IAP package integration | `revenue_cat` or `in_app_purchase` + backend | 3-5d |
| Subscription model | `SubscriptionTier` enum, `UserEntitlement` class | 4h |
| Paywall UI | Upgrade prompts, feature comparison, pricing display | 2-3d |
| Receipt validation | Cloud Function for server-side verification | 1d |
| Tier-aware rate limiting | Replace `static const` with tier-parameterized config | 4h |
| Subscription analytics | Purchase events, conversion tracking, churn signals | 4h |
| Restore purchases flow | Required by App Store guidelines | 4h |
| Subscription management UI | View/cancel/change plan in settings | 1d |

### Pricing Model Observations

Market data suggests two viable approaches for Butlery:

**Option A: One-time purchase** (Paprika/Mela model)
- $4.99 mobile / $9.99 desktop
- Pros: Subscription fatigue is real in 2025-2026; strong word-of-mouth; simpler implementation
- Cons: No recurring revenue; ongoing server costs (LLM, OCR, Firebase) not covered
- **Assessment**: Viable only if AI/OCR features are capped in free tier to control costs

**Option B: Freemium + subscription** (BigOven/Yummly model)
- Free: Core recipe management (limited AI imports)
- Pro: $14.99-24.99/year
- Pros: Recurring revenue covers server costs; aligns with cost structure
- Cons: Conversion rates for recipe apps are typically 2-5%
- **Assessment**: Better fit given LLM/OCR operating costs

**Note**: No monetization decisions have been made — this analysis is readiness assessment only.

---

## Dimension 7: Market Positioning (2/5)

### Summary
Butlery occupies a genuine whitespace in the Swedish market: no competitor combines Swedish-language personal recipe management with social features, AI import, and allergen tracking. However, zero ASO (App Store Optimization) work has been done, and the `com.example` bundle ID signals an unfinished product to anyone who looks.

### Swedish Market Context

**Market size**: Sweden has ~10.5M population, ~8M smartphone users. The recipe app market is fragmented between:
- **ICA Handla**: Dominant for grocery-linked recipes (free, massive distribution)
- **Köket.se**: Dominant for recipe discovery/inspiration (free, ad-supported, TV4-backed)
- **International apps**: Paprika, Mela, Crouton — all English-only, no Swedish localization

**Whitespace**: Personal recipe management in Swedish with social features. No direct competitor.

### Positioning Strengths

1. **Swedish-first**: UI, NLP, ingredient database, and cultural recipes all Swedish-native. Not a translation.
2. **Cross-platform**: Flutter enables iOS + Android + Web simultaneously. Most indie competitors are Apple-only.
3. **Deep links + web platform**: Recipe sharing via URL — enables organic growth.
4. **GDPR compliance**: EU-required, competitive barrier for non-EU indie apps entering the market.

### Positioning Weaknesses

1. **No ASO preparation**: No keywords, descriptions, screenshots, or store listing optimization.
2. **`com.example.butlery`**: Unprofessional bundle ID signals unfinished product. Visible in store listings and app analytics.
3. **No social proof**: No reviews, ratings, or press coverage.
4. **No referral mechanism**: Sharing recipes is implemented but no explicit invite/referral flow with incentives.

### Issues

**M7.1: No referral/invite mechanism**
- Recipe sharing exists but no "invite a friend" flow with tracking.
- Social apps live or die by viral coefficient.
- **Fix**: Add invite flow with deep link tracking. **Effort**: 1d

**L7.1: Web SEO defaults**
- As noted in D5, default Flutter meta tags limit organic web discovery.
- **Effort**: 2h

---

## Phase 2 Preparation

### Sprint Grouping Suggestions

**Sprint A: Store Blockers (must-do before any submission)**
| Issue | ID | Effort |
|-------|-----|--------|
| Change bundle ID across all platforms | C5.1 | 1h |
| Configure Android release signing | C5.2 | 2h |
| Remove orphan NSFaceIDUsageDescription | H5.1 | 15m |
| Draft and host Terms of Service | H5.2 | 2h |
| Fix `runZonedGuarded` no-op | M5.1 | 1h |
| **Total** | | **~6h** |

**Sprint B: Security & Architecture Prerequisites**
| Issue | ID | Effort |
|-------|-----|--------|
| Firestore rules — protect subscription fields | H2.1 | 4h |
| Tier-parameterizable rate limits | H1.1 | 4h |
| Register OCR tracker in DI | M2.1 | 2h |
| **Total** | | **~10h** |

**Sprint C: Table-Stakes Feature Gap**
| Issue | ID | Effort |
|-------|-----|--------|
| Cooking timer in cook mode | M3.1 | 1-2d |
| Apple Sign-In (if social login planned) | H5.3 | 1d |
| Demo account for App Store review | M5.2 | 4h |
| **Total** | | **~3-4d** |

**Sprint D: Revenue Infrastructure (when monetization decision is made)**
| Issue | ID | Effort |
|-------|-----|--------|
| IAP package integration | — | 3-5d |
| Subscription model + entitlement | — | 4h |
| Paywall UI | — | 2-3d |
| Receipt validation Cloud Function | — | 1d |
| Subscription analytics | H1.2 | 4h |
| Store metadata preparation | M5.3 | 1-2d |
| **Total** | | **~2-3 weeks** |

### Cross-References to Other Reports

| Report | Overlap | Notes |
|--------|---------|-------|
| 02 — Security | Firestore rules (H2.1) | Blanket user write rule affects more than just subscription tier |
| 04 — Performance | Rate limiting (H1.1) | Server-side rate limits also flagged for performance tuning |
| 05 — Dependencies | IAP packages | No overlap — packages not yet added |
| 06 — UX/Platform | Store submission (D5) | Store metadata and accessibility overlap |
| 09 — AI/LLM Quality | AI import costs | LLM cost limits in rate_limit_models affect tier design |

### Key Decision Points Before Sprint D

1. **Pricing model**: One-time vs. subscription vs. hybrid — determines IAP package choice and backend complexity.
2. **Free tier limits**: How many recipes? How many AI imports? Collaborative lists? — determines what to gate.
3. **IAP provider**: `in_app_purchase` (raw) vs. `revenue_cat` (managed) — RevenueCat adds cost but dramatically reduces implementation time.
4. **Subscription vs. one-time**: Server costs (LLM, OCR, Firebase) push toward subscription, but market sentiment favors one-time.

---

## Scoring Rationale

| # | Dimension | Score | Key Factors |
|---|-----------|-------|-------------|
| 1 | Entitlement Architecture | 10/20 | FeatureFlagService tier-ready (+5), DI slot clean (+3), zero subscription concepts (-5), 71-file PermissionService blast radius (-3) |
| 2 | Schema Extensibility | 10/15 | SerializationUtils backward-compatible (+5), UserProfile clean for extension (+3), Firestore rules security gap (-5), rate limiters not parameterizable (-3) |
| 3 | Feature Completeness | 14/20 | All core + social + meal planning complete (+12), cooking timer missing (-3), nutritional info missing (-2), voice control missing (-1) |
| 4 | Differentiation & Moat | 11/15 | Swedish NLP genuine moat (+5), AI import pipeline (+3), GDPR rare for indie (+2), social replicable (+1), ICA ecosystem risk (-) |
| 5 | App Store Submission Risk | 4/15 | Two hard blockers (-6), missing ToS/demo/metadata (-3), orphan plist key (-1), Crashlytics gap (-1) |
| 6 | Revenue Infrastructure | 5/10 | Cloud Functions + analytics + DI ready (+5), zero monetization-specific code (-5) |
| 7 | Market Positioning | 2/5 | Swedish whitespace (+2), no ASO (-1), unprofessional bundle ID (-1), no referral (-1) |
| **Total** | | **56/100** | **Strong product foundation, significant store & revenue infrastructure gaps** |
