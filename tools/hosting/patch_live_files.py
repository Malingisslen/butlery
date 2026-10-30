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

`--headers-from-target app` also replaces the response headers with that
firebase.json target's (the CSP among them); rewrites stay as live.

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
    parser.add_argument(
        "--headers-from-target",
        help="also replace the site's response headers with this firebase.json "
        "hosting target's, leaving its rewrites alone",
    )
    parser.add_argument("files", nargs="*", help="/served/path=local/file")
    args = parser.parse_args()
    if not args.files and not args.headers_from_target:
        sys.exit("nothing to patch: name files, --headers-from-target, or both")

    headers = None
    if args.headers_from_target:
        with open("firebase.json", encoding="utf-8") as f:
            hosting = json.load(f)["hosting"]
        matches = [h for h in hosting if h.get("target") == args.headers_from_target]
        if len(matches) != 1:
            sys.exit(f"expected one hosting target {args.headers_from_target!r}")
        headers = [
            {"glob": rule["source"], "headers": {h["key"]: h["value"] for h in rule["headers"]}}
            for rule in matches[0].get("headers", [])
        ]

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
    live_version = releases["releases"][0]["version"]
    live = live_version["name"]
    print(f"live version: {live}")
    config = None
    if headers is not None:
        config = dict(live_version.get("config", {}))
        live_globs = sorted(h["glob"] for h in config.get("headers", []))
        new_globs = sorted(h["glob"] for h in headers)
        # Same rule sources on both sides, so a header set is replaced, never
        # dropped or added somewhere the live site did not have one.
        if live_globs != new_globs:
            sys.exit(f"header globs differ: live {live_globs}, firebase.json {new_globs}")
        config["headers"] = headers
        for rule in headers:
            old = next(h for h in live_version["config"]["headers"] if h["glob"] == rule["glob"])
            for key in sorted(set(old["headers"]) | set(rule["headers"])):
                if old["headers"].get(key) != rule["headers"].get(key):
                    print(f"header {rule['glob']} {key}:\n  - {old['headers'].get(key)}\n  + {rule['headers'].get(key)}")
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

    if config is not None:
        call(token, "PATCH", f"{API}/{version}?update_mask=config", {"config": config})
        print("replaced headers")

    if files:
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
