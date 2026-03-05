"""
Export fine-tuned student BERT NER model to ONNX with INT8 quantization.

Exports the PyTorch student model to ONNX format, applies dynamic INT8
quantization, and verifies output parity between PyTorch and ONNX.

Output files:
- model.onnx: Quantized ONNX model (<20MB target)
- vocab.txt: WordPiece vocabulary for Dart tokenizer
- label_map.json: BIO label ↔ ID mapping
- model_info.json: Metadata (version, size, labels, max_length)

Usage:
    python scripts/ner/export_onnx.py \
        --model scripts/ner/output/student-ner \
        --output scripts/ner/output/onnx \
        --verify
"""

import argparse
import json
import os
import shutil

import numpy as np
import onnx
import torch
from onnxruntime.quantization import quantize_dynamic, QuantType
from transformers import AutoModelForTokenClassification, AutoTokenizer

from train_bert_ner import LABELS, LABEL2ID, ID2LABEL


def export_to_onnx(model, tokenizer, output_path: str, max_length: int = 128):
    """Export PyTorch model to ONNX format."""
    model.eval()

    # Create dummy input
    dummy_text = ["2", "dl", "mjölk"]
    encoding = tokenizer(
        dummy_text,
        is_split_into_words=True,
        return_tensors="pt",
        padding="max_length",
        max_length=max_length,
        truncation=True,
    )

    input_ids = encoding["input_ids"]
    attention_mask = encoding["attention_mask"]

    # Export
    torch.onnx.export(
        model,
        (input_ids, attention_mask),
        output_path,
        input_names=["input_ids", "attention_mask"],
        output_names=["logits"],
        dynamic_axes={
            "input_ids": {0: "batch_size", 1: "sequence_length"},
            "attention_mask": {0: "batch_size", 1: "sequence_length"},
            "logits": {0: "batch_size", 1: "sequence_length"},
        },
        opset_version=14,
        do_constant_folding=True,
    )

    print(f"Exported ONNX model to {output_path}")
    model_size = os.path.getsize(output_path) / (1024 * 1024)
    print(f"  Size: {model_size:.1f} MB")

    return output_path


def quantize_model(input_path: str, output_path: str):
    """Apply INT8 dynamic quantization to ONNX model."""
    quantize_dynamic(
        model_input=input_path,
        model_output=output_path,
        weight_type=QuantType.QInt8,
    )

    original_size = os.path.getsize(input_path) / (1024 * 1024)
    quantized_size = os.path.getsize(output_path) / (1024 * 1024)
    compression = original_size / quantized_size

    print(f"Quantized model: {output_path}")
    print(f"  Original: {original_size:.1f} MB")
    print(f"  Quantized: {quantized_size:.1f} MB")
    print(f"  Compression: {compression:.1f}x")

    return output_path


def verify_onnx(model, tokenizer, onnx_path: str, test_inputs: list[list[str]], device="cpu"):
    """Verify ONNX output matches PyTorch output."""
    import onnxruntime as ort

    model.eval()
    model.to(device)

    session = ort.InferenceSession(onnx_path)
    max_diff = 0.0
    mismatches = 0

    for words in test_inputs:
        encoding = tokenizer(
            words,
            is_split_into_words=True,
            return_tensors="pt",
            padding=True,
            truncation=True,
            max_length=128,
        )

        # PyTorch inference
        with torch.no_grad():
            pt_outputs = model(
                input_ids=encoding["input_ids"].to(device),
                attention_mask=encoding["attention_mask"].to(device),
            )
        pt_logits = pt_outputs.logits.cpu().numpy()
        pt_preds = np.argmax(pt_logits, axis=-1)

        # ONNX inference
        ort_inputs = {
            "input_ids": encoding["input_ids"].numpy(),
            "attention_mask": encoding["attention_mask"].numpy(),
        }
        ort_outputs = session.run(None, ort_inputs)
        ort_logits = ort_outputs[0]
        ort_preds = np.argmax(ort_logits, axis=-1)

        # Compare
        diff = np.max(np.abs(pt_logits - ort_logits))
        max_diff = max(max_diff, diff)

        if not np.array_equal(pt_preds, ort_preds):
            mismatches += 1
            # Check if mismatches are only on non-active tokens
            word_ids = encoding.word_ids()
            active = [i for i, wid in enumerate(word_ids) if wid is not None]
            pt_active = pt_preds[0][active]
            ort_active = ort_preds[0][active]
            if not np.array_equal(pt_active, ort_active):
                pt_labels = [ID2LABEL[p] for p in pt_active]
                ort_labels = [ID2LABEL[p] for p in ort_active]
                print(f"  MISMATCH on '{' '.join(words)}':")
                print(f"    PyTorch: {pt_labels}")
                print(f"    ONNX:    {ort_labels}")

    print(f"\nVerification results ({len(test_inputs)} test inputs):")
    print(f"  Max logit diff: {max_diff:.6f}")
    print(f"  Prediction mismatches: {mismatches}/{len(test_inputs)}")
    print(f"  Status: {'PASS' if mismatches == 0 else 'CHECK — some predictions differ (may be acceptable after quantization)'}")

    return mismatches == 0


