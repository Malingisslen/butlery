#!/usr/bin/env bash
# Fixtures for scripts/ci_docs_only.sh.
# Run: bash scripts/__tests__/ci_docs_only_test.sh
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/ci_docs_only.sh"
fail=0

check() {
  local want="$1" input="$2" got
  got=$(printf '%b' "$input" | bash "$SCRIPT")
  if [ "$got" != "$want" ]; then
    echo "FAIL: want $want got $got for: $input"
    fail=1
  fi
}

check true  'docs/a.md\n'
check true  'README.md\ntasks/todo.md\n.claude/rules/x.md\nmemory/m.txt\nlib/notes/readme.md\n'
check false 'docs/a.md\nlib/main.dart\n'
check false '.github/workflows/test.yml\n'
check false 'pubspec.yaml\n'
check false 'functions/src/index.ts\n'
check false ''
check false '\n'
check false 'docsfoo/x.dart\n'

if [ "$fail" -eq 0 ]; then echo "ci_docs_only: all fixtures passed"; fi
exit "$fail"
