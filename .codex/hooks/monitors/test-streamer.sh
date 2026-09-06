#!/usr/bin/env bash
# Stream flutter test results as Monitor notifications.
# Usage: test-streamer.sh [test-path ...] (defaults to test/unit test/widget)
set -uo pipefail

TEST_PATHS="${*:-test/unit test/widget}"

set +e
flutter test $TEST_PATHS --reporter=expanded 2>&1 | \
  grep --line-buffered -E '^\s*(✓|✗|✕|Skip:|Some tests failed|All tests passed|\+[0-9]+.*-[0-9]+|[0-9]+ tests? passed)' || true
EXIT_CODE=${PIPESTATUS[0]}
set -e

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "flutter test exited with code $EXIT_CODE"
fi
