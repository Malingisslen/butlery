"""Dossier-freshness stamper (PostToolUse Write|Edit helper).

Reads the hook stdin JSON, resolves the edited file to a repo-relative path,
matches it against each role's owned globs in docs/org/role-paths.json, and for
every matching role writes/updates a stale marker under
docs/org/dossier-staleness/<slug>.stale (committed JSON).

The /refresh-dossiers skill reads those markers, re-audits only the stale roles,
and clears them. Stamping is intentionally cheap and fails open — any problem
just means no stamp this edit (the next edit, or a manual refresh, recovers).

Invoked by .claude/hooks/dossier-freshness-stamp.sh. Stdin = raw hook JSON.
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


def repo_root(cwd):
    # Prefer the env the harness sets, then the JSON cwd, then walk up for .git.
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


def slug(role):
    s = role.lower()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


def main():
    raw = sys.stdin.read()
    if not raw.strip():
        return
    file_path = extract_field(raw, "tool_input.file_path") or extract_field(raw, "tool_response.filePath")
    if not file_path:
        return
    cwd = extract_field(raw, "cwd")
    root = repo_root(cwd)

    map_file = os.path.join(root, "docs", "org", "role-paths.json")
    if not os.path.isfile(map_file):
        return
    rel = rel_path(file_path, root)
    if not rel or rel.startswith(".git/"):
        return
    # Don't stamp on edits to the freshness machinery or the dossier docs
    # themselves — only on edits to the code/assets a role owns. (Otherwise
    # /refresh-dossiers editing the map would re-stamp roles in a loop.)
    if (rel.startswith("docs/org/dossier-staleness/")
            or rel.endswith("role-paths.json")
            or rel in ("docs/architecture/ROLE_RESPONSIBILITY_MAP.md",
                       "docs/architecture/ROLE_ORG_DESIGN.md")):
        return

    try:
        roles = json.load(open(map_file, encoding="utf-8")).get("roles", {})
    except Exception:
        return

    matched = []
    for role, globs in roles.items():
        for g in globs:
            if fnmatch.fnmatch(rel, g) or (g.endswith("/**") and rel == g[:-3]):
                matched.append(role)
                break
    if not matched:
        return

    stale_dir = os.path.join(root, "docs", "org", "dossier-staleness")
    os.makedirs(stale_dir, exist_ok=True)
    today = datetime.date.today().isoformat()

    for role in matched:
        marker = os.path.join(stale_dir, slug(role) + ".stale")
        data = {"role": role, "stale_since": today, "triggers": []}
        if os.path.isfile(marker):
            try:
                data = json.load(open(marker, encoding="utf-8"))
                data.setdefault("role", role)
                data.setdefault("stale_since", today)
                data.setdefault("triggers", [])
            except Exception:
                pass
        if rel not in data["triggers"]:
            data["triggers"].append(rel)
        data["last_stamped"] = today
        try:
            with open(marker, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.write("\n")
        except Exception:
            continue


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # fail open — never disrupt a Write/Edit
