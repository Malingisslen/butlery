#!/usr/bin/env bash
# Butlery · ETT kanoniskt kommando, EN reporot (den här filens ../).
# Ordning: manifest → kedja. Slutlig exit = 1 om någon del faller.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
# ZIP-roten ligger tre nivåer över paketet (paket → design-katalog → uploads → rot).
# Fas 0.13: variabeln användes på rad 28 men deklarerades aldrig, och med set -u
# kraschade det dokumenterade huvudkommandot innan manifestkontrollen.
zroot="$(cd "$root/../../.." 2>/dev/null && pwd || echo "$root")"
if [ ! -f "$root/tools/verify.mjs" ]; then
  echo "✖ $root är inte reporoten (tools/verify.mjs saknas)" >&2; exit 2
fi
cd "$root"
mkdir -p fas0

echo "# Butlery verifieringskörning"
echo "reporot: $root"
echo "node: $(node --version)"
# Portabelt ISO-datum: date -Iseconds finns inte i macOS standardmiljö.
echo "datum: $(node -e 'console.log(new Date().toISOString())')"
echo

echo "== manifestkontroll (före de muterande stegen)"
set +e
# LÄGE: en leverans MÅSTE köras med --mode=delivery. Auto kan inte skilja ett
# legitimt repo från en leverans där både markören och alla externa filer
# försvunnit — Fas 0.12 visade att en tömd leveransyta gav exit 0.
mode="${BUTLERY_MANIFEST_MODE:-}"
if [ -z "$mode" ]; then
  if [ -f "$zroot/fas0/DELIVERY" ] || [ -f "$root/fas0/DELIVERY" ]; then mode=delivery; else mode=repo; fi
fi
export BUTLERY_MANIFEST_MODE="$mode"
node fas0/check-manifest.mjs "--mode=$mode" 2>&1 | tee fas0/manifest.log
manifest_code="${PIPESTATUS[0]}"
set -e
# set -e får INTE fälla wrappern här: avslutar manifestet före sin summering
# (t.ex. ogiltigt läge) körde verify.mjs aldrig och ingen slutstatus skrevs.
# Fas 0.11: allt nedan är felsäkert och kedjan körs oavsett.
msum="$(grep -o 'MANIFEST-SUMMARY.*' fas0/manifest.log 2>/dev/null | head -1 || true)"
getv() { echo "$msum" | grep -o "$1=[0-9]*" 2>/dev/null | head -1 | cut -d= -f2 || true; }
if [ -z "$msum" ]; then
  echo "⚠ manifestet skrev ingen MANIFEST-SUMMARY (exit $manifest_code) — kedjan körs ändå och rapporten skrivs" >&2
fi
mfiles="$(getv parsed)"
export BUTLERY_MANIFEST_PARSED="$(getv parsed)"
export BUTLERY_MANIFEST_VERIFIED="$(getv ok)"
export BUTLERY_MANIFEST_BAD="$(getv bad)"
export BUTLERY_MANIFEST_MISSING="$(getv missing)"
export BUTLERY_MANIFEST_DUP="$(getv duplicates)"
export BUTLERY_MANIFEST_UNLISTED="$(getv unlisted)"
export BUTLERY_MANIFEST_OUTSIDE="$(getv outside_absent)"
export BUTLERY_MANIFEST_MODE="$(echo "$msum" | grep -o 'mode=[a-z]*' | head -1 | cut -d= -f2)"
export BUTLERY_MANIFEST_EXPECTED="$(getv expected)"
export BUTLERY_MANIFEST_EXIT="$manifest_code"
export BUTLERY_MANIFEST_FILES="${mfiles:-0}"
if [ "$manifest_code" -eq 0 ]; then export BUTLERY_MANIFEST_STATUS=passed; else export BUTLERY_MANIFEST_STATUS=failed; fi
echo "manifest exit: $manifest_code"
echo

set +e
node tools/verify.mjs 2>&1 | tee fas0/verify.log
verify_code="${PIPESTATUS[0]}"
printf '%s' "$verify_code" > fas0/verify-chain-exit
set -e

final=0
[ "$verify_code" -ne 0 ] && final=1
[ "$manifest_code" -ne 0 ] && final=1

echo
printf '%s' "$final" > fas0/verify-exit
echo "verify exit: $verify_code · manifest exit: $manifest_code · SLUTLIG EXIT: $final"
echo "rapport: $root/fas0/verify-report.json"
exit "$final"
