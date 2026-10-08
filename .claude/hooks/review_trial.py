#!/usr/bin/env python3
"""Opus-vs-Sonnet trial for the code-reviewer and integration-reviewer gates.

Question it answers: can those two gates run on Sonnet without letting through
changes that Opus stops? It answers it without anyone reading reviews.

  hook     SubagentStop. When a gate finishes, snapshot the diff it reviewed and
           record its verdict. When `sonnet-shadow` finishes, record its verdict
           for the snapshot named in its last message. Fails open: never blocks.
  session-start
           SessionStart. Once a gate has enough snapshots, tells the session to
           run /review-trial and report, so nobody has to remember to.
  pending  Snapshots that still lack a Sonnet verdict (the /review-trial command
           replays these).
  report   Plain-Swedish summary plus the verdict of the rule fixed up front.

Opus stays the gate throughout. The shadow never opens a gate, because the
ledger records verdicts per agent name and `sonnet-shadow` is not a gate name.

State lives in .claude/state/review-trial/ (gitignored, per machine).
"""
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

GATES = ("code-reviewer", "integration-reviewer")
SHADOW = "sonnet-shadow"
MIN_PAIRS = 20
MIN_OPUS_FAILS = 5
HARD_CAP = 60
MAX_FILES = 40
CLAIM_SECONDS = 6 * 3600
MAX_FILE_BYTES = 300_000
VERDICT_RE = re.compile(r"REVIEW-VERDICT:\s*(pass|fail)\s*\((\d+)\s*blocking\)", re.I)
SNAPSHOT_RE = re.compile(r"TRIAL-SNAPSHOT:\s*([\w.-]+)")


def state_dir(root: Path) -> Path:
    return root / ".claude" / "state" / "review-trial"


def parse_verdict(text: str):
    matches = VERDICT_RE.findall(text or "")
    if not matches:
        return None
    word, n = matches[-1]
    blocking = int(n)
    # Same reading as the gate: a "pass" that reports blocking findings is a fail.
    return ("fail" if word.lower() == "fail" or blocking > 0 else "pass"), blocking


def git(root: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=root, capture_output=True,
                          text=True, encoding="utf-8", errors="replace").stdout


def read_log(root: Path):
    log = state_dir(root) / "log.jsonl"
    if not log.exists():
        return []
    rows = []
    for line in log.read_text(encoding="utf-8").splitlines():
        try:
            rows.append(json.loads(line))
        except ValueError:
            continue
    return rows


def append_log(root: Path, row: dict) -> None:
    d = state_dir(root)
    d.mkdir(parents=True, exist_ok=True)
    with (d / "log.jsonl").open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")


def capture_done(rows, gate: str) -> bool:
    gate_rows = [r for r in rows if r.get("kind") == "gate" and r.get("gate") == gate]
    fails = sum(1 for r in gate_rows if r["verdict"] == "fail")
    if len(gate_rows) >= HARD_CAP:
        return True
    return len(gate_rows) >= MIN_PAIRS and fails >= MIN_OPUS_FAILS


def capture(root: Path, gate: str, verdict, blocking: int) -> str | None:
    rows = read_log(root)
    if capture_done(rows, gate):
        return None
    # Commit gates review the staged diff; fall back to the working tree for
    # reviews run straight after an edit.
    mode = ["--cached"] if git(root, "diff", "--cached", "--name-only").strip() else ["HEAD"]
    patch = git(root, "diff", *mode)
    if not patch.strip():
        return None
    digest = hashlib.sha256(patch.encode("utf-8")).hexdigest()[:12]
    if any(r.get("gate") == gate and r.get("patch") == digest for r in rows):
        return None
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    snap_id = f"{gate}-{stamp}-{digest}"
    snap = state_dir(root) / "snapshots" / snap_id
    (snap / "tree").mkdir(parents=True, exist_ok=True)
    (snap / "patch.diff").write_text(patch, encoding="utf-8")
    copied = 0
    for name in git(root, "diff", *mode, "--name-only").splitlines():
        src = root / name
        if copied >= MAX_FILES or not src.is_file() or src.stat().st_size > MAX_FILE_BYTES:
            continue
        dst = snap / "tree" / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        copied += 1
    meta = {"id": snap_id, "gate": gate, "opus_verdict": verdict, "opus_blocking": blocking,
            "files": copied, "created": stamp}
    (snap / "meta.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")
    append_log(root, {"kind": "gate", "id": snap_id, "gate": gate, "patch": digest,
                      "verdict": verdict, "blocking": blocking, "ts": stamp})
    return snap_id


