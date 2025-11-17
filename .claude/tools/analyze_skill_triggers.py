#!/usr/bin/env python3
"""
Skill Trigger Analysis Tool
Analyzes prompt logs to identify false positives, collisions, and unused skills
"""

import json
import os
from pathlib import Path
from collections import defaultdict, Counter
from datetime import datetime
from typing import Dict, List, Set, Tuple

# Configuration
LOG_DIR = Path(".claude/cache/prompt-logs")
OUTPUT_DIR = Path(".claude/analysis")
TIMESTAMP = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
REPORT_FILE = OUTPUT_DIR / f"skill_trigger_analysis_{TIMESTAMP}.md"

# All known skills
ALL_SKILLS = [
    "butlery-architecture",
    "code-deduplication-utilities",
    "dependency-injection-patterns",
    "firebase-repository-patterns",
    "flutter-widget-guidelines",
    "gdpr-compliance",
    "navigation-routing",
    "offline-first-patterns",
    "performance-optimization",
    "realtime-collaboration",
    "skill-developer",
    "state-management-patterns",
    "testing-patterns",
]

# Generic keywords that may cause false positives
GENERIC_KEYWORDS = {
    "test", "check", "data", "save", "remove", "show", "display",
    "loading", "ensure", "verify", "investigate", "fetch", "retrieve",
    "create", "update", "delete", "get", "set", "add", "list",
    "service", "repository",
}


