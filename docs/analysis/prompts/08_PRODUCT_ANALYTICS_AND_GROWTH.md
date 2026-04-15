# Product Analytics, Growth & Retention Engineering Analysis

## Analyst

Claude (Opus 4.6) -- comprehensive product analytics and growth analysis agent.

## Mission

Perform a forensic-level investigation of Butlery's product analytics instrumentation, growth infrastructure, and retention engineering. The goal is to verify that the team can answer critical product questions (where users drop off, which features drive retention, what notification types correlate with engagement) and has the infrastructure to experiment and optimize.

80% of mobile app users churn within 3 days. A world-class app measures and combats this. Butlery has 6 specialized analytics trackers, FCM notifications with batching/preferences/quiet hours, and a full onboarding flow -- but no existing prompt evaluates whether these systems actually answer product questions.

This is not a superficial review. This is a deep investigation across 8 weighted dimensions, totaling 100 points.

**Cross-Prompt Boundaries**:
- Analytics SDK integration and infrastructure: covered in `03_INFRASTRUCTURE_AND_OPERATIONS.md` -- skip here.
- Notification delivery infrastructure (FCM setup, Cloud Functions): covered in `03_INFRASTRUCTURE_AND_OPERATIONS.md` -- skip here.
- App store metadata checklist (icons, screenshots, descriptions): covered in `06_USER_EXPERIENCE_AND_PLATFORM.md` -- skip here.
- This prompt owns all analytics event strategy, funnel coverage, retention tracking, notification segmentation/timing, feature flags, onboarding optimization, and re-engagement infrastructure.

---

## Two-Phase Approach

### Phase 1: Investigation & Documentation (THIS PHASE)

**CRITICAL**: Document everything, change nothing.
- Investigate all aspects systematically
- Document findings with file:line references
- Classify issues by severity (Critical/High/Medium/Low)
- Provide effort estimates for each issue
- **ZERO code changes made**
- **ZERO files created or modified**
- Output: Complete findings report ready for Phase 2 planning

### Phase 2: Smart Remediation Planning (AFTER Phase 1 Complete)

- Review ALL Phase 1 findings together
- Prioritize by impact, effort, and dependencies
- Group related issues for efficient batch fixing
- Create optimized fix sequence to minimize breaking changes
- Generate sprint-structured remediation plan

**DO NOT START PHASE 2 UNTIL PHASE 1 IS COMPLETE**

---

## Shared Project Context

```
Project:             Butlery (Swedish recipe and meal planning app)
Firebase project:    butlery-app-1
Framework:           Flutter / Dart
Codebase size:       ~850+ .dart files in lib/, ~150k+ lines of hand-written code
Architecture:        MVVM + Repository
                     Views -> ViewModels -> Services -> Repositories -> Firebase
DI system:           ServiceLocator.get<T>(), modular DI modules

Analytics stack:
  - 6 specialized analytics trackers (under lib/services/analytics/)
  - AnalyticsService facade
  - Firebase Analytics integration
  - Interaction logger (lib/services/feedback/interaction_logger.dart)

Notification stack:
  - FCM Cloud Functions (batching, preferences, quiet hours)
  - NotificationPreferenceManager
  - Deep linking from notifications

Feature flags:
  - FeatureFlagService (lib/services/feature_flags/)
  - Firebase Remote Config usage

Onboarding:
  - 5-page onboarding flow (lib/views/onboarding/)

Generated file exclusions (skip during analysis):
  - *.g.dart
  - *.freezed.dart
  - app_localizations*.dart
```

---

## Investigation Framework: 8 Dimensions (100 Points Total)

### Dimension 1: Analytics Instrumentation Completeness (20 points)

**Investigation Scope**: Is every critical user action tracked? Are there blind spots?

**Specific Investigation Tasks:**

