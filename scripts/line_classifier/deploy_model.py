"""Upload trained line classifier model to Firebase Storage.

Uploads ONNX model + vocab to:
  models/line_classifier/v{version}/model.onnx
  models/line_classifier/v{version}/vocab.txt
  models/line_classifier/latest_version.txt
"""

import argparse
import os
import firebase_admin
from firebase_admin import credentials, storage

BUCKET = "butlery-app-1.firebasestorage.app"
STORAGE_BASE = "models/line_classifier"


def upload_file(bucket, local_path: str, remote_path: str, content_type: str):
    blob = bucket.blob(remote_path)
    blob.upload_from_filename(local_path, content_type=content_type)
    print(f"  Uploaded {local_path} -> {remote_path} ({os.path.getsize(local_path) / 1024:.1f} KB)")


def main():
    parser = argparse.ArgumentParser(description="Deploy line classifier to Firebase Storage")
    parser.add_argument("--onnx-dir", default="output/onnx", help="Directory with model.onnx and vocab.txt")
    parser.add_argument("--version", type=int, default=1, help="Model version number")
    parser.add_argument("--service-account", default="../../functions/service-account.json")
    args = parser.parse_args()

    # Resolve paths relative to script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    onnx_dir = os.path.join(script_dir, args.onnx_dir)
    sa_path = os.path.join(script_dir, args.service_account)

    model_path = os.path.join(onnx_dir, "model.onnx")
    vocab_path = os.path.join(onnx_dir, "vocab.txt")

    for f in [model_path, vocab_path, sa_path]:
        if not os.path.exists(f):
            raise FileNotFoundError(f"Required file not found: {f}")

    # Initialize Firebase
    cred = credentials.Certificate(sa_path)
    firebase_admin.initialize_app(cred, {"storageBucket": BUCKET})
    bucket = storage.bucket()

    version_prefix = f"{STORAGE_BASE}/v{args.version}"
    print(f"Deploying line classifier v{args.version} to {BUCKET}")

    upload_file(bucket, model_path, f"{version_prefix}/model.onnx", "application/octet-stream")
    upload_file(bucket, vocab_path, f"{version_prefix}/vocab.txt", "text/plain")

    # Upload version marker
    version_blob = bucket.blob(f"{STORAGE_BASE}/latest_version.txt")
    version_blob.upload_from_string(str(args.version), content_type="text/plain")
    print(f"  Set latest_version.txt -> {args.version}")

    print("Deploy complete!")


if __name__ == "__main__":
    main()
