export const meta = {
  name: 'sprint-execute-parallel',
  description: 'Full-auto sprint: select Linear tickets, implement area-clusters in parallel worktrees, review, commit, push, close tickets',
  whenToUse: 'Run a complete Butlery sprint end-to-end with parallel implementation. Mirrors the /sprint-execute skill but fans implementation across isolated git worktrees and ships autonomously (commit + push to main + Linear close). Pass args {count, focus, dryRun} to override defaults.',
  phases: [
    { title: 'Select', detail: 'Query Linear + git + todo.md, score, cluster by area, write tasks/todo.md, transition tickets to Todo' },
    { title: 'Implement', detail: 'One agent per area-cluster in an isolated worktree; emits a git patch' },
    { title: 'Integrate', detail: 'Apply all batch patches into the main tree, full dart analyze' },
    { title: 'Review', detail: 'Per-batch code-reviewer + testing-specialist (+ security/rules/functions specialists when relevant); gates the commit markers' },
    { title: 'Fix', detail: 'Address Critical/High findings inline (conditional)' },
    { title: 'Ship', detail: 'Touch only earned markers, commit, push to main, close exact tickets, file follow-ups, prune worktrees' },
  ],
}

// ── args ─────────────────────────────────────────────────────────────────
// args = { count?: number, focus?: string, dryRun?: boolean, allowDirty?: boolean }
// Defensive parse: args can arrive as an object OR (footgun) as a JSON string.
// A stringified arg would otherwise leave every flag undefined — and dryRun:true
// silently becoming dryRun:false once shipped a full sprint to main. Never again.
let A = args
if (typeof A === 'string') {
  try { A = JSON.parse(A) } catch (_) { A = {} }
}
if (!A || typeof A !== 'object') A = {}

const COUNT = A.count ? A.count : null        // null → auto-size 6–10
const FOCUS = A.focus ? A.focus : null        // area label filter
const DRY_RUN = A.dryRun === true || A.dryRun === 'true'
const ALLOW_DIRTY = A.allowDirty === true || A.allowDirty === 'true'

const SKILL = '.claude/commands/sprint-execute.md'
// Patches live in the MAIN repo's .claude/state/sprint-patches, derived from the
// shared git-common-dir so every worktree resolves to the SAME absolute location
// (Fix 1 — a worktree-relative path used to leave patches stranded inside the
// worktree, unreadable by the integration agent). .claude/state/ is gitignored,
// so the dir never gets swept into `git add -A`.
const PATCH_DIR_EXPR = '"$(git rev-parse --git-common-dir)/../.claude/state/sprint-patches"'

// ── Phase 0: clean-tree precondition ───────────────────────────────────────
// The Integrate/Ship phases run `git add -A`, which would otherwise sweep any
// pre-existing uncommitted work into the sprint commit — wrong message, wrong
// tickets closed. Refuse to run on a dirty tree unless explicitly overridden.
// Skipped for dry-run (Fix 5 — a read-only preview is harmless on a dirty tree).
if (!DRY_RUN) {
  const treeState = await agent(
    `Report the working tree state. Run \`git status --porcelain\` and return JSON {clean: boolean, dirtyFiles: string[]} where clean means zero output.`,
    { label: 'precondition', phase: 'Select', schema: { type: 'object', required: ['clean'], properties: { clean: { type: 'boolean' }, dirtyFiles: { type: 'array', items: { type: 'string' } } } } }
  )
  if (treeState && treeState.clean === false && !ALLOW_DIRTY) {
    log(`✋ Aborting: working tree is dirty (${(treeState.dirtyFiles || []).length} file(s)). A sprint commits with \`git add -A\` and would bundle this in-flight work. Commit/stash it first, or pass args.allowDirty=true to override.`)
    return { status: 'aborted-dirty-tree', dirtyFiles: treeState.dirtyFiles || [] }
  }
}

