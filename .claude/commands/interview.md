---
description: Interview me about the plan
argument-hint: [plan]
model: opus
---

Read this plan file $1 and interview me in detail using the AskUserQuestionTool about
literally anything: technical implementation, UI & UX, concerns, tradeoffs, etc.
but make sure the questions are not obvious.

If the plan has multiple viable approaches, include a fit check grid (requirements as rows,
approaches as columns, Y/N cells) in the spec to justify the chosen approach.

Be very in-depth and continue interviewing me continually until it's complete, then write the spec to the file.

## Memory Persistence (REQUIRED after interview)

After writing the spec, persist key decisions to the auto memory system:

1. **MEMORY.md** (`/root/.claude/projects/-home-user-butlery/memory/MEMORY.md`):
   - Add/update entries under "User Preferences" and "Key Decisions"
   - Merge with existing entries - don't duplicate
   - Keep MEMORY.md under 150 lines total

2. **interview-decisions.md** (`/root/.claude/projects/-home-user-butlery/memory/interview-decisions.md`):
   - Add consolidated answers: user preferences, requirements, constraints, rejected approaches
   - Format: prescriptive ("User wants X", "Never do Y") not descriptive ("We discussed X")
   - Merge with existing entries - update if a preference changed, don't just append

3. **patterns.md** (`/root/.claude/projects/-home-user-butlery/memory/patterns.md`):
   - If the interview revealed what works/doesn't work, add to patterns

This ensures the user never has to re-answer the same questions in future sessions.