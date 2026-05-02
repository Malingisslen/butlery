#!/usr/bin/env bash
# Orchestrates the 12-prompt forensic analysis via OpenAI Codex CLI.
# Honors the Wave model from docs/analysis/CODEX_RUN_GUIDE.md:
#   Wave 1 (parallel): 01, 02, 05
#   Wave 2 (parallel): 03, 04, 06
#   Wave 3 (parallel): 07, 08, 09, 10
#   Wave 4 (parallel): 11, 12   (depend on 01-10 outputs being on disk)
#   Synthesis (sequential)      (depends on all 12)
#
# Usage:
#   scripts/run-codex-analysis.sh              # run everything
#   scripts/run-codex-analysis.sh 01 05        # run specific prompts only (skips wave logic)
#   scripts/run-codex-analysis.sh synthesis    # synthesis only
#   SEQUENTIAL=1 scripts/run-codex-analysis.sh # disable wave parallelism (one at a time)
#   DRY_RUN=1    scripts/run-codex-analysis.sh # print what would run, do nothing
#
# Reruns are idempotent: if NN-*.md already exists, that prompt is skipped.
# Delete the file (or pass the prompt number explicitly) to force re-run.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RUN_DIR="docs/analysis/runs/2026-05-codex"
LOG_DIR="$RUN_DIR/_logs"
mkdir -p "$LOG_DIR"

# Topic slugs match the orchestrator's expected output filenames.
declare -A TOPIC=(
  [01]="code-quality"        [02]="security"            [03]="infrastructure"
  [04]="performance"         [05]="dependencies"        [06]="user-experience"
  [07]="ai-llm-quality"      [08]="product-analytics"   [09]="trust-safety-privacy"
  [10]="monetization"        [11]="legal"               [12]="doc-drift"
)

# Knowledge file injection map per CODEX_RUN_GUIDE.md.
declare -A KFILES=(
  [01]="testing-specialist performance-optimizer"
  [02]="firebase-backend-security firestore-rules-tester"
  [03]="e2e-test-specialist testing-specialist cloud-functions-specialist"
  [04]="performance-optimizer cloud-functions-specialist"
  [05]=""
  [06]="uiux-designer"
  [07]="cloud-functions-specialist"
  [08]=""
  [09]="firebase-backend-security cloud-functions-specialist"
  [10]=""
  [11]="firebase-backend-security"
  [12]="cloud-functions-specialist e2e-test-specialist firebase-backend-security firestore-rules-tester performance-optimizer testing-specialist uiux-designer"
)

# Prompt filename stems (NN_*.md in docs/analysis/prompts/).
declare -A PROMPT_FILE=(
  [01]="01_CODE_QUALITY_AND_ARCHITECTURE.md"
  [02]="02_SECURITY_AND_COMPLIANCE.md"
  [03]="03_INFRASTRUCTURE_AND_OPERATIONS.md"
  [04]="04_PERFORMANCE_AND_SCALABILITY.md"
  [05]="05_DEPENDENCIES_AND_SUPPLY_CHAIN.md"
  [06]="06_USER_EXPERIENCE_AND_PLATFORM.md"
  [07]="07_AI_LLM_QUALITY_AND_RELIABILITY.md"
  [08]="08_PRODUCT_ANALYTICS_AND_GROWTH.md"
  [09]="09_TRUST_SAFETY_AND_PRIVACY.md"
  [10]="10_MONETIZATION_AND_COMPETITIVE_POSITIONING.md"
  [11]="11_LEGAL_REVIEW.md"
  [12]="12_DOCUMENTATION_AND_OPERATIONAL_DRIFT.md"
)

build_prompt_for() {
  local n="$1"
  local topic="${TOPIC[$n]}"
  local prompt_file="${PROMPT_FILE[$n]}"
  local kfiles_block=""
  for k in ${KFILES[$n]}; do
    kfiles_block+="   - .claude/agents/${k}.knowledge.md"$'\n'
  done
  [[ -z "$kfiles_block" ]] && kfiles_block="   (none — this prompt is fully tool-agnostic; rely on the prompt + pre-analysis output)"$'\n'

  local extra_inputs=""
  if [[ "$n" == "11" || "$n" == "12" ]]; then
    extra_inputs="
Additional inputs (Wave 4): Read every existing report in $RUN_DIR/ before starting — your job depends on the findings already produced by prompts 01-10."
  fi

  cat <<PROMPT
You are running a forensic Phase 1 investigation on the Butlery codebase. Document findings only — make ZERO code changes. The ONLY file you may write is your final report at $RUN_DIR/${n}-${topic}.md. Use file:line references for every claim.

Read these files in order before producing any output:

1. docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md  (cross-prompt boundaries + dedup rules)
2. docs/analysis/prompts/${prompt_file}  (your specific prompt — follow its Output Format section exactly)
3. Knowledge files (treat the most recent dated entry as authoritative when entries conflict):
${kfiles_block}4. Pre-analysis tooling outputs in $RUN_DIR/_pre-analysis/  (already captured — do not re-run flutter commands)

Important context already known from the pre-analysis run:
- flutter analyze surfaced 1 real bug: ConsentPurpose undefined at lib/services/notifications/notification_service.dart:648.
- flutter test --coverage was terminated at ~45 min because test/views/helpers/infrastructure_integration_test.dart hangs every test on the 10-min default test timeout. 10122 tests passed cleanly before that file (89 skipped, 200 failed). The hang itself is a finding for testing infrastructure quality.
${extra_inputs}

Begin Phase 1 investigation now. Output the report in the format defined by the prompt's Output Format section. Save the final report to $RUN_DIR/${n}-${topic}.md and nothing else.
PROMPT
}