// ── schemas ──────────────────────────────────────────────────────────────
const TICKET = {
  type: 'object',
  required: ['id', 'title', 'priority', 'requiresPlanMode', 'files', 'change'],
  properties: {
    id: { type: 'string', description: 'BUT-XXXX' },
    title: { type: 'string' },
    priority: { type: 'number', description: '1=Urgent..4=Low' },
    labels: { type: 'array', items: { type: 'string' } },
    requiresPlanMode: { type: 'boolean', description: 'Phase 1.5 risk gate result' },
    files: { type: 'array', items: { type: 'string' }, description: 'Target file paths' },
    change: { type: 'string', description: 'One-line intended change' },
  },
}

const PLAN_SCHEMA = {
  type: 'object',
  required: ['sprintName', 'date', 'batches', 'obsolete'],
  properties: {
    sprintName: { type: 'string' },
    date: { type: 'string', description: 'YYYY-MM-DD from `date` command' },
    batches: {
      type: 'array',
      description: 'Area-clustered work units; each becomes one parallel worktree agent',
      items: {
        type: 'object',
        required: ['agentName', 'area', 'theme', 'tickets'],
        properties: {
          agentName: { type: 'string', description: 'e.g. "Agent A"' },
          area: { type: 'string', description: 'Single area label so files stay disjoint across batches' },
          theme: { type: 'string' },
          suggestedAgent: { type: 'string', description: 'flutter-developer | cloud-functions-specialist | etc. or "direct"' },
          tickets: { type: 'array', items: TICKET },
        },
      },
    },
    obsolete: {
      type: 'array',
      description: 'Tickets that git shows already done but Linear still has open',
      items: { type: 'object', required: ['id', 'reason'], properties: { id: { type: 'string' }, reason: { type: 'string' } } },
    },
    linearAvailable: { type: 'boolean' },
  },
}

const TICKET_RESULT = {
  type: 'object',
  required: ['id', 'status'],
  properties: {
    id: { type: 'string' },
    status: { type: 'string', enum: ['done', 'obsolete', 'plan-stale-done', 'failed'] },
    filesChanged: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string', description: 'Step-0 classification + what happened; for obsolete, the resolving commit SHA' },
  },
}

const BATCH_RESULT_SCHEMA = {
  type: 'object',
  required: ['batchName', 'area', 'patchPath', 'ticketResults', 'analyzeClean'],
  properties: {
    batchName: { type: 'string' },
    area: { type: 'string' },
    patchPath: { type: ['string', 'null'], description: 'Path to the .patch file, or null if no code changed' },
    ticketResults: { type: 'array', items: TICKET_RESULT },
    analyzeClean: { type: 'boolean', description: 'dart analyze --fatal-infos clean on changed files' },
    testsRun: { type: 'string', description: 'Which tests were run and their result' },
  },
}

const INTEG_SCHEMA = {
  type: 'object',
  required: ['appliedBatches', 'analyzeClean', 'conflicts'],
  properties: {
    appliedBatches: { type: 'array', items: { type: 'string' } },
    conflicts: { type: 'array', items: { type: 'object', properties: { batch: { type: 'string' }, detail: { type: 'string' } } } },
    analyzeClean: { type: 'boolean' },
    changedFiles: { type: 'array', items: { type: 'string' } },
  },
}

const REVIEW_SCHEMA = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['severity', 'file', 'issue'],
        properties: {
          severity: { type: 'string', enum: ['Critical', 'High', 'Medium', 'Low', 'Info'] },
          file: { type: 'string' },
          issue: { type: 'string' },
          fix: { type: 'string' },
        },
      },
    },
    summary: { type: 'string' },
  },
}

