"""
Train a neural line classifier for Swedish recipe text.

Three stages:
1. Fine-tune KB-BERT for 7-class sequence classification
2. Distill to a 4-layer student model
3. Export to ONNX with INT8 quantization

The model classifies individual recipe lines as:
  ingredient, instruction, title, metadata, sectionHeader, empty, noise

Usage:
    # Full pipeline
    python scripts/line_classifier/train_line_classifier.py \
        --golden data/line_classification_golden.json \
        --silver data/silver_data.json \
        --output output/

    # Stage 1 only (fine-tune teacher)
    python scripts/line_classifier/train_line_classifier.py \
        --golden data/line_classification_golden.json \
        --stage teacher --output output/

    # Stage 2 only (distill)
    python scripts/line_classifier/train_line_classifier.py \
        --teacher output/teacher --stage distill --output output/

    # Stage 3 only (export ONNX)
    python scripts/line_classifier/train_line_classifier.py \
        --student output/student --stage export --output output/
"""

import argparse
import json
import os
import sys

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from pathlib import Path
from sklearn.metrics import classification_report
from sklearn.model_selection import train_test_split
from torch.utils.data import Dataset, DataLoader
from transformers import (
    AutoConfig,
    AutoModelForSequenceClassification,
    AutoTokenizer,
    BertForSequenceClassification,
    Trainer,
    TrainingArguments,
)

# Label set — must match Dart LineType enum order
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
ID2LABEL = {i: label for i, label in enumerate(LABELS)}

DEFAULT_MODEL = "KB/bert-base-swedish-cased"
MAX_LENGTH = 64  # Lines are short, 64 tokens is plenty


# --- Data Loading ---

def load_golden(path: str, exclude_recipe_ids: set[int] | None = None) -> list[tuple[str, str]]:
    """Load golden dataset: list of (text, label).

    Optionally exclude specific recipe_ids for held-out test set.
    """
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if exclude_recipe_ids:
        data = [item for item in data if item.get("recipe_id") not in exclude_recipe_ids]
    return [(item["text"], item["label"]) for item in data]


def load_silver(path: str) -> list[tuple[str, str]]:
    """Load silver dataset: list of (text, label)."""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return [(item["text"], item["label"]) for item in data]


def combine_data(
    golden: list[tuple[str, str]],
    silver: list[tuple[str, str]] | None = None,
    golden_oversample: int = 3,
) -> list[tuple[str, str]]:
    """Combine golden (oversampled) and silver data."""
    # Oversample golden data since it's smaller but higher quality
    combined = golden * golden_oversample
    if silver:
        combined.extend(silver)
    return combined


# --- Dataset ---

class LineClassificationDataset(Dataset):
    def __init__(self, texts: list[str], labels: list[int], tokenizer, max_length=MAX_LENGTH):
        self.texts = texts
        self.labels = labels
        self.tokenizer = tokenizer
        self.max_length = max_length

    def __len__(self):
        return len(self.texts)

    def __getitem__(self, idx):
        encoding = self.tokenizer(
            self.texts[idx],
            truncation=True,
            padding="max_length",
            max_length=self.max_length,
            return_tensors="pt",
        )
        return {
            "input_ids": encoding["input_ids"].squeeze(0),
            "attention_mask": encoding["attention_mask"].squeeze(0),
            "labels": torch.tensor(self.labels[idx], dtype=torch.long),
        }


# --- Stage 1: Fine-tune Teacher ---

