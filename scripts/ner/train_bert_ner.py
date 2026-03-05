"""
Fine-tune KB-BERT for Swedish ingredient NER.

Reads CoNLL-format training data (same as CRF pipeline), fine-tunes
KB/bert-base-swedish-cased for token classification with 9 BIO labels,
evaluates on held-out test set, and saves the checkpoint.

The tokenizer alignment strategy:
1. Pre-tokenize using the same whitespace+punctuation splitter as Dart CRF
2. Map each pre-token to WordPiece subwords
3. Assign the gold label to the first subword, -100 to subsequent subwords
4. At inference time, take the prediction from the first subword per word

Usage:
    python scripts/ner/train_bert_ner.py \
        --input scripts/crf/data/training.conll \
        --output scripts/ner/output/kb-bert-ner \
        --epochs 10
"""

import argparse
import json
import os
import sys

import numpy as np
import torch
from sklearn.metrics import classification_report
from sklearn.model_selection import train_test_split
from torch.utils.data import Dataset
from transformers import (
    AutoModelForTokenClassification,
    AutoTokenizer,
    DataCollatorForTokenClassification,
    Trainer,
    TrainingArguments,
)

# BIO label set — must match Dart BioLabel enum and CRF labels exactly
LABELS = [
    "O",
    "B-QTY", "I-QTY",
    "B-UNIT",
    "B-NAME", "I-NAME",
    "B-PREP", "I-PREP",
    "B-SIZE",
]
LABEL2ID = {label: i for i, label in enumerate(LABELS)}
ID2LABEL = {i: label for i, label in enumerate(LABELS)}

# Pretrained model
DEFAULT_MODEL = "KB/bert-base-swedish-cased"


def read_conll(path: str) -> list[tuple[list[str], list[str]]]:
    """Read CoNLL format: token\\tlabel, blank lines separate sequences."""
    sequences = []
    tokens, labels = [], []

    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                if tokens:
                    sequences.append((tokens, labels))
                    tokens, labels = [], []
                continue
            parts = line.split("\t")
            if len(parts) >= 2:
                tokens.append(parts[0])
                labels.append(parts[1])

    if tokens:
        sequences.append((tokens, labels))

    return sequences


class IngredientNERDataset(Dataset):
    """Dataset that aligns pre-tokenized words with WordPiece subwords."""

    def __init__(
        self,
        sequences: list[tuple[list[str], list[str]]],
        tokenizer,
        max_length: int = 128,
    ):
        self.examples = []
        skipped = 0

        for words, word_labels in sequences:
            encoding = tokenizer(
                words,
                is_split_into_words=True,
                truncation=True,
                max_length=max_length,
                padding=False,
            )

            # Align labels to subword tokens
            word_ids = encoding.word_ids()
            aligned_labels = []
            prev_word_id = None

            for word_id in word_ids:
                if word_id is None:
                    # Special tokens ([CLS], [SEP], [PAD])
                    aligned_labels.append(-100)
                elif word_id != prev_word_id:
                    # First subword of a new word — assign the gold label
                    label_str = word_labels[word_id]
                    if label_str not in LABEL2ID:
                        skipped += 1
                        aligned_labels = None
                        break
                    aligned_labels.append(LABEL2ID[label_str])
                else:
                    # Subsequent subword of the same word — ignore in loss
                    aligned_labels.append(-100)
                prev_word_id = word_id

            if aligned_labels is None:
                continue

            self.examples.append({
                "input_ids": encoding["input_ids"],
                "attention_mask": encoding["attention_mask"],
                "labels": aligned_labels,
                # Store original words for evaluation alignment
                "words": words,
                "word_labels": word_labels,
            })

        if skipped > 0:
            print(f"  Skipped {skipped} sequences with unknown labels")

    def __len__(self):
        return len(self.examples)

    def __getitem__(self, idx):
        ex = self.examples[idx]
        return {
            "input_ids": torch.tensor(ex["input_ids"], dtype=torch.long),
            "attention_mask": torch.tensor(ex["attention_mask"], dtype=torch.long),
            "labels": torch.tensor(ex["labels"], dtype=torch.long),
        }


