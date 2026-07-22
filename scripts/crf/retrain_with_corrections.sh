#!/bin/bash
# Orchestrates the full CRF retraining pipeline with user corrections.
#
# Prerequisites:
#   - firebase login (for Firestore access in stage 1)
#   - npm install in functions/ (for ts-node)
#   - python with python-crfsuite installed
#   - flutter on PATH (for the golden-set regression gate in stage 5)
#   - gcloud/gsutil authenticated (only for stage 6 --deploy)
#
# Usage:
#   ./scripts/crf/retrain_with_corrections.sh            # retrain + gate, print deploy artifacts (no upload)
#   ./scripts/crf/retrain_with_corrections.sh --deploy   # also upload the new weights to Firebase Storage
#
# Env overrides:
#   CRF_STORAGE_BUCKET   default butlery-app-1.firebasestorage.app
#   CRF_WEIGHTS_VERSION  force the published version integer (default: current remote + 1)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DEPLOY=false
for arg in "$@"; do
  case "$arg" in
    --deploy) DEPLOY=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

WEIGHTS="assets/data/crf_ingredient_weights.json"
STORAGE_PATH="models/crf_ingredient_weights.json"
BUCKET="${CRF_STORAGE_BUCKET:-butlery-app-1.firebasestorage.app}"

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
  --output "$WEIGHTS"

echo ""
echo "=== Stage 5: Golden-set eval regression gate ==="
# Hard gate: the freshly written weights must still clear the frozen golden
# dataset (>=85% all-fields exact, enforced inside the test). A regression
# aborts the pipeline here (set -e) so a worse model never reaches Storage.
flutter test test/evaluation/crf_evaluator_test.dart

echo ""
echo "=== Stage 6: Deploy to Firebase Storage (RemoteWeightLoader path) ==="
# Compute the SHA-256 of the exact bytes clients will download. This value
# MUST be pasted into kExpectedCrfWeightHashes in
# lib/services/parsing/_expected_model_hashes.dart in the SAME PR as the
# upload — the loader fail-closes on any version with no registry entry
# (BUT-1238/BUT-877), so a forgotten entry safely refuses the download and
# leaves the bundled weights parsing.
if command -v sha256sum >/dev/null 2>&1; then
  SHA=$(sha256sum "$WEIGHTS" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
  SHA=$(shasum -a 256 "$WEIGHTS" | awk '{print $1}')
else
  SHA=$(python -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$WEIGHTS")
fi

# Next version = current remote custom-metadata version + 1 (RemoteWeightLoader
# reads customMetadata['version'] as an int and only downloads a strictly
# newer one). Missing object → start at 1. CRF_WEIGHTS_VERSION overrides.
CURRENT=0
if REMOTE_META=$(gsutil stat "gs://$BUCKET/$STORAGE_PATH" 2>/dev/null); then
  CURRENT=$(printf '%s\n' "$REMOTE_META" \
    | grep -iE '^[[:space:]]*version:' \
    | head -n1 \
    | awk -F': *' '{print $2}' \
    | tr -dc '0-9')
  CURRENT=${CURRENT:-0}
fi
NEXT="${CRF_WEIGHTS_VERSION:-$((CURRENT + 1))}"

echo "  SHA-256:        $SHA"
echo "  Current remote: v$CURRENT"
echo "  New version:    v$NEXT"
echo ""
echo "  Registry line for lib/services/parsing/_expected_model_hashes.dart"
echo "  (add to kExpectedCrfWeightHashes, same PR as the upload):"
echo ""
echo "    $NEXT: '$SHA',"
echo ""

if [ "$DEPLOY" = true ]; then
  echo "  Uploading to gs://$BUCKET/$STORAGE_PATH (version=$NEXT) ..."
  gsutil -h "x-goog-meta-version:$NEXT" \
    -h "Content-Type:application/json" \
    cp "$WEIGHTS" "gs://$BUCKET/$STORAGE_PATH"
  echo "  Uploaded. Clients refuse v$NEXT until the SHA above ships in a client release."
else
  echo "  Dry run (no --deploy): weights NOT uploaded. To publish, re-run with --deploy"
  echo "  or upload manually:"
  echo "    gsutil -h \"x-goog-meta-version:$NEXT\" -h \"Content-Type:application/json\" \\"
  echo "      cp \"$WEIGHTS\" \"gs://$BUCKET/$STORAGE_PATH\""
fi

echo ""
echo "=== Done ==="
echo "New weights written to: $WEIGHTS"