const SHIP_SCHEMA = {
  type: 'object',
  required: ['committed', 'pushed'],
  properties: {
    committed: { type: 'boolean' },
    sha: { type: 'string' },
    subject: { type: 'string' },
    pushed: { type: 'boolean' },
    closed: { type: 'array', items: { type: 'string' } },
    leftOpen: { type: 'array', items: { type: 'string' } },
    followUps: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
}

// ── Phase 1: Select ────────────────────────────────────────────────────────
phase('Select')

const selectPrompt = `You are running Phase 1 (Selection) of a Butlery sprint. Read ${SKILL} in full and follow Phase 1 + Phase 1.5 exactly.

Steps:
1. Verify Linear MCP is connected (try list_issues team "Butlery"). Set linearAvailable accordingly; if down, still produce a plan from tasks/todo.md + git if possible.
2. Gather IN PARALLEL: Linear backlog (states Backlog, Todo, In Progress, Triage), tasks/todo.md, and \`git log --since="7 days ago" --oneline --no-merges\`.
3. Score each open ticket per the skill's priority scoring. Map BUT-XXX in recent git → flag tickets already done but still open (put them in "obsolete"). EXCLUDE entirely any ticket whose labels contain "onboarding-reserved" — these are reserved human onboarding capstones (e.g. BUT-677, BUT-722); never score, select, transition, or implement them.
4. Select N tickets: ${COUNT ? `EXACTLY ${COUNT}` : 'auto-size 6–10 by backlog volume'}.${FOCUS ? ` Filter to area label "${FOCUS}" (warn if <3).` : ''}
5. CLUSTER tickets by area into batches so that each batch touches a DISJOINT set of files — this is critical: batches run in parallel worktrees and their patches are applied sequentially, so overlapping files would conflict. Never split one area across two batches. Assign each batch a single \`area\`.
6. For each ticket compute the Phase 1.5 \`requiresPlanMode\` flag.
7. Run \`date +%Y-%m-%d\` for the sprint date.
${DRY_RUN ? `8. DRY-RUN — READ-ONLY. Do NOT write tasks/todo.md. Do NOT transition any Linear ticket. Make zero mutations; only read and return the proposed plan.` : `8. Write tasks/todo.md in the skill's format (archive any prior sprint below a --- separator).
9. If Linear is up, transition each selected ticket to "Todo" (resolve state UUIDs once via list_issue_statuses, then save_issue per ticket).`}

${DRY_RUN ? 'NOTE: dry-run — selection only, fully read-only. The pipeline stops after this phase. Do not modify any file or Linear ticket.' : ''}

Return the structured plan. Estimate \`files\` per ticket from a quick code read so the implementation agents start with a target.`

const plan = await agent(selectPrompt, { label: 'select', phase: 'Select', schema: PLAN_SCHEMA })

if (!plan || !plan.batches || plan.batches.length === 0) {
  log('No tickets selected — nothing to do.')
  return { status: 'empty', plan }
}

log(`Selected ${plan.batches.reduce((n, b) => n + b.tickets.length, 0)} tickets across ${plan.batches.length} batch(es): ${plan.batches.map(b => `${b.agentName}[${b.area}]`).join(', ')}`)

if (DRY_RUN) {
  log('Dry-run: stopping after selection.')
  return { status: 'dry-run', plan }
}

// ── Phase 2: Implement (parallel, isolated worktrees) ──────────────────────
phase('Implement')

// A batch is "mechanical" when every ticket is non-risk-gated and low-stakes
// (priority Medium/Low). Such batches run on sonnet to cut cost (Fix 7).
const isMechanical = (batch) =>
  batch.tickets.every(t => !t.requiresPlanMode && (t.priority || 4) >= 3)

const built = (await parallel(plan.batches.map((batch, i) => () => {
  const ticketList = batch.tickets.map(t =>
    `- ${t.id} (P${t.priority}${t.requiresPlanMode ? ', RISK-GATED' : ''}): ${t.title}\n    files: ${(t.files || []).join(', ') || 'discover'}\n    change: ${t.change}`
  ).join('\n')
  const implPrompt = `You are "${batch.agentName}" implementing the "${batch.area}" cluster of a Butlery sprint, in your own isolated git worktree. Read ${SKILL} and follow Phase 2 (Step 0 + per-task steps) and Phase 1.5 discipline exactly.

Your tickets:
${ticketList}

MANDATORY per-ticket Step 0 BEFORE any code: read the actual code, classify Fits / Premise-gone / Plan-stale. Current code-read wins over ticket text.
- Premise-gone → don't code; record status "obsolete" with the resolving commit SHA in notes.
- Plan-stale → re-scope, edit the Linear ticket body via save_issue, then implement (status "plan-stale-done").
- Fits → implement (status "done").
For RISK-GATED tickets: do NOT call EnterPlanMode (loop must not halt). Instead echo the "Risky-ticket plan" block per Phase 1.5 in your reasoning, then proceed.

Use the suggested specialist's conventions (${batch.suggestedAgent || 'direct implementation'}) but implement directly — you cannot spawn sub-agents.

After implementing ALL tickets in this batch:
1. \`/c/tools/flutter/bin/dart format\` the files you changed, then \`dart analyze --fatal-infos\` on them. Fix issues. Set analyzeClean.
2. Run the corresponding test/unit/<area>/ tests if they exist; record result in testsRun.
3. CRITICAL — emit your changes as a patch to a SHARED location, then clean your worktree (do NOT git commit):
   \`PATCHDIR=${PATCH_DIR_EXPR}; mkdir -p "$PATCHDIR"\`
   \`git add -A\`
   \`git diff --cached --binary > "$PATCHDIR/batch-${i}.patch"\`
   \`ABS=$(cd "$PATCHDIR" && pwd)/batch-${i}.patch; echo "$ABS"\`
   \`git reset --hard && git clean -fd\`   # leave the worktree clean so it auto-removes
   Verify the patch is non-empty BEFORE the reset. If you changed nothing (all obsolete), do NOT write a patch and set patchPath to null.
   Return patchPath as the ABSOLUTE path printed in \$ABS (it must resolve from the main repo, not your worktree).

Stay strictly within the "${batch.area}" area — touching files another batch owns will cause an apply conflict.`
  return agent(implPrompt, {
    label: batch.agentName,
    phase: 'Implement',
    isolation: 'worktree',
    schema: BATCH_RESULT_SCHEMA,
    ...(isMechanical(batch) ? { model: 'sonnet' } : {}),
  })
}))).filter(Boolean)

const patches = built.filter(b => b.patchPath).map(b => b.patchPath)
log(`Implementation done: ${built.length} batch(es), ${patches.length} with code changes.`)

// ── Phase 3: Integrate (apply patches into the main tree) ───────────────────
phase('Integrate')

let integ = { appliedBatches: [], analyzeClean: true, conflicts: [], changedFiles: [] }
if (patches.length > 0) {
  const integPrompt = `You are integrating parallel sprint batches into the main working tree. The batches were implemented in isolated worktrees and exported as patch files. Apply them sequentially.

Patches (in order):
${built.filter(b => b.patchPath).map(b => `- ${b.batchName} [${b.area}]: ${b.patchPath}`).join('\n')}

For each patch:
1. \`git apply --3way --whitespace=fix <patchPath>\`.
2. If it applies cleanly, add the batch name to appliedBatches.
3. If it conflicts, record {batch, detail} in conflicts and SKIP that batch (\`git checkout -- .\` only the conflicted hunks if needed) — do not force a broken merge. Area-clustering should make conflicts rare; a conflict means two batches touched the same file (a selection bug).

After applying all clean patches:
4. Run \`/c/tools/flutter/bin/dart format lib test\` then \`dart analyze --fatal-infos\`. Fix trivial issues (unused imports, format). Set analyzeClean.
5. Return the union of changed files (\`git status --porcelain\`).

Do NOT commit. Leave changes unstaged in the working tree for the review phase.`
  integ = await agent(integPrompt, { label: 'integrate', phase: 'Integrate', schema: INTEG_SCHEMA }) || integ
}

if (integ.conflicts && integ.conflicts.length > 0) {
  log(`⚠ ${integ.conflicts.length} batch(es) failed to apply (conflict): ${integ.conflicts.map(c => c.batch).join(', ')}`)
}

if (!integ.changedFiles || integ.changedFiles.length === 0) {
  log('No changes landed in the working tree — nothing to review or ship.')
  return { status: 'no-changes', plan, built, integ }
}

// ── Phase 4: Review (authoritative — gates the marker files) ─────────────────
// Reviewed PER BATCH, scoped to that batch's files, not one giant diff — agents
// stall on large file sets (memory: feedback_agent_timeout.md), so a 30+ file
// single review is unreliable (Fix 3). Area-clustering keeps cross-batch issues
// rare; each reviewer sees only its batch's handful of files.
phase('Review')

const appliedNames = new Set(integ.appliedBatches || [])
const reviewTargets = built.filter(b => b.patchPath && appliedNames.has(b.batchName))
const batchFiles = (b) => [...new Set((b.ticketResults || []).flatMap(t => t.filesChanged || []))]

// Path patterns mirror the commit-gate hook table in CLAUDE.md, so a marker is
// only ever touched after the specialist that owns it genuinely ran (Fix 4).
const backendRe = /^(lib\/repositories\/|lib\/services\/(firebase|firestore|auth|user|gdpr)|functions\/src\/)/
const rulesRe = /(^firestore\.rules$|functions\/src\/__tests__\/.*-rules\.test\.ts$)/
const functionsRe = /^functions\/src\/(?!__tests__\/)/

const matches = (b, re) => batchFiles(b).some(f => re.test(f))
const needBackend = reviewTargets.filter(b => matches(b, backendRe))
const needRules = reviewTargets.filter(b => matches(b, rulesRe))
const needFns = reviewTargets.filter(b => matches(b, functionsRe))

const scopeOf = (b) => {
  const files = batchFiles(b)
  return files.length ? `ONLY these files (from the current working tree): ${files.join(', ')}` : `the files this batch changed (derive from \`git status\` / \`git diff\`)`
}

const reviewTasks = []
for (const b of reviewTargets) {
  reviewTasks.push(() => agent(
    `Review ${scopeOf(b)}. Butlery sprint, "${b.area}" area. Focus on correctness bugs, architecture compliance (MVVM + Repository), project standards (PermissionValidationMixin on repos, data-source conventions, 500-line limit, withValues not withOpacity). Be specific with file + line.`,
    { label: `review:${b.area}`, phase: 'Review', agentType: 'code-reviewer', schema: REVIEW_SCHEMA }
  ).then(r => ({ kind: 'cr', r })))
  reviewTasks.push(() => agent(
    `Test-coverage review of ${scopeOf(b)}. Butlery sprint, "${b.area}" area. Identify lib/ changes lacking corresponding test/ updates, weakened assertions, or mocked-away subjects. Run affected tests if quick. Findings: High = untested new behavior, Medium = thin coverage.`,
    { label: `tests:${b.area}`, phase: 'Review', agentType: 'testing-specialist', schema: REVIEW_SCHEMA }
  ).then(r => ({ kind: 'ts', r })))
}
for (const b of needBackend) {
  reviewTasks.push(() => agent(
    `Security review of ${scopeOf(b)}. Butlery sprint, "${b.area}" area. Validate PermissionValidationMixin usage, Firestore security, auth/permission boundaries, GDPR compliance, and the data-source convention (userService.currentUserProfile vs permissionService.currentUserId). Be specific.`,
    { label: `security:${b.area}`, phase: 'Review', agentType: 'firebase-backend-security', schema: REVIEW_SCHEMA }
  ).then(r => ({ kind: 'fb', r })))
}
for (const b of needRules) {
  reviewTasks.push(() => agent(
    `Firestore rules review of ${scopeOf(b)}. Generate allow/deny cases for the diff and run the rules-unit-testing suite against the emulator if available; report gaps.`,
    { label: `rules:${b.area}`, phase: 'Review', agentType: 'firestore-rules-tester', schema: REVIEW_SCHEMA }
  ).then(r => ({ kind: 'rules', r })))
}
for (const b of needFns) {
  reviewTasks.push(() => agent(
    `Cloud Functions review of ${scopeOf(b)}. Butlery sprint. Check idempotency, retry semantics, region pinning (europe-west1), and cold-start cost. Be specific.`,
    { label: `functions:${b.area}`, phase: 'Review', agentType: 'cloud-functions-specialist', schema: REVIEW_SCHEMA }
  ).then(r => ({ kind: 'fns', r })))
}

const tagged = (await parallel(reviewTasks)).filter(Boolean)
const okFor = (kind, need) => need === 0 || tagged.filter(t => t.kind === kind && t.r).length === need
const crOk = okFor('cr', reviewTargets.length)
const tsOk = okFor('ts', reviewTargets.length)
const fbOk = okFor('fb', needBackend.length)
const rulesOk = okFor('rules', needRules.length)
const fnsOk = okFor('fns', needFns.length)

// Build the exact set of markers it is HONEST to touch (Fix 4). simplify-done is
// covered by the code-reviewer pass (it is the quality/simplification gate).
const markersToTouch = []
if (crOk) { markersToTouch.push('.claude/state/code-review-done.marker', '.claude/state/simplify-done.marker') }
if (tsOk) markersToTouch.push('.claude/state/testing-review-done.marker')
if (needBackend.length && fbOk) markersToTouch.push('.claude/state/firebase-security-done.marker')
if (needRules.length && rulesOk) markersToTouch.push('.claude/state/rules-tester-done.marker')
if (needFns.length && fnsOk) markersToTouch.push('.claude/state/cloud-functions-done.marker')

const reviewComplete = crOk && tsOk && fbOk && rulesOk && fnsOk

const allFindings = tagged.flatMap(t => (t.r && t.r.findings) || [])
const blocking = allFindings.filter(f => f.severity === 'Critical' || f.severity === 'High')
log(`Review: ${allFindings.length} finding(s), ${blocking.length} blocking. Reviewers complete — cr:${crOk} ts:${tsOk} security:${fbOk} rules:${rulesOk} fns:${fnsOk}.`)
if (!reviewComplete) {
  log('⚠ Some review agents did not complete — Ship will only touch markers for reviewers that finished; the commit hook will (correctly) block any gate that is missing until a real review runs.')
}

// ── Phase 5: Fix (conditional) ──────────────────────────────────────────────
phase('Fix')

if (blocking.length > 0) {
  const fixPrompt = `Fix these Critical/High review findings in the current working tree of a Butlery sprint. After fixing, run \`/c/tools/flutter/bin/dart format\` on touched files and \`dart analyze --fatal-infos\`. Do NOT commit.

Findings:
${blocking.map(f => `- [${f.severity}] ${f.file}: ${f.issue}${f.fix ? `\n    suggested: ${f.fix}` : ''}`).join('\n')}

If a finding is wrong or not worth fixing, say so with reasoning rather than papering over it.`
  await agent(fixPrompt, { label: 'fix-blocking', phase: 'Fix', schema: { type: 'object', properties: { fixed: { type: 'array', items: { type: 'string' } }, declined: { type: 'array', items: { type: 'string' } } } } })
} else {
  log('No blocking findings — skipping fix phase.')
}

// ── Phase 6: Ship (commit + push + Linear close + follow-ups) ───────────────
phase('Ship')

const doneResults = built.flatMap(b => b.ticketResults || [])
const obsoleteIds = [
  ...plan.obsolete.map(o => o.id),
  ...doneResults.filter(r => r.status === 'obsolete').map(r => r.id),
]
const doneIds = doneResults.filter(r => r.status === 'done' || r.status === 'plan-stale-done').map(r => r.id)
const failedIds = doneResults.filter(r => r.status === 'failed').map(r => r.id)
const conflictBatches = (integ.conflicts || []).map(c => c.batch)

const markerList = markersToTouch.join(' ')
const shipPrompt = `You are running Phase 3 (Post-sprint, MANDATORY) of a Butlery sprint. Read ${SKILL} Phase 3 + the Follow-up rule and follow them exactly.

Context:
- Tickets implemented (Done): ${doneIds.join(', ') || 'none'}
- Tickets obsolete (close as obsolete): ${obsoleteIds.join(', ') || 'none'}
- Tickets failed (leave open, move to Todo, comment the reason): ${failedIds.join(', ') || 'none'}
- Batches that failed to apply (their tickets did NOT land — treat as failed/open): ${conflictBatches.join(', ') || 'none'}
- Review findings total: ${allFindings.length} (blocking fixed: ${blocking.length})
- Review complete across all required specialists: ${reviewComplete}

Steps:
1. \`git status\` / \`git add -A\`. Final \`dart analyze --fatal-infos\` — fix anything fatal.
2. File Linear follow-up tickets for every deferred sub-scope / reviewer follow-up / test gap (see Follow-up rule). Capture the Medium/Low non-blocking review findings here. Record the new BUT-XXX ids.
3. Touch ONLY these marker files — they correspond to specialist reviews that genuinely completed in this pipeline. Touch NOTHING else, and NEVER use --no-verify to bypass a missing one:
   ${markerList ? `\`touch ${markerList}\`` : '(none — no reviewer completed; do NOT fake any marker)'}
   ${reviewComplete ? '' : 'NOTE: review was INCOMPLETE. If the commit hook blocks on a marker not in the list above, STOP — do not bypass. Leave changes uncommitted, set committed=false, explain in notes, and return so a human can run the missing review.'}