run_one() {
  local n="$1"
  local topic="${TOPIC[$n]}"
  local out="$RUN_DIR/${n}-${topic}.md"
  local log="$LOG_DIR/${n}.log"

  if [[ -s "$out" ]]; then
    echo "[skip] $n ($topic) — already exists at $out"
    return 0
  fi

  echo "[start] prompt $n ($topic) — log: $log"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "  DRY_RUN: would run codex exec for prompt $n"
    build_prompt_for "$n" | head -5
    return 0
  fi

  build_prompt_for "$n" \
    | codex exec --full-auto - \
        > "$log" 2>&1
  local rc=$?

  if [[ $rc -ne 0 ]]; then
    echo "[fail] prompt $n exited $rc — see $log"
    return $rc
  fi

  if [[ ! -s "$out" ]]; then
    echo "[fail] prompt $n finished but $out is empty/missing — see $log"
    return 1
  fi

  echo "[done] $n ($topic)"
}

run_synthesis() {
  local out="$RUN_DIR/SYNTHESIS.md"
  local log="$LOG_DIR/synthesis.log"

  if [[ -s "$out" ]]; then
    echo "[skip] synthesis — already exists at $out"
    return 0
  fi

  for n in 01 02 03 04 05 06 07 08 09 10 11 12; do
    local topic="${TOPIC[$n]}"
    if [[ ! -s "$RUN_DIR/${n}-${topic}.md" ]]; then
      echo "[abort] synthesis: prompt $n output missing at $RUN_DIR/${n}-${topic}.md"
      return 1
    fi
  done

  echo "[start] synthesis — log: $log"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "  DRY_RUN: would run synthesis"
    return 0
  fi

  cat <<'PROMPT' | codex exec --full-auto - > "$log" 2>&1
You are running the Final Synthesis pass for the Butlery forensic analysis.

Read in order:
1. docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md (specifically the Final Synthesis instructions)
2. All twelve Phase 1 reports at docs/analysis/runs/2026-05-codex/01-*.md through 12-*.md
3. docs/analysis/runs/2026-05-codex/_pre-analysis/ for the captured tooling state

Synthesize per the orchestrator's Final Synthesis instructions: weighted overall score, top risks/strengths, sprint-structured remediation roadmap, immediate-attention items.

Save the result to docs/analysis/runs/2026-05-codex/SYNTHESIS.md. Make no other file writes.
PROMPT
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "[fail] synthesis exited $rc — see $log"
    return $rc
  fi
  if [[ ! -s "$out" ]]; then
    echo "[fail] synthesis missing output — see $log"
    return 1
  fi
  echo "[done] synthesis"
}

run_wave() {
  local label="$1"; shift
  local prompts=("$@")
  echo
  echo "=== $label: ${prompts[*]} ==="
  if [[ "${SEQUENTIAL:-0}" == "1" ]]; then
    for n in "${prompts[@]}"; do run_one "$n" || true; done
  else
    local pids=()
    for n in "${prompts[@]}"; do
      run_one "$n" &
      pids+=($!)
    done
    local fail=0
    for pid in "${pids[@]}"; do wait "$pid" || fail=$((fail+1)); done
    [[ $fail -gt 0 ]] && echo "[warn] $label: $fail prompt(s) reported failure — continuing to next wave"
  fi
}

# Argument handling: explicit prompt numbers, "synthesis", or empty (full run).
if [[ $# -gt 0 ]]; then
  for arg in "$@"; do
    if [[ "$arg" == "synthesis" ]]; then
      run_synthesis
    elif [[ -n "${TOPIC[$arg]:-}" ]]; then
      run_one "$arg" || true
    else
      echo "[error] unknown argument: $arg" >&2
      exit 1
    fi
  done
  exit 0
fi

# Full run — wave by wave.
run_wave "Wave 1" 01 02 05
run_wave "Wave 2" 03 04 06
run_wave "Wave 3" 07 08 09 10
run_wave "Wave 4" 11 12
run_synthesis

echo
echo "=== All done. Reports in $RUN_DIR/ ==="
ls -la "$RUN_DIR"/*.md 2>/dev/null