def load_all_logs() -> List[Dict]:
    """Load all JSONL log files"""
    logs = []
    log_files = list(LOG_DIR.glob("*.jsonl"))

    if not log_files:
        print(f"Error: No .jsonl files found in {LOG_DIR}")
        return []

    print(f"Found {len(log_files)} log file(s)")

    for log_file in log_files:
        try:
            with open(log_file, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line:
                        try:
                            logs.append(json.loads(line))
                        except json.JSONDecodeError as e:
                            print(f"Warning: Skipping invalid JSON in {log_file.name}: {e}")
        except Exception as e:
            print(f"Warning: Error reading {log_file.name}: {e}")

    return logs


def analyze_skill_activations(logs: List[Dict]) -> Counter:
    """Count activations per skill"""
    skill_counts = Counter()

    for log_entry in logs:
        activated_skills = log_entry.get("activatedSkills", [])
        for skill in activated_skills:
            skill_name = skill.get("skillName")
            if skill_name:
                skill_counts[skill_name] += 1

    return skill_counts


def detect_keyword_collisions(logs: List[Dict]) -> Dict[str, Set[str]]:
    """Detect keywords that appear in multiple skills"""
    keyword_to_skills = defaultdict(set)

    for log_entry in logs:
        activated_skills = log_entry.get("activatedSkills", [])
        for skill in activated_skills:
            skill_name = skill.get("skillName", "")
            match_reasons = skill.get("matchReason", [])

            for reason in match_reasons:
                if isinstance(reason, dict):
                    pattern = reason.get("pattern")
                    if pattern:
                        keyword_to_skills[pattern].add(skill_name)

    # Filter to only collisions (keywords in 2+ skills)
    collisions = {k: v for k, v in keyword_to_skills.items() if len(v) > 1}
    return collisions


def identify_generic_keywords(logs: List[Dict]) -> List[Tuple[str, str, int, str]]:
    """Identify single-word generic keywords"""
    keyword_data = defaultdict(lambda: {"skill": None, "count": 0})

    for log_entry in logs:
        activated_skills = log_entry.get("activatedSkills", [])
        for skill in activated_skills:
            skill_name = skill.get("skillName", "")
            match_reasons = skill.get("matchReason", [])

            for reason in match_reasons:
                if isinstance(reason, dict) and reason.get("type") == "keyword":
                    pattern = reason.get("pattern", "")
                    # Single-word keywords (no spaces)
                    if pattern and " " not in pattern:
                        key = (pattern, skill_name)
                        if keyword_data[key]["skill"] is None:
                            keyword_data[key]["skill"] = skill_name
                        keyword_data[key]["count"] += 1

    # Convert to list and determine risk level
    results = []
    for (keyword, skill), data in keyword_data.items():
        risk = "HIGH" if keyword.lower() in GENERIC_KEYWORDS else "LOW"
        results.append((keyword, skill, data["count"], risk))

    # Sort by risk (HIGH first) then by count
    results.sort(key=lambda x: (x[3] != "HIGH", -x[2]))
    return results


def find_unused_skills(logs: List[Dict]) -> List[str]:
    """Find skills that never activated"""
    activated_skills = set()

    for log_entry in logs:
        for skill in log_entry.get("activatedSkills", []):
            skill_name = skill.get("skillName")
            if skill_name:
                activated_skills.add(skill_name)

    return [skill for skill in ALL_SKILLS if skill not in activated_skills]


def find_over_triggering_prompts(logs: List[Dict]) -> List[Dict]:
    """Find prompts that triggered 3+ skills"""
    over_triggers = []

    for log_entry in logs:
        activated_skills = log_entry.get("activatedSkills", [])
        if len(activated_skills) >= 3:
            over_triggers.append({
                "prompt": log_entry.get("prompt", {}).get("text", "N/A"),
                "skills": [s.get("skillName") for s in activated_skills],
                "count": len(activated_skills),
            })

    return over_triggers


def find_false_positive_candidates(logs: List[Dict], limit: int = 20) -> List[Dict]:
    """Find prompts where generic keywords matched"""
    candidates = []

    for log_entry in logs:
        prompt_text = log_entry.get("prompt", {}).get("text", "")
        activated_skills = log_entry.get("activatedSkills", [])

        for skill in activated_skills:
            match_reasons = skill.get("matchReason", [])
            for reason in match_reasons:
                if isinstance(reason, dict) and reason.get("type") == "keyword":
                    keyword = reason.get("pattern", "").lower()
                    if keyword in GENERIC_KEYWORDS:
                        candidates.append({
                            "prompt": prompt_text,
                            "keyword": reason.get("pattern"),
                            "skill": skill.get("skillName"),
                        })
                        break  # Only one per skill per prompt

        if len(candidates) >= limit:
            break

    return candidates[:limit]


def generate_report(logs: List[Dict]):
    """Generate the analysis report"""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    total_prompts = len(logs)
    skill_counts = analyze_skill_activations(logs)
    total_activations = sum(skill_counts.values())
    avg_activations = total_activations / total_prompts if total_prompts > 0 else 0

    with open(REPORT_FILE, 'w', encoding='utf-8') as f:
        f.write("# Skill Trigger Analysis Report\n\n")
        f.write(f"**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"**Log Files**: {len(list(LOG_DIR.glob('*.jsonl')))} files\n")
        f.write(f"**Analysis Tool**: analyze_skill_triggers.py\n\n")
        f.write("---\n\n")

        # Section 1: Skill Activation Summary
        f.write("## 1. Skill Activation Summary\n\n")
        f.write("| Skill Name | Activation Count |\n")
        f.write("|------------|------------------|\n")

        for skill, count in skill_counts.most_common():
            f.write(f"| `{skill}` | {count} |\n")

        f.write(f"\n**Total Activations**: {total_activations}\n")
        f.write(f"**Total Prompts**: {total_prompts}\n")
        f.write(f"**Average Activations per Prompt**: {avg_activations:.2f}\n\n")
        f.write("---\n\n")

        # Section 2: Keyword Collision Analysis
        f.write("## 2. Keyword Collision Analysis\n\n")
        f.write("Keywords that appear in multiple skills:\n\n")

        collisions = detect_keyword_collisions(logs)
        if collisions:
            f.write("| Keyword | Skill Count | Skills |\n")
            f.write("|---------|-------------|--------|\n")
            for keyword, skills in sorted(collisions.items(), key=lambda x: len(x[1]), reverse=True):
                skills_str = ", ".join(sorted(skills))
                f.write(f"| `{keyword}` | {len(skills)} | {skills_str} |\n")
            f.write(f"\n⚠ Found {len(collisions)} keyword collisions\n\n")
        else:
            f.write("No keyword collisions detected.\n\n")

        f.write("---\n\n")

        # Section 3: Generic Single-Word Keywords
        f.write("## 3. Generic Single-Word Keywords\n\n")
        f.write("Single-word keywords that may cause false positives:\n\n")
        f.write("| Keyword | Skill | Activation Count | Risk Level |\n")
        f.write("|---------|-------|------------------|------------|\n")

        generic_keywords = identify_generic_keywords(logs)
        for keyword, skill, count, risk in generic_keywords[:30]:
            f.write(f"| `{keyword}` | {skill} | {count} | {risk} |\n")

        f.write("\n---\n\n")

        # Section 4: Unused Skills
        f.write("## 4. Unused Skills\n\n")
        f.write("Skills that never activated in the logs:\n\n")

        unused = find_unused_skills(logs)
        if unused:
            for skill in unused:
                f.write(f"- `{skill}` (0 activations)\n")
        else:
            f.write("All skills have been activated at least once.\n")

        f.write("\n---\n\n")

        # Section 5: Over-Triggering Prompts
        f.write("## 5. Over-Triggering Prompts\n\n")
        f.write("Prompts that activated 3 or more skills (potential false positives):\n\n")

        over_triggers = find_over_triggering_prompts(logs)
        if over_triggers:
            for item in over_triggers[:20]:
                f.write(f"**Prompt**: \"{item['prompt']}\"\n")
                f.write(f"- **Skills**: {', '.join(item['skills'])}\n")
                f.write(f"- **Count**: {item['count']}\n\n")
        else:
            f.write("No prompts triggered 3+ skills.\n")

        f.write("\n---\n\n")

        # Section 6: False Positive Candidates
        f.write("## 6. False Positive Candidates\n\n")
        f.write("Prompts where generic keywords matched (sample of 20):\n\n")

        fp_candidates = find_false_positive_candidates(logs)
        for candidate in fp_candidates:
            f.write(f"**Prompt**: \"{candidate['prompt']}\"\n")
            f.write(f"- **Matched Keyword**: `{candidate['keyword']}`\n")
            f.write(f"- **Skill**: {candidate['skill']}\n\n")

        f.write("---\n\n")

        # Summary
        f.write("## Summary\n\n")
        f.write(f"- **Total Prompts Analyzed**: {total_prompts}\n")
        f.write(f"- **Total Skill Activations**: {total_activations}\n")
        f.write(f"- **Average Skills per Prompt**: {avg_activations:.2f}\n\n")
        f.write("### Recommendations\n\n")
        f.write("1. **Resolve Keyword Collisions**: Review Section 2 for keywords appearing in multiple skills\n")
        f.write("2. **Replace Generic Keywords**: Review Section 3 for high-risk single-word triggers\n")
        f.write("3. **Investigate Unused Skills**: Review Section 4 for skills that may need better triggers or removal\n")
        f.write("4. **Fix Over-Triggering**: Review Section 5 for prompts activating too many skills\n")
        f.write("5. **Validate False Positives**: Review Section 6 for potentially irrelevant activations\n\n")
        f.write("---\n\n")
        f.write("**Next Steps**: Use this report to optimize `.claude/skill-rules.json`\n")


def main():
    print("=" * 64)
    print("     SKILL TRIGGER ANALYSIS TOOL")
    print("=" * 64)
    print()

    # Check if log directory exists
    if not LOG_DIR.exists():
        print(f"Error: Log directory not found: {LOG_DIR}")
        return

    # Load logs
    print("[1/6] Loading prompt logs...")
    logs = load_all_logs()

    if not logs:
        print("Error: No valid log entries found")
        return

    print(f"✓ Loaded {len(logs)} log entries\n")

    # Run analyses
    print("[2/6] Counting activations per skill...")
    skill_counts = analyze_skill_activations(logs)
    print(f"✓ Found {len(skill_counts)} skills with activations\n")

    print("[3/6] Detecting keyword collisions...")
    collisions = detect_keyword_collisions(logs)
    print(f"✓ Found {len(collisions)} keyword collisions\n")

    print("[4/6] Identifying generic single-word keywords...")
    generic = identify_generic_keywords(logs)
    print(f"✓ Identified {len(generic)} single-word keywords\n")

    print("[5/6] Finding unused skills...")
    unused = find_unused_skills(logs)
    print(f"✓ Found {len(unused)} unused skills\n")

    print("[6/6] Generating report...")
    generate_report(logs)
    print(f"✓ Report generated\n")

    print("=" * 64)
    print("✓ Analysis complete!")
    print("=" * 64)
    print()
    print(f"Report saved to: {REPORT_FILE}")
    print()


if __name__ == "__main__":
    main()