4. Write a conventional commit (feat/fix/refactor) with body: why + key changes + a "Known follow-ups (filed in Linear)" section listing the BUT-XXX from step 2. Footer EXACTLY: \`Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\`.
5. \`git commit\`. If lefthook reformats and the commit fails, re-stage all and commit again with the same message — never --amend, never --no-verify.
6. Verification gate: \`git status\` MUST show a clean tracked tree. Repeat step 5 until clean.
7. \`git push -u origin HEAD\`.
8. Close Linear tickets — close ONLY the EXACT ticket IDs listed here; do NOT infer, add, or close any other ticket even if it looks related or is referenced in the diff:
   - Done-state: ${doneIds.join(', ') || '(none)'} — comment "Fixed in commit <short-sha>: <subject>".
   - Obsolete: ${obsoleteIds.join(', ') || '(none)'} — comment "Obsolete — resolved by <sha>".
   - Move back to Todo with a failure comment: ${[...failedIds, ...conflictBatches].join(', ') || '(none)'}.
9. Clean up: \`rm -rf ${PATCH_DIR_EXPR}\` and \`git worktree prune\` (remove the per-batch worktrees that have been emptied).

Return the ship summary.`

// Ship is wrapped: a StructuredOutput miss here used to throw and discard the
// ENTIRE run (>1M tokens of completed+reviewed work) even though Ship's real
// work — commit/push/Linear — happens via side effects, not the return value.
// Catch it, then verify ground truth from git directly.
let ship = null
try {
  ship = await agent(shipPrompt, { label: 'ship', phase: 'Ship', schema: SHIP_SCHEMA })
} catch (e) {
  log('⚠ Ship did not return structured output (' + String(e && e.message || e).slice(0, 120) + '). Its commit/push/Linear side effects may still have landed — verifying git state directly.')
}

