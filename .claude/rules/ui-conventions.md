---
paths:
  - "lib/views/**"
  - "lib/widgets/**"
---

# UI Conventions

## Responsive Design
- Center + ConstrainedBox with responsive max width
- See `responsive-layout-validator` skill for breakpoints and patterns

## Terse Prompt Signals
User prompts are bimodal: detailed plans OR ultra-short commands.

| Signal | Meaning | Response |
|--------|---------|----------|
| `"continue"` | Resume at next step in current task | Don't ask "continue what?" - check plan/context and proceed |
| `"try it out"` / `"test it"` | Run the app and verify | Execute `flutter run -d chrome`, test, report result |
| Bare screenshot path | "Look at this" | Analyze proactively - describe what you see, don't ask what to look for |
| `"The issue remains"` | Previous fix failed | Try a DIFFERENT approach. Don't retry the same thing. |
| `"But..."` at start | Your previous claim was wrong | Stop and verify your claim before responding |
| `"are you really?"` | User doubts your statement | Actually verify (run command, check file) before confirming |
| `"what about X?"` | You missed/skipped something | Go check X immediately |
| `"Implement the following plan:"` | Complete spec, execute it | Don't ask clarifying questions. Parse and execute. |

## UI Mockup Comparison
- Be EXHAUSTIVE: check search box accents, avatar initials/images, icon colors, spacing, border radius, opacity, typography weight, and all small details
- List ALL differences, not just obvious ones
- Don't declare match until every element is verified