def train_teacher(
    train_data: list[tuple[str, str]],
    output_dir: str,
    model_name: str = DEFAULT_MODEL,
    epochs: int = 5,
    batch_size: int = 16,
    lr: float = 2e-5,
):
    """Fine-tune KB-BERT for sequence classification."""
    print(f"\n{'='*60}")
    print(f"Stage 1: Fine-tune teacher ({model_name})")
    print(f"{'='*60}")

    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForSequenceClassification.from_pretrained(
        model_name,
        num_labels=len(LABELS),
        id2label=ID2LABEL,
        label2id=LABEL2ID,
    )

    # Split data
    texts = [t for t, _ in train_data]
    labels = [LABEL2ID[l] for _, l in train_data]
    train_texts, val_texts, train_labels, val_labels = train_test_split(
        texts, labels, test_size=0.15, random_state=42, stratify=labels,
    )

    train_dataset = LineClassificationDataset(train_texts, train_labels, tokenizer)
    val_dataset = LineClassificationDataset(val_texts, val_labels, tokenizer)

    print(f"Train: {len(train_dataset)}, Val: {len(val_dataset)}")
    print(f"Label distribution (train):")
    for label, lid in LABEL2ID.items():
        count = train_labels.count(lid)
        print(f"  {label}: {count}")

    training_args = TrainingArguments(
        output_dir=output_dir,
        num_train_epochs=epochs,
        per_device_train_batch_size=batch_size,
        per_device_eval_batch_size=batch_size,
        learning_rate=lr,
        weight_decay=0.01,
        eval_strategy="epoch",
        save_strategy="epoch",
        load_best_model_at_end=True,
        metric_for_best_model="eval_loss",
        logging_steps=50,
        save_total_limit=2,
        fp16=torch.cuda.is_available(),
    )

    def compute_metrics(eval_pred):
        logits, labels = eval_pred
        predictions = np.argmax(logits, axis=-1)
        accuracy = (predictions == labels).mean()
        return {"accuracy": accuracy}

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=val_dataset,
        compute_metrics=compute_metrics,
    )

    trainer.train()

    # Evaluate
    predictions = trainer.predict(val_dataset)
    preds = np.argmax(predictions.predictions, axis=-1)
    print("\nValidation Report:")
    print(classification_report(
        val_labels, preds, target_names=LABELS, digits=3,
    ))

    # Save
    model.save_pretrained(output_dir)
    tokenizer.save_pretrained(output_dir)
    print(f"Teacher saved to {output_dir}")

    return model, tokenizer


# --- Stage 2: Distill to Student ---

