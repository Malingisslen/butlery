# Parser Enhancement Roadmap — Remaining Work

## What's Been Done

All Phase 1, Phase 2, and actionable Phase 3 items are complete:

- **1.1** Golden dataset (433 entries) + CRF evaluation framework (`test/evaluation/crf_evaluator.dart`)
- **1.2** CRF weights updated with edge case + compound features
- **1.3** Unified ingredient parsing via `IngredientParsingStrategy` (CRF first, regex fallback)
- **2.1** Edge case CRF features (ranges, conjunctions, optionals, group headers, parens)
- **2.2** Wider context window (prev2/next2 features)
- **2.3** Active learning pipeline: correction tracking in Firestore + remote weight loading from Firebase Storage
- **2.4** Confidence calibration: per-tier quality discounts, CRF confidence scoring
- **2.5** Swedish compound word detection (`SwedishCompoundSplitter`)
- **3.3** Selective LLM enhancement: patch only weak fields via `StructureMode.enhance`
- **3.4** OCR error correction (`OcrErrorCorrector`) with Swedish confusion matrix
- **10** User correction → retrain pipeline (`export-corrections.ts` + `export_corrections.dart`)
- **11** Livsmedelsverket ingredient fetch script (`fetch-livsmedelsverket.ts`)
- **13** Replaced Mistral with Gemini 2.0 Flash (`gemini-client.ts`)

Current accuracy: **89.6%** all-fields exact match on 433-entry golden dataset.

---

## Ready to Train: On-Device BERT NER (Item 15)

Code scaffolding is **complete**. All that remains is training the model and uploading to Firebase Storage.

### What's built
- **Python pipeline**: `scripts/ner/train_bert_ner.py`, `distill_to_student.py`, `export_onnx.py`
- **Dart inference**: `lib/services/parsing/ner/` — WordPiece tokenizer, ONNX service, neural parser, model manager
- **Cascade integration**: `IngredientParsingStrategy` routes uncertain CRF lines → BERT NER → Gemini
- **Tests**: 35 tests passing (tokenizer, parser, strategy)
- **Runtime**: `flutter_onnxruntime` (MIT licensed, not `fonnx` which is GPL)

### To train and deploy

```bash
# 1. Install Python dependencies
pip install -r scripts/ner/requirements.txt

# 2. Fine-tune KB-BERT on ingredient NER (needs GPU, ~2h on A100)
python scripts/ner/train_bert_ner.py \
    --input scripts/crf/data/training.conll \
    --output scripts/ner/output/kb-bert-ner \
    --golden test/golden/crf_ingredients.json \
    --epochs 10

# 3. Distill 12-layer → 4-layer student
python scripts/ner/distill_to_student.py \
    --teacher scripts/ner/output/kb-bert-ner \
    --input scripts/crf/data/training.conll \
    --output scripts/ner/output/student-ner \
    --golden test/golden/crf_ingredients.json \
    --epochs 20

# 4. Export to ONNX with INT8 quantization (<20MB)
python scripts/ner/export_onnx.py \
    --model scripts/ner/output/student-ner \
    --output scripts/ner/output/onnx \
    --verify

# 5. Upload to Firebase Storage
# model.onnx + vocab.txt → models/ingredient_ner/v1/
# Create latest_version.txt with content "1"
```

### Expected impact
- **F1**: ~75% (CRF alone) → ~83-88% (CRF + BERT)
- **Gemini calls**: 50-70% reduction (BERT handles uncertain lines on-device)
- **Model size**: ~15MB download, cached locally
- **Runtime cost**: Zero (on-device inference)
- **Graceful degradation**: If model not downloaded, cascade skips BERT tier entirely

---

## Remaining: Future Vision

### Neural Line Classification

**Why**: Hand-crafted `_scoreAsIngredient()`/`_scoreAsInstruction()` fail on prose recipes.

- Use DistilBERT sentence embeddings + logistic regression for line type prediction
- Replace hand-crafted emission probabilities in Viterbi with neural scores
- Keep transition matrix but learn from data

**Effort**: 5-7 days | **Dependencies**: BERT NER above | **Impact**: +10-15% on unstructured text

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
- [flutter_onnxruntime](https://pub.dev/packages/flutter_onnxruntime) — ONNX Runtime for Flutter (MIT)
- [Livsmedelsverket API](https://www.livsmedelsverket.se/en/about-us/open-data/food-composition-data/) — 2,400 Swedish food items
- [FoodBERT](https://www.charlenechambliss.com/blog/introducing-foodbert) — DistilBERT for food entities
- [Confidence-aware routing](https://arxiv.org/html/2510.01237) — model cascade with calibrated confidence
