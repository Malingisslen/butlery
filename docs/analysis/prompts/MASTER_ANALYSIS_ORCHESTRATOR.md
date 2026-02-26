# Master Analysis Orchestrator

**Consolidated entry point for 10 analysis prompts covering the entire Butlery Flutter codebase.**

This orchestrator coordinates 10 focused, self-contained prompts: 6 original prompts covering core engineering concerns, plus 4 new prompts covering AI quality, product analytics, trust/safety, and competitive positioning.

Each prompt can run independently or as part of a coordinated analysis session.

---

## Purpose

Run a comprehensive, forensic-level audit of the Butlery codebase across ten dimensions.
The approach is strictly two-phase:

- **Phase 1: Investigation only.** No code changes. Produce findings with file:line references.
- **Phase 2: Smart remediation.** Prioritized fix plan based on Phase 1 findings.

---

## Known Project Context

All 10 prompts share these baseline facts. Do not re-discover them during analysis.

```
Project:             Butlery (Swedish recipe and meal planning app)
Firebase project:    butlery-app-1
Framework:           Flutter / Dart
Codebase size:       ~850+ .dart files in lib/, ~150k+ lines of hand-written code
Architecture:        MVVM + Repository
                     Views -> ViewModels -> Services -> Repositories -> Firebase
DI system:           ServiceLocator.get<T>(), modular DI modules
                     (Core, Content, Social, Messaging, Collaboration, Performance, UI)
                     Constructor injection in DI modules, ServiceLocator in widgets/ViewModels

Key patterns:
  - BaseService              (pre-flight checks, caching)
  - BaseFirebaseRepository   (CRUD + audit logging)
  - ErrorHandlingMixin       (async error handling, retries) -- 100% adopted
  - SerializationUtils       (Firestore parsing)            -- 100% adopted
  - AsyncOperationMixin      (loading/error states)
  - PermissionValidationMixin (security on all repositories)

AI/NLP stack:
  - Cloud Functions: Mistral AI integration (structure-recipe, ocr-recipe-image)
  - Client-side: Multi-tier parsing pipeline (site config, regex, LLM fallback)
  - NLP: Swedish compound splitter, Viterbi context processor, line classifier
  - Tagging: 5-phase auto-tagging pipeline

Social features:     Friends, sharing, comments, ratings, groups, messaging
Firebase services:   Firestore, Auth, Storage, FCM, Cloud Functions
Platforms:           Android, iOS, Web, macOS, Windows
CI/CD:               GitHub Actions -- 5 workflows
                     (analyze.yml, test.yml, build-validation.yml,
                      architecture-validation.yml, e2e_tests.yml)
                     Dependabot enabled
Security:            Firestore rules: 1465 lines, 74 match rules
                     Storage rules: 61 lines
                     34 composite Firestore indexes
GDPR:                Phase 1 complete (Articles 7, 15, 17, 30)
Test coverage:       ViewModels 100%, Services 96%, Firebase Repos 88%
Monetization:        Pre-monetization (no decisions yet)
Target market:       Swedish-speaking users (primary)

Generated file exclusions (skip during analysis):
  - *.g.dart
  - *.freezed.dart
  - app_localizations*.dart
```

---

## Pre-Analysis Tooling

Run these commands BEFORE feeding any prompt. Attach their output as context.

```bash
# 1. Flutter static analysis (required)
flutter analyze

# 2. Dart Code Metrics - deeper lint analysis (if installed)
dcm analyze lib/

# 3. OSV vulnerability scanner (if installed)
osv-scanner --lockfile=pubspec.lock

# 4. Dependency freshness
flutter pub outdated

# 5. Custom code intelligence (if available)
dart tools/code_intelligence_platform.dart
```

If a tool is not installed, skip it and note its absence in the prompt context.
The prompts are designed to work without optional tooling, but results improve with it.

---

## The 10 Prompts

| #  | File                                                | Scope                                              | Weight |
|----|----------------------------------------------------|----------------------------------------------------|--------|
| 01 | `01_CODE_QUALITY_AND_ARCHITECTURE.md`              | Code correctness, patterns, readability, doc health | 15%    |
| 02 | `02_SECURITY_AND_COMPLIANCE.md`                    | OWASP, auth, encryption, rules, GDPR               | 14%    |
| 03 | `03_INFRASTRUCTURE_AND_OPERATIONS.md`              | Build, test, deploy, monitor, recover               | 14%    |
| 04 | `04_PERFORMANCE_AND_SCALABILITY.md`                | Startup, frame rate, memory, queries, scaling       | 14%    |
| 05 | `05_DEPENDENCIES_AND_SUPPLY_CHAIN.md`              | CVEs, licenses, maintenance, bloat                  | 8%     |
| 06 | `06_USER_EXPERIENCE_AND_PLATFORM.md`               | Design, accessibility, i18n, platform compliance    | 10%    |
| 07 | `07_AI_LLM_QUALITY_AND_RELIABILITY.md`             | AI output quality, NLP accuracy, OCR robustness     | 10%    |
| 08 | `08_PRODUCT_ANALYTICS_AND_GROWTH.md`               | Analytics, funnels, retention, notifications         | 5%     |
| 09 | `09_TRUST_SAFETY_AND_PRIVACY.md`                   | UGC moderation, consent sequencing, privacy manifest | 7%    |
| 10 | `10_MONETIZATION_AND_COMPETITIVE_POSITIONING.md`   | Entitlements, feature completeness, market position  | 3%    |