1. **Event Taxonomy Audit**
   ```
   Map all analytics events currently logged:
   - List every event name, parameters, and trigger location
   - Check naming consistency (snake_case? camelCase? prefix conventions?)
   - Check for duplicate events (same action logged with different names)
   - Verify PII exclusion (no user emails, names, or IDs in event params)

   Search patterns:
   - analytics.log / trackEvent / logEvent calls across codebase
   - AnalyticsService method calls
   - Firebase Analytics event logging
   ```

2. **Critical Action Coverage**
   ```
   For each critical user action, verify an analytics event exists:

   Recipe lifecycle:
   - [ ] Recipe created (manual)
   - [ ] Recipe imported (URL)
   - [ ] Recipe imported (OCR/image)
   - [ ] Recipe imported (AI structured)
   - [ ] Recipe edited
   - [ ] Recipe deleted
   - [ ] Recipe viewed
   - [ ] Recipe cooked ("lagat idag")
   - [ ] Recipe shared
   - [ ] Recipe favorited

   Social actions:
   - [ ] Friend request sent
   - [ ] Friend request accepted
   - [ ] Comment posted
   - [ ] Rating given
   - [ ] Group created
   - [ ] Group joined
   - [ ] Content shared to group

   Menu planning:
   - [ ] Menu created
   - [ ] Menu recipe added
   - [ ] Shopping list generated
   - [ ] Shopping list item checked

   Import pipeline (end-to-end):
   - [ ] Import initiated (which method?)
   - [ ] Import tier used (site config / regex / LLM)
   - [ ] Import succeeded
   - [ ] Import failed (with failure reason)
   - [ ] Import duration
   - [ ] Post-import edit (user corrected AI output)

   Navigation:
   - [ ] Screen views (all major screens)
   - [ ] Tab switches
   - [ ] Search performed (with query? without PII?)
   ```
   - Document every gap with severity (Critical = unmeasurable core flow)

3. **Event Parameter Quality**
   ```
   Check:
   - Are events parameterized enough for analysis? (e.g., "recipe_created" should include source: manual/import/ocr)
   - Are boolean/enum parameters used instead of free-text?
   - Are timestamps included where duration matters?
   - Are events correlated (e.g., import_started and import_completed share a session ID)?
   ```

**Files to audit:**
- `lib/services/analytics/` (all 6 trackers + facade)
- `lib/services/feedback/interaction_logger.dart`
- All ViewModels (search for analytics calls)

**Output Required:**
- Complete event inventory (name, params, trigger location)
- Critical action coverage matrix (action x tracked?)
- Event quality assessment (naming, parameters, deduplication)
- Instrumentation gap list with severity

---

### Dimension 2: Funnel Coverage (18 points)

**Investigation Scope**: Are the critical user funnels fully instrumented from entry to completion?

**Specific Investigation Tasks:**

1. **Onboarding Funnel**
   ```
   Map every step in the onboarding flow:
   - App opened first time
   - Onboarding page 1 viewed / completed
   - Onboarding page 2 viewed / completed
   - ... (all 5 pages)
   - Onboarding completed
   - First recipe created / imported (time-to-first-value)

   Check:
   - Is each step individually tracked?
   - Can you calculate drop-off between each step?
   - Is time-to-first-value tracked?
   - Are skip/back actions tracked?
   ```

2. **Recipe Import Funnel**
   ```
   Map the full import pipeline:
   - Import button tapped
   - URL entered / image selected
   - Parsing started (which tier?)
   - Parsing progress events
   - Parsing completed (success/partial/fail)
   - Recipe review screen shown
   - User edits made (which fields?)
   - Recipe saved
   - Time from initiation to saved recipe

   Check: Can you identify where users abandon the import flow?
   ```

3. **Social Activation Funnel**
   ```
   Map:
   - First friend added
   - First share action
   - First comment given
   - First group joined/created
   - Progression from solo user to socially active

   Check: Can you segment users by social engagement level?
   ```

