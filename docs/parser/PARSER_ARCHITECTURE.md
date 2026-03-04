# Butlery Recipe Parser Architecture

Multi-tier recipe extraction system that converts web URLs, social media posts, plain text, and photos into structured recipe data.

## Key Metrics

| Metric | Value |
|--------|-------|
| Accuracy | 85%+ all-fields exact match (433-entry golden dataset) |
| Tiers | 5 (SchemaOrg → SiteConfig → RuleBased → CRF → LLM) |
| Ingredient cascade | CRF → BERT NER → Gemini fallback |
| LLM | Gemini 2.0 Flash via Cloud Functions |
| On-device ML | CRF weights + ONNX BERT NER model |

---

## Architecture Overview

```
URL / Text / Photo
        │
        ▼
┌─────────────────────────────────────────────────────┐
│              Recipe Parser Service                    │
│                                                       │
│   Tier 1: SchemaOrg  ──→  JSON-LD / Microdata        │
│   Tier 2: SiteConfig ──→  Per-domain CSS selectors    │
│   Tier 3: RuleBased  ──→  Swedish line classification │
│   Tier 4: CRF        ──→  On-device sequence labeling │
│   Tier 5: LLM        ──→  Gemini 2.0 Flash (cloud)   │
│                                                       │
│   Each tier produces confidence scores per field.     │
│   Parsing stops when quality exceeds threshold (70%). │
│   Results are merged across tiers (highest wins).     │
└─────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────┐
│           Ingredient Parsing Cascade                  │
│                                                       │
│   For each ingredient line:                           │
│   1. CRF parser (on-device, fast)                     │
│   2. If confidence < 0.7 → BERT NER (on-device ONNX) │
│   3. If still uncertain  → Gemini (cloud, per-line)   │
│                                                       │
│   Output: ParsedIngredient with quantity, unit, name, │
│           size, preparation, confidence               │
└─────────────────────────────────────────────────────┘
```

---

## Tier Comparison

| Tier | Strategy | Speed | Cost | Best For |
|------|----------|-------|------|----------|
| **SchemaOrg** | JSON-LD / Microdata via `RecipeScraper` | <100ms | Free | Major recipe sites with structured data |
| **SiteConfig** | Per-domain CSS selectors from Firestore | <200ms | Free | Known sites without schema.org |
| **RuleBased** | Swedish line classification (`SwedishLineClassifier`) + Viterbi | <500ms | Free | Plain text, copy-pasted recipes |
| **CRF** | Conditional Random Field sequence labeling | <100ms | Free | Ingredient line parsing (all tiers) |
| **LLM** | Gemini 2.0 Flash via Cloud Functions | 2-5s | ~$0.10/M tokens | Fallback for ambiguous/complex content |

Tiers run in order. Each produces a `TierResult` with per-field `FieldResult` objects carrying confidence scores (0.0–1.0). The `RecipeMerger` combines results, keeping the highest-confidence value per field.

---

## Ingredient Parsing

All tiers use `IngredientParsingStrategy` as the single entry point for parsing ingredient lines. It implements a confidence-based cascade:

### CRF Parser

On-device Conditional Random Field model trained on Swedish ingredient lines.

- **Weights**: Bundled in `assets/data/crf_ingredient_weights.json`, updated remotely via `RemoteWeightLoader` from Firebase Storage
- **Features**: Token shape, prefix/suffix, position, context window (prev2/next2), Swedish compound detection
- **Decoding**: Viterbi algorithm (`CrfViterbiDecoder`)
- **BIO labels**: `O`, `B-QTY`, `I-QTY`, `B-UNIT`, `B-NAME`, `I-NAME`, `B-PREP`, `I-PREP`, `B-SIZE`

### BERT NER (On-Device)

4-layer student model distilled from KB-BERT (Swedish), runs via ONNX Runtime.

- **Model**: `flutter_onnxruntime` package, max 128 tokens, INT8 quantized (~15MB)
- **Tokenizer**: Pure Dart WordPiece implementation matching HuggingFace `BertTokenizer` (cased)
- **Versioning**: Firebase Storage `models/ingredient_ner/v{N}/` with `latest_version.txt` discovery
- **Caching**: Downloaded to app support directory, checked every 12 hours
- **Confidence threshold**: 0.7 — lines below this fall through to Gemini
- **Infrastructure**: `NerModelManager` extends `RemoteModelLoader` base class

### Gemini Fallback

Cloud-based extraction for lines neither CRF nor BERT can handle confidently.

- **Model**: Gemini 2.0 Flash (`functions/src/llm/gemini-client.ts`)
- **Modes**: `extract`, `enhance`, `spoken`, `ingredientLines`
- **Structured output**: Server-side JSON Schema enforcement
- **Cost optimization**: Only uncertain lines are sent, not full recipes

---

## ParsedIngredient Model

`lib/models/parsing/parsed_ingredient.dart`

| Field | Type | Example |
|-------|------|---------|
| `name` | `String` | "lök" |
| `originalLine` | `String` | "2 stora lökar, hackade" |
| `quantity` | `String?` | "2" |
| `unit` | `String?` | "st" |
| `size` | `String?` | "stora" |
| `preparation` | `String?` | "hackade" |
| `confidence` | `ParseConfidence` | high/medium/low |
| `notes` | `String?` | — |