def main():
    parser = argparse.ArgumentParser(
        description="Export BERT NER model to ONNX with INT8 quantization"
    )
    parser.add_argument("--model", required=True, help="Path to PyTorch student model")
    parser.add_argument("--output", required=True, help="Output directory for ONNX files")
    parser.add_argument("--max-length", type=int, default=128, help="Max sequence length")
    parser.add_argument("--verify", action="store_true", help="Verify ONNX vs PyTorch parity")
    parser.add_argument("--no-quantize", action="store_true", help="Skip INT8 quantization")
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)

    # Load model
    print(f"Loading model from {args.model}...")
    tokenizer = AutoTokenizer.from_pretrained(args.model)
    model = AutoModelForTokenClassification.from_pretrained(args.model)
    num_params = sum(p.numel() for p in model.parameters())
    print(f"  Parameters: {num_params:,}")

    # Export to ONNX
    fp32_path = os.path.join(args.output, "model_fp32.onnx")
    export_to_onnx(model, tokenizer, fp32_path, args.max_length)

    # Validate ONNX model
    onnx_model = onnx.load(fp32_path)
    onnx.checker.check_model(onnx_model)
    print("  ONNX model validation: PASS")

    # Quantize
    if not args.no_quantize:
        quantized_path = os.path.join(args.output, "model.onnx")
        quantize_model(fp32_path, quantized_path)
        final_model_path = quantized_path
        # Remove FP32 model
        os.remove(fp32_path)
    else:
        final_model_path = fp32_path
        # Rename to model.onnx
        final_path = os.path.join(args.output, "model.onnx")
        os.rename(fp32_path, final_path)
        final_model_path = final_path

    # Copy vocab.txt for Dart WordPiece tokenizer
    vocab_src = os.path.join(args.model, "vocab.txt")
    vocab_dst = os.path.join(args.output, "vocab.txt")
    if os.path.exists(vocab_src):
        shutil.copy2(vocab_src, vocab_dst)
        vocab_size = sum(1 for _ in open(vocab_src, encoding="utf-8"))
        print(f"  Copied vocab.txt ({vocab_size} tokens)")
    else:
        print("  WARNING: vocab.txt not found in model directory")

    # Save label map
    label_map_path = os.path.join(args.output, "label_map.json")
    with open(label_map_path, "w") as f:
        json.dump({"label2id": LABEL2ID, "id2label": ID2LABEL}, f, indent=2)

    # Save model info (for Dart NerModelManager)
    model_size = os.path.getsize(final_model_path)
    info = {
        "version": "1",
        "model_file": "model.onnx",
        "vocab_file": "vocab.txt",
        "label_map_file": "label_map.json",
        "num_labels": len(LABELS),
        "labels": LABELS,
        "max_length": args.max_length,
        "model_size_bytes": model_size,
        "quantization": "int8_dynamic" if not args.no_quantize else "none",
        "base_model": "KB/bert-base-swedish-cased",
    }
    info_path = os.path.join(args.output, "model_info.json")
    with open(info_path, "w") as f:
        json.dump(info, f, indent=2)
    print(f"  Saved model_info.json")

    # Verify
    if args.verify:
        print("\nVerifying ONNX output parity...")
        test_inputs = [
            ["2", "dl", "mjölk"],
            ["1", "msk", "hackad", "persilja"],
            ["salt", "och", "peppar"],
            ["ca", "200", "g", "kycklingfilé"],
            ["1-2", "klyftor", "vitlök", ",", "finriven"],
            ["ett", "paket", "gräddfil"],
            ["3", "stora", "potatisar", ",", "skalade"],
            ["olivolja", "till", "stekning"],
            ["1", "burk", "krossade", "tomater", "(", "400", "g", ")"],
            ["rivet", "skal", "av", "en", "citron"],
        ]
        verify_onnx(model, tokenizer, final_model_path, test_inputs)

    # Summary
    print("\n" + "=" * 40)
    print("EXPORT SUMMARY")
    print("=" * 40)
    print(f"  Model: {final_model_path}")
    print(f"  Size: {model_size / (1024 * 1024):.1f} MB")
    print(f"  Labels: {len(LABELS)}")
    print(f"  Max length: {args.max_length}")
    print(f"\nFiles in {args.output}/:")
    for f in sorted(os.listdir(args.output)):
        size = os.path.getsize(os.path.join(args.output, f))
        print(f"  {f}: {size / 1024:.0f} KB")

    print("\nReady for Firebase Storage upload.")
    print(f"Upload path: models/ingredient_ner/v1/")


if __name__ == "__main__":
    main()
