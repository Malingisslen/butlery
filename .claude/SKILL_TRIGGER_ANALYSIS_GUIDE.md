# Skill Trigger Analysis Guide

## Overview

This guide explains how to analyze prompt logs to optimize skill trigger patterns in `.claude/skill-rules.json`.

**Purpose**: Tune keyword and intent pattern triggers to minimize false positives while maintaining accuracy.

**Current Status**: All file-based triggers removed (Nov 6, 2025). Only prompt-based matching is active.

## What Are Prompt Logs?

Prompt logs capture every user prompt and which skills were activated. They're stored in:
- **Location**: `.claude/cache/prompt-logs/YYYY-MM-DD.jsonl`
- **Format**: JSONL (JSON Lines) - one JSON object per line
- **Created by**: `prompt-logger.ts` hook (runs on UserPromptSubmit)

## Log Entry Structure

Each line in the log file is a JSON object with:

```json
{
  "sessionId": "uuid",
  "promptId": "uuid",
  "timestamp": "2025-11-06T22:41:01.702Z",
  "prompt": {
    "text": "Can you check now which skills this triggered?",
    "length": 46,
    "wordCount": 8,
    "hasCodeBlocks": false
  },
  "activatedSkills": [
    {
      "skillName": "testing-patterns",
      "priority": "critical",
      "enforcement": "suggest",
      "matchReason": [
        {
          "type": "keyword",
          "pattern": "check",
          "matchedText": "check"
        }
      ]
    }
  ],
  "gitContext": {
    "branch": "feature/ingredient-parser-v2-and-modul1",
    "modifiedFiles": ["..."],
    "timestamp": "..."
  },
  "sessionMetadata": {
    "conversationTurn": 5,
    "timeSinceLastPrompt": 120,
    "totalPromptsInSession": 5
  },
  "detectedPatterns": {
    "isQuestion": true,
    "isRefactoring": false,
    "isCreation": false,
    "isDebugging": false,
    "isExploration": true,
    "mentionsArchitecture": false,
    "mentionsTesting": false
  }
}
```

## Key Fields to Analyze

### 1. `prompt.text`
The actual user prompt. Read this to understand context.

### 2. `activatedSkills`
Array of skills that matched. Each has:
- `skillName`: Which skill activated
- `matchReason`: Why it matched (keyword or intent pattern)
  - `type`: "keyword" or "intent"
  - `pattern`: The trigger word/regex that matched
  - `matchedText`: The actual text that matched

### 3. `detectedPatterns`
Automatic categorization of prompt intent:
- `isQuestion`: Asking for info
- `isCreation`: Creating new code/feature
- `isRefactoring`: Modifying existing code
- `isDebugging`: Fixing bugs
- `isExploration`: Understanding/analyzing codebase

## Analysis Workflow

### Step 1: Extract All Activations

Read the JSONL file and collect all skill activations:

```bash
# Count activations per skill
cat .claude/cache/prompt-logs/2025-11-06.jsonl | \
  jq -r '.activatedSkills[].skillName' | \
  sort | uniq -c | sort -rn

# Example output:
# 15 testing-patterns
# 12 code-deduplication-utilities
# 8 skill-developer
# 3 butlery-architecture
```

### Step 2: Identify False Positives

Look for skills that activated when they shouldn't have.

**Common False Positive Patterns:**

1. **Generic Words Triggering Specific Skills**
   - "check" → testing-patterns (should only trigger for test-related checks)
   - "data" → firebase-repository-patterns (too generic)
   - "remove" → gdpr-compliance (should only trigger for user data deletion)

2. **Conversational Words**
   - "analyze" in casual context triggering code-deduplication-utilities
   - "test" in "test this idea" triggering testing-patterns

**How to spot them:**
```bash
# View all prompts that activated testing-patterns
cat .claude/cache/prompt-logs/2025-11-06.jsonl | \
  jq -r 'select(.activatedSkills[].skillName == "testing-patterns") |
         {prompt: .prompt.text, reason: .activatedSkills[0].matchReason[0].pattern}'
```

Review each one:
- ✅ "write unit test for RecipeService" - CORRECT
- ❌ "check the logs" - FALSE POSITIVE (keyword: "check")
- ❌ "let's test this approach" - FALSE POSITIVE (keyword: "test")

### Step 3: Identify False Negatives

Look for prompts where a skill SHOULD have activated but didn't.

**How to spot them:**

1. Read through prompts where you expected a skill but it's missing from `activatedSkills[]`
2. Check if prompt intent matches a skill domain (use `detectedPatterns`)

Example:
```json
{
  "prompt": "create unit tests for the shopping service",
  "activatedSkills": [],  // ❌ testing-patterns should have matched!
  "detectedPatterns": {
    "isCreation": true,
    "mentionsTesting": false  // Pattern detector missed it
  }
}
```

### Step 4: Categorize Trigger Quality

For each keyword/pattern in `skill-rules.json`, classify as:

| Quality | Description | Action |
|---------|-------------|--------|
| ✅ **Good** | High precision, low false positives | Keep |
| ⚠️ **Noisy** | Some false positives, but mostly correct | Tighten (make more specific) |
| ❌ **Bad** | Mostly false positives | Remove or replace |
| 🔍 **Missing** | False negatives (skill should activate but doesn't) | Add new triggers |

## Common Problems & Solutions

### Problem 1: Single Generic Word Triggers

**Example:**
```json
"keywords": ["check", "test", "data", "remove", "analyze"]
```

**Issue**: These words appear in casual conversation
- "can you check this?" (not about testing)
- "let me test this idea" (not about unit tests)
- "remove this line" (not about GDPR deletion)

**Solution**: Use multi-word phrases or intent patterns instead

```json
// Before
"keywords": ["check"]

// After
"keywords": ["unit test", "widget test", "test coverage"]
"intentPatterns": [
  "check.*test",
  "verify.*test.*passes"
]
```

### Problem 2: Over-Broad Intent Patterns

**Example:**
```json
"intentPatterns": [
  "make.*sure.*it.*works",
  "verify.*that",
  "check.*if"
]
```

**Issue**: These match general verification, not test-specific

**Solution**: Add test-specific context

```json
"intentPatterns": [
  "make.*sure.*test.*works",
  "verify.*test.*passes",
  "check.*if.*test.*fails"
]
```

### Problem 3: Missing Domain-Specific Triggers

**Example**: Skill doesn't activate for valid prompts

**Solution**: Add missing keywords/patterns

```json
// Add common variations
"keywords": [
  "unit test",
  "integration test",
  "e2e test",  // Added
  "test suite",  // Added
  "test file"  // Added
]
```

## Recommended Trigger Patterns

### Good Keyword Patterns

✅ **Multi-word technical terms**
- "unit test", "widget test", "dependency injection"
- Specific enough to avoid casual usage

✅ **Domain-specific jargon**
- "BaseFirebaseRepository", "ServiceLocator.get", "fromFirestore"
- Only used in technical context

✅ **Compound phrases**
- "test coverage", "mock repository", "audit log"
- Natural combinations that indicate intent

### Good Intent Patterns

✅ **Action + Domain Object**
```json
"create.*test",
"write.*test",
"add.*repository",
"mock.*service"
```

✅ **Technical Context Required**
```json
"test.*fail(s|ed|ing)",
"test.*pass(es|ed|ing)",
"mock.*firebase"
```

### Bad Keyword Patterns

❌ **Single generic words**
- "test", "check", "data", "remove", "analyze"
- Too common in conversation

❌ **Vague verbs**
- "ensure", "verify", "validate", "investigate"
- Used in many contexts

❌ **Common nouns**
- "service", "repository", "data", "user"
- Too generic

## Analysis Script Example

```bash
#!/bin/bash
# analyze-triggers.sh

LOG_FILE=".claude/cache/prompt-logs/2025-11-06.jsonl"

echo "=== Skill Activation Summary ==="
jq -r '.activatedSkills[].skillName' "$LOG_FILE" | sort | uniq -c | sort -rn

echo -e "\n=== False Positive Candidates ==="
echo "Prompts with 'check' keyword:"
jq -r 'select(.activatedSkills[].matchReason[].pattern == "check") |
       "  - \"\(.prompt.text)\""' "$LOG_FILE"

echo -e "\n=== Unused Skills ==="
ALL_SKILLS="butlery-architecture testing-patterns firebase-repository-patterns state-management-patterns code-deduplication-utilities flutter-widget-guidelines gdpr-compliance realtime-collaboration offline-first-patterns navigation-routing dependency-injection-patterns performance-optimization skill-developer"

for skill in $ALL_SKILLS; do
  count=$(jq -r ".activatedSkills[].skillName" "$LOG_FILE" | grep -c "^$skill$")
  if [ "$count" -eq 0 ]; then
    echo "  - $skill (never activated)"
  fi
done
```

## Decision Framework

For each trigger in `skill-rules.json`:

1. **Count activations**: How often does this trigger activate?
2. **Sample prompts**: Read 5-10 prompts that used this trigger
3. **Calculate accuracy**:
   - True positives / Total activations = Precision
   - If precision < 70%, the trigger is too noisy
4. **Action**:
   - Precision ≥ 90%: Keep as-is ✅
   - Precision 70-89%: Tighten trigger ⚠️
   - Precision < 70%: Remove or replace ❌

## Expected Outcomes

After analysis, you should:

1. **Remove noisy keywords**: Generic words with high false positive rate
2. **Add missing patterns**: New triggers for false negatives
3. **Tighten broad patterns**: Make intent patterns more specific
4. **Document decisions**: Note why each trigger was kept/removed

## Next Steps After Analysis

1. Edit `.claude/skill-rules.json` with findings
2. Test with new prompts
3. Re-analyze after 20-30 more prompts
4. Iterate until precision ≥ 90% for all skills

## Questions to Ask During Analysis

- Which skills never activate? (Consider removing or adjusting triggers)
- Which skills activate too often? (Too many noisy keywords)
- Are there prompt patterns not covered by any skill? (Missing skills)
- Do false positives share common words? (Remove those keywords)
- What makes true positives different from false positives? (Add that context to patterns)

## Success Metrics

**Good trigger configuration:**
- Average 1-3 skills per prompt
- < 10% false positive rate
- < 5% false negative rate
- Skills activate only when genuinely relevant

**Signs of problems:**
- 5+ skills activating on simple prompts
- Same skill always activating (too generic)
- Skill never activating (triggers too specific or skill not useful)

---

**Last Updated**: Nov 6, 2025
**Status**: File-based triggers removed, prompt-only matching active
