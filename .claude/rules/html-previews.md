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

## Widget Component Library

The component library (`_butlery-components.html`) catalogs every reusable visual widget.

### When Creating a New Widget
1. Add its HTML equivalent to `_butlery-components.html` in the appropriate section
2. Include all variants (named constructors, style enums)
3. Show the CSS class name and Flutter class name
4. Get approval on the visual before writing Dart code

### When Modifying an Existing Widget
1. Check if the widget is in the component library
2. If the visual appearance changes, update the HTML to match
3. If adding new variants, add them to the library

### When Building a New View
1. Read `_butlery-components.html` to see what building blocks exist
2. Compose the view from existing components before creating new ones
3. If a needed component doesn't exist, add it to the library first

### Component Library as Source of Truth
- Every branded/reusable visual widget must be in the library
- The library shows what components LOOK LIKE — Flutter code shows how they WORK
- When the user asks "what widgets do we have?", reference the library

## HTML Preview File Naming
- `{view-name}-preview.html` for new views
- `{view-name}-comparison.html` for A/B options
- `{view-name}-responsive.html` for breakpoint previews
- Delete preview files after implementation is approved

## Directions mode + preview gate (2026-07-05)
A NEW `lib/views/*.dart` file is blocked by `preview-gate.sh` until
`~/.claude/state/preview-done-<view-basename>.marker` exists. The legitimate stamping flow
is `/preview --directions` (see `.claude/commands/preview.md`): 3–4 deliberately
incompatible variants with steal/skip chips at `tasks/previews/<slug>-directions.html`,
Malin's picks folded into the design decision BEFORE the marker is touched.
