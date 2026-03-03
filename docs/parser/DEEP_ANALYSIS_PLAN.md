# Deep Analysis: Butlery Language Parser — Enhancement Opportunities

## Context

The Butlery parser is a 4-tier cascading system for extracting structured recipe data from Swedish text. It currently sits at **92.5% all-fields exact match** on a 318-entry golden dataset, far exceeding the original 75% CRF target.

---

## 1. Current Architecture Assessment

### What Works Well
- **Tiered cascade** (SchemaOrg → SiteConfig → RuleBased → LLM) is architecturally sound
- **Quality-based progression** with per-field confidence is production-grade
- **Selective LLM enhancement** (patch weak fields only) saves ~60-70% tokens
- **Security hardening** (P0-2 injection prevention, cache poisoning protection) is thorough
- **Active learning pipeline** (correction tracking + remote weight loading) is forward-looking
- **Swedish-specific features** (compound splitter, OCR error corrector, character normalizer)

### Where It Falls Short

| Area | Current State | Gap |
|------|--------------|-----|
| **Accuracy** | 92.5% exact match (was 57.9%) | Industry leaders hit 95%+ |
| **CRF weights** | ML-trained, 2,361 features | Was hand-crafted 5.7KB |
| **Training data** | 13K+ scraped lines | Was 121 golden entries |
| **Ingredient vocab** | 5,527 entries (Firebase synced) | Was ~350 static |
| **Preparation vocab** | 143 entries | Was ~106 |
| **LLM provider** | Mistral only | No structured output guarantee |
| **Instruction parsing** | Minimal structure | Just splits by line |

---

## 2. Prioritized Roadmap (Cost-Optimized)

### Tier A: Zero Ongoing Cost, High Accuracy Gain (Do First)

| # | Enhancement | Status | Accuracy Impact |
|---|------------|--------|----------------|
| 1 | Scrape 10K+ lines + retrain CRF | **DONE** | 57.9% → 71.4% |
| 2 | Bigram + gazeteer CRF features | **DONE** | Included in training |
| 3 | Expand KnownIngredients → 5,527 | **DONE** | Firebase-synced vocab |
| 4 | Definite form + compound splitter + vocab | **DONE** | 71.4% → 92.5% |
| 5 | Few-shot Swedish examples in LLM prompt | **DONE** | +10-20% when LLM used |
| 6 | CRF→LLM line-level routing | **DONE** | Same, 80% fewer LLM calls |
| 7 | Expand golden dataset to 500+ | **DONE (433)** | Human-verified measurement |
| **Result** | | **89.6% accuracy** | **Exceeded 75% target** |

### Tier B: Zero Cost, Good Returns

| # | Enhancement | Dev Days |
|---|------------|----------|
| 8 | Synthetic training data via Claude AI Max | **DONE** | 85.0% → 87.8% |
| 9 | Golden dataset expansion via Claude AI Max | **DONE** | 318 → 433 entries |
| 10 | User correction → retrain pipeline | 2-3 |
| 11 | Livsmedelsverket ingredient DB | 5-7 |
| 12 | Unify ParsedIngredient models | **DONE** |
| 18 | Add `size` field to ParsedIngredient | **DONE** |

### Tier C: Ongoing API Costs (Consider Carefully)

| # | Enhancement | Dev Days | When |
|---|------------|----------|------|
| 13 | Gemini Flash structured outputs | 3-5 | After Tier A proves insufficient |
| 14 | VLM direct photo→recipe | 3-5 | If photo import is key |

### Tier D: High Dev Cost, Zero Ongoing (Long-Term)

| # | Enhancement | Dev Days | When |
|---|------------|----------|------|
| 15 | On-device DistilBERT NER | 10-15 | After CRF ceiling is hit |
| 16 | On-device VLM (Gemma 3n) | 15-20 | When API costs significant |
| 17 | Multi-language support | 10-15/lang | Market expansion |

---

## 3. Key Insight: The Cost-Optimal Path

**Phase 1 (Tier A) achieves ~75-85% accuracy at $0 ongoing cost.** The CRF architecture is already built — it's starved for training data. Every % gained in Tiers 1-3 = fewer expensive LLM calls.

**The anti-pattern to avoid**: Don't add new cloud APIs when the on-device CRF is severely undertrained. Fix the CRF first — it's free.

---

## 4. Critical Files

- `lib/services/parsing/recipe_parser_service.dart` — Main orchestrator
- `lib/services/parsing/crf/*.dart` — CRF model
- `lib/services/parsing/ingredient_parsing_strategy.dart` — CRF/regex routing
- `lib/utils/text/ingredient_parser.dart` — Legacy regex parser
- `lib/constants/known_ingredients.dart` — ~350 ingredient vocabulary
- `lib/constants/preparation_words.dart` — Cooking verbs/states
- `assets/data/crf_ingredient_weights.json` — CRF weights (5.7KB)
- `scripts/crf/` — Training pipeline
- `test/evaluation/crf_evaluator.dart` — Accuracy evaluation
- `test/golden/crf_ingredients.json` — 121 golden entries

---

## 5. Verification

After implementing any enhancement:
1. Run `dart run test/evaluation/crf_evaluator.dart` against golden dataset
2. Compare accuracy metrics: exact match %, per-field F1
3. Run `flutter test test/unit/services/parsing/` for regression
4. Run `flutter test test/unit/utils/text/` for ingredient parsing
5. Test with real Swedish recipe URLs
