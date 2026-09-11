#!/usr/bin/env bash
# BUT-2061/BUT-1921: block committing a credential that matches a known key shape.
#
# This scan used to live as an inline `run:` string in lefthook.yml, and it could
# not fail a commit. Two independent defects, both measured 2026-09-11:
#
#   1. The command ended `... && echo Potential secrets detected! && exit 1 || true`.
#      `||` binds after the whole `&&` chain, so the `|| true` swallowed the
#      DELIBERATE `exit 1` on the secrets-found path, not just grep's benign
#      exit 1 meaning "no match". Every outcome of the step reported success.
#
#   2. The `run:` value was a YAML DOUBLE-QUOTED scalar, so the `'\n'` inside
#      `tr ' ' '\n'` was parsed by YAML into a real line break before any shell
#      saw it. That made this the only multi-line `run:` in the file, which is
#      what `sh: line 2:` in the BUT-2061 transcript points at.
#
# The exact input that produced that transcript's
# `[: <path>: binary operator expected` was NOT reproduced: running the parsed
# two-line string under `sh` and under `bash` with a two-file list exits 0 with
# no output. So the LOCATION is measured and the trigger is not, and no sentence
# here claims a cause for it.
#
# Living in a file rather than a YAML string is what removes defect 2 as a
# class: there is no second escaping layer between this text and the shell.
#
# Exit contract: 0 = clean, 1 = a match was found (or the scan could not run).
# Called from lefthook with the staged files as arguments.

set -uo pipefail

SELF_TEST=0
if [ "${1:-}" = "--self-test" ]; then
  SELF_TEST=1
  shift
fi

# AWS AKIA + Google AIza + OpenAI sk- + Stripe sk_live/sk_test + Slack bot
# tokens and webhooks + private-key bodies + npm/GitHub tokens + service
# accounts. Extended for Stripe and Slack by BUT-812; carried here verbatim.
PATTERN='(AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|sk-[a-zA-Z0-9]{20,}|sk_live_[A-Za-z0-9]{24,}|sk_test_[A-Za-z0-9]{24,}|xoxb-[0-9]+-[0-9]+-[A-Za-z0-9]+|hooks\.slack\.com/services/T[A-Z0-9]+/B[A-Z0-9]+/[A-Za-z0-9]+|-----BEGIN (RSA|EC) PRIVATE KEY|npm_[a-zA-Z0-9]{36}|ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|ghs_[a-zA-Z0-9]{36}|"type":[[:space:]]*"service_account")'

# The standard FlutterFire file ships client-side API keys by design.
EXCLUDE='firebase_options.dart'

if [ "$SELF_TEST" -eq 1 ]; then
  FIXTURE_DIR=$(mktemp -d)
  trap 'rm -rf "$FIXTURE_DIR"' EXIT

  # A shape the scan MUST catch. Split at build time so this file does not
  # itself carry a string matching its own pattern — a fixture that trips the
  # guard on the guard is how a self-test becomes uninstallable.
  printf 'const k = "AKIA%s";\n' "0123456789ABCDEF" \
    > "$FIXTURE_DIR/leaky.dart"
  printf 'const k = "not a credential";\n' > "$FIXTURE_DIR/clean.dart"
  printf 'const apiKey = "AIza%s";\n' "0123456789012345678901234567890abcd" \
    > "$FIXTURE_DIR/firebase_options.dart"

  GUARD="${BASH_SOURCE[0]}"
  FAILURES=0

  # `bash "$GUARD"`, never "$GUARD" directly: the file is committed mode 644, so
  # a direct call exits 126 on Linux before reading a line — which the
  # check_null_filter.sh self-test once scored as a fixture failing rather than
  # as a harness that never started.
  bash "$GUARD" "$FIXTURE_DIR/leaky.dart" >/dev/null 2>&1
  LEAKY_RC=$?
  bash "$GUARD" "$FIXTURE_DIR/clean.dart" >/dev/null 2>&1
  CLEAN_RC=$?
  bash "$GUARD" "$FIXTURE_DIR/firebase_options.dart" >/dev/null 2>&1
  EXCLUDED_RC=$?
  bash "$GUARD" >/dev/null 2>&1
  NO_ARGS_RC=$?
  SECRET_SCAN_PROBE_FORCE_GREP_RC=2 bash "$GUARD" "$FIXTURE_DIR/clean.dart" \
    >/dev/null 2>&1
  OUTAGE_RC=$?
  # The seam must not be usable to silence the guard: forcing 1 ("no match")
  # is rejected, so the leaky fixture still fails.
  SECRET_SCAN_PROBE_FORCE_GREP_RC=1 bash "$GUARD" "$FIXTURE_DIR/leaky.dart" \
    >/dev/null 2>&1
  SEAM_ABUSE_RC=$?

  for rc in "$LEAKY_RC" "$CLEAN_RC" "$EXCLUDED_RC" "$NO_ARGS_RC" \
            "$OUTAGE_RC" "$SEAM_ABUSE_RC"; do
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; then
      echo "SELF-TEST FAIL: the guard could not be run (exit $rc)." >&2
      echo "This is the harness, not the fixtures — check $GUARD." >&2
      FAILURES=$((FAILURES + 1))
    fi
  done

  if [ "$FAILURES" -eq 0 ]; then
    # The case the inline version could not satisfy in ANY input: a found
    # secret must make the process exit non-zero. This assertion is the whole
    # reason the guard moved out of lefthook.yml.
    if [ "$LEAKY_RC" -ne 1 ]; then
      echo "SELF-TEST FAIL: a credential-shaped string did NOT fail the scan." >&2
      FAILURES=$((FAILURES + 1))
    fi

    if [ "$CLEAN_RC" -ne 0 ]; then
      echo "SELF-TEST FAIL: an ordinary string was flagged as a credential." >&2
      FAILURES=$((FAILURES + 1))
    fi

    if [ "$EXCLUDED_RC" -ne 0 ]; then
      echo "SELF-TEST FAIL: firebase_options.dart was not excluded." >&2
      FAILURES=$((FAILURES + 1))
    fi

    if [ "$NO_ARGS_RC" -ne 0 ]; then
      echo "SELF-TEST FAIL: an empty file list should be a clean pass." >&2
      FAILURES=$((FAILURES + 1))
    fi

    # A scan that could not RUN must not be indistinguishable from one that
    # found nothing. This is the defect class BUT-2061 was filed about.
    if [ "$OUTAGE_RC" -ne 1 ]; then
      echo "SELF-TEST FAIL: a failed grep was reported as a clean scan." >&2
      FAILURES=$((FAILURES + 1))
    fi

    if [ "$SEAM_ABUSE_RC" -ne 1 ]; then
      echo "SELF-TEST FAIL: the probe seam silenced a real detection." >&2
      FAILURES=$((FAILURES + 1))
    fi
  fi

  if [ "$FAILURES" -ne 0 ]; then
    echo "check_secret_scan.sh no longer detects what it claims to." >&2
    exit 1
  fi

  echo "check_secret_scan.sh self-test: detection, exclusion and exit code all OK."
  exit 0
