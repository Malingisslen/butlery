---
paths:
  - "lib/views/**"
  - "lib/widgets/**"
---

# Visual Preview Rules

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