---

## Quality & Feedback

### Quality-Based Progression

Each tier contributes confidence scores per field. A weighted formula produces an overall quality score. Parsing stops when quality exceeds the threshold (default 70%), avoiding unnecessary LLM calls.

### Feedback Loop

User corrections feed back into model improvement:

1. User edits a parsed ingredient → correction saved to Firestore
2. `export-corrections.ts` Cloud Function exports corrections as training data
3. CRF weights retrained and uploaded to Firebase Storage
4. `RemoteWeightLoader` picks up new weights on next check (12h interval)
5. BERT NER model retrained periodically via Python pipeline (`scripts/ner/`)

### Golden Dataset

433-entry human-verified test set (`test/golden/crf_ingredients.json`). Automated evaluation via `test/evaluation/crf_evaluator.dart` computes per-label token-level P/R/F1, span-level metrics, and per-field exact match. Minimum threshold: 85% all-fields exact match.

---

## Caching

- **Local recipe cache**: `LocalRecipeCache` — LRU in-memory cache for recently parsed recipes
- **Parsed recipe cache**: `ParsedRecipeCache` — persistent cache keyed by URL hash
- **CRF weights**: Cached locally, remote check throttled to avoid redundant downloads
- **NER model**: Cached in app support directory with version tracking

---

## Security

| Layer | Protection |
|-------|------------|
| Input sanitization | HTML stripping, URL validation, size limits |
| LLM prompts | Injection-resistant templates, output schema enforcement |
| Firebase | Security rules on corrections collection, API key in Secrets Manager |
| Rate limiting | Per-user parsing limits, LLM call budgets |
| Model downloads | Size limits (25MB model, 5MB vocab), Firebase Storage security rules |

---

## File Organization

```
lib/services/parsing/
├── recipe_parser_service.dart      # Main orchestrator
├── ingredient_parsing_strategy.dart # CRF → NER → LLM cascade
├── ingredient_conversion.dart       # Unit conversion
├── ingredient_registry_service.dart # Known ingredient lookup
├── remote_model_loader.dart         # Base class for remote model management
├── cache/
│   ├── local_recipe_cache.dart
│   └── parsed_recipe_cache.dart
├── common/
│   └── recipe_merger.dart           # Cross-tier result merging
├── crf/
│   ├── crf_feature_extractor.dart   # Feature engineering
│   ├── crf_ingredient_parser.dart   # CRF inference + label assembly
│   ├── crf_viterbi_decoder.dart     # Viterbi decoding
│   └── remote_weight_loader.dart    # Firebase Storage weight updates
├── feedback/
│   └── recipe_diff_calculator.dart  # User correction tracking
├── ner/
│   ├── ner_model_manager.dart       # ONNX model download + versioning
│   ├── neural_ingredient_parser.dart # BERT NER inference wrapper
│   ├── onnx_ner_service.dart        # ONNX Runtime bridge
│   └── wordpiece_tokenizer.dart     # Pure Dart WordPiece
├── parsers/
│   ├── swedish_line_classifier.dart # Ingredient vs instruction scoring
│   └── viterbi_context_processor.dart
├── sanitizers/
│   └── html_sanitizer.dart
└── tiers/
    ├── parsing_tier.dart            # Base class + tier enum
    ├── parsing_context.dart         # Shared context across tiers
    ├── schema_org_tier.dart
    ├── site_config_tier.dart
    ├── rule_based_tier.dart
    ├── crf_tier.dart
    └── llm_tier.dart

lib/models/parsing/
├── parsed_ingredient.dart
├── parsed_recipe.dart
├── field_result.dart
├── tier_result.dart
├── parse_metadata.dart
├── site_config.dart
├── field_correction.dart
├── ingredient_correction.dart
├── instruction_correction.dart
└── parsing_correction.dart

functions/src/llm/
└── gemini-client.ts                 # Gemini 2.0 Flash API client

scripts/ner/
├── train_bert_ner.py                # KB-BERT fine-tuning
├── distill_to_student.py            # 12→4 layer distillation
└── export_onnx.py                   # ONNX export + INT8 quantization

test/
├── golden/crf_ingredients.json      # 433-entry golden dataset
├── evaluation/crf_evaluator.dart    # Automated accuracy evaluation
└── benchmark/parser_accuracy_benchmark.dart
```

---

## Future Vision

### Neural Line Classification

Replace hand-crafted `_scoreAsIngredient()`/`_scoreAsInstruction()` with DistilBERT sentence embeddings + logistic regression. Keep Viterbi transition matrix but learn emission probabilities from data. Expected impact: +10-15% on unstructured text.

### On-Device SLM

Replace cloud LLM with on-device small language model (Qwen3-0.6B or Gemma 3n, ~300MB). Fully offline recipe extraction.

### Multi-Language Support

Language detection, language-specific vocabularies, multilingual CRF/DistilBERT. Start with English + Norwegian/Danish.

### Recipe Understanding

Beyond extraction: technique detection, difficulty estimation, cuisine classification, dietary analysis, ingredient substitution suggestions.

### Federated Learning

Train on-device, aggregate only model updates. GDPR-optimal approach to continuous improvement.
