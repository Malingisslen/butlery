#!/usr/bin/env python3
"""Stakeholder router for the Phase-2 deliberation system.

Given a changed fileset (or a flag marking the input as a plan), decide which
role-org stakeholders should review it and at what blast-radius tier. Reuses the
role->path ownership map (docs/org/role-paths.json) built for the freshness loop,
so role selection stays honest to ROLE_RESPONSIBILITY_MAP.md.

Tiers (from docs/architecture/ROLE_ORG_DESIGN.md, "Trigger"):
  - full-panel : a plan, OR any high-stakes path, OR a broad blast radius (>=3 roles).
                 Panel = roles owning the touched paths UNION a fixed high-stakes core.
  - single     : touches 1-2 roles, no high-stakes path -> just those owners.
  - skip       : only trivial/doc paths that no role owns -> no review.

Usage:
  python tools/stakeholder_router.py [--plan] [--json] <path> [<path> ...]
  git diff --name-only main... | python tools/stakeholder_router.py --stdin
"""
import argparse
import fnmatch
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAP = os.path.join(ROOT, "docs", "org", "role-paths.json")

# Veto-level cross-cutting roles always seated on a full panel, even if the
# change doesn't touch a file they "own" — their concerns apply to any
# significant change. Names must match ROLE_RESPONSIBILITY_MAP.md headings.
HIGH_STAKES_CORE = [
    "Security Architect",
    "Privacy / Data Protection Officer (GDPR)",
    "Legal Counsel",
    "Software Architect",
    "Product Manager",
    "Financial Controller / FinOps",
]

# Paths whose change alone forces a full panel (auth, on-device/LLM, GDPR
# cascade, rules, payments). Mirrors the DESIGN.md "high-stakes paths" list.
HIGH_STAKES_PATTERNS = [
    "firestore.rules", "storage.rules",
    "lib/services/auth/**", "lib/services/security/**",
    "lib/services/session_timeout_service.dart",
    "lib/services/device_integrity_service.dart",
    "lib/services/llm/**", "functions/src/llm/**",
    "lib/services/account/**",
    "functions/src/account/**", "functions/src/audit_logs/**",
    "functions/src/cleanup/**",
    "functions/src/__tests__/*-rules.test.ts",
    # Allergen/dietary verdict — Butlery's #1 safety surface (role #10 owns it).
    # A wrong "free-from" verdict is a health risk, so any change to the verdict
    # producers or the TriState safety types convenes the full panel.
    "lib/services/tagging/phases/**",
    "lib/services/tagging/allergen_mismatch.dart",
    "lib/services/tagging/config/allergen_config.dart",
    "lib/services/tagging/config/dietary_config.dart",
    "lib/services/tagging/ingredient_lookup_service.dart",
    "lib/models/tagging/tri_state.dart",
    "lib/models/tagging/tag_result.dart",
    "lib/models/tagging/tag_decision.dart",
    # single-star forms: fnmatch's * crosses '/', so these match the substring
    # anywhere in the path (fnmatch has no true ** recursion).
    "*purchase*", "*billing*", "*monetization*",
    "*subscription*", "*revenuecat*", "*payment*",
]

# A path that no role owns AND looks like docs/assets is "trivial".
# Single-star: fnmatch '*' spans '/', so "*.md" matches both "README.md" and
# "docs/x/y.md" (whereas "**/*.md" would miss the root-level file).
TRIVIAL_PATTERNS = [
    "*.md", "docs/**", "*.txt",
    "*.png", "*.jpg", "*.jpeg", "*.gif", "*.svg", "*.webp",
]


def matches_any(path, patterns):
    for g in patterns:
        if fnmatch.fnmatch(path, g) or (g.endswith("/**") and path == g[:-3]):
            return True
    return False


def load_roles():
    return json.load(open(MAP, encoding="utf-8")).get("roles", {})


def route(paths, is_plan=False):
    roles_map = load_roles()
    matched = {}          # path -> [roles]
    owners = set()
    high_stakes_hits = []
    trivial = []
    for p in paths:
        p = p.replace("\\", "/").strip().lstrip("/")
        if not p:
            continue
        rs = [role for role, globs in roles_map.items() if matches_any(p, globs)]
        matched[p] = rs
        owners.update(rs)
        if matches_any(p, HIGH_STAKES_PATTERNS):
            high_stakes_hits.append(p)
        if not rs and matches_any(p, TRIVIAL_PATTERNS):
            trivial.append(p)

    non_trivial = [p for p in matched if p not in trivial]

    # Route by BLAST RADIUS, not by "is it a plan" — a plan is reviewed at the tier
    # its files warrant, so mid-risk plans get the cheap focused tier instead of
    # always convening the (expensive) full panel. The full panel (owners + the
    # veto-level high-stakes core) is reserved for HIGH-STAKES PATHS only — NOT raw
    # owner-count, since one theme file is co-owned by several design roles and that
    # is not a broad blast radius.
    if high_stakes_hits:
        tier = "full-panel"
    elif owners:
        # "single" = focused review by the direct owner(s) only (1..N), no core.
        tier = "single"
    elif is_plan or non_trivial:
        # a plan, or non-trivial code no role owns -> at least one reviewer
        # (architect + PM decide) rather than silently skipping.
        tier = "single"
    else:
        tier = "skip"

    if tier == "full-panel":
        panel = sorted(set(owners) | set(HIGH_STAKES_CORE))
        core_added = sorted(set(HIGH_STAKES_CORE) - owners)
    elif tier == "single":
        panel = sorted(owners) if owners else ["Software Architect", "Product Manager"]
        core_added = []
    else:
        panel = []
        core_added = []

    return {
        "tier": tier,
        "panel": panel,
        "high_stakes_hits": sorted(set(high_stakes_hits)),
        "trivial_skipped": sorted(trivial),
        "core_added": core_added,
        "matched": matched,
        "is_plan": is_plan,
    }


def main():
    # Role names / paths may contain non-ASCII; force UTF-8 stdout so printing the
    # panel never crashes on a cp1252 Windows console (where stakeholder-review runs).
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--plan", action="store_true", help="treat input as a plan -> full panel")
    ap.add_argument("--stdin", action="store_true", help="read newline-separated paths from stdin")
    ap.add_argument("--json", action="store_true", help="emit raw JSON only")
    args = ap.parse_args()

    paths = list(args.paths)
    if args.stdin:
        paths += [ln for ln in sys.stdin.read().splitlines() if ln.strip()]

    result = route(paths, is_plan=args.plan)
    if args.json:
        print(json.dumps(result, ensure_ascii=False))
        return
    print(f"tier: {result['tier']}")
    if result["high_stakes_hits"]:
        print(f"high-stakes paths: {result['high_stakes_hits']}")
    print(f"panel ({len(result['panel'])}): {result['panel']}")
    if result["core_added"]:
        print(f"  (+high-stakes core seated: {result['core_added']})")
    if result["trivial_skipped"]:
        print(f"trivial/skipped: {result['trivial_skipped']}")


if __name__ == "__main__":
    main()
