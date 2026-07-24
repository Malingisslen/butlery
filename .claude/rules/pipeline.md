---
paths:
  - "lib/services/import/**"
  - "lib/services/parsing/**"
  - "lib/services/tagging/**"
  - "lib/services/menu/**"
  - "lib/viewmodels/menu/**"
  - "functions/src/llm/**"
---

# The USP chain — import → parse → tag → personalize

Read `docs/architecture/RECIPE_PIPELINE.md` before changing anything here. It maps what is
live, what is dormant, and what is dead (audited 2026-07-01) — the difference is not
visible from the code alone, and dormant paths look identical to live ones.

Improvement backlog: `docs/architecture/PIPELINE_IMPROVEMENT_ROADMAP.md`.

Tagging domain knowledge (TriState allergen logic, the five-phase pipeline) lives in the
`tagging-domain-knowledge` skill; ingredient lookup patterns in
`firebase-ingredient-patterns`.