def create_student_config(teacher_config, num_layers=4, hidden_size=312, intermediate_size=1200):
    """Create a smaller student config."""
    student_config = AutoConfig.from_pretrained(
        teacher_config.name_or_path if hasattr(teacher_config, "name_or_path") else DEFAULT_MODEL,
    )
    student_config.num_hidden_layers = num_layers
    student_config.hidden_size = hidden_size
    student_config.intermediate_size = intermediate_size
    student_config.num_attention_heads = max(1, hidden_size // 64)
    student_config.num_labels = len(LABELS)
    student_config.id2label = ID2LABEL
    student_config.label2id = LABEL2ID
    return student_config


def distill_student(
    teacher_dir: str,
    train_data: list[tuple[str, str]],
    output_dir: str,
    epochs: int = 20,
    batch_size: int = 16,
    lr: float = 5e-5,
    temperature: float = 4.0,
    alpha_kd: float = 0.7,
):
    """Distill teacher to 4-layer student using KL divergence."""
    print(f"\n{'='*60}")
    print(f"Stage 2: Distill to student (4 layers)")
    print(f"{'='*60}")

    tokenizer = AutoTokenizer.from_pretrained(teacher_dir)
    teacher = AutoModelForSequenceClassification.from_pretrained(teacher_dir)
    teacher.eval()

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    teacher.to(device)

    # Create student
    student_config = create_student_config(teacher.config)
    student = BertForSequenceClassification(student_config)
    student.to(device)

    print(f"Teacher params: {sum(p.numel() for p in teacher.parameters()):,}")
    print(f"Student params: {sum(p.numel() for p in student.parameters()):,}")

    # Prepare data
    texts = [t for t, _ in train_data]
    labels = [LABEL2ID[l] for _, l in train_data]
    train_texts, val_texts, train_labels, val_labels = train_test_split(
        texts, labels, test_size=0.15, random_state=42, stratify=labels,
    )

    train_dataset = LineClassificationDataset(train_texts, train_labels, tokenizer)
    val_dataset = LineClassificationDataset(val_texts, val_labels, tokenizer)

    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=batch_size)

    optimizer = torch.optim.AdamW(student.parameters(), lr=lr, weight_decay=0.01)
    ce_loss_fn = nn.CrossEntropyLoss()
    kd_loss_fn = nn.KLDivLoss(reduction="batchmean")

    best_val_acc = 0.0

    for epoch in range(epochs):
        student.train()
        total_loss = 0.0

        for batch in train_loader:
            input_ids = batch["input_ids"].to(device)
            attention_mask = batch["attention_mask"].to(device)
            gold_labels = batch["labels"].to(device)

            # Teacher forward (no grad)
            with torch.no_grad():
                teacher_out = teacher(input_ids=input_ids, attention_mask=attention_mask)
                teacher_logits = teacher_out.logits

            # Student forward
            student_out = student(input_ids=input_ids, attention_mask=attention_mask)
            student_logits = student_out.logits

            # KD loss: soft label matching
            kd_loss = kd_loss_fn(
                F.log_softmax(student_logits / temperature, dim=-1),
                F.softmax(teacher_logits / temperature, dim=-1),
            ) * (temperature ** 2)

            # Hard label loss
            ce_loss = ce_loss_fn(student_logits, gold_labels)

            # Combined loss
            loss = alpha_kd * kd_loss + (1 - alpha_kd) * ce_loss

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            total_loss += loss.item()

        # Validation
        student.eval()
        val_preds, val_true = [], []
        with torch.no_grad():
            for batch in val_loader:
                input_ids = batch["input_ids"].to(device)
                attention_mask = batch["attention_mask"].to(device)
                out = student(input_ids=input_ids, attention_mask=attention_mask)
                preds = torch.argmax(out.logits, dim=-1)
                val_preds.extend(preds.cpu().tolist())
                val_true.extend(batch["labels"].tolist())

        val_acc = sum(p == t for p, t in zip(val_preds, val_true)) / len(val_true)
        avg_loss = total_loss / len(train_loader)
        print(f"Epoch {epoch+1}/{epochs}: loss={avg_loss:.4f}, val_acc={val_acc:.3f}")

        if val_acc > best_val_acc:
            best_val_acc = val_acc
            student.save_pretrained(output_dir)
            tokenizer.save_pretrained(output_dir)

    print(f"\nBest validation accuracy: {best_val_acc:.3f}")
    print(f"Student saved to {output_dir}")

    # Final evaluation
    print("\nFinal Validation Report:")
    print(classification_report(val_true, val_preds, target_names=LABELS, digits=3))

    return student, tokenizer


# --- Stage 3: Export ONNX ---

def export_onnx(
    student_dir: str,
    output_dir: str,
    max_length: int = MAX_LENGTH,
    verify: bool = True,
):
    """Export student model to quantized ONNX."""
    print(f"\n{'='*60}")
    print(f"Stage 3: Export to ONNX")
    print(f"{'='*60}")

    from onnxruntime.quantization import quantize_dynamic, QuantType
    import onnx

    tokenizer = AutoTokenizer.from_pretrained(student_dir)
    model = AutoModelForSequenceClassification.from_pretrained(student_dir)
    model.eval()

    os.makedirs(output_dir, exist_ok=True)
    raw_path = os.path.join(output_dir, "model_raw.onnx")
    quantized_path = os.path.join(output_dir, "model.onnx")

    # Dummy input
    dummy = tokenizer(
        "2 dl mjölk",
        return_tensors="pt",
        padding="max_length",
        max_length=max_length,
        truncation=True,
    )

    torch.onnx.export(
        model,
        (dummy["input_ids"], dummy["attention_mask"]),
        raw_path,
        input_names=["input_ids", "attention_mask"],
        output_names=["logits"],
        dynamic_axes={
            "input_ids": {0: "batch_size", 1: "sequence_length"},
            "attention_mask": {0: "batch_size", 1: "sequence_length"},
            "logits": {0: "batch_size"},
        },
        opset_version=14,
    )

    # INT8 quantization
    quantize_dynamic(
        raw_path,
        quantized_path,
        weight_type=QuantType.QInt8,
    )
    os.remove(raw_path)

    # Copy vocab
    vocab_src = os.path.join(student_dir, "vocab.txt")
    vocab_dst = os.path.join(output_dir, "vocab.txt")
    if os.path.exists(vocab_src):
        import shutil
        shutil.copy2(vocab_src, vocab_dst)

    # Save metadata
    model_size = os.path.getsize(quantized_path)
    info = {
        "model_type": "line_classifier",
        "base_model": DEFAULT_MODEL,
        "num_labels": len(LABELS),
        "labels": LABELS,
        "label2id": LABEL2ID,
        "max_length": max_length,
        "quantization": "INT8",
        "size_bytes": model_size,
    }
    with open(os.path.join(output_dir, "model_info.json"), "w") as f:
        json.dump(info, f, indent=2)

    # Save label map
    with open(os.path.join(output_dir, "label_map.json"), "w") as f:
        json.dump({"label2id": LABEL2ID, "id2label": ID2LABEL}, f, indent=2)

    print(f"ONNX model: {quantized_path} ({model_size / 1024 / 1024:.1f} MB)")

    # Verify
    if verify:
        import onnxruntime as ort
        session = ort.InferenceSession(quantized_path)
        ort_inputs = {
            "input_ids": dummy["input_ids"].numpy(),
            "attention_mask": dummy["attention_mask"].numpy(),
        }
        ort_out = session.run(None, ort_inputs)[0]

        with torch.no_grad():
            pt_out = model(**dummy).logits.numpy()

        diff = np.abs(ort_out - pt_out).max()
        print(f"Max output difference (PyTorch vs ONNX): {diff:.6f}")
        pt_pred = LABELS[np.argmax(pt_out)]
        ort_pred = LABELS[np.argmax(ort_out)]
        print(f"Test prediction: PyTorch={pt_pred}, ONNX={ort_pred}")

    return quantized_path


