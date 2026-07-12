#!/usr/bin/env python3
"""BUT-1239: model-version CI guard.

Fails when a model family's published `latest_version.txt` in Firebase
Storage exceeds the maximum version present in the local hash registry
(`lib/services/parsing/_expected_model_hashes.dart`).

Why this exists: clients refuse to load a model version they have no
SHA-256 hash for (fail-close contract, BUT-877). If someone bumps
`latest_version.txt` in Storage without first landing the matching hash
entry in the registry (and shipping a client that has it), every client
silently falls back to the slower rule-based / LLM parsing tier. This
guard catches that drift early — nightly — instead of in production.

Direction of the check: published > local-max is the failure. Published
== local-max is fine (clients are caught up). Published < local-max is
also fine (registry is ahead of Storage, e.g. a hash landed before the
upload — the intended publish order).

Run locally:
    python3 tools/ci/check_model_versions.py

Requires `gsutil` on PATH and an authenticated gcloud (Application
Default Credentials or an activated service account) with read access to
`gs://butlery-app-1.firebasestorage.app/models/**`.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

BUCKET = "butlery-app-1.firebasestorage.app"

# Maps the registry family (Dart map name suffix) → Storage path segment.
FAMILIES = {
    "ner": "ingredient_ner",
    "line_classifier": "line_classifier",
    "whisper": "whisper_sv",
}

# Registry map names, keyed by the family used in FAMILIES.
REGISTRY_MAPS = {
    "ner": "kExpectedNerModelHashes",
    "line_classifier": "kExpectedLineClassifierModelHashes",
    "whisper": "kExpectedWhisperModelHashes",
}

# Families whose FIRST Storage publish hasn't happened yet: a missing
# latest_version.txt is the expected registry-first state, not drift.
# REMOVE a family from this set the moment its first upload lands —
# for an already-published family a missing pointer is a loud failure
# (deleted object, typo'd path, wrong bucket), never a silent OK.
# (whisper_sv v1 published 2026-07-12 — set is empty until the next new family.)
PREPUBLISH_FAMILIES: set[str] = set()

REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_FILE = REPO_ROOT / "lib" / "services" / "parsing" / "_expected_model_hashes.dart"


class GuardError(Exception):
    """A fatal, user-facing error (missing tool, parse failure, etc.)."""


def parse_local_max_versions(dart_source: str) -> dict[str, int]:
    """Return {family: max_int_key} for each registry map.

    An empty map yields max 0. Raises GuardError if a map is missing
    entirely (a structural change we want to notice loudly).
    """
    result: dict[str, int] = {}
    for family, map_name in REGISTRY_MAPS.items():
        # Match `const Map<int, String> <map_name> = <...>{ ... };`
        # capturing the body between the opening and closing brace.
        body_match = re.search(
            re.escape(map_name) + r"\s*=\s*<[^>]*>\s*\{(.*?)\};",
            dart_source,
            re.DOTALL,
        )
        if body_match is None:
            raise GuardError(
                f"Registry map '{map_name}' not found in {REGISTRY_FILE}. "
                "Did the file structure change?"
            )
        body = body_match.group(1)
        # Int keys are `<digits>:` at the start of an entry (ignoring
        # comments / whitespace). Match a digit run immediately before a colon.
        keys = [int(k) for k in re.findall(r"(?m)^\s*(\d+)\s*:", body)]
        result[family] = max(keys) if keys else 0
    return result


def read_published_version(family_path: str) -> int | None:
    """gsutil cat the family's latest_version.txt and parse the int.

    Strips an optional leading 'v' (handles both `5` and `v5`). Returns
    None when the object doesn't exist yet — a registry that is ahead of
    Storage is the intended publish order (hash lands first), so a family
    awaiting its first upload must not fail the guard.
    """
    uri = f"gs://{BUCKET}/models/{family_path}/latest_version.txt"
    try:
        proc = subprocess.run(
            ["gsutil", "cat", uri],
            capture_output=True,
            text=True,
            timeout=60,
        )
    except FileNotFoundError as exc:
        raise GuardError(
            "gsutil not found on PATH. Install the Google Cloud SDK and "
            "authenticate (gcloud auth login / activate-service-account) "
            "before running this guard locally."
        ) from exc
    except subprocess.TimeoutExpired as exc:
        raise GuardError(f"gsutil cat timed out reading {uri}.") from exc

    if proc.returncode != 0:
        stderr = proc.stderr.strip()
        if "No URLs matched" in stderr or "NotFoundException" in stderr:
            return None
        raise GuardError(
            f"gsutil cat failed for {uri} (exit {proc.returncode}). "
            "Check that the object exists and that gcloud is authenticated "
            f"with read access.\n--- gsutil stderr ---\n{stderr}"
        )

    raw = proc.stdout.strip()
    cleaned = raw[1:] if raw[:1].lower() == "v" else raw
    try:
        return int(cleaned)
    except ValueError as exc:
        raise GuardError(
            f"Could not parse published version from {uri}: got {raw!r}."
        ) from exc


def main() -> int:
    if "--help" in sys.argv or "-h" in sys.argv:
        print(__doc__)
        return 0

    # `--parse-only` validates the Dart-parsing path without touching
    # Storage — used by CI smoke / local sanity checks.
    parse_only = "--parse-only" in sys.argv

    if not REGISTRY_FILE.exists():
        print(f"ERROR: registry file not found: {REGISTRY_FILE}", file=sys.stderr)
        return 1

    try:
        local_max = parse_local_max_versions(REGISTRY_FILE.read_text(encoding="utf-8"))
    except GuardError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if parse_only:
        for family, mx in local_max.items():
            print(f"[parse-only] {family}: local-max = {mx}")
        return 0

    failures: list[str] = []
    try:
        for family, family_path in FAMILIES.items():
            published = read_published_version(family_path)
            local = local_max[family]
            if published is None:
                if family in PREPUBLISH_FAMILIES:
                    print(
                        f"OK: {family} ({family_path}) — awaiting first "
                        f"publish (local registry max={local}; registry-"
                        f"first is the intended order). Remove from "
                        f"PREPUBLISH_FAMILIES once uploaded."
                    )
                    continue
                failures.append(
                    f"{family} ({family_path}): latest_version.txt is "
                    f"MISSING from Storage for an already-published family "
                    f"— clients can no longer discover model versions "
                    f"(deleted object? typo'd path? wrong bucket?)."
                )
                continue
            if published > local:
                failures.append(
                    f"{family} ({family_path}): published latest_version="
                    f"{published} EXCEEDS local registry max={local}. "
                    f"Land the v{published} SHA-256 hash in "
                    f"{REGISTRY_MAPS[family]} (and ship a client that has it) "
                    f"BEFORE bumping latest_version.txt — otherwise clients "
                    f"fail-close and fall back to slower parsing."
                )
            else:
                print(
                    f"OK: {family} ({family_path}) — published={published} "
                    f"<= local registry max={local}"
                )
    except GuardError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if failures:
        print("\nMODEL VERSION GUARD FAILED:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        return 1

    print("\nAll model families are in sync with the local hash registry.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
