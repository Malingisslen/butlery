#!/usr/bin/env python3
"""
Trigger Precision Calculator
Calculates effectiveness metrics for skill triggers
"""

import json
import os
from pathlib import Path
from collections import defaultdict, Counter
from datetime import datetime
from typing import Dict, List, Tuple

# Configuration
LOG_DIR = Path(".claude/cache/prompt-logs")
OUTPUT_DIR = Path(".claude/analysis")
TIMESTAMP = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
REPORT_FILE = OUTPUT_DIR / f"trigger_precision_metrics_{TIMESTAMP}.md"

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


def load_all_logs() -> List[Dict]:
    """Load all JSONL log files"""
    logs = []
    log_files = list(LOG_DIR.glob("*.jsonl"))

    if not log_files:
        print(f"Error: No .jsonl files found in {LOG_DIR}")
        return []

    for log_file in log_files:
        try:
            with open(log_file, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line:
                        try:
                            logs.append(json.loads(line))
                        except json.JSONDecodeError:
                            pass  # Skip invalid JSON
        except Exception:
            pass  # Skip files with errors

    return logs


def calculate_overall_metrics(logs: List[Dict]) -> Dict:
    """Calculate overall activation metrics"""
    total_prompts = len(logs)
    total_activations = 0
    prompts_with_activations = 0

    for log_entry in logs:
        activated_skills = log_entry.get("activatedSkills", [])
        if activated_skills:
            prompts_with_activations += 1
            total_activations += len(activated_skills)

    prompts_without_activations = total_prompts - prompts_with_activations
    avg_activations = total_activations / total_prompts if total_prompts > 0 else 0
    activation_rate = (prompts_with_activations / total_prompts * 100) if total_prompts > 0 else 0

    return {
        "total_prompts": total_prompts,
        "total_activations": total_activations,
        "prompts_with_activations": prompts_with_activations,
        "prompts_without_activations": prompts_without_activations,
        "avg_activations": avg_activations,
        "activation_rate": activation_rate,
    }


def analyze_keyword_effectiveness(logs: List[Dict]) -> List[Tuple[str, str, int]]:
    """Analyze keyword effectiveness by activation count"""
    keyword_data = defaultdict(lambda: {"skill": None, "count": 0})

    for log_entry in logs:
        activated_skills = log_entry.get("activatedSkills", [])
        for skill in activated_skills:
            skill_name = skill.get("skillName", "")
            match_reasons = skill.get("matchReason", [])

            for reason in match_reasons:
                if isinstance(reason, dict) and reason.get("type") == "keyword":
                    pattern = reason.get("pattern", "")
                    if pattern:
                        key = (pattern, skill_name)
                        if keyword_data[key]["skill"] is None:
                            keyword_data[key]["skill"] = skill_name
                        keyword_data[key]["count"] += 1

    # Convert to sorted list
    results = [(keyword, skill, data["count"]) for (keyword, skill), data in keyword_data.items()]
    results.sort(key=lambda x: x[2], reverse=True)
    return results


def analyze_intent_effectiveness(logs: List[Dict]) -> List[Tuple[str, str, int]]:
    """Analyze intent pattern effectiveness"""
    intent_data = defaultdict(lambda: {"skill": None, "count": 0})

    for log_entry in logs:
        activated_skills = log_entry.get("activatedSkills", [])
        for skill in activated_skills:
            skill_name = skill.get("skillName", "")
            match_reasons = skill.get("matchReason", [])

            for reason in match_reasons:
                if isinstance(reason, dict) and reason.get("type") == "intent":
                    pattern = reason.get("pattern", "")
                    if pattern:
                        key = (pattern, skill_name)
                        if intent_data[key]["skill"] is None:
                            intent_data[key]["skill"] = skill_name
                        intent_data[key]["count"] += 1

    # Convert to sorted list
    results = [(pattern, skill, data["count"]) for (pattern, skill), data in intent_data.items()]
    results.sort(key=lambda x: x[2], reverse=True)
    return results


def analyze_per_skill_performance(logs: List[Dict]) -> Dict[str, Dict]:
    """Calculate performance metrics for each skill"""
    skill_metrics = {skill: {"total": 0, "keyword": 0, "intent": 0} for skill in ALL_SKILLS}

    for log_entry in logs:
        activated_skills = log_entry.get("activatedSkills", [])
        for skill in activated_skills:
            skill_name = skill.get("skillName")
            if skill_name in skill_metrics:
                skill_metrics[skill_name]["total"] += 1

                match_reasons = skill.get("matchReason", [])
                for reason in match_reasons:
                    if isinstance(reason, dict):
                        match_type = reason.get("type")
                        if match_type == "keyword":
                            skill_metrics[skill_name]["keyword"] += 1
                        elif match_type == "intent":
                            skill_metrics[skill_name]["intent"] += 1

    return skill_metrics


def calculate_match_type_distribution(logs: List[Dict]) -> Dict:
    """Calculate distribution of keyword vs intent matches"""
    keyword_count = 0
    intent_count = 0

    for log_entry in logs:
        activated_skills = log_entry.get("activatedSkills", [])
        for skill in activated_skills:
            match_reasons = skill.get("matchReason", [])
            for reason in match_reasons:
                if isinstance(reason, dict):
                    match_type = reason.get("type")
                    if match_type == "keyword":
                        keyword_count += 1
                    elif match_type == "intent":
                        intent_count += 1

    total = keyword_count + intent_count
    keyword_pct = (keyword_count / total * 100) if total > 0 else 0
    intent_pct = (intent_count / total * 100) if total > 0 else 0

    return {
        "keyword_count": keyword_count,
        "intent_count": intent_count,
        "total": total,
        "keyword_pct": keyword_pct,
        "intent_pct": intent_pct,
    }


def calculate_activation_distribution(logs: List[Dict]) -> Dict:
    """Calculate distribution of how many skills activate per prompt"""
    distribution = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}

    for log_entry in logs:
        skill_count = len(log_entry.get("activatedSkills", []))
        if skill_count >= 4:
            distribution[4] += 1
        else:
            distribution[skill_count] += 1

    total = len(logs)
    percentages = {k: (v / total * 100) if total > 0 else 0 for k, v in distribution.items()}

    return {
        "counts": distribution,
        "percentages": percentages,
        "total": total,
    }


