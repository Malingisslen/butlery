#!/bin/bash
# Orchestrates the full CRF retraining pipeline with user corrections.
#
# Prerequisites:
#   - firebase login (for Firestore access in stage 1)
#   - npm install in functions/ (for ts-node)
#   - python with python-crfsuite installed
#
# Usage: ./scripts/crf/retrain_with_corrections.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Stage 1: Export corrections from Firestore ==="
cd "$PROJECT_ROOT/functions"
npx ts-node src/admin/export-corrections.ts
cd "$PROJECT_ROOT"

echo ""
echo "=== Stage 2: Convert corrections to CoNLL (with validation) ==="
dart run scripts/crf/export_corrections.dart

echo ""
echo "=== Stage 3: Merge training data ==="
cat scripts/crf/data/training.conll scripts/crf/data/corrections_training.conll \
  > scripts/crf/data/merged.conll
wc -l scripts/crf/data/merged.conll | xargs echo "Merged file:"

echo ""
echo "=== Stage 4: Retrain CRF model ==="
python scripts/crf/train_crf.py \
  --input scripts/crf/data/merged.conll \
  --output assets/data/crf_ingredient_weights.json

echo ""
echo "=== Done ==="
echo "New weights written to: assets/data/crf_ingredient_weights.json"
echo "Run tests: flutter test test/unit/services/parsing/crf/"
