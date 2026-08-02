#!/usr/bin/env bash
# Butlery · LEVERANSKONTROLL. Kör från ZIP-roten efter uppackning:
#   bash "uploads/Butlery Skarmar etapp 3 onboarding/Butlery design uppdatering v12/fas0/verify-delivery.sh"
#
# Alltid --mode=delivery: varje zip:/-post är obligatorisk. Fas 0.12 — auto-läget
# föll tillbaka på repo när markören OCH alla sju leveransfiler saknades.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
cd "$root"
echo "# Leveranskontroll (delivery-läge, inga undantag)"
node fas0/check-manifest.mjs --mode=delivery 2>&1 | tee fas0/manifest-delivery.log
code="${PIPESTATUS[0]}"
echo "delivery-exit: $code"
exit "$code"