def compute_metrics(eval_pred):
    """Token-level classification report (ignoring -100 padding)."""
    logits, labels = eval_pred
    predictions = np.argmax(logits, axis=-1)

    true_labels = []
    pred_labels = []

    for pred_seq, label_seq in zip(predictions, labels):
        for p, l in zip(pred_seq, label_seq):
            if l == -100:
                continue
            true_labels.append(ID2LABEL[l])
            pred_labels.append(ID2LABEL[p])

    # Compute per-label metrics
    report = classification_report(
        true_labels, pred_labels,
        labels=LABELS,
        output_dict=True,
        zero_division=0,
    )

    return {
        "precision": report["macro avg"]["precision"],
        "recall": report["macro avg"]["recall"],
        "f1": report["macro avg"]["f1-score"],
    }


def evaluate_detailed(model, tokenizer, sequences, device="cpu"):
    """Detailed token-level and span-level evaluation."""
    model.eval()
    model.to(device)

    all_true = []
    all_pred = []

    for words, word_labels in sequences:
        encoding = tokenizer(
            words,
            is_split_into_words=True,
            truncation=True,
            max_length=128,
            padding=False,
            return_tensors="pt",
        )

        with torch.no_grad():
            outputs = model(
                input_ids=encoding["input_ids"].to(device),
                attention_mask=encoding["attention_mask"].to(device),
            )

        logits = outputs.logits[0]
        predictions = torch.argmax(logits, dim=-1).cpu().numpy()
        word_ids = encoding.word_ids()

        # Map subword predictions back to word-level
        word_preds = {}
        for idx, word_id in enumerate(word_ids):
            if word_id is None:
                continue
            if word_id not in word_preds:
                # First subword — use its prediction
                word_preds[word_id] = ID2LABEL[predictions[idx]]

        pred_labels = [
            word_preds.get(i, "O") for i in range(len(words))
        ]

        all_true.extend(word_labels)
        all_pred.extend(pred_labels)

    print("\n=== Detailed Token-Level Evaluation ===")
    print(classification_report(
        all_true, all_pred,
        labels=LABELS,
        zero_division=0,
    ))

    # Span-level evaluation
    def extract_spans(labels_list):
        spans = {}
        for i, label in enumerate(labels_list):
            if label == "O":
                continue
            prefix, entity_type = label.split("-", 1)
            if prefix == "B":
                spans[i] = (entity_type, [i])
            elif prefix == "I" and i > 0:
                # Find the most recent B- span of same type
                for j in range(i - 1, -1, -1):
                    if j in spans and spans[j][0] == entity_type:
                        spans[j][1].append(i)
                        break
        return spans

    # Count span matches
    span_correct = 0
    span_total_true = 0
    span_total_pred = 0

    offset = 0
    for words, word_labels in sequences:
        n = len(words)
        true_slice = all_true[offset:offset + n]
        pred_slice = all_pred[offset:offset + n]

        true_spans = set(
            (s[0], tuple(s[1])) for s in extract_spans(true_slice).values()
        )
        pred_spans = set(
            (s[0], tuple(s[1])) for s in extract_spans(pred_slice).values()
        )

        span_correct += len(true_spans & pred_spans)
        span_total_true += len(true_spans)
        span_total_pred += len(pred_spans)
        offset += n

    span_p = span_correct / span_total_pred if span_total_pred else 0
    span_r = span_correct / span_total_true if span_total_true else 0
    span_f1 = 2 * span_p * span_r / (span_p + span_r) if (span_p + span_r) else 0

    print(f"\n=== Span-Level Evaluation ===")
    print(f"Precision: {span_p:.4f}")
    print(f"Recall:    {span_r:.4f}")
    print(f"F1:        {span_f1:.4f}")

    return {
        "token_report": classification_report(
            all_true, all_pred, labels=LABELS, output_dict=True, zero_division=0
        ),
        "span_f1": span_f1,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Fine-tune KB-BERT for ingredient NER"
    )
    parser.add_argument("--input", required=True, help="CoNLL training file")
    parser.add_argument("--output", required=True, help="Output directory for model checkpoint")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Pretrained model name")
    parser.add_argument("--epochs", type=int, default=10, help="Training epochs")
    parser.add_argument("--batch-size", type=int, default=32, help="Batch size")
    parser.add_argument("--lr", type=float, default=5e-5, help="Learning rate")
    parser.add_argument("--max-length", type=int, default=128, help="Max sequence length")
    parser.add_argument("--test-size", type=float, default=0.1, help="Validation split fraction")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    parser.add_argument(
        "--golden", default=None,
        help="Path to golden dataset JSON for final evaluation"
    )
    args = parser.parse_args()

    # Set seeds
    torch.manual_seed(args.seed)
    np.random.seed(args.seed)

    # Device
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Device: {device}")

    # Load data
    print(f"Loading CoNLL data from {args.input}...")
    sequences = read_conll(args.input)
    print(f"  {len(sequences)} sequences")

    # Label distribution
    label_counts = {}
    for _, labels in sequences:
        for label in labels:
            label_counts[label] = label_counts.get(label, 0) + 1
    print("  Label distribution:")
    for label in LABELS:
        count = label_counts.get(label, 0)
        print(f"    {label}: {count}")

    # Split
    train_seqs, val_seqs = train_test_split(
        sequences, test_size=args.test_size, random_state=args.seed
    )
    print(f"  Train: {len(train_seqs)}, Val: {len(val_seqs)}")

    # Load tokenizer and model
    print(f"Loading model {args.model}...")
    tokenizer = AutoTokenizer.from_pretrained(args.model)
    model = AutoModelForTokenClassification.from_pretrained(
        args.model,
        num_labels=len(LABELS),
        id2label=ID2LABEL,
        label2id=LABEL2ID,
    )

    # Create datasets
    print("Creating datasets...")
    train_dataset = IngredientNERDataset(train_seqs, tokenizer, args.max_length)
    val_dataset = IngredientNERDataset(val_seqs, tokenizer, args.max_length)
    print(f"  Train examples: {len(train_dataset)}")
    print(f"  Val examples: {len(val_dataset)}")

    # Data collator handles padding
    data_collator = DataCollatorForTokenClassification(tokenizer, padding=True)

    # Training arguments
    training_args = TrainingArguments(
        output_dir=args.output,
        num_train_epochs=args.epochs,
        per_device_train_batch_size=args.batch_size,
        per_device_eval_batch_size=args.batch_size,
        learning_rate=args.lr,
        weight_decay=0.01,
        warmup_ratio=0.1,
        eval_strategy="epoch",
        save_strategy="epoch",
        load_best_model_at_end=True,
        metric_for_best_model="f1",
        greater_is_better=True,
        logging_steps=50,
        save_total_limit=2,
        fp16=torch.cuda.is_available(),
        seed=args.seed,
        report_to="none",
    )

    # Train
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=val_dataset,
        data_collator=data_collator,
        compute_metrics=compute_metrics,
    )

    print("\nStarting training...")
    trainer.train()

    # Save best model
    print(f"\nSaving model to {args.output}...")
    trainer.save_model(args.output)
    tokenizer.save_pretrained(args.output)

    # Save label mapping
    label_map_path = os.path.join(args.output, "label_map.json")
    with open(label_map_path, "w") as f:
        json.dump({"label2id": LABEL2ID, "id2label": ID2LABEL}, f, indent=2)

    # Detailed evaluation on validation set
    print("\n" + "=" * 60)
    print("VALIDATION SET EVALUATION")
    print("=" * 60)
    evaluate_detailed(model, tokenizer, val_seqs, device)

    # Optional: evaluate on golden dataset
    if args.golden and os.path.exists(args.golden):
        print("\n" + "=" * 60)
        print("GOLDEN DATASET EVALUATION")
        print("=" * 60)

        with open(args.golden, encoding="utf-8") as f:
            golden = json.load(f)

        golden_seqs = []
        for entry in golden:
            if "tokens" in entry and "labels" in entry:
                golden_seqs.append((entry["tokens"], entry["labels"]))

        if golden_seqs:
            print(f"  {len(golden_seqs)} golden sequences")
            evaluate_detailed(model, tokenizer, golden_seqs, device)
        else:
            print("  No token/label data in golden dataset")

    print("\nDone!")


if __name__ == "__main__":
    main()