def generate_report(logs: List[Dict]):
    """Generate the precision metrics report"""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    overall = calculate_overall_metrics(logs)
    keywords = analyze_keyword_effectiveness(logs)
    intents = analyze_intent_effectiveness(logs)
    skill_perf = analyze_per_skill_performance(logs)
    match_dist = calculate_match_type_distribution(logs)
    activation_dist = calculate_activation_distribution(logs)

    with open(REPORT_FILE, 'w', encoding='utf-8') as f:
        f.write("# Trigger Precision Metrics Report\n\n")
        f.write(f"**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"**Log Files**: {len(list(LOG_DIR.glob('*.jsonl')))} files\n")
        f.write(f"**Analysis Tool**: calculate_trigger_precision.py\n\n")
        f.write("---\n\n")

        # Overall Metrics
        f.write("## Overall Metrics\n\n")
        f.write("| Metric | Value |\n")
        f.write("|--------|-------|\n")
        f.write(f"| Total Prompts | {overall['total_prompts']} |\n")
        f.write(f"| Total Activations | {overall['total_activations']} |\n")
        f.write(f"| Prompts with Skills | {overall['prompts_with_activations']} |\n")
        f.write(f"| Prompts without Skills | {overall['prompts_without_activations']} |\n")
        f.write(f"| Average Skills per Prompt | {overall['avg_activations']:.2f} |\n")
        f.write(f"| Activation Rate | {overall['activation_rate']:.1f}% |\n\n")
        f.write("---\n\n")

        # Keyword Effectiveness
        f.write("## 1. Keyword Effectiveness\n\n")
        f.write("Top 20 most effective keywords (by activation count):\n\n")
        f.write("| Keyword | Skill | Activations | Match Type |\n")
        f.write("|---------|-------|-------------|------------|\n")

        for keyword, skill, count in keywords[:20]:
            f.write(f"| `{keyword}` | {skill} | {count} | keyword |\n")

        f.write("\n---\n\n")

        # Intent Pattern Effectiveness
        f.write("## 2. Intent Pattern Effectiveness\n\n")
        f.write("Top 20 most effective intent patterns (by activation count):\n\n")
        f.write("| Pattern | Skill | Activations | Match Type |\n")
        f.write("|---------|-------|-------------|------------|\n")

        for pattern, skill, count in intents[:20]:
            # Truncate long patterns
            display_pattern = pattern[:50] + "..." if len(pattern) > 50 else pattern
            f.write(f"| `{display_pattern}` | {skill} | {count} | intent |\n")

        f.write("\n---\n\n")

        # Per-Skill Performance
        f.write("## 3. Per-Skill Performance\n\n")
        f.write("Detailed metrics for each skill:\n\n")
        f.write("| Skill | Total Activations | Keyword Matches | Intent Matches | Avg Triggers/Prompt |\n")
        f.write("|-------|-------------------|-----------------|----------------|---------------------|\n")

        total_prompts = overall['total_prompts']
        for skill in ALL_SKILLS:
            metrics = skill_perf[skill]
            avg = metrics["total"] / total_prompts if total_prompts > 0 else 0
            f.write(f"| `{skill}` | {metrics['total']} | {metrics['keyword']} | {metrics['intent']} | {avg:.2f} |\n")

        f.write("\n---\n\n")

        # Match Type Distribution
        f.write("## 4. Match Type Distribution\n\n")
        f.write("| Match Type | Count | Percentage |\n")
        f.write("|------------|-------|------------|\n")
        f.write(f"| Keyword Matches | {match_dist['keyword_count']} | {match_dist['keyword_pct']:.1f}% |\n")
        f.write(f"| Intent Pattern Matches | {match_dist['intent_count']} | {match_dist['intent_pct']:.1f}% |\n")
        f.write(f"| **Total** | **{match_dist['total']}** | **100%** |\n\n")

        insight = "Keywords are triggering more than intent patterns" if match_dist['keyword_count'] > match_dist['intent_count'] else "Intent patterns are triggering more than keywords"
        f.write(f"**Insight**: {insight}\n\n")
        f.write("---\n\n")

        # Activation Distribution
        f.write("## 5. Activation Distribution\n\n")
        f.write("How many skills activate per prompt:\n\n")
        f.write("| Skills Activated | Prompt Count | Percentage | Status |\n")
        f.write("|------------------|--------------|------------|--------|\n")

        dist_counts = activation_dist['counts']
        dist_pct = activation_dist['percentages']

        f.write(f"| 0 skills | {dist_counts[0]} | {dist_pct[0]:.1f}% | ⚪ No match |\n")
        f.write(f"| 1 skill | {dist_counts[1]} | {dist_pct[1]:.1f}% | ✅ Ideal |\n")
        f.write(f"| 2 skills | {dist_counts[2]} | {dist_pct[2]:.1f}% | ✅ Good |\n")
        f.write(f"| 3 skills | {dist_counts[3]} | {dist_pct[3]:.1f}% | ⚠️ Moderate |\n")
        f.write(f"| 4+ skills | {dist_counts[4]} | {dist_pct[4]:.1f}% | ❌ Over-triggering |\n\n")

        quality_score = "⚠️ Needs improvement (too many over-triggers)" if dist_counts[4] > overall['total_prompts'] / 10 else "✅ Good (low over-triggering rate)"
        f.write(f"**Quality Score**: {quality_score}\n\n")
        f.write("---\n\n")

        # Summary and Recommendations
        f.write("## Summary & Recommendations\n\n")
        f.write("### Key Findings\n\n")
        f.write(f"1. **Overall Activation Rate**: {overall['prompts_with_activations']}/{overall['total_prompts']} prompts triggered at least one skill ({overall['activation_rate']:.1f}%)\n")
        f.write(f"2. **Match Type Balance**: Keywords ({match_dist['keyword_pct']:.1f}%) vs Intent Patterns ({match_dist['intent_pct']:.1f}%)\n")
        f.write(f"3. **Over-Triggering**: {dist_counts[4]} prompts activated 4+ skills ({dist_pct[4]:.1f}%)\n\n")

        f.write("### Recommendations\n\n")

        # Generate recommendations based on metrics
        if dist_counts[4] > overall['total_prompts'] / 10:
            f.write("- ⚠️ **High Priority**: Reduce over-triggering by tightening generic keywords\n")

        if match_dist['keyword_count'] > match_dist['intent_count'] * 2:
            f.write("- ⚠️ **Consider**: Keywords dominating - may need more intent patterns for context\n")

        if overall['prompts_without_activations'] > overall['total_prompts'] / 3:
            f.write("- ℹ️ **Note**: High no-match rate - consider adding more triggers or accept as normal\n")

        f.write("\n### Target Metrics (Industry Best Practices)\n\n")
        f.write(f"- ✅ **Activation Rate**: 60-80% (current: {overall['activation_rate']:.1f}%)\n")
        f.write(f"- ✅ **Avg Skills/Prompt**: 1-3 (current: {overall['avg_activations']:.2f})\n")
        f.write(f"- ✅ **Over-Trigger Rate**: <10% (current: {dist_pct[4]:.1f}%)\n\n")
        f.write("---\n\n")
        f.write("**Next Steps**: Use these metrics to prioritize optimization efforts in `.claude/skill-rules.json`\n")


def main():
    print("=" * 64)
    print("     TRIGGER PRECISION CALCULATOR")
    print("=" * 64)
    print()

    # Check if log directory exists
    if not LOG_DIR.exists():
        print(f"Error: Log directory not found: {LOG_DIR}")
        return

    # Load logs
    print(f"Analyzing log files in {LOG_DIR}...")
    logs = load_all_logs()

    if not logs:
        print("Error: No valid log entries found")
        return

    print(f"Loaded {len(logs)} log entries\n")

    # Run analyses
    print("[1/5] Calculating keyword effectiveness...")
    keywords = analyze_keyword_effectiveness(logs)
    print(f"✓ Analyzed {len(keywords)} keywords\n")

    print("[2/5] Calculating intent pattern effectiveness...")
    intents = analyze_intent_effectiveness(logs)
    print(f"✓ Analyzed {len(intents)} intent patterns\n")

    print("[3/5] Calculating per-skill performance metrics...")
    skill_perf = analyze_per_skill_performance(logs)
    print(f"✓ Analyzed {len(skill_perf)} skills\n")

    print("[4/5] Analyzing match type distribution...")
    match_dist = calculate_match_type_distribution(logs)
    print(f"✓ Analyzed match distribution\n")

    print("[5/5] Generating report...")
    generate_report(logs)
    print(f"✓ Report generated\n")

    print("=" * 64)
    print("✓ Precision calculation complete!")
    print("=" * 64)
    print()
    print(f"Report saved to: {REPORT_FILE}")
    print()


if __name__ == "__main__":
    main()