4. **Retention-Critical Funnels**
   ```
   Check:
   - Day 1, Day 7, Day 30 return events
   - Session frequency tracking
   - Feature engagement depth (how many features does a user touch?)
   - Churn risk signals (decreasing session frequency, unused features)
   ```

**Files to audit:**
- `lib/views/onboarding/` (all 5 pages)
- `lib/services/import/` (import flow)
- `lib/views/social/` (social feature views)
- Analytics service calls at each funnel step

**Output Required:**
- Funnel diagrams with instrumented vs uninstrumented steps
- Drop-off measurement capability per funnel
- Time-to-value tracking assessment
- Funnel gap severity classification

---

### Dimension 3: Retention & Cohort Tracking Infrastructure (15 points)

**Investigation Scope**: Can the team track retention cohorts and identify what drives long-term engagement?

**Specific Investigation Tasks:**

1. **Cohort Definition Capability**
   ```
   Check:
   - Can users be grouped by signup date (daily/weekly cohorts)?
   - Can users be grouped by acquisition source?
   - Can users be grouped by first action (manual recipe vs import)?
   - Is there a user properties system for segmentation?
   ```

2. **Retention Metrics**
   ```
   Check:
   - Day 1 / Day 7 / Day 30 retention tracking
   - Session frequency and duration tracking
   - Feature-level retention (do users who use feature X retain better?)
   - Resurrection tracking (users who return after 30+ day absence)
   ```

3. **North Star Metric**
   ```
   Check:
   - Is there a defined North Star metric? (e.g., "recipes cooked per week")
   - Is it tracked?
   - Is it dashboarded?
   - Can it be segmented by cohort?
   ```

4. **User Lifecycle Stage Tracking**
   ```
   Check:
   - New user, activated, engaged, power user, at-risk, churned stages
   - Are these stages defined and tracked?
   - Are there automated triggers based on lifecycle stage?
   ```

**Output Required:**
- Cohort tracking capability assessment
- Retention metric coverage
- North Star metric status
- User lifecycle tracking gaps

---

### Dimension 4: Notification Strategy & Segmentation (15 points)

**Investigation Scope**: Are notifications strategically timed, segmented, and tied to engagement outcomes?

**Specific Investigation Tasks:**

1. **Notification Types Inventory**
   ```
   List all notification types:
   - Social (friend request, comment, share, group invite)
   - Content (new recipe from friend, recipe suggestion)
   - Engagement (cooking reminder, menu planning prompt)
   - System (app update, policy change)

   For each type:
   - Is it implemented?
   - Is it configurable (user can toggle on/off)?
   - Does it have a deep link to relevant content?
   - Is send rate tracked?
   - Is open rate tracked?
   - Is conversion tracked (notification -> action)?
   ```

2. **Notification Segmentation**
   ```
   Check:
   - Can FCM sends target user segments? (not just broadcast)
   - Is there behavioral targeting? (e.g., "users who haven't opened in 3 days")
   - Is there preference-based targeting? (respecting user notification prefs)
   - Are quiet hours enforced server-side?
   ```

3. **Notification Deep Linking**
   ```
   Check:
   - Do all notifications deep link to the relevant content?
   - Is the deep link target correct (exact recipe, exact comment, etc.)?
   - What happens if the deep link target is deleted?
   - Is the deep link authenticated (user must be logged in)?
   ```

4. **Notification Effectiveness Measurement**
   ```
   Check:
   - Can the team correlate notification sends with retention?
   - Can they identify which notification types drive engagement vs annoyance?
   - Is there notification fatigue detection?
   - Are notification A/B tests possible?
   ```

**Files to audit:**
- `lib/services/notifications/` (all modules)
- `lib/services/notifications/notification_preference_manager.dart`
- Cloud Functions for notification sending
- Deep link routing configuration

**Output Required:**
- Notification type inventory with capability matrix
- Segmentation capability assessment
- Deep link coverage audit
- Effectiveness measurement gaps

---

