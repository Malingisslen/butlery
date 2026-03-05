"""
Evaluate a trained ONNX line classifier against the golden dataset.

Runs inference on the full golden dataset (or a held-out test split)
and reports per-label precision/recall/F1, confusion matrix, and
per-source accuracy.

Usage:
    # Evaluate on full golden dataset
    python scripts/line_classifier/evaluate_model.py \
        --model assets/ml/line_classifier/model.onnx \
        --vocab assets/ml/line_classifier/vocab.txt \
        --golden scripts/line_classifier/data/line_classification_golden.json

    # Evaluate on 20% held-out test split (by recipe_id)
    python scripts/line_classifier/evaluate_model.py \
        --model output/onnx/model.onnx \
        --vocab output/onnx/vocab.txt \
        --golden scripts/line_classifier/data/line_classification_golden.json \
        --test-split 0.2

    # Evaluate only on specific held-out recipe IDs
    python scripts/line_classifier/evaluate_model.py \
        --model output/onnx/model.onnx \
        --vocab output/onnx/vocab.txt \
        --golden scripts/line_classifier/data/line_classification_golden.json \
        --test-recipe-ids 5 12 18 25
"""

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np

LABELS = [
    "ingredient",
    "instruction",
    "title",
    "metadata",
    "sectionHeader",
    "empty",
    "noise",
]
LABEL2ID = {label: i for i, label in enumerate(LABELS)}
MAX_LENGTH = 64


def load_vocab(vocab_path: str) -> dict[str, int]:
    """Load WordPiece vocabulary."""
    vocab = {}
    with open(vocab_path, encoding="utf-8") as f:
        for i, line in enumerate(f):
            vocab[line.strip()] = i
    return vocab


def tokenize(text: str, vocab: dict[str, int], max_length: int = MAX_LENGTH) -> tuple[list[int], list[int]]:
    """Simple WordPiece tokenization matching the Dart-side implementation."""
    tokens = ["[CLS]"]
    for word in text.lower().split():
        if word in vocab:
            tokens.append(word)
        else:
            # WordPiece subword tokenization
            remaining = word
            while remaining:
                found = False
                for end in range(len(remaining), 0, -1):
                    subword = remaining[:end]
                    if len(tokens) > 1 and remaining != word:
                        subword = "##" + subword
                    if subword in vocab:
                        tokens.append(subword)
                        remaining = remaining[end:]
                        found = True
                        break
                if not found:
                    tokens.append("[UNK]")
                    break
    tokens.append("[SEP]")

    # Truncate
    if len(tokens) > max_length:
        tokens = tokens[:max_length - 1] + ["[SEP]"]

    input_ids = [vocab.get(t, vocab.get("[UNK]", 0)) for t in tokens]
    attention_mask = [1] * len(input_ids)

    # Pad
    pad_length = max_length - len(input_ids)
    input_ids += [0] * pad_length
    attention_mask += [0] * pad_length

    return input_ids, attention_mask


def split_by_recipe_id(data: list[dict], test_fraction: float, seed: int = 42) -> tuple[list[dict], list[dict]]:
    """Split data into train/test by recipe_id to keep recipes intact."""
    rng = np.random.RandomState(seed)
    recipe_ids = sorted(set(item["recipe_id"] for item in data))
    rng.shuffle(recipe_ids)

    n_test = max(1, int(len(recipe_ids) * test_fraction))
    test_ids = set(recipe_ids[:n_test])

    test_data = [item for item in data if item["recipe_id"] in test_ids]
    train_data = [item for item in data if item["recipe_id"] not in test_ids]
    return train_data, test_data


