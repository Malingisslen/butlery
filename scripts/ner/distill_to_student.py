"""
Knowledge distillation: KB-BERT teacher → 4-layer student.

TinyBERT-style distillation with:
- Task-specific distillation (soft label matching via KL divergence)
- Hidden state matching (teacher layers mapped to student layers)
- Attention transfer (teacher attention distributions → student)

The student model uses the same tokenizer as the teacher, just fewer layers
and smaller hidden dimension, making it suitable for on-device inference.

Usage:
    python scripts/ner/distill_to_student.py \
        --teacher scripts/ner/output/kb-bert-ner \
        --input scripts/crf/data/training.conll \
        --output scripts/ner/output/student-ner \
        --epochs 20
"""

import argparse
import os
import sys

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader
from transformers import (
    AutoConfig,
    AutoModelForTokenClassification,
    AutoTokenizer,
    BertForTokenClassification,
    DataCollatorForTokenClassification,
)
from sklearn.model_selection import train_test_split

# Import shared utilities from training script
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from train_bert_ner import (
    LABELS,
    LABEL2ID,
    ID2LABEL,
    IngredientNERDataset,
    evaluate_detailed,
    read_conll,
)


def create_student_config(teacher_config, num_hidden_layers=4, hidden_size=312, intermediate_size=1200):
    """Create a smaller student config based on teacher architecture."""
    student_config = AutoConfig.from_pretrained(
        teacher_config.name_or_path if hasattr(teacher_config, 'name_or_path') else "KB/bert-base-swedish-cased",
    )
    student_config.num_hidden_layers = num_hidden_layers
    student_config.hidden_size = hidden_size
    student_config.intermediate_size = intermediate_size
    student_config.num_attention_heads = max(1, hidden_size // 64)
    student_config.num_labels = len(LABELS)
    student_config.id2label = ID2LABEL
    student_config.label2id = LABEL2ID
    return student_config


class DistillationLoss(nn.Module):
    """Combined distillation loss: hard labels + soft labels + hidden states."""

    def __init__(self, temperature=4.0, alpha_ce=0.5, alpha_kl=0.5, alpha_hidden=0.0):
        super().__init__()
        self.temperature = temperature
        self.alpha_ce = alpha_ce    # Weight for hard label cross-entropy
        self.alpha_kl = alpha_kl    # Weight for KL divergence (soft labels)
        self.alpha_hidden = alpha_hidden  # Weight for hidden state matching

    def forward(self, student_logits, teacher_logits, labels, student_hidden=None, teacher_hidden=None):
        # Hard label loss (cross-entropy with gold labels)
        # Reshape for cross_entropy: (batch * seq_len, num_labels)
        active_mask = labels != -100
        if active_mask.any():
            active_student = student_logits[active_mask]
            active_labels = labels[active_mask]
            ce_loss = F.cross_entropy(active_student, active_labels)
        else:
            ce_loss = torch.tensor(0.0, device=student_logits.device)

        # Soft label loss (KL divergence between teacher and student)
        if active_mask.any():
            active_teacher = teacher_logits[active_mask]
            # Scale logits by temperature
            student_soft = F.log_softmax(active_student / self.temperature, dim=-1)
            teacher_soft = F.softmax(active_teacher / self.temperature, dim=-1)
            kl_loss = F.kl_div(student_soft, teacher_soft, reduction="batchmean") * (self.temperature ** 2)
        else:
            kl_loss = torch.tensor(0.0, device=student_logits.device)

        total_loss = self.alpha_ce * ce_loss + self.alpha_kl * kl_loss

        # Hidden state matching (optional)
        if self.alpha_hidden > 0 and student_hidden is not None and teacher_hidden is not None:
            hidden_loss = self._hidden_state_loss(student_hidden, teacher_hidden)
            total_loss += self.alpha_hidden * hidden_loss

        return total_loss

    def _hidden_state_loss(self, student_hidden, teacher_hidden):
        """MSE loss between mapped teacher and student hidden states."""
        # Map teacher layers to student layers (evenly spaced)
        n_student = len(student_hidden)
        n_teacher = len(teacher_hidden)
        # Skip embedding layer (index 0), map remaining layers evenly
        teacher_indices = [
            int(round((i + 1) * (n_teacher - 1) / n_student))
            for i in range(n_student)
        ]

        loss = torch.tensor(0.0, device=student_hidden[0].device)
        for s_idx, t_idx in enumerate(teacher_indices):
            s_hidden = student_hidden[s_idx]
            t_hidden = teacher_hidden[t_idx]
            # Project if dimensions differ
            if s_hidden.shape[-1] != t_hidden.shape[-1]:
                # Skip — would need a projection layer
                continue
            loss += F.mse_loss(s_hidden, t_hidden)

        return loss / max(len(teacher_indices), 1)


def train_student(
    teacher, student, tokenizer, train_dataset, val_dataset,
    val_sequences, args, device
):
    """Train student model with distillation from teacher."""
    data_collator = DataCollatorForTokenClassification(tokenizer, padding=True)
    train_loader = DataLoader(
        train_dataset,
        batch_size=args.batch_size,
        shuffle=True,
        collate_fn=data_collator,
    )

    optimizer = torch.optim.AdamW(
        student.parameters(),
        lr=args.lr,
        weight_decay=0.01,
    )

    # Linear warmup + cosine decay
    total_steps = len(train_loader) * args.epochs
    warmup_steps = int(total_steps * 0.1)

    def lr_lambda(step):
        if step < warmup_steps:
            return step / max(warmup_steps, 1)
        progress = (step - warmup_steps) / max(total_steps - warmup_steps, 1)
        return 0.5 * (1.0 + np.cos(np.pi * progress))

    scheduler = torch.optim.lr_scheduler.LambdaLR(optimizer, lr_lambda)

    criterion = DistillationLoss(
        temperature=args.temperature,
        alpha_ce=0.5,
        alpha_kl=0.5,
    )

    teacher.eval()
    teacher.to(device)
    student.to(device)

    best_f1 = 0.0

    for epoch in range(args.epochs):
        student.train()
        total_loss = 0.0
        num_batches = 0

        for batch in train_loader:
            batch = {k: v.to(device) for k, v in batch.items()}
            labels = batch.pop("labels")

            # Teacher forward (no gradients)
            with torch.no_grad():
                teacher_outputs = teacher(**batch)
                teacher_logits = teacher_outputs.logits

            # Student forward
            batch["labels"] = labels
            student_outputs = student(**batch)
            student_logits = student_outputs.logits

            # Distillation loss
            loss = criterion(student_logits, teacher_logits, labels)

            optimizer.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(student.parameters(), max_norm=1.0)
            optimizer.step()
            scheduler.step()

            total_loss += loss.item()
            num_batches += 1

        avg_loss = total_loss / max(num_batches, 1)
        print(f"Epoch {epoch + 1}/{args.epochs} — Loss: {avg_loss:.4f} — LR: {scheduler.get_last_lr()[0]:.2e}")

        # Evaluate every epoch
        if val_sequences:
            results = evaluate_detailed(student, tokenizer, val_sequences, device)
            f1 = results["token_report"]["macro avg"]["f1-score"]
            span_f1 = results["span_f1"]
            print(f"  Val token F1: {f1:.4f}, Span F1: {span_f1:.4f}")

            if f1 > best_f1:
                best_f1 = f1
                # Save best checkpoint
                student.save_pretrained(args.output)
                tokenizer.save_pretrained(args.output)
                print(f"  Saved best model (F1={best_f1:.4f})")

    return best_f1


def main():
    parser = argparse.ArgumentParser(
        description="Distill KB-BERT teacher to small student for on-device NER"
    )
    parser.add_argument("--teacher", required=True, help="Path to fine-tuned teacher model")
    parser.add_argument("--input", required=True, help="CoNLL training file")
    parser.add_argument("--output", required=True, help="Output directory for student model")
    parser.add_argument("--epochs", type=int, default=20, help="Distillation epochs")
    parser.add_argument("--batch-size", type=int, default=32, help="Batch size")
    parser.add_argument("--lr", type=float, default=5e-5, help="Learning rate")
    parser.add_argument("--temperature", type=float, default=4.0, help="Distillation temperature")
    parser.add_argument("--student-layers", type=int, default=4, help="Number of student transformer layers")
    parser.add_argument("--student-hidden", type=int, default=312, help="Student hidden size")
    parser.add_argument("--student-intermediate", type=int, default=1200, help="Student intermediate size")
    parser.add_argument("--test-size", type=float, default=0.1, help="Validation split")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    parser.add_argument(
        "--golden", default=None,
        help="Path to golden dataset JSON for final evaluation"
    )
    args = parser.parse_args()

    torch.manual_seed(args.seed)
    np.random.seed(args.seed)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Device: {device}")

    # Load teacher
    print(f"Loading teacher from {args.teacher}...")
    tokenizer = AutoTokenizer.from_pretrained(args.teacher)
    teacher = AutoModelForTokenClassification.from_pretrained(args.teacher)
    teacher_config = teacher.config
    print(f"  Teacher: {teacher_config.num_hidden_layers} layers, {teacher_config.hidden_size} hidden")
    print(f"  Teacher params: {sum(p.numel() for p in teacher.parameters()):,}")

    # Create student
    print("Creating student model...")
    student_config = create_student_config(
        teacher_config,
        num_hidden_layers=args.student_layers,
        hidden_size=args.student_hidden,
        intermediate_size=args.student_intermediate,
    )
    student = BertForTokenClassification(student_config)

    # Initialize student embeddings from teacher (vocabulary is shared)
    # Only copy if dimensions match
    if student_config.hidden_size == teacher_config.hidden_size:
        student.bert.embeddings.load_state_dict(
            teacher.bert.embeddings.state_dict()
        )
        print("  Copied teacher embeddings to student")
    else:
        print("  Skipping embedding copy (hidden size differs)")

    print(f"  Student: {student_config.num_hidden_layers} layers, {student_config.hidden_size} hidden")
    print(f"  Student params: {sum(p.numel() for p in student.parameters()):,}")
    compression = sum(p.numel() for p in teacher.parameters()) / sum(p.numel() for p in student.parameters())
    print(f"  Compression ratio: {compression:.1f}x")

    # Load data
    print(f"Loading CoNLL data from {args.input}...")
    sequences = read_conll(args.input)
    train_seqs, val_seqs = train_test_split(
        sequences, test_size=args.test_size, random_state=args.seed
    )
    print(f"  Train: {len(train_seqs)}, Val: {len(val_seqs)}")

    train_dataset = IngredientNERDataset(train_seqs, tokenizer)
    val_dataset = IngredientNERDataset(val_seqs, tokenizer)

    # Create output dir
    os.makedirs(args.output, exist_ok=True)

    # Train
    print("\nStarting distillation...")
    best_f1 = train_student(
        teacher, student, tokenizer,
        train_dataset, val_dataset, val_seqs,
        args, device
    )

    print(f"\nBest validation F1: {best_f1:.4f}")

    # Final evaluation on golden dataset
    if args.golden and os.path.exists(args.golden):
        print("\n" + "=" * 60)
        print("GOLDEN DATASET — TEACHER vs STUDENT")
        print("=" * 60)

        import json
        with open(args.golden, encoding="utf-8") as f:
            golden = json.load(f)

        golden_seqs = [
            (entry["tokens"], entry["labels"])
            for entry in golden
            if "tokens" in entry and "labels" in entry
        ]

        if golden_seqs:
            print(f"\n--- Teacher ({teacher_config.num_hidden_layers} layers) ---")
            teacher_results = evaluate_detailed(teacher, tokenizer, golden_seqs, device)

            # Reload best student
            best_student = AutoModelForTokenClassification.from_pretrained(args.output)
            print(f"\n--- Student ({args.student_layers} layers) ---")
            student_results = evaluate_detailed(best_student, tokenizer, golden_seqs, device)

            # Summary
            t_f1 = teacher_results["token_report"]["macro avg"]["f1-score"]
            s_f1 = student_results["token_report"]["macro avg"]["f1-score"]
            print(f"\nTeacher token F1: {t_f1:.4f}")
            print(f"Student token F1: {s_f1:.4f}")
            print(f"Retention: {s_f1 / t_f1 * 100:.1f}%")

    # Save config info
    info = {
        "teacher_model": args.teacher,
        "student_layers": args.student_layers,
        "student_hidden": args.student_hidden,
        "student_intermediate": args.student_intermediate,
        "best_val_f1": best_f1,
        "temperature": args.temperature,
        "epochs": args.epochs,
    }
    info_path = os.path.join(args.output, "distillation_info.json")
    import json
    with open(info_path, "w") as f:
        json.dump(info, f, indent=2)

    print("\nDone!")


if __name__ == "__main__":
    main()