# --- Main ---

def main():
    parser = argparse.ArgumentParser(description="Train neural line classifier")
    parser.add_argument("--golden", type=str, default="data/line_classification_golden.json")
    parser.add_argument("--silver", type=str, default=None)
    parser.add_argument("--output", type=str, default="output/")
    parser.add_argument("--stage", choices=["all", "teacher", "distill", "export"], default="all")
    parser.add_argument("--teacher", type=str, default=None, help="Path to teacher model (for distill stage)")
    parser.add_argument("--student", type=str, default=None, help="Path to student model (for export stage)")
    parser.add_argument("--epochs-teacher", type=int, default=5)
    parser.add_argument("--epochs-student", type=int, default=20)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--test-recipe-ids", type=int, nargs="+", default=None,
                        help="Recipe IDs to exclude from training (held-out test set)")
    args = parser.parse_args()

    output = Path(args.output)
    teacher_dir = str(output / "teacher")
    student_dir = str(output / "student")
    onnx_dir = str(output / "onnx")

    # Load data for stages that need it
    train_data = None
    exclude_ids = set(args.test_recipe_ids) if args.test_recipe_ids else None
    if args.stage in ("all", "teacher", "distill"):
        golden = load_golden(args.golden, exclude_recipe_ids=exclude_ids)
        if exclude_ids:
            print(f"Excluded recipe IDs from training: {sorted(exclude_ids)}")
        silver = load_silver(args.silver) if args.silver else None
        train_data = combine_data(golden, silver)
        print(f"Training data: {len(train_data)} samples")

    # Stage 1: Teacher
    if args.stage in ("all", "teacher"):
        train_teacher(train_data, teacher_dir, epochs=args.epochs_teacher, batch_size=args.batch_size)

    # Stage 2: Distill
    if args.stage in ("all", "distill"):
        t_dir = args.teacher or teacher_dir
        distill_student(t_dir, train_data, student_dir, epochs=args.epochs_student, batch_size=args.batch_size)

    # Stage 3: Export
    if args.stage in ("all", "export"):
        s_dir = args.student or student_dir
        export_onnx(s_dir, onnx_dir)

    print(f"\n{'='*60}")
    print("Done! Output files:")
    if os.path.exists(onnx_dir):
        for f in sorted(os.listdir(onnx_dir)):
            size = os.path.getsize(os.path.join(onnx_dir, f))
            print(f"  {f} ({size / 1024:.1f} KB)")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
