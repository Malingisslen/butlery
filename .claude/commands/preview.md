# HTML Design Preview

Generate a visual HTML mockup for a UI component or screen layout.

## Arguments
$ARGUMENTS = description of what to preview (e.g., "cooking mode landscape split view", "friend request card with accept/reject buttons")

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
