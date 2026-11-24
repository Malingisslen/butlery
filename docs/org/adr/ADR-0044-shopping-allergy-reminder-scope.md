# ADR-0044: Allergy reminder on the shopping list – which data and which words

Date: 2026-11-24 · Ticket: BUT-2494 · Status: decided by Malin 2026-11-24

## Context
Stakeholder review (full panel) of `tasks/but-2494-plan.md`. Malin chose option B: shared household allergies count in the reminder, under consent v2.

## Conflicts
1. Diner profiles. Privacy and Legal: the guardian consent and family DPIA cover menus only, so a child's allergens on the shopping list need their own versioned consent. The plan had counted them. Escalated (legal/privacy, interpretive).
2. Wording. Legal: "välj laktosfri" is an instruction and an item without a box can read as safe; wants softer wording and a standing "read the label" line. Malin approved "välj laktosfri" in the mockup. Escalated (product decision vs legal advice).

## Decision (Malin, 2026-11-24)
1. Diner profiles count, under a new guardian consent version that names the shopping list; a profile consented under the old wording counts for menus only until the guardian approves the new text.
2. The approved wording stays ("Laktos i hushållet, välj laktosfri"), and a line "Påminnelser kan saknas. Läs alltid innehållet." shows at the top of the list whenever a reminder does.
