#!/usr/bin/env python3
"""Replace a few files on the LIVE Firebase Hosting site without redeploying it.

Why: the `app` site's web build is published by hand and is months older than
main, while its `.well-known/` files decide whether the "glömt lösenord" link
opens the app (BUT-2170). A normal `firebase deploy --only hosting:app` would
republish the whole web app. This clones the live version, swaps only the
named files, and releases the clone, so everything else is byte-identical.

Usage (gcloud must already be signed in to the project):
  python3 tools/hosting/patch_live_files.py --site <app hosting site> \
      /.well-known/assetlinks.json=web/.well-known/assetlinks.json \
      /.well-known/apple-app-site-association=web/.well-known/apple-app-site-association

Stdlib only; the access token comes from `gcloud`.
"""

import argparse
import gzip
import hashlib
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://firebasehosting.googleapis.com/v1beta1"


def access_token() -> str:
    # CI signs in with Workload Identity Federation, so there is no key file to
    # sign a JWT with; gcloud holds the federated credential.
    return subprocess.run(
        ["gcloud", "auth", "print-access-token"],
        capture_output=True,
        check=True,
        text=True,
    ).stdout.strip()


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

    token = access_token()
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
