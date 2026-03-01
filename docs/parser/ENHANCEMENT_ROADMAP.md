# Parser Enhancement Roadmap — Remaining Work

## What's Been Done

All Phase 1, Phase 2, and actionable Phase 3 items are complete:

- **1.1** Golden dataset (121 entries) + CRF evaluation framework (`test/evaluation/crf_evaluator.dart`)
- **1.2** CRF weights updated with edge case + compound features
- **1.3** Unified ingredient parsing via `IngredientParsingStrategy` (CRF first, regex fallback)
- **2.1** Edge case CRF features (ranges, conjunctions, optionals, group headers, parens)
- **2.2** Wider context window (prev2/next2 features)
- **2.3** Active learning pipeline: correction tracking in Firestore + remote weight loading from Firebase Storage
- **2.4** Confidence calibration: per-tier quality discounts, CRF confidence scoring
- **2.5** Swedish compound word detection (`SwedishCompoundSplitter`)
- **3.3** Selective LLM enhancement: patch only weak fields via `StructureMode.enhance`
- **3.4** OCR error correction (`OcrErrorCorrector`) with Swedish confusion matrix

Baseline evaluation: 57.9% all-fields exact match on golden dataset.

---

## Remaining: Neural Models + Future Vision

These items require ML model training infrastructure (Python pipelines, GPU training, ONNX export) and cannot be implemented as pure code changes.

### On-Device DistilBERT for Ingredient NER

**Why**: CRF tops out at ~75% F1. BERT-CRF hybrids reach ~83%.

- Fine-tune KB-BERT (Swedish) or DistilBERT on Swedish ingredient NER task
- Distill to ONNX (<20MB model size)
- Use `fonnx` Flutter package (CoreML on iOS, NNAPI on Android, WASM on Web)
- **Hybrid cascade**: CRF first, DistilBERT only on uncertain lines
- Build WordPiece tokenizer in Dart

**New files**: `neural_ingredient_parser.dart`, `onnx_inference_service.dart`, `wordpiece_tokenizer.dart`, `assets/models/ingredient_ner.onnx`

**Effort**: 10-15 days | **Impact**: F1 ~75% -> ~83%

### Neural Line Classification

**Why**: Hand-crafted `_scoreAsIngredient()`/`_scoreAsInstruction()` fail on prose recipes.

- Use DistilBERT sentence embeddings + logistic regression for line type prediction
- Replace hand-crafted emission probabilities in Viterbi with neural scores
- Keep transition matrix but learn from data

**Effort**: 5-7 days | **Dependencies**: DistilBERT above | **Impact**: +10-15% on unstructured text

### On-Device SLM (Small Language Model)

Replace cloud LLM with on-device Qwen3-0.6B or Gemma 3n (~300MB download). Fully offline recipe extraction. **Effort**: 15-20 days.

### Multi-Language Support

Language detection, language-specific vocabularies, multilingual CRF/DistilBERT. Start with English + Norwegian/Danish. **Effort**: 10-15 days per language.

### Recipe Understanding (Beyond Extraction)

Technique detection, difficulty estimation, cuisine classification, dietary analysis, ingredient substitution suggestions. **Effort**: 20+ days.

### Federated Learning

Train on-device, aggregate only model updates. GDPR-optimal. **Effort**: 20+ days (research-grade).

---

## Key Sources

- [KB-BERT](https://huggingface.co/KB/bert-base-swedish-cased) — Swedish BERT from KBLab
- [fonnx](https://github.com/Telosnex/fonnx) — ONNX for Flutter (CoreML/NNAPI/WASM)
- [Livsmedelsverket API](https://www.livsmedelsverket.se/en/about-us/open-data/food-composition-data/) — 2,400 Swedish food items
- [FoodBERT](https://www.charlenechambliss.com/blog/introducing-foodbert) — DistilBERT for food entities
- [Confidence-aware routing](https://arxiv.org/html/2510.01237) — model cascade with calibrated confidence