### Dimension 5: Feature Flag & Experimentation Infrastructure (12 points)

**Investigation Scope**: Can the team run experiments and progressively roll out features?

**Specific Investigation Tasks:**

1. **Feature Flag System**
   ```
   Check feature_flag_service.dart:
   - What flags currently exist?
   - Are flags remotely configurable (Firebase Remote Config)?
   - Can flags be targeted by user segment?
   - Is there a default value strategy for new users?
   - How are flags consumed in code? (direct check vs abstraction)
   ```

2. **Remote Config Usage**
   ```
   Search for Firebase Remote Config:
   - What values are remotely configurable?
   - Can AI features be disabled remotely? (kill switch)
   - Can UI elements be A/B tested?
   - Are config values cached and refreshed appropriately?
   ```

3. **A/B Testing Capability**
   ```
   Check:
   - Is there infrastructure for randomized experiments?
   - Can experiment assignments be logged as analytics user properties?
   - Can conversion metrics be segmented by experiment group?
   - Is there a mechanism to gradually roll out (1% -> 10% -> 50% -> 100%)?
   ```

4. **Progressive Delivery**
   ```
   Check:
   - Can features be rolled back without an app update?
   - Is there a canary release mechanism?
   - Can specific users (beta testers) get features early?
   - Is there a maintenance mode toggle?
   ```

**Files to audit:**
- `lib/services/feature_flags/feature_flag_service.dart`
- `lib/core/di/modules/search_module.dart` (feature flag example)
- Firebase Remote Config usage across codebase

**Output Required:**
- Feature flag inventory
- Remote Config usage assessment
- A/B testing capability evaluation
- Progressive delivery readiness

---

### Dimension 6: Onboarding Flow Optimization (10 points)

**Investigation Scope**: Is the onboarding flow optimized for activation and retention?

**Specific Investigation Tasks:**

1. **Onboarding Flow Structure**
   ```
   Read lib/views/onboarding/ (all 5 pages):
   - What does each page collect/show?
   - Is the flow skippable?
   - Is progress indicated?
   - How long does it take? (measure complexity)
   ```

2. **Activation Metrics**
   ```
   Check:
   - Is "activated user" defined? (e.g., "created first recipe within 24 hours")
   - Is the activation event tracked?
   - Can drop-off be measured at each onboarding step?
   - Is there a "quick win" that demonstrates value fast?
   ```

3. **Personalization**
   ```
   Check:
   - Does onboarding collect allergen/dietary preferences?
   - Is the first experience personalized based on these choices?
   - Are two-step quick picks implemented for fast personalization?
   - Is the app immediately useful after onboarding? (pre-populated content?)
   ```

4. **Re-Engagement for Incomplete Onboarding**
   ```
   Check:
   - What happens if a user abandons onboarding mid-flow?
   - Can they resume where they left off?
   - Is there a notification to bring them back?
   - Is there a simplified re-entry path?
   ```

**Files to audit:**
- `lib/views/onboarding/` (all 5 pages)
- Onboarding-related analytics events
- Post-onboarding first experience flow

**Output Required:**
- Onboarding flow map with instrumentation status
- Activation metric definition and tracking assessment
- Personalization capability evaluation
- Incomplete onboarding handling

---

### Dimension 7: App Store Optimization (ASO) Technical Readiness (5 points)

**Investigation Scope**: Is the app technically ready for ASO and discoverability?

**Specific Investigation Tasks:**

1. **Review Prompt Strategy**
   ```
   Check:
   - Is there an in-app review prompt? (StoreKit / Play In-App Review API)
   - When is it triggered? (after meaningful success event?)
   - Is it rate-limited per Apple/Google guidelines?
   - Is the trigger event tracked in analytics?
   ```

2. **Deep Linking for Marketing**
   ```
   Check:
   - Are universal links / app links configured?
   - Can marketing campaigns deep link to specific content?
   - Is campaign attribution tracked? (UTM parameters or equivalent)
   - Can referral sources be identified in analytics?
   ```

