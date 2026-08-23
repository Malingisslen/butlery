"""Workflow-map freshness stamper (PostToolUse Write|Edit helper).

Reads the hook stdin JSON, resolves the edited file to a repo-relative path,
and checks whether that path is referenced by any node in the workflow map
(docs/onboarding/workflow-map.html, the <script id="data"> JSON). If so, the
map's flow description may have drifted — write/update the committed marker
docs/onboarding/workflow-map.stale listing the trigger paths.

Refresh procedure (any session that sees the marker): re-trace ONLY the flows
whose nodes match the trigger paths, update the map's JSON data block, run
`python3 tools/check_workflow_map.py`, then delete the marker.

Sibling of dossier_stamp.py — same contract: cheap, fails open, never disrupts
a Write/Edit. Invoked by .claude/hooks/map-freshness-stamp.sh.
"""
import datetime
import fnmatch
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
try:
    from parse_hook_json import extract_field
except Exception:
    def extract_field(raw, field):  # minimal fallback
        m = re.search(r'"' + re.escape(field.split(".")[-1]) + r'"\s*:\s*"([^"]*)"', raw)
        return m.group(1) if m else ""

MAP_REL = "docs/onboarding/workflow-map.html"
MARKER_REL = "docs/onboarding/workflow-map.stale"
REPO_ROOTS = ("lib/", "functions/", "test/", "tools/")


def repo_root(cwd):
    root = os.environ.get("CLAUDE_PROJECT_DIR") or cwd or os.getcwd()
    root = root.replace("\\", "/")
    probe = root
    for _ in range(8):
        if os.path.isdir(os.path.join(probe, ".git")):
            return probe
        parent = os.path.dirname(probe)
        if parent == probe:
            break
        probe = parent
    return root


def drive_norm(p):
    p = p.replace("\\", "/")
    m = re.match(r"^/([a-zA-Z])/(.*)", p) or re.match(r"^([a-zA-Z]):/(.*)", p)
    if m:
        return m.group(1).upper() + ":/" + m.group(2)
    return p


def rel_path(file_path, root):
    fp = drive_norm(file_path)
    r = drive_norm(root).rstrip("/")
    if fp.startswith(r + "/"):
        return fp[len(r) + 1:]
    return fp.lstrip("/")


def map_tokens(root):
    """All checkable path tokens from the map's nodes[].path fields."""
    map_file = os.path.join(root, MAP_REL)
    if not os.path.isfile(map_file):
        return []
    html = open(map_file, encoding="utf-8").read()
    m = re.search(r'<script id="data" type="application/json">(.*?)</script>', html, re.S)
    if not m:
        return []
    try:
        data = json.loads(m.group(1))
    except Exception:
        return []
    tokens = []
    for node in data.get("nodes", []):
        for raw in node.get("path", "").split(","):
            tok = re.sub(r":\d+(-\d+)?$", "", raw.strip())
            if tok.startswith(REPO_ROOTS):
                tokens.append(tok)
    return tokens


def matches(rel, tok):
    if rel == tok:
        return True
    if "*" in tok and fnmatch.fnmatch(rel, tok):
        return True
    # token names a directory the edited file lives in
    if not tok.endswith((".dart", ".ts", ".js", ".py")) and rel.startswith(tok.rstrip("/") + "/"):
        return True
    return False


def main():
    # Dispatcher fast path — post-edit-dispatch.sh already parsed the payload.
    # `root` stays self-derived either way: inheriting the dispatcher's idea of the
    # repo root could land the marker somewhere else than rel_path() assumes.
    if os.environ.get("BUTLERY_HOOK_DISPATCH") == "1":
        file_path = os.environ.get("BUTLERY_HOOK_FILE", "")
        cwd = os.environ.get("BUTLERY_HOOK_CWD", "")
    else:
        raw = sys.stdin.read()
        if not raw.strip():
            return
        file_path = extract_field(raw, "tool_input.file_path") or extract_field(raw, "tool_response.filePath")
        cwd = extract_field(raw, "cwd")
    if not file_path:
        return
    root = repo_root(cwd)
    rel = rel_path(file_path, root)
    # anti-loop: edits to the map, the marker, or this machinery never stamp
    if not rel or rel in (MAP_REL, MARKER_REL) or rel.startswith(".claude/"):
        return

    if not any(matches(rel, tok) for tok in map_tokens(root)):
        return

    marker = os.path.join(root, MARKER_REL)
    today = datetime.date.today().isoformat()
    data = {"map": MAP_REL, "stale_since": today, "triggers": []}
    if os.path.isfile(marker):
        try:
            data = json.load(open(marker, encoding="utf-8"))
            data.setdefault("triggers", [])
            data.setdefault("stale_since", today)
        except Exception:
            pass
    if rel not in data["triggers"]:
        data["triggers"].append(rel)
    data["last_stamped"] = today
    with open(marker, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # fail open — never disrupt a Write/Edit
