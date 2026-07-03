"""Workflow-map freshness linter (CI + local).

The interactive workflow map (docs/onboarding/workflow-map.html) is data-driven:
its embedded <script id="data"> JSON lists every component with a repo path, and
every flow step references component ids. This linter keeps the map honest
mechanically:

  1. every node path that looks like a repo path must exist (glob tokens must
     match at least one file) — catches renames/deletions;
  2. every flow step's from/to must reference an existing node id — catches
     JSON edits that break the diagram;
  3. COVERAGE: every feature ID in docs/feature_inventory.csv must be claimed
     by at least one flow's "features" array, and no flow may claim an unknown
     ID — a new feature without a mapped flow fails CI.

Semantic drift (behavior changed inside a still-existing file) is handled by the
map-freshness stamp hook + docs/onboarding/workflow-map.stale, not by this script.

Usage: python3 tools/check_workflow_map.py   (exits 1 with a list of problems)
"""
import glob
import json
import os
import re
import sys

MAP_FILE = "docs/onboarding/workflow-map.html"
# A path token only counts as checkable if it starts with a known source root.
REPO_ROOTS = ("lib/", "functions/", "docs/", "test/", "tools/")


def extract_data_json(html):
    m = re.search(
        r'<script id="data" type="application/json">(.*?)</script>', html, re.S
    )
    if not m:
        raise ValueError("no <script id=\"data\"> block found")
    return json.loads(m.group(1))


def checkable_tokens(path_field):
    """Split a node's path field into repo-path tokens worth checking."""
    tokens = []
    for raw in path_field.split(","):
        tok = raw.strip()
        tok = re.sub(r":\d+(-\d+)?$", "", tok)  # strip :line / :line-line suffix
        if tok.startswith(REPO_ROOTS):
            tokens.append(tok)
    return tokens


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)
    if not os.path.isfile(MAP_FILE):
        print(f"workflow-map linter: {MAP_FILE} missing — skipping")
        return 0

    with open(MAP_FILE, encoding="utf-8") as f:
        data = extract_data_json(f.read())

    problems = []

    node_ids = set()
    for node in data.get("nodes", []):
        node_ids.add(node.get("id", ""))
        for tok in checkable_tokens(node.get("path", "")):
            if "*" in tok:
                if not glob.glob(tok, recursive=True):
                    problems.append(f"node '{node['id']}': glob matches nothing: {tok}")
            elif not os.path.exists(tok):
                problems.append(f"node '{node['id']}': path missing: {tok}")

    for action in data.get("actions", []):
        for i, step in enumerate(action.get("steps", []), 1):
            for end in ("from", "to"):
                if step.get(end) not in node_ids:
                    problems.append(
                        f"flow '{action.get('id')}' step {i}: unknown node id "
                        f"'{step.get(end)}' in '{end}'"
                    )

    # Coverage cross-check against the feature inventory.
    inv_csv = "docs/feature_inventory.csv"
    covered = 0
    if os.path.isfile(inv_csv):
        import csv as _csv

        with open(inv_csv, encoding="utf-8") as f:
            inventory = {row["Feature ID"].strip() for row in _csv.DictReader(f) if row.get("Feature ID")}
        claimed = set()
        for action in data.get("actions", []):
            for fid in action.get("features", []):
                claimed.add(fid)
                if fid not in inventory:
                    problems.append(
                        f"flow '{action.get('id')}': claims unknown feature id '{fid}' "
                        f"(not in {inv_csv})"
                    )
        missing = sorted(inventory - claimed)
        covered = len(inventory & claimed)
        for fid in missing:
            problems.append(f"feature '{fid}' is not covered by any flow (add it to a flow's features)")

    if problems:
        print(f"workflow-map linter: {len(problems)} problem(s) in {MAP_FILE}:")
        for p in problems:
            print(f"  - {p}")
        print(
            "\nFix: update the nodes[].path entries in the map's JSON data block, "
            "or re-trace the affected flow if the architecture moved. "
            "See CLAUDE.md 'Workflow map freshness'."
        )
        return 1

    print(
        f"workflow-map linter: OK — {len(node_ids)} nodes, "
        f"{len(data.get('actions', []))} flows, all referenced paths exist, "
        f"feature coverage {covered}/137"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