3. **Technical ASO Elements**
   ```
   Check:
   - App indexing for search engines (Firebase App Indexing or equivalent)
   - Structured data for recipe content (Schema.org Recipe)
   - Social sharing metadata (Open Graph tags for shared recipes)
   ```

**Output Required:**
- Review prompt implementation status
- Deep linking capability for marketing
- Technical ASO readiness assessment

---

### Dimension 8: Re-Engagement & Win-Back Infrastructure (5 points)

**Investigation Scope**: Can the app bring back lapsed users?

**Specific Investigation Tasks:**

1. **Lapsed User Detection**
   ```
   Check:
   - Is there a definition of "lapsed user"? (e.g., no session in 14 days)
   - Is lapse detected on the server side? (Cloud Function cron?)
   - Are lapsed users segmented for re-engagement?
   ```

2. **Win-Back Notifications**
   ```
   Check:
   - Are there automated win-back notification campaigns?
   - Is notification content personalized? ("Your friends shared 3 new recipes")
   - Is there escalation? (Day 7 nudge, Day 14 reminder, Day 30 final attempt)
   - Is re-engagement success tracked?
   ```

3. **Email Re-Engagement**
   ```
   Check:
   - Is there email infrastructure for re-engagement?
   - Are email preferences respected?
   - Is there an unsubscribe mechanism?
   ```

**Output Required:**
- Lapsed user detection capability
- Win-back infrastructure assessment
- Re-engagement channel coverage

---

## Scoring Framework

| # | Dimension | Points | Scoring Guidance |
|---|-----------|--------|------------------|
| 1 | Analytics Instrumentation | /20 | 20: Every critical action tracked with quality params. 10: Major actions tracked, gaps in secondary flows. 0: Minimal or no analytics. |
| 2 | Funnel Coverage | /18 | 18: All critical funnels fully instrumented, drop-off measurable. 9: Main funnels partially covered. 0: No funnel tracking. |
| 3 | Retention & Cohort Tracking | /15 | 15: Cohorts defined, retention tracked, North Star measured. 8: Basic session tracking. 0: No retention infrastructure. |
| 4 | Notification Strategy | /15 | 15: Segmented, timed, deep-linked, effectiveness measured. 8: Basic notifications work. 0: Broadcast-only, no measurement. |
| 5 | Feature Flags & Experimentation | /12 | 12: Remote flags, A/B testing, progressive delivery. 6: Basic flags exist. 0: No feature flag system. |
| 6 | Onboarding Optimization | /10 | 10: Fully instrumented, personalized, activation tracked. 5: Onboarding exists but uninstrumented. 0: No onboarding. |
| 7 | ASO Technical Readiness | /5 | 5: Review prompts, deep links, app indexing. 3: Partial. 0: None. |
| 8 | Re-Engagement Infrastructure | /5 | 5: Lapse detection, win-back campaigns, multi-channel. 3: Basic nudges. 0: No re-engagement. |

---

## Output Format

### Executive Summary

```
BUTLERY PRODUCT ANALYTICS & GROWTH ANALYSIS - PHASE 1 FINDINGS
================================================================
Analysis Date: [Date]
Analyst: Claude (Opus 4.6)
Scope: Analytics, funnels, retention, notifications, experimentation, onboarding

OVERALL SCORE: X/100
+-- Analytics Instrumentation:        X/20 points
+-- Funnel Coverage:                  X/18 points
+-- Retention & Cohort Tracking:      X/15 points
+-- Notification Strategy:            X/15 points
+-- Feature Flags & Experimentation:  X/12 points
+-- Onboarding Optimization:          X/10 points
+-- ASO Technical Readiness:          X/5 points
+-- Re-Engagement Infrastructure:     X/5 points

STATUS: [Launch Ready | Needs Work | Critical Gaps]

CRITICAL GAPS: X found
HIGH PRIORITY: X found
MEDIUM PRIORITY: X found
LOW PRIORITY: X found

TOP 5 GROWTH RISKS:
1. [Description]
2. [Description]
3. [Description]
4. [Description]
5. [Description]
```

