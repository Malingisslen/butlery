#!/usr/bin/env python3
"""Turn the last day's `ai_cap_signal` log lines into koll decisions.

The morning koll runs this (step BU4 in its SKILL.md) and upserts what it
writes; tasks/ai-cap-signal-plan.md is the design. Deterministic: one
`gcloud logging read` per query, no Firestore reads, no LLM.

    python tools/ai_cap_report.py --project <id> --koll-out <file.json>
    python tools/ai_cap_report.py --self-test

Exit 0 with an empty list is a calm day. Exit 2 means a read failed: the
morning koll must report that as a blind spot, never as calm.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections import defaultdict

REPO = "C:\\Butlery\\butlery"
SIGNAL = "ai_cap_signal"
COST_DENIED = "llm_cost_ceiling_denied"

# cap -> (stable id, system/config field or None, Swedish name, stakes reached, stakes near)
CAPS = {
    "global_day": ("butlery-ai-tak-global-dag", "globalDailyLimit",
                   "AI-taket per dygn för alla användare", 4, 3),
    "global_hour": ("butlery-ai-tak-global-timme", "globalHourlyLimit",
                    "AI-taket per timme för alla användare", 3, 2),
    "guest_day": ("butlery-ai-tak-gast-dag", "guestDailyImportLimit",
                  "taket för gästimporter per dygn", 3, 2),
}
PER_USER_ID = "butlery-ai-tak-per-anvandare"


def read_logs(project: str, message: str, freshness: str) -> list[dict]:
    cmd = [
        "gcloud", "logging", "read",
        f'jsonPayload.message="{message}"',
        f"--project={project}", f"--freshness={freshness}",
        "--limit=2000", "--format=json",
    ]
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                         shell=sys.platform == "win32")
    if out.returncode != 0:
        raise RuntimeError(out.stderr.strip() or f"gcloud exited {out.returncode}")
    return json.loads(out.stdout or "[]")


def summarise(signals: list[dict], denials: list[dict]) -> dict:
    """Worst level per shared cap, deduplicated per UTC day, plus per-user counts."""
    shared: dict[str, dict] = {}
    users_reached: dict[str, set] = defaultdict(set)
    users_near: dict[str, set] = defaultdict(set)
    for entry in signals:
        p = entry.get("jsonPayload", {})
        cap, level = p.get("cap"), p.get("level")
        day = str(entry.get("timestamp", ""))[:10]
        if cap in CAPS:
            cur = shared.get(cap)
            rank = 2 if level == "reached" else 1
            if cur is None or rank > cur["rank"]:
                shared[cap] = {"rank": rank, "level": level, "limit": p.get("limit"),
                               "days": set()}
            shared[cap]["days"].add((day, level))
        elif cap == "user_day":
            who = p.get("userIdHash") or "?"
            op = p.get("operationType") or "?"
            (users_reached if level == "reached" else users_near)[op].add(who)
    cost_users = {(e.get("jsonPayload", {}).get("uidHash") or "?") for e in denials}
    return {"shared": shared, "users_reached": users_reached,
            "users_near": users_near, "cost_users": cost_users}


def shared_decision(cap: str, info: dict) -> dict:
    ident, field, name, stakes_reached, stakes_near = CAPS[cap]
    limit = info["limit"]
    suggested = int(limit) * 2 if isinstance(limit, (int, float)) else None
    reached = info["level"] == "reached"
    days = sorted({d for d, _ in info["days"]})
    when = "igår" if len(days) <= 1 else f"{len(days)} dagar"
    if reached:
        title = f"Butlery: {name} nåddes {when}"
        why = (f"Taket ligger på {limit}. När det nås får användarna beskedet att "
               "systemets kapacitetsgräns är nådd tills perioden är slut. Det är "
               "dags att höja om användningen är äkta.")
    else:
        title = f"Butlery: {name} var nära ({when})"
        why = (f"Minst 80 % av taket på {limit} användes. Ingen stoppades, men "
               "fortsätter det växa slår användarna snart i taket.")
    raise_prompt = (
        f"Butlery: {name} ({field} i system/config) är {limit} och "
        f"{'nåddes' if reached else 'var nära'} senaste dygnet enligt morgonkollens "
        f"ai_cap_signal. Läs system/config och system/llmLimits (eller "
        f"system/guestImportLimits) i prod, kontrollera i loggarna att trafiken är "
        f"äkta användning och inte ett enskilt konto, och höj {field} till "
        f"{suggested if suggested else 'ett dubblat värde'}. Läs tillbaka värdet och "
        "säg till att det gäller först när funktionernas instanser startat om "
        "(inom ungefär en timme)."
    )
    look_prompt = (
        f"Butlery: {name} ({field}) {'nåddes' if reached else 'var nära'} senaste "
        "dygnet. Ta reda på vilka anrop som drev det (operationType, tid på dygnet, "
        "om ett fåtal konton står för det mesta) och rapportera utan att ändra något."
    )
    return {
        "id": ident, "source": "morgonkoll", "product": "Butlery",
        "stakes": stakes_reached if reached else stakes_near,
        "title": title, "why": why,
        "routes": [
            {"name": f"Höj till {suggested}" if suggested else "Höj taket",
             "recommended": reached,
             "note": "användare stoppas annars igen nästa gång trafiken är lika hög.",
             "repo": REPO, "prompt": raise_prompt},
            {"name": "Titta först vad som drev det",
             "recommended": not reached,
             "note": "ett nära-tak kan vara en enstaka topp; billigt att kolla innan du höjer.",
             "repo": REPO, "prompt": look_prompt},
            {"name": "Låt ligga",
             "note": ("taket stoppar fortsatt anrop när det nås, och kostnaden hålls nere."
                      if reached else "ingenting går sönder; kortet kommer tillbaka om det händer igen.")},
        ],
    }


def per_user_decision(summary: dict) -> dict | None:
    reached = summary["users_reached"]
    cost = summary["cost_users"]
    if not reached and not cost:
        return None
    parts = [f"{len(v)} användare nådde sitt dagstak för {op}" for op, v in sorted(reached.items())]
    if cost:
        parts.append(f"{len(cost)} användare nådde sitt kostnadstak")
    prompt = (
        "Butlery: morgonkollens ai_cap_signal (user_day) och llm_cost_ceiling_denied "
        f"visar senaste dygnet: {'; '.join(parts)}. Taken per användare ligger i kod "
        "(RATE_LIMIT_CONFIGS.dailyLimit i functions/src/middleware/rate_limiter.ts, "
        "LLM_COST_CEILINGS i functions/src/middleware/llm_cost_ledger.ts). Ta reda på "
        "om det är vanlig användning eller ett konto som missbrukar, och föreslå ett "
        "nytt värde med kostnaden per dygn innan du ändrar något."
    )
    return {
        "id": PER_USER_ID, "source": "morgonkoll", "product": "Butlery", "stakes": 2,
        "title": "Butlery: användare slog i sitt eget AI-tak",
        "why": ("; ".join(parts) + ". Taken per användare skyddar mot att en person "
                "drar hela kostnaden. Höjs bara med en kodändring."),
        "routes": [
            {"name": "Utred och föreslå", "recommended": True,
             "note": "ett fåtal träffar är normalt; många betyder att taket är för lågt.",
             "repo": REPO, "prompt": prompt},
            {"name": "Låt ligga",
             "note": "de som slog i får vänta till nästa dygn; ingenting går sönder."},
        ],
    }


def decisions(summary: dict) -> list[dict]:
    out = [shared_decision(cap, info) for cap, info in sorted(summary["shared"].items())]
    per_user = per_user_decision(summary)
    if per_user:
        out.append(per_user)
    return out


def text_summary(summary: dict) -> str:
    lines = []
    for cap, info in sorted(summary["shared"].items()):
        level = "nått" if info["level"] == "reached" else "nära"
        lines.append(f"{CAPS[cap][2]}: {level} (tak {info['limit']})")
    for op, v in sorted(summary["users_near"].items()):
        lines.append(f"{len(v)} användare nära dagstaket för {op}")
    for op, v in sorted(summary["users_reached"].items()):
        lines.append(f"{len(v)} användare nådde dagstaket för {op}")
    if summary["cost_users"]:
        lines.append(f"{len(summary['cost_users'])} användare nådde kostnadstaket")
    return "\n".join(lines) or "Inga AI-tak nära eller nådda senaste dygnet."


def self_test() -> None:
    def sig(cap, level, limit, ts="2026-10-20T10:00:00Z", **extra):
        return {"timestamp": ts, "jsonPayload": {"message": SIGNAL, "cap": cap,
                "level": level, "limit": limit, "count": limit, **extra}}
    signals = [
        sig("global_hour", "near", 20), sig("global_hour", "reached", 20),
        sig("guest_day", "reached", 5), sig("guest_day", "reached", 5),
        sig("user_day", "reached", 100, operationType="structureRecipe", userIdHash="a"),
        sig("user_day", "reached", 100, operationType="structureRecipe", userIdHash="a"),
        sig("user_day", "near", 50, operationType="ocrRecipeImage", userIdHash="b"),
    ]
    denials = [{"jsonPayload": {"message": COST_DENIED, "uidHash": "c"}}]
    out = decisions(summarise(signals, denials))
    ids = [d["id"] for d in out]
    assert ids == ["butlery-ai-tak-global-timme", "butlery-ai-tak-gast-dag",
                   PER_USER_ID], ids
    hour = out[0]
    assert hour["stakes"] == 3 and "nåddes" in hour["title"], hour
    assert hour["routes"][0]["name"] == "Höj till 40" and hour["routes"][0]["recommended"]
    assert "1 användare nådde sitt dagstak för structureRecipe" in out[2]["why"], out[2]
    assert "1 användare nådde sitt kostnadstak" in out[2]["why"]
    near_only = decisions(summarise([sig("global_day", "near", 100)], []))
    assert near_only[0]["stakes"] == 3 and not near_only[0]["routes"][0]["recommended"]
    assert decisions(summarise([], [])) == []
    assert all(r.get("prompt") is None for d in out for r in d["routes"]
               if r["name"] == "Låt ligga")
    print("self-test ok")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project")
    ap.add_argument("--freshness", default="1d")
    ap.add_argument("--koll-out")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        self_test()
        return 0
    if not args.project:
        ap.error("--project is required")
    try:
        signals = read_logs(args.project, SIGNAL, args.freshness)
        denials = read_logs(args.project, COST_DENIED, args.freshness)
    except (RuntimeError, json.JSONDecodeError) as err:
        print(f"AI-taken: kunde inte hämtas ({err})")
        return 2
    summary = summarise(signals, denials)
    items = decisions(summary)
    print(text_summary(summary))
    print("ids: " + ",".join(d["id"] for d in items))
    if args.koll_out:
        with open(args.koll_out, "w", encoding="utf-8") as fh:
            json.dump(items, fh, ensure_ascii=False, indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
