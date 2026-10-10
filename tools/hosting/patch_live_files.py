#!/usr/bin/env python3
"""Replace a few files on the LIVE Firebase Hosting site without redeploying it.

Why: the `app` site's web build is published by hand and is months older than
main, while its `.well-known/` files decide whether the "glömt lösenord" link
opens the app (BUT-2170). A normal `firebase deploy --only hosting:app` would
republish the whole web app. This clones the live version, swaps only the
named files, and releases the clone, so everything else is byte-identical.

Usage (CI passes the service-account key file):
  python3 tools/hosting/patch_live_files.py --site butlery-app-1 \
      --key "$RUNNER_TEMP/sa.json" \
      /.well-known/assetlinks.json=web/.well-known/assetlinks.json \
      /.well-known/apple-app-site-association=web/.well-known/apple-app-site-association

Stdlib only; the JWT is signed with the `openssl` CLI.
"""

import argparse
import base64
import gzip
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

API = "https://firebasehosting.googleapis.com/v1beta1"
SCOPE = "https://www.googleapis.com/auth/firebase.hosting"


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def access_token(key_path: str) -> str:
    with open(key_path, encoding="utf-8") as f:
        key = json.load(f)
    now = int(time.time())
    header = b64url(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    claims = b64url(
        json.dumps(
            {
                "iss": key["client_email"],
                "scope": SCOPE,
                "aud": key["token_uri"],
                "iat": now,
                "exp": now + 600,
            }
        ).encode()
    )
    signing_input = f"{header}.{claims}".encode()
    with tempfile.NamedTemporaryFile("w", delete=False) as pem:
        pem.write(key["private_key"])
    try:
        signature = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", pem.name],
            input=signing_input,
            capture_output=True,
            check=True,
        ).stdout
    finally:
        os.unlink(pem.name)
    assertion = f"{header}.{claims}.{b64url(signature)}"
    body = (
        "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer"
        f"&assertion={assertion}"
    ).encode()
    req = urllib.request.Request(key["token_uri"], data=body, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)["access_token"]


def call(token, method, url, body=None, raw=None, content_type=None):
    data = raw if raw is not None else (
        json.dumps(body).encode() if body is not None else None
    )
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    if data is not None:
        req.add_header("Content-Type", content_type or "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            text = resp.read()
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {url} -> {e.code}: {e.read().decode()[:500]}")
    return json.loads(text) if text else {}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--site", required=True)
    parser.add_argument("--key", required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("files", nargs="+", help="/served/path=local/file")
    args = parser.parse_args()

    files = {}
    for spec in args.files:
        served, local = spec.split("=", 1)
        if not served.startswith("/"):
            sys.exit(f"served path must start with /: {served}")
        with open(local, "rb") as f:
            gz = gzip.compress(f.read(), mtime=0)
        files[served] = (hashlib.sha256(gz).hexdigest(), gz)

    token = access_token(args.key)
    site = f"{API}/sites/{args.site}"

    releases = call(token, "GET", f"{site}/releases?pageSize=1")
    live = releases["releases"][0]["version"]["name"]
    print(f"live version: {live}")
    if args.dry_run:
        for served, (digest, _) in files.items():
            print(f"would replace {served} ({digest[:12]})")
        return

    op = call(
        token,
        "POST",
        f"{site}/versions:clone",
        {"sourceVersion": live, "finalize": False},
    )
    while not op.get("done"):
        time.sleep(3)
        op = call(token, "GET", f"{API}/{op['name']}")
    if "error" in op:
        sys.exit(f"clone failed: {op['error']}")
    version = op["response"]["name"]
    print(f"cloned to: {version}")

    populated = call(
        token,
        "POST",
        f"{API}/{version}:populateFiles",
        {"files": {p: d for p, (d, _) in files.items()}},
    )
    required = set(populated.get("uploadRequiredHashes", []))
    for served, (digest, gz) in files.items():
        if digest in required:
            call(
                token,
                "POST",
                f"{populated['uploadUrl']}/{digest}",
                raw=gz,
                content_type="application/octet-stream",
            )
        print(f"replaced {served}")

    call(
        token,
        "PATCH",
        f"{API}/{version}?update_mask=status",
        {"status": "FINALIZED"},
    )
    release = call(token, "POST", f"{site}/releases?versionName={version}", {})
    print(f"released: {release.get('name')}")


if __name__ == "__main__":
    main()
