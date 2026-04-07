---
paths:
  - "lib/views/**"
  - "lib/widgets/**"
  - "tasks/todo.md"
---

# Visual Preview Rules

## In Plan Mode
When a plan includes new views or significant view changes:
1. Include ASCII wireframes directly in the plan file for each new/changed screen
2. Use simple box-drawing characters to show layout structure, component placement, and hierarchy
3. For complex screens, note that an HTML preview will be generated before implementation begins
4. When using AskUserQuestion during planning to clarify design choices, use the `preview` field with ASCII mockups

**Plan file ASCII format:**
```
┌─────────────────────────┐
│ HEADER: screen title    │
├─────────────────────────┤
│                         │
│  [component description]│
│                         │
├─────────────────────────┤
│ NAV: tab1 | tab2 | tab3│
└─────────────────────────┘
```

## Two Preview Tiers

### Tier 1: ASCII Previews (AskUserQuestion)
For quick structural decisions — use the `preview` field on AskUserQuestion options.

**When to use:**
- Quick "A or B?" with simple components
- Structural layout choices (arrangement, hierarchy)
- "Should this button go here or there?"
- Component variations (2-3 options to compare)

### Tier 2: HTML Previews (Browser)
For full-fidelity visual mockups — write to `docs/design/previews/` using `_butlery-template.html`.

**When to use:**
- New views or screens (before writing Flutter code)
- Significant layout redesigns
- Color/typography decisions that need real rendering
- Responsive/tablet layout work
- A/B comparisons needing pixel-accurate representation

## HTML Preview Workflow
When creating a new view or significantly redesigning an existing one:
1. Generate an HTML preview in `docs/design/previews/` using `_butlery-template.html` as base
2. Open it via Chrome MCP or tell the user to open in browser
3. Get approval before writing Flutter code

## Promoting Previews to Permanent Mockups
After a preview is approved and successfully implemented:
1. Screenshot the HTML preview via Chrome MCP (375x812 phone frame)
2. Save to `docs/design/mockups/butlery-{NN}-{screen-name}.png` (continue sequence from existing 7)
3. The preview HTML can then be deleted — the PNG is the permanent reference

## Design Token Sync
The HTML template (`_butlery-template.html`) hardcodes CSS custom properties that mirror the Flutter theme.
- If theme tokens change (colors, spacing, fonts), update the template CSS to match
- Source of truth: Flutter theme files in `lib/theme/`
- The component library (`_butlery-components.html`) inherits from the template — one update covers both

## When NOT to Generate Previews
- Bug fixes that don't change layout
- Backend/logic changes
- Minor style tweaks (color, font size)
- Changes the user has already approved via mockup PNG

## HTML Preview File Naming
- `{view-name}-preview.html` for new views
- `{view-name}-comparison.html` for A/B options
- `{view-name}-responsive.html` for breakpoint previews
- Delete preview files after implementation is approved