def handle_hook(root: Path, payload: dict) -> None:
    agent = (payload.get("agent_type") or "").split(":")[-1]
    text = payload.get("last_assistant_message") or ""
    parsed = parse_verdict(text)
    if not parsed:
        return
    verdict, blocking = parsed
    if agent in GATES:
        capture(root, agent, verdict, blocking)
    elif agent == SHADOW:
        m = SNAPSHOT_RE.search(text)
        if m and (state_dir(root) / "snapshots" / m.group(1)).is_dir():
            append_log(root, {"kind": "shadow", "id": m.group(1), "verdict": verdict,
                              "blocking": blocking,
                              "ts": datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")})


def pairs(rows):
    shadows = {}
    for r in rows:
        if r.get("kind") == "shadow":
            shadows[r["id"]] = r  # the latest replay wins
    return [(r, shadows.get(r["id"])) for r in rows if r.get("kind") == "gate"]


def pending(root: Path) -> list[str]:
    return [g["id"] for g, s in pairs(read_log(root)) if s is None
            and (state_dir(root) / "snapshots" / g["id"]).is_dir()]


def ready_to_replay(root: Path) -> bool:
    rows = read_log(root)
    waiting = {g["gate"] for g, s in pairs(rows) if s is None}
    return any(capture_done(rows, gate) for gate in waiting)


def session_start(root: Path) -> str | None:
    if not ready_to_replay(root):
        return None
    # Parallel sessions all start this hook; only one per window runs the replay.
    claim = state_dir(root) / "replay-claimed"
    now = datetime.now(timezone.utc).timestamp()
    if claim.exists() and now - claim.stat().st_mtime < CLAIM_SECONDS:
        return None
    claim.write_text(str(now), encoding="utf-8")
    return json.dumps({"hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": (
            "REVIEW TRIAL READY: enough gate reviews are stored to compare Opus with "
            "Sonnet. Run /review-trial now, in the background, without waiting for "
            "Malin, and give her its result in two or three Swedish sentences as soon "
            "as it is done.")}})


def report(root: Path) -> str:
    rows = read_log(root)
    out = ["Granskningsprovet: Sonnet jämfört med Opus på samma ändringar", ""]
    for gate in GATES:
        done = [(g, s) for g, s in pairs(rows) if g["gate"] == gate and s is not None]
        waiting = sum(1 for g, s in pairs(rows) if g["gate"] == gate and s is None)
        opus_fails = [(g, s) for g, s in done if g["verdict"] == "fail"]
        missed = [g["id"] for g, s in opus_fails if s["verdict"] == "pass"]
        weaker = sum(1 for g, s in opus_fails if s["verdict"] == "fail" and s["blocking"] < g["blocking"])
        stricter = sum(1 for g, s in done if g["verdict"] == "pass" and s["verdict"] == "fail")
        same = sum(1 for g, s in done if g["verdict"] == s["verdict"])
        out.append(f"{gate}:")
        out.append(f"  Jämförda ändringar: {len(done)} (väntar på Sonnet: {waiting})")
        out.append(f"  Samma utslag: {same} av {len(done)}")
        out.append(f"  Opus stoppade: {len(opus_fails)}, varav Sonnet släppte igenom: {len(missed)}")
        out.append(f"  Båda stoppade men Sonnet hittade färre blockerande fel: {weaker}")
        out.append(f"  Sonnet stoppade där Opus släppte igenom: {stricter}")
        if len(done) < MIN_PAIRS or len(opus_fails) < MIN_OPUS_FAILS:
            out.append(f"  Utslag: för tidigt. Regeln kräver minst {MIN_PAIRS} jämförelser "
                       f"varav minst {MIN_OPUS_FAILS} där Opus stoppade.")
        elif missed:
            out.append("  Utslag: behåll Opus. Sonnet släppte igenom ändringar som Opus stoppade "
                       f"({', '.join(missed)}).")
        else:
            out.append("  Utslag: byt till Sonnet. Den släppte inte igenom något som Opus stoppade.")
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def self_test() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        git(root, "init", "-q")
        git(root, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q",
            "--allow-empty", "-m", "base")
        (root / "a.dart").write_text("void main() {}\n", encoding="utf-8")
        git(root, "add", "a.dart")
        assert parse_verdict("x\nREVIEW-VERDICT: pass (2 blocking)") == ("fail", 2)
        assert parse_verdict("no verdict") is None
        handle_hook(root, {"agent_type": "code-reviewer",
                           "last_assistant_message": "REVIEW-VERDICT: fail (1 blocking)"})
        handle_hook(root, {"agent_type": "code-reviewer",
                           "last_assistant_message": "REVIEW-VERDICT: fail (1 blocking)"})
        ids = pending(root)
        assert len(ids) == 1, f"same bytes must be captured once, got {ids}"
        snap = state_dir(root) / "snapshots" / ids[0]
        assert (snap / "tree" / "a.dart").is_file() and (snap / "patch.diff").is_file()
        handle_hook(root, {"agent_type": "sonnet-shadow", "last_assistant_message":
                           "TRIAL-SNAPSHOT: does-not-exist\nREVIEW-VERDICT: pass (0 blocking)"})
        assert pending(root) == ids, "a shadow naming an unknown snapshot is ignored"
        handle_hook(root, {"agent_type": "sonnet-shadow", "last_assistant_message":
                           f"TRIAL-SNAPSHOT: {ids[0]}\nREVIEW-VERDICT: pass (0 blocking)"})
        assert pending(root) == []
        text = report(root)
        assert "varav Sonnet släppte igenom: 1" in text and "för tidigt" in text, text
        rows = [{"kind": "gate", "gate": "code-reviewer", "verdict": "pass"}] * MIN_PAIRS
        assert not capture_done(rows, "code-reviewer"), "needs Opus fails, not just volume"
        rows += [{"kind": "gate", "gate": "code-reviewer", "verdict": "fail"}] * MIN_OPUS_FAILS
        assert capture_done(rows, "code-reviewer")
        assert session_start(root) is None, "one stored review is not enough to replay"
        log = state_dir(root) / "log.jsonl"
        with log.open("a", encoding="utf-8") as f:
            for i in range(MIN_PAIRS):
                f.write(json.dumps({"kind": "gate", "id": f"x{i}", "gate": "code-reviewer",
                                    "verdict": "fail" if i < MIN_OPUS_FAILS else "pass",
                                    "blocking": 1}) + "\n")
        assert "/review-trial" in (session_start(root) or ""), "ready trial must announce"
        assert session_start(root) is None, "a second session in the window stays quiet"
    print("review_trial self-test: ok")
    return 0


def main() -> int:
    root = Path(git(Path.cwd(), "rev-parse", "--show-toplevel").strip() or ".")
    cmd = sys.argv[1] if len(sys.argv) > 1 else "hook"
    if cmd == "--self-test":
        return self_test()
    if cmd == "session-start":
        try:
            out = session_start(root)
        except Exception:  # never disturb a session start
            out = None
        if out:
            print(out)
        return 0
    if cmd == "pending":
        print("\n".join(pending(root)))
        return 0
    if cmd == "report":
        sys.stdout.reconfigure(encoding="utf-8")
        print(report(root), end="")
        return 0
    try:
        handle_hook(root, json.loads(sys.stdin.read() or "{}"))
    except Exception:  # a measurement must never disturb the session it measures
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