### Per-Dimension Report Format

For each dimension, provide: summary (2-3 sentences), issues grouped by CRITICAL/HIGH/MEDIUM/LOW with file:line references, impact description, required fix, and effort estimate. Include recommendations and quick wins.

### Analytics Coverage Dashboard

| User Action Category | Actions Defined | Actions Tracked | Coverage |
|---------------------|-----------------|-----------------|----------|
| Recipe lifecycle | X | Y | Z% |
| Social actions | X | Y | Z% |
| Menu planning | X | Y | Z% |
| Import pipeline | X | Y | Z% |
| Navigation | X | Y | Z% |
| Onboarding | X | Y | Z% |

### Phase 2 Preparation

Provide total issue counts by severity, estimated total remediation effort, and next steps for Phase 2 smart planning.

---

## Investigation Execution Plan

### Stage 1: Analytics Service Deep Dive (1.5 hours)

```
Read and analyze:
- lib/services/analytics/ (all 6 trackers + facade)
- lib/services/feedback/interaction_logger.dart
- Search for all analytics event logging across codebase

Focus: Event inventory, naming consistency, parameter quality, PII exclusion
```

### Stage 2: Funnel & Flow Analysis (1.5 hours)

```
Read and analyze:
- lib/views/onboarding/ (all 5 pages)
- lib/services/import/ (import flow instrumentation)
- lib/views/social/ (social feature instrumentation)
- Key ViewModels for analytics calls at funnel steps

Focus: Funnel completeness, drop-off measurement, activation tracking
```

### Stage 3: Notification & Feature Flag Review (1 hour)

```
Read and analyze:
- lib/services/notifications/ (all modules)
- lib/services/feature_flags/feature_flag_service.dart
- Firebase Remote Config usage
- Cloud Functions for notification sending

Focus: Segmentation, deep linking, experimentation, progressive delivery
```

### Stage 4: Retention & Re-Engagement Assessment (1 hour)

```
Read and analyze:
- Retention-related analytics events
- Win-back notification logic
- Lapsed user detection (if any)
- Review prompt implementation

Focus: Cohort tracking, lifecycle stages, re-engagement channels
```

### Stage 5: Report Compilation (1 hour)

Compile all findings into structured report.

**Total: 6-7 hours**

---

## Phase 1 Deliverables Checklist

- [ ] Executive summary with overall score (out of 100)
- [ ] Detailed findings for all 8 dimensions with file:line references
- [ ] Issue classification (Critical/High/Medium/Low) with counts and effort estimates
- [ ] Complete analytics event inventory
- [ ] Critical action coverage matrix
- [ ] Funnel instrumentation diagrams
- [ ] Retention metric coverage assessment
- [ ] Notification capability matrix
- [ ] Feature flag inventory
- [ ] Onboarding flow instrumentation map
- [ ] Analytics Coverage Dashboard
- [ ] Phase 2 preparation section with issue grouping

---

## Critical Reminders

1. **DOCUMENT, DO NOT FIX** -- this is investigation only
2. **PRODUCT FOCUS** -- this prompt cares about "can we measure and improve?" not "does it work?"
3. **NO INFRASTRUCTURE DUPLICATION** -- skip FCM setup, SDK integration (covered by Prompt 03)
4. **NO APP STORE METADATA** -- skip icons, screenshots, descriptions (covered by Prompt 06)
5. **ZERO CODE CHANGES** -- investigation and documentation only
6. **REALISTIC** -- pre-launch apps naturally have analytics gaps; calibrate severity appropriately
7. **ACTIONABLE** -- every gap should have a concrete recommendation with effort estimate
8. **PRIVACY-AWARE** -- flag any analytics that might capture PII