Each prompt is fully self-contained. It includes the shared project context block above
and its own investigation checklist. No prompt requires output from another to execute.

---

## Execution Strategy

### Option A: Sequential

Run prompts in numeric order: 01 -> 02 -> ... -> 10.

Simple and reliable. Each session starts fresh. Total time: 10 sessions.

### Option B: Parallel Agents (Recommended)

Split into three waves to maximize throughput while respecting soft dependencies.

**Wave 1** (independent, run in parallel):
- 01 Code Quality and Architecture
- 02 Security and Compliance
- 05 Dependencies and Supply Chain

**Wave 2** (run after Wave 1 completes):
- 03 Infrastructure and Operations
- 04 Performance and Scalability
- 06 User Experience and Platform

**Wave 3** (run after Wave 2 completes, or in parallel with Wave 2):
- 07 AI/LLM Quality and Reliability
- 08 Product Analytics and Growth
- 09 Trust, Safety and Privacy
- 10 Monetization and Competitive Positioning

Wave 3 prompts have minimal dependencies on Wave 1-2 and can run in parallel with Wave 2
if preferred. The only soft dependency is that Prompt 09 benefits from Prompt 02's GDPR
findings, and Prompt 10 benefits from Prompt 06's app store metadata review.

### Soft Dependencies

These are not hard blockers, but running them in order improves cross-referencing:

| Run first                | Before                         | Reason                                           |
|--------------------------|--------------------------------|--------------------------------------------------|
| 05 Dependencies          | 02 Security                    | CVE findings inform security assessment          |
| 01 Code Quality          | 04 Performance                 | Architecture issues inform perf diagnosis        |
| 03 Infrastructure        | 06 User Experience             | Build/deploy context informs platform UX         |
| 02 Security              | 09 Trust, Safety & Privacy     | GDPR findings inform consent sequencing audit    |
| 04 Performance           | 07 AI/LLM Quality              | Timeout findings inform AI failure mode analysis |
| 06 User Experience       | 10 Monetization & Competitive  | App store metadata informs submission risk        |
| 03 Infrastructure        | 08 Product Analytics           | SDK integration informs analytics completeness   |

If running in parallel, each prompt produces complete findings on its own.
The dependencies only matter if you want one prompt to reference another's output.

---

## Cross-Prompt Deduplication Rules

To avoid redundant analysis, each topic is owned by exactly one prompt.
Other prompts that touch adjacent areas must defer to the owning prompt.

### Original Deduplication Rules (Prompts 01-06)

| Topic                          | Owned by              | Skip in            |
|--------------------------------|-----------------------|---------------------|
| Firestore/Storage security rules | 02 Security         | 04 Performance      |
| Firebase schema and queries    | 04 Performance        | 01 Code Quality     |
| GDPR compliance                | 02 Security           | 01 Code Quality     |
| App store metadata checklist   | 06 User Experience    | 03 Infrastructure, 10 Monetization |
| Dependency CVEs and licenses   | 05 Dependencies       | 02 Security, 07 AI Quality |
| Test coverage and strategy     | 03 Infrastructure     | 01 Code Quality     |
| Accessibility                  | 06 User Experience    | 01 Code Quality     |
| CI/CD pipeline design          | 03 Infrastructure     | 01 Code Quality     |
| Monitoring and observability   | 03 Infrastructure     | 04 Performance      |
| Disaster recovery              | 03 Infrastructure     | 02 Security         |

### New Deduplication Rules (Prompts 07-10)

| Topic                                   | Owned by                  | Skip in                   |
|-----------------------------------------|---------------------------|---------------------------|
| AI/LLM API key security                | 02 Security               | 07 AI Quality             |
| AI/LLM Cloud Function timeout/perf     | 04 Performance            | 07 AI Quality             |
| AI/LLM output validation & quality     | **07 AI Quality**         | 01, 02, 04                |
| NLP pipeline accuracy                  | **07 AI Quality**         | 01 Code Quality           |
| Analytics SDK integration              | 03 Infrastructure         | 08 Growth                 |
| Analytics event strategy & completeness | **08 Growth**            | 03, 06                    |
| Notification delivery infrastructure   | 03 Infrastructure         | 08 Growth                 |
| Notification strategy & segmentation   | **08 Growth**            | 03, 06                    |
| GDPR consent service implementation    | 02 Security               | 09 Trust/Safety           |
| SDK consent race conditions            | **09 Trust/Safety**       | 02 Security               |
| Privacy manifest & ATT                 | **09 Trust/Safety**       | 02, 06                    |
| UGC moderation                         | **09 Trust/Safety**       | 02, 06                    |
| App store rejection risk assessment    | **10 Monetization**       | 06 UX                     |
| Competitive feature analysis           | **10 Monetization**       | 06 UX                     |

