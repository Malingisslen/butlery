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
    stamp(root, [rel_path(file_path, root)])


def stamp(root, rels):
    """Add every rel the map references to the marker; returns the ones added."""
    tokens = map_tokens(root)
    # anti-loop: edits to the map, the marker, or this machinery never stamp
    hits = [r for r in rels
            if r and r not in (MAP_REL, MARKER_REL) and not r.startswith(".claude/")
            and any(matches(r, tok) for tok in tokens)]
    if not hits:
        return []

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
    for rel in hits:
        if rel not in data["triggers"]:
            data["triggers"].append(rel)
    data["last_stamped"] = today
    with open(marker, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    return hits


def git_lines(root, *args):
    import subprocess
    out = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True, check=True).stdout
    return [line.strip() for line in out.splitlines() if line.strip()]


def staged():
    """Pre-commit mode: the edit hook above sees only edits made with Claude's Edit/Write,
    so a file a script or a codemod changed never stamps the map. At commit time every
    changed file is staged, however it was changed. A commit that stages the map itself
    is the re-trace, so it stamps nothing."""
    root = git_lines(os.getcwd(), "rev-parse", "--show-toplevel")[0]
    files = git_lines(root, "diff", "--cached", "--name-only", "--diff-filter=ACMRD")
    if MAP_REL in files:
        return []
    hits = stamp(root, files)
    if hits:
        print(f"workflow-map: {len(hits)} staged file(s) are in the map; marked {MARKER_REL} for a re-trace.")
    return hits


def self_test():
    import shutil
    import subprocess
    import tempfile
    tmp = tempfile.mkdtemp()
    try:
        run = lambda *a: subprocess.run(["git", *a], cwd=tmp, capture_output=True, check=True)
        run("init", "-q")
        os.makedirs(os.path.join(tmp, "docs", "onboarding"))
        os.makedirs(os.path.join(tmp, "lib", "views"))
        data = {"nodes": [{"path": "lib/views/mapped_view.dart:10-20"}]}
        with open(os.path.join(tmp, MAP_REL), "w", encoding="utf-8") as f:
            f.write('<script id="data" type="application/json">' + json.dumps(data) + "</script>")
        for name in ("mapped_view.dart", "other_view.dart"):
            open(os.path.join(tmp, "lib", "views", name), "w").write("x")
        marker = os.path.join(tmp, MARKER_REL)
        cwd = os.getcwd()
        os.chdir(tmp)
        try:
            run("add", "--", "lib/views/other_view.dart")
            assert staged() == [] and not os.path.exists(marker), "an unmapped file stamped the map"
            run("add", "--", "lib/views/mapped_view.dart")
            assert staged() == ["lib/views/mapped_view.dart"] and os.path.exists(marker), "a mapped file did not stamp"
            os.remove(marker)
            run("add", "--", MAP_REL)
            assert staged() == [] and not os.path.exists(marker), "a commit carrying the map stamped it"
        finally:
            os.chdir(cwd)
        print("map_stamp --self-test: 3 cases passed")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()  # fails loudly: a test must not pass by swallowing its own error
        sys.exit(0)
    try:
        staged() if "--staged" in sys.argv else main()
    except Exception:
        pass  # fail open — never disrupt a Write/Edit
