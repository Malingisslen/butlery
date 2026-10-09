Butlery Sans 0.626

Release scope
This is a metadata-only and packaging-only update from 0.625.
No glyph, width, spacing, kerning, OpenType behavior, hinting or appearance
has changed.

Included styles
- Regular 400
- Italic 400
- Semibold 600
- Semibold Italic 600
- Bold 700
- Bold Italic 700

Included formats
- TTF for app/native use.
- OTF for print and design interchange.
- WOFF2 for web/PWA use.
- app-assets/ contains versioned TTF and WOFF2 files ready for integration.

Release-bundle licensing
- app-assets/licenses/Butlery-Sans/OFL-1.1.txt
- app-assets/licenses/Butlery-Sans/THIRD_PARTY_NOTICES.txt
- app-assets/FONT-VERSION.txt
- app-assets/assets-manifest.json

The app should expose the two licensing documents through a discoverable route,
for example Settings > About > Licenses. Copy the complete app-assets directory;
do not copy only the font binaries.

Implementation rules
- Declare all six @font-face entries from butlery-sans.css.
- Set font-synthesis: none so missing styles are never faked.
- Use font-style: italic for the true italic styles.
- Use font-weight: 600 or 700 for true semibold and bold.
- Underline and strike-through remain text decorations in code.
- Use proportional figures in body copy and tabular figures for aligned
  quantities, dates and timers.

License
Butlery Sans is a renamed derivative using Mona Sans, Albert Sans and DM Sans
source material under the SIL Open Font License 1.1. See OFL-1.1.txt,
THIRD_PARTY_NOTICES.txt and FONTLOG.txt.