// Ground-truth verification — a short, focused agent that only reads git state,
// so the summary reflects reality even when Ship's self-report is missing.
const verify = await agent(
  `Report repo state after a sprint ship. Run \`git log -1 --format=%h%x20%s\`, \`git status --porcelain\`, and \`git rev-list --count @{u}..HEAD 2>/dev/null\`. Return JSON {headSha, headSubject, treeClean (porcelain empty), ahead (the count, 0 = pushed/in sync), pushed (ahead==0)}.`,
  { label: 'verify-ship', phase: 'Ship', schema: { type: 'object', required: ['headSha', 'treeClean', 'pushed'], properties: { headSha: { type: 'string' }, headSubject: { type: 'string' }, treeClean: { type: 'boolean' }, ahead: { type: 'number' }, pushed: { type: 'boolean' } } } }
) || {}

const shipOk = !!(ship && ship.committed && ship.pushed) || (verify.treeClean === true && verify.pushed === true)
if (!shipOk) {
  log(`⚠ Ship incomplete — headSha=${verify.headSha || '?'} treeClean=${verify.treeClean} pushed=${verify.pushed}. The integrated+reviewed work is in the tree; finish the commit/push/Linear manually before the next sprint.`)
}

// ── Final summary ───────────────────────────────────────────────────────────
return {
  status: shipOk ? 'complete' : 'ship-incomplete',
  sprint: plan.sprintName,
  date: plan.date,
  tickets: { done: doneIds, obsolete: obsoleteIds, failed: [...failedIds, ...conflictBatches] },
  conflicts: integ.conflicts,
  review: { total: allFindings.length, blockingFixed: blocking.length },
  commit: verify.headSha ? `${verify.headSha} ${verify.headSubject || ''}` : (ship && ship.sha ? `${ship.sha} ${ship.subject || ''}` : null),
  pushed: verify.pushed === true || (ship ? ship.pushed === true : false),
  treeClean: verify.treeClean,
  shipReportedStructuredOutput: !!ship,
  linearClosed: ship ? ship.closed : [],
  linearLeftOpen: ship ? ship.leftOpen : [],
  followUps: ship ? ship.followUps : [],
}
