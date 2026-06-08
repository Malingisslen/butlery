#!/usr/bin/env bash
# BUT-1213 (enforce half of BUT-944): keep the favourite/saved icon convention
# from eroding. `AdaptiveIcons` (lib/widgets/common/icons/adaptive_icon.dart)
# is the single source for the concept glyphs:
#   heart    -> AdaptiveIcons.favouriteFilled / favouriteOutline  (favourite, like)
#   bookmark -> AdaptiveIcons.savedTemplate   / savedTemplateOutline (template/saved)
#
# This guard FAILS CI when raw `Icons.favorite*` or `Icons.bookmark*` appears in
# lib/views/ or lib/widgets/ — both glyphs have NO legitimate non-concept use, so
# a raw occurrence is always a convention violation. Use the AdaptiveIcons getter.
#
# Deliberately NOT enforced here: `Icons.star*`. Star is genuinely overloaded —
# ratings (star_rating_row), sort menus, dietary chips, permission-role badges —
# so a hard ban would false-positive. The "star = primary/featured" concept is
# left to manual review / the design-system audit. (See BUT-1213 for the colour
# half, still pending a product decision.)
#
# The AdaptiveIcons definition file is the one allowed home for the raw glyphs.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SEARCH_PATHS=()
for p in lib/views lib/widgets; do
  if [[ -d "$p" ]]; then
    SEARCH_PATHS+=("$p")
  fi
done

if [[ ${#SEARCH_PATHS[@]} -eq 0 ]]; then
  echo "OK: no lib/views or lib/widgets to scan."
  exit 0
fi

# Raw concept glyphs that must route through AdaptiveIcons. The optional
# `(_[a-z]+)*` suffix subsumes every Material variant — favorite / favorite_border
# / favorite_rounded / bookmark / bookmark_add / bookmark_border / … — so new
# glyph spellings can't slip past without enumerating each. The trailing `\b`
# keeps it from catching unrelated identifiers. Broadening is safe here precisely
# because favourite + bookmark have no legitimate non-concept use.
PATTERN='Icons\.(favorite|bookmark)(_[a-z]+)*\b'

# The AdaptiveIcons definition legitimately maps these glyphs.
matches="$(grep -rnE "$PATTERN" "${SEARCH_PATHS[@]}" \
  --include='*.dart' \
  --exclude='adaptive_icon.dart' || true)"

if [[ -n "$matches" ]]; then
  echo "❌ Icon-convention violation (BUT-944/BUT-1213): raw favourite/bookmark glyph in lib/views|lib/widgets."
  echo "   Use AdaptiveIcons.favouriteFilled/favouriteOutline (heart) or AdaptiveIcons.savedTemplate/savedTemplateOutline (bookmark)."
  echo ""
  echo "$matches"
  exit 1
fi

echo "OK: no raw favourite/bookmark glyphs in lib/views or lib/widgets."
exit 0