When a prompt encounters a topic owned by another prompt, it should note
"Deferred to prompt NN" and move on. Do not duplicate the analysis.

---

## Final Synthesis

After all 10 prompts complete Phase 1, merge their reports into a single executive summary.

### Weighted Scoring Formula

```
Overall Score = (01 * 0.15) + (02 * 0.14) + (03 * 0.14) + (04 * 0.14)
              + (05 * 0.08) + (06 * 0.10) + (07 * 0.10) + (08 * 0.05)
              + (09 * 0.07) + (10 * 0.03)
```

Each prompt produces a score from 0-100. The weighted average yields the overall health score.

### Score Interpretation

| Range   | Rating       | Action                                    |
|---------|--------------|-------------------------------------------|
| 90-100  | Excellent    | Minor polish only                         |
| 75-89   | Good         | Targeted improvements, no urgency         |
| 60-74   | Acceptable   | Prioritized remediation within 2 sprints  |
| 40-59   | Needs work   | Significant remediation, block new features|
| 0-39    | Critical     | Stop feature work, fix foundations first  |

### Consolidation Steps

1. **Collect all CRITICAL findings** from all 10 reports into a single list.
   Sort by severity (CRITICAL > HIGH > MEDIUM > LOW), then by effort (quick wins first).

2. **Deduplicate.** If two prompts flagged the same issue despite dedup rules,
   keep the deeper analysis and discard the shallow mention.

3. **Build unified remediation roadmap.**
   Group fixes into sprints:
   - Sprint 1: All CRITICAL items and quick-win HIGH items (focus: app store blockers from 09, data integrity from 02/07)
   - Sprint 2: Remaining HIGH items and systemic MEDIUM items
   - Sprint 3: Remaining MEDIUM items and LOW items worth fixing
   - Backlog: LOW items and nice-to-haves

4. **Produce executive summary.**
   One page covering: overall score, top 5 risks, top 5 strengths,
   sprint roadmap overview, and any items requiring immediate attention.

---

## Prompt Lineage

### Original 6 Prompts (v4)

This consolidated system replaces the following 16 prompts from the v2/ directory:

| Consolidated into | Replaces (v2/v3 prompts)                                            |
|--------------------|---------------------------------------------------------------------|
| 01 Code Quality    | Code Analysis, Documentation Analysis, MD File Analysis, Edge Cases |
| 02 Security        | Security Analysis, Firebase Analysis (security portions)            |
| 03 Infrastructure  | CI/CD Analysis, Testing Analysis, Monitoring, Disaster Recovery     |
| 04 Performance     | Performance Analysis, Scalability Analysis, Firebase (query/index)  |
| 05 Dependencies    | Dependencies Analysis                                              |
| 06 User Experience | UX/UI Analysis, Internationalization, Platform Analysis             |

The v2/ directory is retained for reference but should not be used for new analyses.

### New 4 Prompts (v4.1)

Added to close gaps identified in the original 6-prompt system:

| Prompt | Covers gaps in |
|--------|---------------|
| 07 AI/LLM Quality | AI output validation, NLP accuracy, prompt engineering, OCR robustness -- previously only API key (02) and timeout (04) were checked |
| 08 Product Analytics | Analytics event strategy, funnel coverage, retention tracking, notification strategy -- previously only SDK integration (03) was checked |
| 09 Trust, Safety & Privacy | UGC moderation, SDK consent sequencing, privacy manifests, ATT, data transfers -- previously only GDPR services (02) were checked |
| 10 Monetization & Competitive | Entitlement readiness, feature completeness, competitive positioning, app store submission risk -- previously not covered |

---

## Usage Example

```
1. Run pre-analysis tooling (see above). Save output to a file.

2. Open a new Claude session. Paste:
   - The contents of this orchestrator (for context)
   - The contents of 01_CODE_QUALITY_AND_ARCHITECTURE.md
   - The pre-analysis tooling output

3. Let the prompt execute Phase 1. Save the report.

4. Repeat for prompts 02-10 (or run in parallel per Option B).

5. Open a final session. Paste all 10 reports.
   Ask: "Synthesize these 10 analysis reports using the Final Synthesis
   instructions from the Master Analysis Orchestrator."

6. The output is your consolidated audit report with overall score
   and unified remediation roadmap.
```