fi

# No files matched the glob. Nothing to scan is a clean pass.
if [ "$#" -eq 0 ]; then
  exit 0
fi

TARGETS=()
for f in "$@"; do
  case "$f" in
    *"$EXCLUDE") continue ;;
  esac
  # A staged path can name a file that no longer exists on disk (a staged
  # delete). grep would report that as an error, and an error must not read as
  # "no secrets" — skipping it here keeps the two outcomes distinguishable.
  [ -f "$f" ] || continue
  TARGETS+=("$f")
done

if [ "${#TARGETS[@]}" -eq 0 ]; then
  exit 0
fi

# `-H` is load-bearing with a single file argument: without it grep prints the
# matching line and not the path, and the message below would name no file.
HITS=$(grep -lE "$PATTERN" "${TARGETS[@]}")
GREP_RC=$?

# Test seam for the branch below, which no fixture can reach portably: making
# grep fail needs an unreadable file, and Windows ignores the permission bits
# this repo's guards run under. Without the seam that branch survives a mutation
# probe — measured 2026-09-11, and it is the one branch whose failure mode is an
# outage reading as a clean scan.
#
# The override is accepted ONLY for values above 1, so it can force the guard to
# FAIL and can never be used to make it pass. A bypass spelled `=1` would be a
# way to disarm a security gate with an environment variable.
if [ "${SECRET_SCAN_PROBE_FORCE_GREP_RC:-}" -gt 1 ] 2>/dev/null; then
  GREP_RC="$SECRET_SCAN_PROBE_FORCE_GREP_RC"
fi

# grep's contract: 0 = matched, 1 = no match, >1 = it failed. Only the first is
# a finding, and only the third is an outage — collapsing >1 into either is the
# shape that made the inline version indistinguishable from a working guard.
if [ "$GREP_RC" -gt 1 ]; then
  echo "❌ secret-scan could NOT run (grep exit $GREP_RC)." >&2
  echo "   Treated as a failure, not as a clean scan: a guard that cannot run" >&2
  echo "   must not be indistinguishable from one that found nothing." >&2
  exit 1
fi

if [ "$GREP_RC" -eq 0 ]; then
  echo "❌ Potential secrets detected in:"
  echo "$HITS" | sed 's/^/   /'
  echo ""
  echo "These files match a known credential shape (AWS/Google/OpenAI/Stripe/"
  echo "Slack/GitHub/npm token, private key body, or a service-account JSON)."
  echo "Move the value to an environment variable or Secret Manager. If it is a"
  echo "false positive, narrow the pattern in tools/check_secret_scan.sh and add"
  echo "a self-test case for the shape you just excluded."
  exit 1
fi

exit 0
