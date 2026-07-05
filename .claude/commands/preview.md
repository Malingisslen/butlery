# HTML Design Preview

Generate a visual HTML mockup for a UI component or screen layout.

## Arguments
$ARGUMENTS = description of what to preview (e.g., "cooking mode landscape split view", "friend request card with accept/reject buttons"). `--directions` (or any NEW screen — see below) switches to design-directions mode.

## Directions mode (MANDATORY for any NEW screen — this is what satisfies the preview gate)

The `preview-gate.sh` hook blocks creating a new `lib/views/*.dart` file until the marker
`~/.claude/state/preview-done-<slug>.marker` exists (`<slug>` = the view file's basename
without `.dart`, e.g. `pantry_overview_view` for `lib/views/pantry_overview_view.dart`).
This mode is the flow that legitimately stamps it. Rationale: recognizing a preference is
far easier than specifying one — Malin reacts to variants instead of describing a design.

1. Establish the target view file name (ask if not obvious) — the slug derives from it.
2. Build ONE self-contained HTML file at `tasks/previews/<slug>-directions.html` containing
   **3–4 deliberately INCOMPATIBLE directions** for the same screen (e.g. dense list vs
   airy cards vs split-pane vs timeline — vary structure, not just color), all using the
   Butlery design tokens (steps 1–2 of the single-mockup flow below) inside phone frames.
3. Make it a decision interface, not a gallery:
   - Every notable element gets clickable **steal / skip** chips (pure inline JS).
   - A sticky footer textarea auto-assembles Malin's picks into a copy-paste reply
     ("Direction B base; steal A's header; skip C's tabs").
   - 2–4 multiple-choice questions for genuine unknowns the variants expose (placement,
     density, what's above the fold).
4. Render it to Malin: `SendUserFile` with `display: render` (Chrome MCP screenshot as
   fallback context if useful). WAIT for her picks — never pick for her.
5. Fold her reply into a one-paragraph design decision (recorded in the plan/todo for the
   screen), THEN stamp: `touch ~/.claude/state/preview-done-<slug>.marker` — and only then
   start the Flutter implementation. Delete the directions HTML after (disposable, tasks/).

Escape hatch (rare, say so out loud): a genuinely non-visual view or mechanical file move
uses `SKIP_PREVIEW_GATE=1` instead of a fake preview.

## Steps

1. Read `docs/design/previews/_butlery-template.html` for the base template
2. Read `docs/design/butlery-mockup-reference.md` for design token reference
3. Create a new HTML file based on the template:
   - Use the Butlery design tokens (colors, fonts, spacing, square corners)
   - Build the described UI component or screen layout
   - Include a phone frame wrapper (375x812) for mobile previews
   - Make it self-contained (no external dependencies beyond Google Fonts)
4. Write the file to `docs/design/previews/{descriptive-name}-preview.html`
5. If Chrome MCP is available:
   - Navigate to the file using `file:///` URL
   - Take a screenshot and present it
6. If Chrome MCP is not available:
   - Tell the user to open the file in their browser
   - Provide the full file path

## Naming Convention
- Use kebab-case: `cooking-mode-preview.html`, `friend-card-comparison.html`
- Suffix: `-preview` for single designs, `-comparison` for A/B options

## After Approval
If the preview represents a new or significantly changed screen:
1. Screenshot the HTML preview via Chrome MCP (capture the phone frame at 375x812)
2. Save the screenshot to `docs/design/mockups/butlery-{NN}-{screen-name}.png` (continue sequence from existing mockups)
3. Delete the preview HTML file
4. Proceed with Flutter implementation using the approved design

For minor component previews, just delete the file and proceed.