def evaluate(
    model_path: str,
    vocab_path: str,
    golden_path: str,
    test_split: float | None = None,
    test_recipe_ids: list[int] | None = None,
):
    """Run evaluation and print results."""
    import onnxruntime as ort

    # Load model
    session = ort.InferenceSession(model_path)
    vocab = load_vocab(vocab_path)

    # Load data
    with open(golden_path, encoding="utf-8") as f:
        data = json.load(f)

    # Filter to test set if requested
    if test_recipe_ids:
        test_ids = set(test_recipe_ids)
        data = [item for item in data if item["recipe_id"] in test_ids]
        print(f"Evaluating on {len(data)} entries from recipe IDs: {sorted(test_ids)}")
    elif test_split:
        _, data = split_by_recipe_id(data, test_split)
        test_ids = sorted(set(item["recipe_id"] for item in data))
        print(f"Evaluating on {len(data)} entries (test split {test_split}) from recipe IDs: {test_ids}")
    else:
        print(f"Evaluating on full golden dataset: {len(data)} entries")

    if not data:
        print("ERROR: No data to evaluate on.")
        sys.exit(1)

    # Run inference
    true_labels = []
    pred_labels = []
    per_source: dict[str, dict[str, list]] = defaultdict(lambda: {"true": [], "pred": []})

    for item in data:
        text = item["text"]
        label = item["label"]
        source = item.get("source", "unknown")

        if label not in LABEL2ID:
            print(f"WARNING: Unknown label '{label}', skipping")
            continue

        input_ids, attention_mask = tokenize(text, vocab)

        ort_inputs = {
            "input_ids": np.array([input_ids], dtype=np.int64),
            "attention_mask": np.array([attention_mask], dtype=np.int64),
        }
        logits = session.run(None, ort_inputs)[0]
        pred_id = int(np.argmax(logits[0]))

        true_id = LABEL2ID[label]
        true_labels.append(true_id)
        pred_labels.append(pred_id)
        per_source[source]["true"].append(true_id)
        per_source[source]["pred"].append(pred_id)

    true_labels = np.array(true_labels)
    pred_labels = np.array(pred_labels)

    # Overall accuracy
    accuracy = (true_labels == pred_labels).mean()
    print(f"\nOverall accuracy: {accuracy:.3f} ({(true_labels == pred_labels).sum()}/{len(true_labels)})")

    # Per-label metrics
    print(f"\n{'Label':<15} {'Prec':>6} {'Rec':>6} {'F1':>6} {'Support':>8}")
    print("-" * 45)
    for label_name in LABELS:
        label_id = LABEL2ID[label_name]
        tp = ((pred_labels == label_id) & (true_labels == label_id)).sum()
        fp = ((pred_labels == label_id) & (true_labels != label_id)).sum()
        fn = ((pred_labels != label_id) & (true_labels == label_id)).sum()
        support = (true_labels == label_id).sum()

        precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0.0

        print(f"{label_name:<15} {precision:>6.3f} {recall:>6.3f} {f1:>6.3f} {support:>8}")

    # Confusion matrix
    n_labels = len(LABELS)
    cm = np.zeros((n_labels, n_labels), dtype=int)
    for t, p in zip(true_labels, pred_labels):
        cm[t][p] += 1

    print(f"\nConfusion Matrix (rows=true, cols=predicted):")
    header = f"{'':>15}" + "".join(f"{l[:6]:>7}" for l in LABELS)
    print(header)
    for i, label_name in enumerate(LABELS):
        row = f"{label_name:>15}" + "".join(f"{cm[i][j]:>7}" for j in range(n_labels))
        print(row)

    # Per-source accuracy
    print(f"\n{'Source':<20} {'Accuracy':>8} {'Count':>6}")
    print("-" * 36)
    for source in sorted(per_source.keys()):
        s_true = np.array(per_source[source]["true"])
        s_pred = np.array(per_source[source]["pred"])
        s_acc = (s_true == s_pred).mean()
        print(f"{source:<20} {s_acc:>8.3f} {len(s_true):>6}")

    # Return test recipe IDs for use with training exclusion
    if test_split:
        test_ids = sorted(set(item["recipe_id"] for item in data if item["recipe_id"] in {item["recipe_id"] for item in data}))
        print(f"\nHeld-out recipe IDs (for --test-recipe-ids in training): {' '.join(str(x) for x in test_ids)}")

    return accuracy


def main():
    parser = argparse.ArgumentParser(description="Evaluate ONNX line classifier")
    parser.add_argument("--model", type=str, required=True, help="Path to ONNX model")
    parser.add_argument("--vocab", type=str, required=True, help="Path to vocab.txt")
    parser.add_argument("--golden", type=str, required=True, help="Path to golden dataset JSON")
    parser.add_argument("--test-split", type=float, default=None, help="Fraction of recipes to hold out (e.g. 0.2)")
    parser.add_argument("--test-recipe-ids", type=int, nargs="+", default=None, help="Specific recipe IDs to evaluate on")
    args = parser.parse_args()

    evaluate(
        model_path=args.model,
        vocab_path=args.vocab,
        golden_path=args.golden,
        test_split=args.test_split,
        test_recipe_ids=args.test_recipe_ids,
    )


if __name__ == "__main__":
    main()
