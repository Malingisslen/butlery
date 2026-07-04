#!/usr/bin/env python3
"""cost_per_accepted_change.py — the metric the loops literature says nobody tracks.

Autonomy is only paying off if the work it ships *survives*. This computes an
"accept rate" proxy from git history alone — NO LLM, per CLAUDE.md cost rules
(a git-log diff beats an agent for "what changed").

Definition (deliberately conservative, explainable):
  - A **candidate** commit is one authored/co-authored by Claude (the autonomous
    loop) in the window — matched on the Co-Authored-By trailer or author name.
  - A candidate is **reworked** if a LATER commit within REWORK_DAYS whose subject
    looks corrective (revert|fix|hotfix|bug|broke|regress|redo|undo) touches any of
    the same files. Reworked ≈ the shipped change didn't hold as-is.
  - **accept_rate = 1 - reworked/candidates.** The loops rule of thumb: below ~50%
    accept, the loop costs more review than it saves.

This is a proxy, not truth (a legitimate follow-up feature can look like a rework;
a silently-wrong change that nobody fixed counts as accepted). It's a *trend* signal
for /org-retro and the janitor, read over time — not a verdict on any single commit.

Usage:
  python tools/cost_per_accepted_change.py [--days N] [--rework-days N] [--json]
"""
import argparse
import io
import json
import re
import subprocess
import sys

# Windows console defaults to cp1252 and chokes on the arrow glyph; force UTF-8.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

CORRECTIVE = re.compile(r"\b(revert|fix|hotfix|bug|broke|broken|regress|redo|undo|re-?fix)\b", re.I)
CLAUDE = re.compile(r"claude|anthropic", re.I)


def git(args):
    return subprocess.run(["git"] + args, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout


def commits_since(days):
    # sha \x1f subject \x1f author \x1f body(trailers), commits separated by \x1e
    fmt = "%H\x1f%s\x1f%an\x1f%b\x1e"
    raw = git(["log", f"--since={days} days ago", "--no-merges", f"--pretty=format:{fmt}"])
    out = []
    for rec in raw.split("\x1e"):
        rec = rec.strip("\n")
        if not rec.strip():
            continue
        parts = rec.split("\x1f")
        if len(parts) < 4:
            continue
        sha, subject, author, body = parts[0], parts[1], parts[2], parts[3]
        out.append({"sha": sha, "subject": subject, "author": author, "body": body})
    return out  # newest first


def files_of(sha):
    raw = git(["show", "--name-only", "--pretty=format:", sha])
    return {f for f in raw.splitlines() if f.strip()}


def ts_of(sha):
    v = git(["show", "-s", "--pretty=format:%ct", sha]).strip()
    return int(v) if v.isdigit() else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=30, help="window of candidate commits")
    ap.add_argument("--rework-days", type=int, default=7, help="how long after a commit a rework counts")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    commits = commits_since(a.days)
    if not commits:
        print(json.dumps({"error": "no commits in window"}) if a.json else "No commits in window.")
        return

    # Enrich with timestamp + files once.
    for c in commits:
        c["ts"] = ts_of(c["sha"])
        c["files"] = files_of(c["sha"])
        c["claude"] = bool(CLAUDE.search(c["author"]) or CLAUDE.search(c["body"]))
        c["corrective"] = bool(CORRECTIVE.search(c["subject"]))

    candidates = [c for c in commits if c["claude"]]
    correctives = [c for c in commits if c["corrective"]]
    rework_secs = a.rework_days * 86400

    reworked = []
    for cand in candidates:
        for corr in correctives:
            if corr["sha"] == cand["sha"]:
                continue
            # corrective must come AFTER the candidate, within the window
            if corr["ts"] <= cand["ts"] or corr["ts"] - cand["ts"] > rework_secs:
                continue
            overlap = cand["files"] & corr["files"]
            # ignore pure-scratch/doc overlaps — only count real code churn
            code_overlap = {f for f in overlap if f.startswith(("lib/", "functions/src/"))}
            if code_overlap:
                reworked.append({"commit": cand["sha"][:9], "subject": cand["subject"][:60],
                                 "reworked_by": corr["sha"][:9], "files": sorted(code_overlap)[:5]})
                break

    n = len(candidates)
    r = len(reworked)
    accept = round(1 - r / n, 3) if n else None

    result = {
        "window_days": a.days,
        "rework_days": a.rework_days,
        "autonomous_commits": n,
        "reworked": r,
        "accept_rate": accept,
        "reworked_detail": reworked,
        "verdict": ("healthy" if (accept or 0) >= 0.5 else "below-50%-review-the-loop") if n else "no-data",
    }

    if a.json:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(f"Cost-per-accepted-change ({a.days}d window, {a.rework_days}d rework horizon)")
        print(f"  autonomous commits: {n}")
        print(f"  reworked:           {r}")
        print(f"  accept rate:        {accept if accept is not None else 'n/a'}  → {result['verdict']}")
        if reworked:
            print("  reworked commits:")
            for rw in reworked:
                print(f"    {rw['commit']} {rw['subject']}  (by {rw['reworked_by']})")


if __name__ == "__main__":
    main()
