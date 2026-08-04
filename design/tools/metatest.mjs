#!/usr/bin/env node
// Butlery · METATESTER: beteendeprov mot rapportlogiken. Kör: node tools/metatest.mjs
//
// Fas 0.8: proven matar konstruerade rapporter genom de RENA funktionerna i
// report-logic.mjs och kräver rätt slutsats. Tidigare var sju av nio prov
// källtextssökningar — de upptäckte inte att en manifestkrasch av fel orsak ändå
// passerade, eftersom de bara krävde "någon icke-nollkod".
import { readFileSync, writeFileSync, mkdtempSync, rmSync, mkdirSync, copyFileSync, existsSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { CONTROLS } from './controls.mjs';
import { GENERATORS, GENERATED_OUTPUTS, GENERATED_REGISTER } from './gen-targets.mjs';
import { checkAppTheme } from './check-app-theme.mjs';
import { renderMarkdown } from './gen-report.mjs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { classifyStep, reduceControls, computeTotals, countRequirements, DEPENDS_ON, manifestIntegrity, validateRegistry, validateReport, validateRegistryCoverage, parseEvidence, validateReportSchema, checkNamespaces } from './report-logic.mjs';

// PROCESSPROV — sanerad miljö och ÄNDLIG timeout.
//
// Fas 1 (fjärde vändan): M-07:s fixtur ärvde BUTLERY_MANIFEST_MODE=delivery från
// wrappern och startade check-manifest UTAN uttryckligt läge. Fixturen låg så
// grunt att zip-roten (../../..) blev "/", varpå manifestkontrollen började
// traversera hela filsystemet. Kedjan hängde på 100 % CPU och skrev aldrig
// METATEST-SUMMARY — direktkörning utan den ärvda miljön gav 34/34, vilket
// bevisade orsaken. Två skydd: ingen BUTLERY_*-variabel ärvs in i ett
// processprov, och en timeout räknas som TESTFEL i stället för att hänga.
const PROC_TIMEOUT_MS = Number(process.env.BUTLERY_METATEST_TIMEOUT_MS || 90000);
// Fas 1 (femte vändan): cleanEnv() sanerade basmiljön men opts.env kunde
// återinföra BUTLERY_* — gateEnv() spred process.env rakt igenom. Nu filtreras
// BÅDA leden: bara uttryckligen tillåtna CI- och fasvärden får skickas in.
const ALLOWED_CHILD_ENV = /^(GITHUB_(ACTIONS|RUN_ID|RUN_ATTEMPT|SHA|REPOSITORY|WORKFLOW)|RUNNER_OS|CI|BUTLERY_PHASE|BUTLERY_MANIFEST_MODE)$/;
const cleanEnv = (extra = {}) => {
  const e = { ...process.env };
  for (const k of Object.keys(e)) if (/^BUTLERY_/.test(k) || /^GITHUB_/.test(k) || /^RUNNER_/.test(k) || k === 'CI') delete e[k];
  for (const [k, v] of Object.entries(extra)) {
    if (!ALLOWED_CHILD_ENV.test(k)) continue;   // tysta bort allt annat
    e[k] = v;
  }
  return e;
};
export const __cleanEnvForTest = cleanEnv;
function runProc(bin, args, opts = {}) {
  const p = spawnSync(bin, args, {
    cwd: opts.cwd, encoding: 'utf8',
    timeout: opts.timeout ?? PROC_TIMEOUT_MS, killSignal: 'SIGKILL',
    env: cleanEnv(opts.env || {})
  });
  const out = (p.stdout || '') + (p.stderr || '');
  const timedOut = p.error && (p.error.code === 'ETIMEDOUT' || /ETIMEDOUT/.test(String(p.error)));
  return {
    code: timedOut ? 'TIMEOUT' : p.status,
    timedOut: !!timedOut,
    out: out + (timedOut ? '\n✖ processen avbröts efter ' + PROC_TIMEOUT_MS + ' ms' : '')
  };
}
const results = [];
const t = (name, ok, detail) => { results.push({ name, ok }); console.log((ok ? '✔ ' : '✖ ') + name + (detail ? ' — ' + detail : '')); };
// Ett kraschande testfall får INTE hindra resterande grupper eller summeringen.
// Fas 0.14: M-24 kastade ENOENT, ingen METATEST-SUMMARY skrevs, och M-25…M-27
// kördes aldrig i den kanoniska kedjan.
const group = (name, fn) => {
  try { fn(); }
  catch (e) { results.push({ name, ok: false }); console.error('✖ ' + name + ' KRASCHADE — ' + e.message); }
};

// Registerposter i CHK-format med fasfält — de gamla fixturerna använde råa id
// och saknade resolutionPhase/requiredForGate. Fas 0.11.
const ctrl = (legacyId, source, extra = {}) => ({
  id: 'CHK-' + legacyId, legacyId, name: legacyId, owner: 'DS', source,
  resolutionPhase: 0, requiredForGate: [], ...extra
});
const okManifest = { status: 'passed', exitCode: 0, expected: 5, parsed: 5, verified: 5, bad: 0, missing: 0, duplicates: 0, unlisted: 0, outsideAbsent: 0 };

// KANONISK rapportfixtur: byggd ur HELA CONTROLS med oförändrad source, owner,
// resolutionPhase och requiredForGate. Fas 0.14: M-23:s och M-24:s fixturer var
// beskurna och gav påhittad metadata, vilket krockade med registertäckningen.
// "Grön grind, röd total" modelleras genom att en kontroll UTANFÖR grinden är
// failed — inte genom en motsägelsefull totalsiffra.
// ── KANONISKA RAPPORTBYGGARE ────────────────────────────────────────────────
// Fas 0.17: fixturen hade handskrivna controls/tally/totaler som avvek från
// reduceringen — statiska kontroller lagrades som passed men reducerades till
// not run, schemaValidation saknades, och CI-kontexten var inte densamma i
// bygget som i grindkörningen. Nu byggs ALLT ur reduceControls/computeTotals.

// Deterministisk CI-miljö för de positiva fallen. Samma i fixturbygget och i
// barnprocessen, annars reduceras CHK-CI-01 olika.
const CI_ENV = {
  GITHUB_ACTIONS: 'true', GITHUB_RUN_ID: '12345678901', GITHUB_RUN_ATTEMPT: '1',
  GITHUB_SHA: 'b'.repeat(40), GITHUB_REPOSITORY: 'butlery/spec', GITHUB_WORKFLOW: 'verify'
};

// RÅ rapport: steg, summeringar, evidens och perControl. Inga statusrader.
function rawReport(opts = {}) {
  const now = opts.now ?? Date.now();
  const failOutsideGate = opts.failOutsideGate !== false;
  return {
    schema: 'butlery-verify-report/2', runId: '0123456789abcdef',
    generatedAt: new Date(now - 60000).toISOString(),
    canonicalCommand: 'bash fas0/run-verify.sh',
    sources: { 'tokens.json': { version: '1.9', inputSha256: 'a'.repeat(64) } },
    packageIdentity: { manifestSha256: 'AUTO', manifestExpected: 1, cwd: '/x', node: process.version,
      commit: CI_ENV.GITHUB_SHA, artifactFingerprint: { sha256: 'AUTOFP', mode: 'repo', declared: 1, hashed: 1, missing: 0, totalEntries: 1, outsideEntries: 0 } },
    steps: [
      { step: 'Rapportschema ur källan', script: 'tools/gen-schema.mjs', status: 'passed', exitCode: 0 },
      { step: 'Preflight: incheckad genererad kod', script: 'tools/preflight.mjs', status: 'passed', exitCode: 0 },
      { step: 'Ikonräkning', script: 'tools/gen-icons.mjs', status: 'passed', exitCode: 0 },
      { step: 'CSS ur tokens', script: 'tools/gen-css.mjs', status: 'passed', exitCode: 0 },
      { step: 'Flutter ur tokens', script: 'tools/gen-flutter.mjs', status: 'passed', exitCode: 0 },
      { step: 'Räkneankare', script: 'tools/gen-counts.mjs', status: 'passed', exitCode: 0 },
      { step: 'Kontrollgeometri', script: 'tools/lint-controls.mjs', status: 'passed', exitCode: 0 },
      { step: 'Genererad kod', script: 'tools/test-generated.mjs', status: 'passed', exitCode: 0 },
      { step: 'Spec-lint', script: 'tools/spec-lint.mjs', status: failOutsideGate ? 'failed' : 'passed', exitCode: failOutsideGate ? 1 : 0 },
      { step: 'Verifierarens egna mutationsprov', script: 'tools/selftest.mjs', status: 'passed', exitCode: 0 },
      { step: 'Metatester för verktygskedjan', script: 'tools/metatest.mjs', status: 'passed', exitCode: 0 }
    ],
    selftestSummary: { pass: 31, fail: 0, skipped: 0 },
    selftestCoverage: { runtime: 22, proven_negative: 16, exempt: 6, uncovered: 0 },
    metatestSummary: { pass: 31, fail: 0, total: 31 },
    preflightSummary: 'PREFLIGHT-SUMMARY checked=2 stale=0 tokens=1.9',
    measures: { specErrors: failOutsideGate ? 8 : 0, specWarnings: 0, geometryDeviations: 0, coverageErrors: 0 },
    manifest: { status: 'passed', exitCode: 0, expected: 1, parsed: 1, verified: 1, bad: 0, missing: 0, duplicates: 0, unlisted: 0, outsideAbsent: 0 },
    manifestMode: 'repo', requirements: { total: 429, byStatus: { verifierad: 85 } },
    ranControls: CONTROLS.filter(c => c.source === 'spec-lint').map(c => c.legacyId).filter(Boolean),
    perControl: failOutsideGate ? { 'T-02': { errors: 8, warnings: 0 } } : {},
    generatedDrift: [],
    schemaArtifact: { missing: false, drift: false, deliveredSha256: 'c'.repeat(64) },
    schemaValidation: { ok: true, problems: [] },
    inputSchemaValidation: { ok: true, problems: [] },
    chainExitCode: failOutsideGate ? 1 : 0,
    currentPhase: 0,
    ciEvidence: {
      schema: 'butlery-ci-evidence/2', ciProvider: 'github-actions', githubActions: 'true',
      runId: CI_ENV.GITHUB_RUN_ID, runAttempt: CI_ENV.GITHUB_RUN_ATTEMPT,
      repository: CI_ENV.GITHUB_REPOSITORY, workflow: CI_ENV.GITHUB_WORKFLOW,
      commit: CI_ENV.GITHUB_SHA, manifestSha256: 'AUTO',
      verifyExitCode: failOutsideGate ? 1 : 0,
      startedAt: new Date(now - 120000).toISOString(),
      completedAt: new Date(now - 90000).toISOString()
    },
    ...(opts.report || {})
  };
}

// Kör den RIKTIGA reduceringen och de riktiga totalerna på en rå rapport.
function reduceInto(r, ciEnv = CI_ENV) {
  r.controls = reduceControls(CONTROLS, {
    ciEvidence: r.ciEvidence, packageIdentity: r.packageIdentity,
    chainExitCode: r.chainExitCode, ciEnv,
    selftestSummary: r.selftestSummary, selftestCoverage: r.selftestCoverage,
    metatestSummary: r.metatestSummary, preflightSummary: r.preflightSummary,
    perControl: r.perControl, measures: r.measures, steps: r.steps,
    ranControls: r.ranControls, manifest: r.manifest,
    manifestMode: r.manifestMode, generatedDrift: r.generatedDrift,
    schemaArtifact: r.schemaArtifact, schemaValidation: r.schemaValidation
  });
  r.tally = { passed: 0, failed: 0, blocked: 0, 'not run': 0, 'not applicable': 0 };
  for (const c of r.controls) r.tally[c.status] = (r.tally[c.status] || 0) + 1;
  Object.assign(r, computeTotals({
    steps: r.steps, controls: r.controls, manifest: r.manifest,
    generatedDrift: r.generatedDrift, manifestMode: r.manifestMode, currentPhase: r.currentPhase ?? 0
  }));
  r.result = r.overallResult;
  return r;
}

// FINALISERAD rapport, som grinden kräver.
function finalizedGateReport(opts = {}) {
  const r = reduceInto(rawReport(opts), opts.ciEnv ?? CI_ENV);
  r.finalized = true;
  r.finalizedAt = new Date((opts.now ?? Date.now()) - 30000).toISOString();
  r.generatedAt = r.generatedAt || new Date().toISOString();
  return r;
}

// Bakåtkompatibelt namn: samma kanoniska bygge.
function fullReport(opts = {}) { return finalizedGateReport(opts); }
const step = (script, status, extra = {}) => ({ step: script, script: 'tools/' + script + '.mjs', status, exitCode: status === 'failed' ? 1 : 0, specErrors: 0, specWarnings: 0, geometryDeviations: 0, ...extra });
const base = { perControl: {}, measures: {}, steps: [], ranControls: [], manifest: okManifest, generatedDrift: [], manifestMode: 'repo' };

/* M-01 · fällande stderr med exit 0 ska fälla steget */
group('M-01', () => {
    const a = classifyStep('✖ T-02 något gick fel\n', 0);
    const b = classifyStep('allt bra\n', 0);
    const c = classifyStep('LC-SUMMARY deviations=307 coverage_errors=1\n', 0);
    const d = classifyStep('SELFTEST-SUMMARY pass=16 fail=1 skipped=0\n', 0);
    t('M-01 · diagnostik på stderr + exit 0 fäller steget',
      a.status === 'failed' && a.integrity && b.status === 'passed' && c.status === 'failed' && d.status === 'failed');
});

/* M-02 · en failed kontroll gör totalen failed även när alla steg passerar */
group('M-02', () => {
    const controls = reduceControls([ctrl('T-02', 'spec-lint')],
      { ...base, perControl: { 'T-02': { errors: 8, warnings: 0 } }, ranControls: ['T-02'], steps: [step('spec-lint', 'passed')] });
    const tot = computeTotals({ steps: [step('spec-lint', 'passed')], controls, manifest: okManifest, generatedDrift: [] });
    t('M-02 · failed kontroll trots passed steg ger overallResult failed',
      controls[0].status === 'failed' && tot.pipelineResult === 'passed' && tot.overallResult === 'failed' && tot.exitCode === 1,
      'kontroll ' + controls[0].status + ' · pipeline ' + tot.pipelineResult + ' · total ' + tot.overallResult);
});

/* M-03 · diagnostik kan aldrig reduceras till passed */
group('M-03', () => {
    const rows = reduceControls([ctrl('LC-01', 'lint-controls'), ctrl('ST-01', 'selftest')],
      { ...base, measures: { geometryDeviations: 0, coverageErrors: 2 },
        selftestSummary: { pass: 16, fail: 1, skipped: 0 },
        steps: [step('lint-controls', 'passed'), step('selftest', 'passed')] });
    t('M-03 · täckningsfel och fällt självtest kan inte ge passed',
      rows[0].status === 'failed' && rows[1].status === 'failed',
      'LC-01 ' + rows[0].status + ' · ST-01 ' + rows[1].status);
});

/* M-04 · GEN-01 som ENDA fel ger exit 1 */
group('M-04', () => {
    // Fullständigt giltigt manifest, så provet ISOLERAR GEN-01.
    const controls = reduceControls([ctrl('GEN-01', 'wrapper')], { ...base, generatedDrift: ['icons.json'] });
    const tot = computeTotals({ steps: [step('spec-lint', 'passed')], controls, manifest: okManifest, generatedDrift: ['icons.json'] });
    t('M-04 · GEN-01 ensam ger overallResult failed och exit 1',
      controls[0].status === 'failed' && tot.overallResult === 'failed' && tot.finalExitCode === 1);
});

/* M-05 · producent faller, konsument passerar mot gammal fil → blocked */
group('M-05', () => {
    const controls = reduceControls([ctrl('TG-01', 'test-generated')],
      { ...base, steps: [step('gen-css', 'failed'), step('test-generated', 'passed')] });
    const tot = computeTotals({ steps: [step('gen-css', 'failed'), step('test-generated', 'passed')], controls, manifest: okManifest, generatedDrift: [] });
    t('M-05 · konsument blir blocked trots passed, och blocked fäller totalen',
      controls[0].status === 'blocked' && controls[0].blockedBy === 'gen-css' && tot.controlsResult === 'failed',
      'TG-01 ' + controls[0].status);
});

/* M-06 · T-06 är delad: usages blockeras, sökvägar mäts vidare */
group('M-06', () => {
    const ctx = { ...base, perControl: { 'T-06a': { errors: 57 }, 'T-06b': { errors: 1 } },
      ranControls: ['T-06a', 'T-06b'], steps: [step('gen-icons', 'failed'), step('spec-lint', 'failed', { specErrors: 58 })] };
    const rows = reduceControls([ctrl('T-06a', 'spec-lint'), ctrl('T-06b', 'spec-lint')], ctx);
    t('M-06 · T-06a blocked av gen-icons, T-06b självständigt failed',
      rows[0].status === 'blocked' && rows[1].status === 'failed' && !rows[1].blockedBy,
      'T-06a ' + rows[0].status + ' · T-06b ' + rows[1].status);
    t('M-06b · beroendegrafen pekar bara på usages-delen (CHK-form)',
      !!DEPENDS_ON['CHK-T-06a'] && !DEPENDS_ON['CHK-T-06b'] && !DEPENDS_ON['CHK-T-06'] && !DEPENDS_ON['T-06a']);
});

/* M-07 · manifestet: noll poster, fel hash, och krasch av FEL orsak */
group('M-07', () => {
    const dir = mkdtempSync(join(tmpdir(), 'butlery-mt-'));
    mkdirSync(join(dir, 'fas0'), { recursive: true });
    // HELA runtimeberoendet. Fas 0.16: check-manifest.mjs importerar numera
  // tools/report-logic.mjs, och barnprocesserna dog med ERR_MODULE_NOT_FOUND.
  mkdirSync(join(dir, 'tools'), { recursive: true });
  copyFileSync('fas0/check-manifest.mjs', join(dir, 'fas0/check-manifest.mjs'));
  copyFileSync('tools/report-logic.mjs', join(dir, 'tools/report-logic.mjs'));
    // UTTRYCKLIGT repo-läge: fixturen är ingen leverans, och auto/delivery skulle
    // leta efter en leveransrot som inte finns.
    const run = () => runProc(process.execPath, ['fas0/check-manifest.mjs', '--mode=repo'], { cwd: dir });

    writeFileSync(join(dir, 'fas0/andrade-filer.md'), '# tom\n<!--manifest:files=0-->\n');
    const empty = run();
    t('M-07a · noll poster fäller MED rätt orsak',
      empty.code !== 0 && /parsade noll rader|saknar <!--manifest/.test(empty.out), 'exit ' + empty.code);

    writeFileSync(join(dir, 'fas0/andrade-filer.md'),
      '# fel hash\n<!--manifest:files=1-->\n\n## Reporoten\n\n| Fil | SHA-256 |\n|---|---|\n| \`fas0/check-manifest.mjs\` | \`' + '0'.repeat(64) + '\` |\n');
    const badHash = run();
    t('M-07b · fel hash fäller MED hashdiagnostik',
      badHash.code !== 0 && /✖ hash:/.test(badHash.out) && /bad=1/.test(badHash.out), 'exit ' + badHash.code);

    writeFileSync(join(dir, 'fas0/andrade-filer.md'), '# utan deklaration\n\n## Reporoten\n\n| Fil | SHA-256 |\n|---|---|\n');
    const noDecl = run();
    t('M-07c · saknad files-deklaration fäller MED rätt orsak',
      noDecl.code !== 0 && /saknar <!--manifest:files/.test(noDecl.out), 'exit ' + noDecl.code);

    // Krasch av FEL orsak (ogiltig JS) får inte räknas som ett giltigt manifestfel.
    writeFileSync(join(dir, 'fas0/check-manifest.mjs'), 'throw new Error("krasch av annan orsak");\n');
    const crash = run();
    t('M-07d · krasch av annan orsak ger ingen MANIFEST-SUMMARY',
      crash.code !== 0 && !/MANIFEST-SUMMARY/.test(crash.out), 'exit ' + crash.code);

    rmSync(dir, { recursive: true, force: true });
});

/* M-08 · not run och blocked godkänner aldrig grinden */
group('M-08', () => {
    // Fas 0.10: fasfältet heter requiredForGate, inte phase.
    const rows = [
      { id: 'A', status: 'passed', requiredForGate: [0] },
      { id: 'B', status: 'not run', requiredForGate: [0] }
    ];
    const gateFail = computeTotals({ steps: [], controls: rows, manifest: base.manifest, generatedDrift: [] });
    const later = [{ id: 'A', status: 'passed', requiredForGate: [0] }, { id: 'CHK-R-02', status: 'not run', resolutionPhase: 2, requiredForGate: [] }];
    const gateOk = computeTotals({ steps: [], controls: later, manifest: base.manifest, generatedDrift: [] });
    t('M-08 · not run i fasens scope fäller grinden, senare fas gör det inte',
      gateFail.phaseGateResult === 'failed' && gateOk.phaseGateResult === 'passed');
});

/* M-09 · manifest not run kan inte ge passed */
group('M-09', () => {
    const tot = computeTotals({ steps: [step('spec-lint', 'passed')], controls: [], manifest: { status: 'not run' }, generatedDrift: [] });
    t('M-09 · manifest not run ger overallResult failed', tot.overallResult === 'failed' && tot.exitCode === 1);
});

/* M-10 · kravstatus räknas ur matrisens rader */
group('M-10', () => {
    // Fas 0.10: syntetisk fixtur MED tabellhuvud och skiljelinje, plus en POSITIV
    // fixtur ur den VERKLIGA matrisen — en syntetisk rubrik bevisar inte att
    // parsern klarar källformatet.
    const md = ['## Kravmatris', '',
      '| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Status |',
      '|---|---|---|---|---|',
      '| K-01 | x | auth | \`#a\` | verifierad |',
      '| K-02 | y | auth | \`#b\` | implementerad |',
      '| K-03 | z | auth | — | beslutad |',
      '',
      '## Historik', '',
      '| Krav-ID | Normativ regel | Berörd vy | Skärmbevis | Status |',
      '|---|---|---|---|---|',
      '| K-04 | w | auth | — | implementerad | <!--hist-->'].join('\n');
    const r = countRequirements(md);
    const synthetic = r.total === 3 && r.byStatus.verifierad === 1 && r.byStatus.implementerad === 1 && r.byStatus.beslutad === 1 && (r.integrityProblems || []).length === 0;
    // POSITIV FIXTUR: den verkliga evidensmatrisen ska ge många rader och inga
    // strukturproblem av typen "kravrad utan tabellhuvud".
    let real = false, realDetail = 'evidensmatris.md saknas';
    if (existsSync('evidensmatris.md')) {
      const rr = countRequirements(readFileSync('evidensmatris.md', 'utf8'));
      const structural = (rr.integrityProblems || []).filter(p => /utan tabellhuvud|utanför en deklarerad/.test(p));
      real = rr.total > 300 && structural.length === 0;
      realDetail = rr.total + ' rader · ' + structural.length + ' strukturproblem · ' + JSON.stringify(rr.byStatus);
    }
    t('M-10 · kravstatus räknas maskinellt, hoppar historik och klarar det VERKLIGA formatet',
      synthetic && real, 'syntetisk ' + synthetic + ' · verklig: ' + realDetail);
});

/* M-11 · WRAPPERN: körs utan förinställda miljövariabler, i båda rötterna */
group('M-11', () => {
    const sh = readFileSync('fas0/run-verify.sh', 'utf8');
    const code = sh.split('\n').filter(l => !/^\s*#/.test(l)).join('\n');
    const weighs = /\[ "\$verify_code" -ne 0 \] && final=1/.test(code) && /\[ "\$manifest_code" -ne 0 \] && final=1/.test(code);
    const portableDate = !/date -Iseconds/.test(code) && /node -e ['"]console\.log\(new Date\(\)\.toISOString/.test(code);
    const exportsAll = ['EXPECTED', 'PARSED', 'VERIFIED', 'MODE'].every(k => new RegExp('BUTLERY_MANIFEST_' + k).test(sh));

    // RIKTIGT PROCESSTEST: alla variabler som används måste vara deklarerade.
    // Fas 0.13: 'zroot' användes men deklarerades aldrig, och med set -u kraschade
    // det dokumenterade huvudkommandot innan manifestkontrollen. En källregex
    // fångade det inte.
    const used = new Set([...code.matchAll(/\$\{?([a-z_][a-z0-9_]*)\}?/gi)].map(x => x[1]));
    const declared = new Set([...code.matchAll(/^\s*(?:export\s+)?([a-z_][a-z0-9_]*)=/gim)].map(x => x[1]));
    const builtins = new Set(['BASH_SOURCE', 'PIPESTATUS', 'PATH', 'HOME', 'PWD', 'IFS', 'BUTLERY_MANIFEST_MODE', 'BUTLERY_PHASE', 'BUTLERY_COMMIT', 'BUTLERY_CI', '1', '2']);
    const undeclared = [...used].filter(v => !declared.has(v) && !builtins.has(v) && !/^BUTLERY_/.test(v) && !/^[0-9]+$/.test(v));

    // Kör wrappern på riktigt i en kopia UTAN miljövariabler. Verktygen behöver
    // inte lyckas — men bash får inte falla på en odeklarerad variabel.
    const dir = mkdtempSync(join(tmpdir(), 'butlery-wrap-'));
    mkdirSync(join(dir, 'fas0'), { recursive: true });
    mkdirSync(join(dir, 'tools'), { recursive: true });
    copyFileSync('fas0/run-verify.sh', join(dir, 'fas0/run-verify.sh'));
    writeFileSync(join(dir, 'fas0/check-manifest.mjs'), 'console.log("MANIFEST-SUMMARY mode=repo expected=1 parsed=1 ok=1 bad=0 missing=0 duplicates=0 unlisted=0 outside_absent=0");process.exit(0);\n');
    writeFileSync(join(dir, 'tools/verify.mjs'), 'console.log("stub");process.exit(0);\n');
    const p = runProc('bash', ['fas0/run-verify.sh'], { cwd: dir, env: {} });
    const out = p.out;
    const noUnbound = !/unbound variable/.test(out);
    rmSync(dir, { recursive: true, force: true });

    t('M-11 · wrappern kör utan förinställd miljö och har inga odeklarerade variabler',
      weighs && portableDate && exportsAll && noUnbound && undeclared.length === 0,
      'väger ' + weighs + ' · datum ' + portableDate + ' · export ' + exportsAll +
      ' · unbound ' + (noUnbound ? 'nej' : 'JA: ' + out.split('\n').find(l => /unbound/.test(l))) +
      (undeclared.length ? ' · odeklarerade: ' + undeclared.join(', ') : ''));
});

/* M-12 · inget runtimekontroll bär hårdkodad status */
group('M-12', () => {
    const c = readFileSync('tools/controls.mjs', 'utf8');
    const bad = [...c.matchAll(/source: '(spec-lint|lint-controls|test-generated|selftest|metatest)'[^}]*status: '(passed|failed)'/g)];
    t('M-12 · ingen runtimekontroll har hårdkodad status', bad.length === 0, bad.length ? bad.length + ' hittade' : '');
});

/* M-13 · TABELLSTYRD INVARIANT: overall är passed ENDAST om alla nödvändiga
   delresultat är godkända. phaseGateResult räknades ut men ingick inte i totalen. */
group('M-13', () => {
    const goodManifest = { status: 'passed', exitCode: 0, expected: 5, parsed: 5, verified: 5, bad: 0, missing: 0, duplicates: 0, unlisted: 0, outsideAbsent: 0 };
    const rows = [
      ['allt grönt', { steps: [step('spec-lint', 'passed')], controls: [{ id: 'A', status: 'passed', requiredForGate: [0] }], manifest: goodManifest, generatedDrift: [] }, 'passed'],
      ['grind failed, övrigt grönt', { steps: [step('spec-lint', 'passed')], controls: [{ id: 'A', status: 'not run', requiredForGate: [0] }], manifest: goodManifest, generatedDrift: [] }, 'failed'],
      ['grind blocked', { steps: [step('spec-lint', 'passed')], controls: [{ id: 'A', status: 'blocked', requiredForGate: [0] }], manifest: goodManifest, generatedDrift: [] }, 'failed'],
      // Fas 0.16: 'not run' utanför grinden fäller TOTALEN men inte fasgrinden.
    ['not run utanför grinden fäller totalen', { steps: [step('spec-lint', 'passed')], controls: [{ id: 'A', status: 'passed', requiredForGate: [0] }, { id: 'R', status: 'not run', requiredForGate: [] }], manifest: goodManifest, generatedDrift: [] }, 'failed'],
    ['not applicable utanför grinden är godkänt', { steps: [step('spec-lint', 'passed')], controls: [{ id: 'A', status: 'passed', requiredForGate: [0] }, { id: 'R', status: 'not applicable', why: 'skäl', requiredForGate: [] }], manifest: goodManifest, generatedDrift: [] }, 'passed'],
      ['pipeline failed', { steps: [step('spec-lint', 'failed')], controls: [{ id: 'A', status: 'passed', requiredForGate: [0] }], manifest: goodManifest, generatedDrift: [] }, 'failed'],
      ['drift', { steps: [step('spec-lint', 'passed')], controls: [{ id: 'A', status: 'passed', requiredForGate: [0] }], manifest: goodManifest, generatedDrift: ['x'] }, 'failed'],
      ['manifest parsed 0', { steps: [step('spec-lint', 'passed')], controls: [{ id: 'A', status: 'passed', requiredForGate: [0] }], manifest: { status: 'passed', exitCode: 0, expected: 0, parsed: 0, verified: 0 }, generatedDrift: [] }, 'failed']
    ];
    let bad = 0;
    for (const [label, input, want] of rows) {
      const got = computeTotals(input).overallResult;
      if (got !== want) { console.error('  ✖ ' + label + ': fick ' + got + ', väntade ' + want); bad++; }
    }
    // Grinden påverkas bara av requiredForGate — bevisa båda delarna.
  const nr = computeTotals({ steps: [step('spec-lint', 'passed')],
    controls: [{ id: 'A', status: 'passed', requiredForGate: [0] }, { id: 'R', status: 'not run', requiredForGate: [] }],
    manifest: goodManifest, generatedDrift: [] });
  if (nr.phaseGateResult !== 'passed') { console.error('  ✖ not run utanför grinden fällde fasgrinden'); bad++; }
  if (nr.controlsResult !== 'failed') { console.error('  ✖ not run fällde inte controlsResult'); bad++; }
  t('M-13 · tabellstyrd invariant för overallResult (' + rows.length + ' fall + not run-avgränsning)', bad === 0, bad ? bad + ' avvikelser' : '');
});

/* M-14 · manifestintegritet: syntetiskt passed med parsed 0 godkänns inte */
group('M-14', () => {
    const a = manifestIntegrity({ status: 'passed', exitCode: 0, expected: 0, parsed: 0, verified: 0 });
    const b = manifestIntegrity({ status: 'passed', exitCode: 0, expected: 5, parsed: 5, verified: 4, outsideAbsent: 1 }, 'delivery');
    const c = manifestIntegrity({ status: 'passed', exitCode: 0, expected: 5, parsed: 5, verified: 4, outsideAbsent: 1 }, 'repo');
    const d = manifestIntegrity({ status: 'passed', exitCode: 0, expected: 5, parsed: 4, verified: 4 });
    t('M-14 · manifestintegritet fäller parsed 0, delivery med saknad fil och parsed≠expected',
      !a.ok && !b.ok && c.ok && !d.ok, JSON.stringify([a.ok, b.ok, c.ok, d.ok]));
});

/* M-15 · registerschema och rapportvalidering */
group('M-15', () => {
    const r1 = validateRegistry([{ id: 'A', name: 'a', owner: 'DS', source: 'spec-lint', resolutionPhase: 0, requiredForGate: [] }]);
    const r2 = validateRegistry([{ id: 'A', name: 'a', owner: 'DS', source: 'spec-lint', resolutionPhase: 0, requiredForGate: [] },
                                 { id: 'A', name: 'b', owner: 'DS', source: 'spec-lint', resolutionPhase: 0, requiredForGate: [] }]);
    const r3 = validateRegistry([{ id: 'B', name: 'b', owner: 'DS', source: 'spec-lint', status: 'nästan', resolutionPhase: 0, requiredForGate: [] }]);
    const r4 = validateRegistry([{ id: 'C', name: 'c', owner: 'DS', source: 'spec-lint', status: 'not applicable', resolutionPhase: 0, requiredForGate: [] }]);
    const v1 = validateReport([{ id: 'A', status: 'passed' }], { passed: 1, failed: 0, blocked: 0, 'not run': 0, 'not applicable': 0 });
    const v2 = validateReport([{ id: 'A', status: 'passed' }, { id: 'B', status: 'blocked' }], { passed: 1, failed: 0, blocked: 0, 'not run': 0, 'not applicable': 0 });
    t('M-15 · schemat fäller dubblett-id, okänd status och n/a utan motivering; tally måste summera',
      r1.ok && !r2.ok && !r3.ok && !r4.ok && v1.ok && !v2.ok, JSON.stringify([r1.ok, r2.ok, r3.ok, r4.ok, v1.ok, v2.ok]));
});

/* M-16 · evidensparsern fäller de tre mutationerna */
group('M-16', () => {
    const head = '## Kravmatris\n\n| Id | Krav | Beslut | Skärmbevis | Status |\n|---|---|---|---|---|\n';
    const ok = parseEvidence(head + '| K-01 | x | B-1 | \`#a\` | verifierad |');
    const hist = parseEvidence(head + '| K-01 | x | B-1 | \`#a\` | verifierad | <!--hist-->');
    const typo = parseEvidence(head + '| K-01 | x | B-1 | \`#a\` | implmenterad |');
    const dupId = parseEvidence(head + '| K-01 | x | B-1 | \`#a\` | verifierad |\n| K-01 | y | B-2 | \`#b\` | beslutad |');
    const inHist = parseEvidence('## Historik\n\n| Id | Krav | Beslut | Skärmbevis | Status |\n|---|---|---|---|---|\n| K-01 | x | B-1 | \`#a\` | verifierad | <!--hist-->');
    t('M-16 · hist utanför historikavsnitt, statusstavfel och dubblett-id fälls; hist i historikavsnitt gör det inte',
      ok.problems.length === 0 &&
      hist.problems.some(p => /hist.*utanför/i.test(p)) &&
      typo.problems.some(p => /okänd eller saknad status/i.test(p)) &&
      dupId.problems.some(p => /dubblerat/i.test(p)) &&
      inHist.problems.length === 0 && inHist.rows.length === 0,
      'ok ' + ok.problems.length + ' · hist ' + hist.problems.length + ' · typo ' + typo.problems.length + ' · dup ' + dupId.problems.length + ' · inHist ' + inHist.problems.length);
});

/* M-17 · CHK-CI-01 kräver verklig CI-kontext, inte bara tre fält */
group('M-17', () => {
    const c = ctrl('CI-01', 'ci-evidence', { requiredForGate: [0] });
    const pkg = { manifestSha256: 'a'.repeat(64) };
    const good = {
      schema: 'butlery-ci-evidence/2', ciProvider: 'github-actions', githubActions: 'true',
      runId: '12345678901', runAttempt: '1', repository: 'butlery/spec', commit: 'b'.repeat(40),
      workflow: 'verify', manifestSha256: 'a'.repeat(64), verifyExitCode: 1,
      startedAt: '2026-08-01T10:00:00.000Z', completedAt: '2026-08-01T10:04:00.000Z'
    };
    // Fixturen simulerar en LEVANDE CI-miljö, annars fäller bindningskravet allt.
    const liveEnv = { GITHUB_ACTIONS: 'true', GITHUB_RUN_ID: '12345678901', GITHUB_RUN_ATTEMPT: '1',
      GITHUB_SHA: 'b'.repeat(40), GITHUB_REPOSITORY: 'butlery/spec', GITHUB_WORKFLOW: 'verify' };
    const run = (ev, env2 = liveEnv) => reduceControls([c], { ...base, ciEvidence: ev, packageIdentity: pkg, ciEnv: env2 })[0];
    const cases = [
      ['inget bevis', undefined, 'not run'],
      ['giltigt CI-bevis (röd kedja)', good, 'passed'],
      ['lokalt bevis utan CI-kontext', { ...good, githubActions: undefined, ciProvider: 'local' }, 'failed'],
      ['fel commit-form', { ...good, commit: 'abc123' }, 'failed'],
      ['påhittat run-id', { ...good, runId: 'lokal-körning' }, 'failed'],
      ['fel manifesthash', { ...good, manifestSha256: 'c'.repeat(64) }, 'failed'],
      ['ogiltig exitkod', { ...good, verifyExitCode: 'success' }, 'failed'],
      ['ogiltigt datum', { ...good, completedAt: 'igår' }, 'failed'],
      ['datum i framtiden', { ...good, completedAt: '2099-01-01T00:00:00.000Z' }, 'failed'],
      ['gammalt bevisschema', { ...good, schema: undefined }, 'failed'],
      // Fas 0.12: bindning till den LEVANDE körningen, inte bara formvalidering.
      ['completedAt före startedAt', { ...good, completedAt: '2026-08-01T09:00:00.000Z' }, 'failed'],
      ['annan giltig commit än körningens', { ...good, commit: 'c'.repeat(40) }, 'failed'],
      ['annat repository än körningens', { ...good, repository: 'annan/repo' }, 'failed'],
      ['annat run-id än körningens', { ...good, runId: '99999999999' }, 'failed'],
      ['annat run-attempt än körningens', { ...good, runAttempt: '7' }, 'failed'],
      ['giltigt bevis men körning utanför CI', good, 'failed', {}]
    ];
    let bad = 0;
    for (const [label, ev, want, env2] of cases) {
      const got = run(ev, env2 === undefined ? liveEnv : env2).status;
      if (got !== want) { console.error('  ✖ ' + label + ': fick ' + got + ', väntade ' + want); bad++; }
    }
    t('M-17 · CI-beviset binds till paket och levande körning (' + cases.length + ' fall: 1 positivt, 1 saknat, ' + (cases.length - 2) + ' ogiltiga)', bad === 0, bad ? bad + ' avvikelser' : '');
});

/* M-18 · GEN-01:s register täcker samtliga generatorers skrivmål */
group('M-18', () => {
    // Fas 1 (andra vändan): M-18 läste GENERATED_OUTPUTS ur verify.mjs källtext
    // och bar sin EGEN generatorlista, där gen-app-theme.mjs saknades. Nu läses
    // det centrala registret i tools/gen-targets.mjs — samma modul som verify.mjs
    // importerar — så listorna inte kan glida isär igen.
    const listed = GENERATED_OUTPUTS;
    const usesRegister = /from '\.\/gen-targets\.mjs'/.test(readFileSync('tools/verify.mjs', 'utf8'));
    const chainSteps = [...readFileSync('tools/verify.mjs', 'utf8').matchAll(/'(tools\/gen-[a-z-]+\.mjs)'/g)].map(m2 => m2[1]);
    const written = new Set();
    for (const g of GENERATORS) {
      if (!existsSync(g)) continue;
      const src = readFileSync(g, 'utf8');
      for (const mm of src.matchAll(/writeFileSync\(\s*'([^']+)'/g)) written.add(mm[1]);
      for (const L of src.matchAll(/const (?:TARGETS|OUT|OUTPUTS)\s*=\s*\[([\s\S]*?)\]/g))
        for (const mm of L[1].matchAll(/'([^']+)'/g)) written.add(mm[1]);
      for (const mm of src.matchAll(/const (?:OUT_?FILE|DEST|TARGET|ICONS|SRC_ICONS)\s*=\s*'([^']+)'/g)) written.add(mm[1]);
    }
    const missing = [...written].filter(f => !listed.includes(f));
    // Varje generator i registret måste också vara ett STEG i kedjan.
    const notInChain = GENERATORS.filter(g => !chainSteps.includes(g));
    t('M-18 · GEN-01-registret täcker samtliga generatorers skrivmål',
      written.size > 0 && missing.length === 0 && usesRegister && notInChain.length === 0,
      'register ' + listed.length + ' · generatorer ' + GENERATORS.length + ' · skrivmål ' + written.size +
      (missing.length ? ' · SAKNAS I REGISTRET: ' + missing.join(', ') : '') +
      (notInChain.length ? ' · SAKNAS I KEDJAN: ' + notInChain.join(', ') : '') +
      (usesRegister ? '' : ' · verify.mjs importerar inte gen-targets.mjs'));
});

/* M-19 · preflight, T-15 och GEN-01 har skilda roller */
group('M-19', () => {
    const pf = readFileSync('tools/preflight.mjs', 'utf8');
    const lc = readFileSync('tools/lint-core.mjs', 'utf8');
    const headerAnchored = /slice\(0, 12\)/.test(lc) && /\\btokens\\s\+/.test(lc);
    t('M-19 · preflight mäter incheckad drift och T-15:s headerparser är ankrad till header-raden',
      /GEN-02/.test(pf) && /tokens\.json/.test(pf) && /generated-header/.test(lc) && headerAnchored,
      'ankrad: ' + headerAnchored);
});

/* M-20 · namnrymderna är disjunkta och maskinellt märkta */
group('M-20', () => {
    const rows = parseEvidence('## Kravmatris\n\n| Krav-ID | Regel | Vy | Skärmbevis | Status |\n|---|---|---|---|---|\n| T-14 | x | y | — | beslutad |').rows;
    const ns = checkNamespaces([ctrl('T-14', 'spec-lint')], rows);
    const reqPrefixed = rows.every(r => /^REQ-/.test(r.machineId));
    // Rå-id T-14 finns i båda mängderna, men maskin-id gör dem disjunkta.
    t('M-20 · CHK- och REQ-prefix gör mängderna disjunkta även vid samma rå-id',
      ns.ok && reqPrefixed && rows[0].id === 'T-14' && rows[0].machineId === 'REQ-T-14',
      JSON.stringify(ns.problems));
});

/* M-21 · rapportschemat fäller ofullständiga och dubbelräknade rapporter */
group('M-21', () => {
    // EN kanonisk fixtur — rapportkontraktet dupliceras inte i M-21/23/24/25.
    // Fas 0.15: lokala "giltiga" rapporter saknade sources och artifactFingerprint.
    const okReport = fullReport({ failOutsideGate: false });
    okReport.packageIdentity.manifestSha256 = 'a'.repeat(64);
    okReport.packageIdentity.artifactFingerprint = { sha256: 'a'.repeat(64), mode: 'repo', declared: 1, hashed: 1, missing: 0, totalEntries: 1, outsideEntries: 0 };
    okReport.ciEvidence.manifestSha256 = 'a'.repeat(64);
    const clone = () => JSON.parse(JSON.stringify(okReport));
    const bad = [
      ['saknat runId', (() => { const r = clone(); delete r.runId; return r; })()],
      ['fel schemaversion', (() => { const r = clone(); r.schema = 'butlery-verify-report/1'; return r; })()],
      ['tally utan blocked', (() => { const r = clone(); delete r.tally.blocked; return r; })()],
      ['kontroll utan CHK-prefix', (() => { const r = clone(); r.controls[0].id = 'T-02'; return r; })()],
      ['dubbelräknade spec-fel', (() => { const r = clone(); const c0 = r.controls.find(c => c.source === 'spec-lint'); c0.errors = 999; return r; })()],
      ['saknat sources', (() => { const r = clone(); delete r.sources; return r; })()],
      ['saknat artifactFingerprint', (() => { const r = clone(); delete r.packageIdentity.artifactFingerprint; return r; })()]
    ];
    const okEmpty = validateReportSchema(okReport).length === 0;
    const allFail = bad.every(([, r]) => validateReportSchema(r).length > 0);
    t('M-21 · rapportschemat godkänner en komplett rapport och fäller fem trasiga',
      okEmpty && allFail, 'giltig ' + okEmpty + ' · trasiga fällda ' + allFail + (okEmpty ? '' : ' · ' + validateReportSchema(okReport).join('; ')));
});

/* M-22 · MANIFESTET: riktigt integrationstest av delivery-läget */
group('M-22', () => {
    const dir = mkdtempSync(join(tmpdir(), 'butlery-mf-'));
    const pkg = join(dir, 'uploads/p1/p2');
    mkdirSync(join(pkg, 'fas0'), { recursive: true });
    mkdirSync(join(pkg, 'tools'), { recursive: true });
  copyFileSync('fas0/check-manifest.mjs', join(pkg, 'fas0/check-manifest.mjs'));
  copyFileSync('tools/report-logic.mjs', join(pkg, 'tools/report-logic.mjs'));
    const shaOf = f => createHash('sha256').update(readFileSync(f)).digest('hex');
    // Ett minimalt paket: en reporotsfil + två leveransfiler.
    writeFileSync(join(pkg, 'x.md'), '# x\n');
    writeFileSync(join(dir, 'support.js'), '// support\n');
    mkdirSync(join(dir, 'fas0'), { recursive: true });
    writeFileSync(join(dir, 'fas0/DELIVERY'), 'butlery-delivery/1\n');
    const write = () => {
      // report-logic.mjs måste med, annars fäller set-likheten basfallet.
      const rows = [
        ['x.md', shaOf(join(pkg, 'x.md'))],
        ['fas0/check-manifest.mjs', shaOf(join(pkg, 'fas0/check-manifest.mjs'))],
        ['tools/report-logic.mjs', shaOf(join(pkg, 'tools/report-logic.mjs'))]
      ];
      const out = [
        ['zip:/support.js', shaOf(join(dir, 'support.js'))],
        ['zip:/fas0/DELIVERY', shaOf(join(dir, 'fas0/DELIVERY'))]
      ];
      let md = '# m\n\n<!--manifest:files=' + (rows.length + out.length) + '-->\n\n## Reporoten\n\n| Fil | SHA-256 |\n|---|---|\n';
      for (const [f, h] of rows) md += '| \`' + f + '\` | \`' + h + '\` |\n';
      md += '\n## Leveransytan utanför reporoten\n\n| Fil | SHA-256 |\n|---|---|\n';
      for (const [f, h] of out) md += '| \`' + f + '\` | \`' + h + '\` |\n';
      writeFileSync(join(pkg, 'fas0/andrade-filer.md'), md);
    };
    write();
    const run = mode => runProc(process.execPath, ['fas0/check-manifest.mjs', '--mode=' + mode], { cwd: pkg });
    const full = run('delivery');
    // ODEKLARERAD fil i LEVERANSYTAN. Fas 1 (tredje vändan): set-likheten mättes
    // bara inom reporoten, så tre odeklarerade filer i ZIP-ytan gav unlisted=0.
    // Fas 1 (fjärde vändan): undantaget var ett wildcard över uploads/vNN-*.log
    // och .json, så exakt de filerna slank igenom ändå. Alla tre namnformerna
    // provas nu — inklusive de två som föll igenom.
    const undeclaredCases = [];
    // Fas 1 (femte vändan): surprise.png och uploads/scraps/undeclared.json gav
    // fortfarande unlisted=0 — TEXT-allowlisten och de breda katalogundantagen.
    for (const rel of ['extra.md', 'uploads/v99-undeclared.json', 'uploads/v99-undeclared.log',
      'uploads/v22-second-verify.log', 'surprise.png', 'uploads/scraps/undeclared.json', 'exports/oanmald.bin']) {
      mkdirSync(join(dir, rel.split('/').slice(0, -1).join('/')) || dir, { recursive: true });
      writeFileSync(join(dir, rel), '# odeklarerad\n');
      const r = run('delivery');
      undeclaredCases.push([rel, r.code, /olistad artefakt i leveransytan/.test(r.out)]);
      rmSync(join(dir, rel));
    }
    const allUndeclaredFell = undeclaredCases.every(([, code, saw]) => code !== 0 && saw);
    const afterExtra = run('delivery');
    // Ta bort EN leveransfil.
    rmSync(join(dir, 'support.js'));
    const oneMissing = run('delivery');
    // Ta bort ALLA leveransfiler, inklusive markören.
    rmSync(join(dir, 'fas0/DELIVERY'));
    const allMissing = run('delivery');
    const autoEmpty = run('auto');
    const badMode = run('deliveri');
    t('M-22 · delivery-läget fäller saknad leveransfil, tömd leveransyta OCH varje odeklarerad fil i ZIP-ytan',
      full.code === 0 && allUndeclaredFell &&
      afterExtra.code === 0 && oneMissing.code !== 0 && allMissing.code !== 0 && badMode.code === 2,
      'komplett ' + full.code + ' · odeklarerade: ' + undeclaredCases.map(([f, c, saw]) => f + '=' + c + (saw ? '' : '(ingen diagnostik)')).join(', ') +
      ' · återställd ' + afterExtra.code + ' · en saknad ' + oneMissing.code + ' · alla saknade ' + allMissing.code +
      ' · auto utan markör ' + autoEmpty.code + ' (därför kräver leveranskontrollen --mode=delivery) · fel läge ' + badMode.code);
    rmSync(dir, { recursive: true, force: true });
});

/* M-23 · GRINDEN: riktiga negativa tester som kör gate.mjs */
group('M-23', () => {
    // Fixturen måste känna manifesthashen INNAN reduceringen, annars reduceras
  // CHK-CI-01 mot ett bevis för fel paket. mkPkg bygger därför paketet först och
  // reducerar sedan.
  const mkPkg = (reportObj, extra = {}) => {
      const dir = mkdtempSync(join(tmpdir(), 'butlery-gate-'));
      mkdirSync(join(dir, 'fas0'), { recursive: true });
      mkdirSync(join(dir, 'tools'), { recursive: true });
      for (const f of ['tools/gate.mjs', 'tools/controls.mjs', 'tools/report-logic.mjs']) copyFileSync(f, join(dir, f));
      // Manifestet listar en fil, så fingeravtrycket kan räknas i båda ändar.
      writeFileSync(join(dir, 'x.md'), extra.payload ?? '# x\n');
      const xh = createHash('sha256').update(readFileSync(join(dir, 'x.md'))).digest('hex');
      const mfBody = '# m\n<!--manifest:files=1-->\n\n## Reporoten\n\n| Fil | SHA-256 |\n|---|---|\n| \`x.md\` | \`' + xh + '\` |\n';
      writeFileSync(join(dir, 'fas0/andrade-filer.md'), mfBody);
      const mfHash = createHash('sha256').update(Buffer.from(mfBody)).digest('hex');
      const fp = createHash('sha256').update('x.md:' + xh + '\n').digest('hex');
      if (reportObj && typeof reportObj === 'object') {
        if (reportObj.packageIdentity) {
          if (reportObj.packageIdentity.manifestSha256 === 'AUTO') reportObj.packageIdentity.manifestSha256 = mfHash;
          if (reportObj.packageIdentity.artifactFingerprint && reportObj.packageIdentity.artifactFingerprint.sha256 === 'AUTOFP')
            reportObj.packageIdentity.artifactFingerprint = { sha256: fp, mode: 'repo', declared: 1, hashed: 1, missing: 0, totalEntries: 1, outsideEntries: 0 };
        }
        if (reportObj.ciEvidence && reportObj.ciEvidence.manifestSha256 === 'AUTO') reportObj.ciEvidence.manifestSha256 = mfHash;
        // AUTO-värdena påverkar reduceringen (CHK-CI-01 binds mot manifesthashen),
        // så raderna räknas om EFTER substitutionen — annars avviker de lagrade
        // raderna från grindens omreducering. Fas 0.17.
        if (extra.reduce !== false && Array.isArray(reportObj.controls)) {
          const wasFinal = reportObj.finalized, at = reportObj.finalizedAt;
          reduceInto(reportObj, CI_ENV);
          if (wasFinal !== undefined) reportObj.finalized = wasFinal;
          if (at !== undefined) reportObj.finalizedAt = at;
          if (extra.after) extra.after(reportObj);
        }
        writeFileSync(join(dir, 'fas0/verify-report.json'), JSON.stringify(reportObj, null, 2));
      } else if (typeof reportObj === 'string') {
        writeFileSync(join(dir, 'fas0/verify-report.json'), reportObj);
      }
      return dir;
    };
    // HERMETISKT: barnprocessen får inte ärva GITHUB_*. Fas 0.15: M-23 passerade
    // lokalt men föll i CI eftersom grinden då krävde en levande CI-bindning.
    // DETERMINISTISK miljö: fixturen byggs med CI_ENV, alltså måste grinden köra
    // med samma. Fas 0.17: proven rensade CI-miljön och CHK-CI-01 reducerades då
    // till failed i barnprocessen medan fixturen byggts med giltigt bevis.
    // Bara CI-kontexten skickas in; runProc() sanerar resten. Fas 1 (femte
    // vändan): den gamla varianten spred process.env och kunde återinföra
    // BUTLERY_PHASE från moderprocessen.
    const gateEnv = () => ({ ...CI_ENV });
    const runGate = (dir, phase) => runProc(process.execPath, ['tools/gate.mjs', '--phase=' + phase], { cwd: dir, env: gateEnv() });
    const run = (reportObj, phase, extra = {}) => {
      const dir = mkPkg(reportObj, extra);
      if (extra.mutate) extra.mutate(dir);
      const res = runGate(dir, phase);
      rmSync(dir, { recursive: true, force: true });
      return res;
    };

    const cases = [];
    // POSITIVT: hela registret, grinden grön, totalen röd via en kontroll utanför grinden.
    cases.push(['grön grind, röd total (hela registret)', run(fullReport(), 0), 0]);
    cases.push(['ingen rapport', run(null, 0), 2]);
    cases.push(['tom rapport med fel schema', run({ schema: 'x', controls: [] }, 0), 1]);
    cases.push(['ogiltig fas', run(fullReport(), 'not-a-phase'), 2]);
    cases.push(['okänd fas', run(fullReport(), 9), 2]);
    cases.push(['beskuren rapport (bara grindkontrollerna)', run(fullReport(), 0, {
      after: rr => { rr.controls = rr.controls.filter(c => (c.requiredForGate || []).includes(0));
        rr.tally = { passed: 0, failed: 0, blocked: 0, 'not run': 0, 'not applicable': 0 };
        for (const c of rr.controls) rr.tally[c.status]++; } }), 1]);
    cases.push(['dubblerad grindkontroll', run(fullReport(), 0, {
      after: rr => { rr.controls.push({ ...rr.controls[0] }); rr.tally[rr.controls[0].status]++; } }), 1]);
    cases.push(['fel manifesthash', run(fullReport(), 0, {
      after: rr => { rr.packageIdentity.manifestSha256 = 'f'.repeat(64); } }), 1]);
    cases.push(['fällande grindkontroll', run(fullReport(), 0, {
      after: rr => { const g2 = rr.controls.find(c => (c.requiredForGate || []).includes(0));
        g2.status = 'failed'; g2.errors = 1; rr.tally.passed--; rr.tally.failed++; rr.phaseGateResult = 'failed'; } }), 1]);
    cases.push(['lagrad grindstatus motsäger omräkningen', run(fullReport(), 0, {
      after: rr => { const g2 = rr.controls.find(c => (c.requiredForGate || []).includes(0));
        g2.status = 'failed'; g2.errors = 1; rr.tally.passed--; rr.tally.failed++; rr.phaseGateResult = 'passed'; } }), 1]);
    cases.push(['rapporten beräknad för annan fas', run(fullReport(), 0, { after: rr => { rr.currentPhase = 2; } }), 1]);
    cases.push(['gammal rapport, rätt manifest', run(fullReport(), 0, {
      after: rr => { rr.generatedAt = '2020-01-01T00:00:00.000Z'; rr.finalizedAt = '2020-01-01T00:00:00.000Z'; } }), 1]);
    // STALE ARTEFAKTYTA: filen ändras EFTER att rapporten skrevs.
    cases.push(['artefaktytan ändrad efter rapporten', run(fullReport(), 0, {
      mutate: dir => writeFileSync(join(dir, 'x.md'), '# x muterad efter rapporten\n') }), 1]);
    // TALLYNS FÖRDELNING: rätt summa, fel fördelning.
    cases.push(['rätt totalsumma, fel statusfördelning', run(fullReport(), 0, {
      after: rr => { rr.tally.passed--; rr.tally['not applicable']++; } }), 1]);

    // Fas 0.16 · nya negativa fall.
    cases.push(['ofinaliserad rapport', run(fullReport(), 0, {
      after: rr => { delete rr.finalized; delete rr.finalizedAt; delete rr.inputSchemaValidation; } }), 1]);
    cases.push(['grindkontroll passed med diagnostik', run(fullReport(), 0, {
      after: rr => { const g2 = rr.controls.find(c => (c.requiredForGate || []).includes(0)); g2.errors = 6; } }), 1]);
    // Fas 0.17: en rad ändrad UTAN att status ändras måste också fällas.
    cases.push(['kontrollrad ändrad utan statusändring', run(fullReport(), 0, {
      after: rr => { rr.controls[0].name = 'omdöpt av någon'; rr.controls[0].why = 'påhittad motivering'; } }), 1]);
    // Fas 0.18: fält UTANFÖR den gamla hårdkodade listan måste också fällas.
    cases.push(['ändrat legacyId', run(fullReport(), 0, {
      after: rr => { rr.controls[0].legacyId = 'PÅHITT-99'; } }), 1]);
    cases.push(['ändrat scope', run(fullReport(), 0, {
      after: rr => { rr.controls[0].scope = 'omskriven avgränsning'; } }), 1]);
    cases.push(['ändrat passedTests', run(fullReport(), 0, {
      after: rr => { const c = rr.controls.find(x => x.passedTests !== undefined) || rr.controls[0];
        c.passedTests = (c.passedTests ?? 0) + 7; } }), 1]);
    cases.push(['ändrat nästlat coverage', run(fullReport(), 0, {
      after: rr => { const c = rr.controls.find(x => x.coverage) || rr.controls[0];
        c.coverage = { ...(c.coverage || {}), uncovered: 9 }; } }), 1]);
    cases.push(['ändrat nästlat integrity', run(fullReport(), 0, {
      after: rr => { const c = rr.controls.find(x => x.integrity) || rr.controls[0];
        c.integrity = { ...(c.integrity || { ok: true, problems: [] }), ok: false }; } }), 1]);
    cases.push(['ändrat manifestfält verified', run(fullReport(), 0, {
      after: rr => { const c = rr.controls.find(x => x.id === 'CHK-MF-01') || rr.controls[0];
        c.verified = (c.verified ?? 0) + 5; } }), 1]);
    cases.push(['extra fält på kontrollraden', run(fullReport(), 0, {
      after: rr => { rr.controls[0].pahittatFalt = 'ska fällas'; } }), 1]);
    cases.push(['borttaget fält på kontrollraden', run(fullReport(), 0, {
      after: rr => { delete rr.controls[0].scope; } }), 1]);
    cases.push(['CHK-MT-01 passed mot metatestSummary.fail 6', run(fullReport(), 0, {
      after: rr => { rr.metatestSummary = { pass: 25, fail: 6, total: 31 }; } }), 1]);
    cases.push(['CHK-ST-01 passed mot selftestSummary.fail 2', run(fullReport(), 0, {
      after: rr => { rr.selftestSummary = { pass: 29, fail: 2, skipped: 0 }; } }), 1]);
    cases.push(['finalizeAborted', run(fullReport(), 0, { after: rr => { rr.finalizeAborted = true; } }), 1]);

    let bad = 0;
    for (const cs of cases) {
      if (cs[1].code !== cs[2]) {
        console.error('  ✖ ' + cs[0] + ': exit ' + cs[1].code + ', väntade ' + cs[2] +
          (cs[1].out ? ' :: ' + cs[1].out.split('\n').filter(l => /^✖|GATE-SUMMARY/.test(l)).slice(0, 2).join(' | ') : ''));
        bad++;
      }
    }
    t('M-23 · gate.mjs är fail-closed (' + cases.length + ' fall, kör verkligt)', bad === 0, bad ? bad + ' avvikelser' : '');
});

/* M-24 · FINALISERINGEN: riktigt processtest, kraschsäkert */
group('M-24', () => {
    const shaOf = buf => createHash('sha256').update(buf).digest('hex');
    const build = (opts = {}) => {
      const dir = mkdtempSync(join(tmpdir(), 'butlery-fin-'));
      mkdirSync(join(dir, 'fas0'), { recursive: true });
      mkdirSync(join(dir, 'tools'), { recursive: true });
      for (const f of ['tools/finalize.mjs', 'tools/controls.mjs', 'tools/report-logic.mjs', 'tools/gen-report.mjs', 'tools/gate.mjs'])
        copyFileSync(f, join(dir, f));
      writeFileSync(join(dir, 'x.md'), '# x\n');
      const xh = shaOf(readFileSync(join(dir, 'x.md')));
      const mfBody = '# m\n<!--manifest:files=1-->\n\n## Reporoten\n\n| Fil | SHA-256 |\n|---|---|\n| \`x.md\` | \`' + xh + '\` |\n';
      writeFileSync(join(dir, 'fas0/andrade-filer.md'), mfBody);
      const mf = shaOf(Buffer.from(mfBody));
      const fp = shaOf(Buffer.from('x.md:' + xh + '\n'));
      const now = Date.now();
      const started = new Date(now - 120000).toISOString();
      const completed = new Date(now - 60000).toISOString();
      const ev = {
        schema: 'butlery-ci-evidence/2', ciProvider: 'github-actions', githubActions: 'true',
        runId: '12345678901', runAttempt: '1', repository: 'butlery/spec', workflow: 'verify',
        commit: 'b'.repeat(40), manifestSha256: mf, verifyExitCode: 1,
        startedAt: started, completedAt: completed, ...(opts.evidence || {})
      };
      if (opts.noEvidence !== true) writeFileSync(join(dir, 'fas0/ci-evidence.json'), JSON.stringify(ev, null, 2));
      writeFileSync(join(dir, 'fas0/verify-exit'), String(opts.chainExit ?? 1));
      const report = fullReport({ report: {
        generatedAt: opts.generatedAt || new Date(now - 90000).toISOString(),
        ...(opts.report || {})
      } });
      report.packageIdentity.manifestSha256 = mf;
      report.packageIdentity.artifactFingerprint = { sha256: fp, mode: 'repo', declared: 1, hashed: 1, missing: 0, totalEntries: 1, outsideEntries: 0 };
      if (report.ciEvidence) { report.ciEvidence.manifestSha256 = mf; Object.assign(report.ciEvidence, opts.evidence || {}); }
      if (opts.noEvidence === true) delete report.ciEvidence;
      if (opts.schemaArtifact) report.schemaArtifact = opts.schemaArtifact;
      // Räkna om EFTER substitutionen, så de lagrade raderna stämmer med grindens
      // omreducering. Fas 0.17: reduceringen kördes mot AUTO-värden.
      { const wf = report.finalized, at = report.finalizedAt;
        reduceInto(report, CI_ENV);
        report.finalized = wf; report.finalizedAt = at; }
      if (opts.report && 'runId' in opts.report) report.runId = opts.report.runId;
      if (opts.report && 'generatedAt' in opts.report) report.generatedAt = opts.report.generatedAt;
      if (opts.generatedAt) report.generatedAt = opts.generatedAt;
      writeFileSync(join(dir, 'fas0/verify-report.json'), JSON.stringify(report, null, 2));
      const before = new Map();
      for (const f of ['tools/finalize.mjs', 'tools/controls.mjs', 'tools/report-logic.mjs', 'fas0/andrade-filer.md', 'x.md'])
        before.set(f, shaOf(readFileSync(join(dir, f))));
      return { dir, before };
    };
    // FASOBEROENDE. Fas 1 (tredje vändan): runFinalize() och gateEnvM24() ärvde
    // BUTLERY_PHASE från moderprocessen, medan provet körde gate.mjs --phase=0.
    // Under en riktig Fas 1-körning föll därför M-24 ("A grinden grön") — provet
    // mätte fasblandning, inte finalisering. Fasen skickas nu uttryckligen och
    // fall A körs för BÅDA faserna.
    const runFinalize = (dir, phase = 0) => {
      const p = runProc(process.execPath, ['tools/finalize.mjs'], { cwd: dir, env: { ...CI_ENV, BUTLERY_PHASE: String(phase) } });
      const out = p.out;
      // Fas 1 (femte vändan): raden nedan läste p.status ur ett runProc-resultat
      // som bara bär {code, timedOut, out} — M-24 rapporterade "exit undefined".
      // KRASCHSÄKERT: läs det som finns, anta inget.
      let rep = null, md = null;
      try { rep = JSON.parse(readFileSync(join(dir, 'fas0/verify-report.json'), 'utf8')); } catch {}
      try { md = readFileSync(join(dir, 'fas0/kontrollstatus.md'), 'utf8'); } catch {}
      return { code: p.code, out, rep, md };
    };
    const statusOf = (rep, id) => (rep?.controls || []).find(c => c.id === id)?.status;
    // SAMMA CI-miljö som finaliseringen körde i. Fas 0.17: fall A finaliserade i
    // simulerad CI men körde grinden utan miljön, så omreduceringen gjorde
    // CHK-CI-01 röd med rätta.
    const gateEnvM24 = (phase = 0) => ({ ...CI_ENV, BUTLERY_PHASE: String(phase) });
    const gate = (dir, phase = 0) => runProc(process.execPath, ['tools/gate.mjs', '--phase=' + phase],
      { cwd: dir, env: gateEnvM24(phase) }).code;
    const problems = [];
    const check = (label, cond, detail) => { if (!cond) problems.push(label + (detail ? ': ' + detail : '')); };

    // A · giltigt bevis → CI passed, inget ändrat, samma runId i båda filerna.
    // Körs för VARJE definierad fas: grinden bedömer bara en rapport som räknats
    // för samma fas, så fasen är en parameter och inte en miljöslump.
    for (const phase of [...new Set(CONTROLS.flatMap(c => c.requiredForGate || []))].sort((a, b) => a - b)) {
      const A = 'A(fas ' + phase + ') ';
      const { dir, before } = build();
      const r = runFinalize(dir, phase);
      check(A + 'finalize-exit', r.code === 0, 'exit ' + r.code + ' :: ' + r.out.split('\n').filter(l => /^✖/.test(l)).slice(0, 2).join(' | '));
      check(A + 'CI passed', statusOf(r.rep, 'CHK-CI-01') === 'passed',
        String(statusOf(r.rep, 'CHK-CI-01')) + ' — ' + ((r.rep?.controls || []).find(c => c.id === 'CHK-CI-01')?.why || '?'));
      check(A + 'Markdown skriven', !!r.md);
      check(A + 'samma runId', !!(r.rep && r.md && r.md.includes(r.rep.runId)));
      check(A + 'rapporten räknad för fasen', Number(r.rep?.currentPhase) === phase, String(r.rep?.currentPhase));
      for (const [f, h] of before) {
        let now2 = null;
        try { now2 = shaOf(readFileSync(join(dir, f))); } catch {}
        check(A + 'oförändrad ' + f, now2 === h);
      }
      check(A + 'totalen röd', r.rep?.overallResult === 'failed', String(r.rep?.overallResult));
      check(A + 'grinden grön', gate(dir, phase) === 0);
      rmSync(dir, { recursive: true, force: true });
    }
    // B · ogiltigt bevis → CI failed
    { const { dir } = build({ evidence: { commit: 'c'.repeat(40) } });
      check('B ogiltig commit', statusOf(runFinalize(dir).rep, 'CHK-CI-01') === 'failed');
      rmSync(dir, { recursive: true, force: true }); }
    // C · exitkodsmismatch
    { const { dir } = build({ evidence: { verifyExitCode: 0 }, chainExit: 1 });
      check('C exitkodsmismatch', statusOf(runFinalize(dir).rep, 'CHK-CI-01') === 'failed');
      rmSync(dir, { recursive: true, force: true }); }
    // D · stale ingångsrapport
    { const { dir } = build({ generatedAt: '2020-01-01T00:00:00.000Z' });
      const r = runFinalize(dir);
      check('D stale ingångsrapport flaggad', (r.rep?.finalizeProblems || []).length > 0 || /tidigare körning|före CI-körningens start/.test(r.out));
      rmSync(dir, { recursive: true, force: true }); }
    // E · numeriskt runId i INGÅNGSRAPPORTEN får inte tvättas bort
    { const { dir } = build({ report: { runId: 12345 } });
      const r = runFinalize(dir);
      check('E ingångs-runId flaggat', r.rep?.inputSchemaValidation && r.rep.inputSchemaValidation.ok === false,
        JSON.stringify(r.rep?.inputSchemaValidation?.problems?.slice(0, 2) || null));
      check('E grinden röd', gate(dir) !== 0);
      rmSync(dir, { recursive: true, force: true }); }
    // E2 · numeriskt generatedAt i ingångsrapporten
    { const { dir } = build({ report: { generatedAt: 1234567890 } });
      const r = runFinalize(dir);
      check('E2 ingångs-generatedAt flaggat', r.rep?.inputSchemaValidation && r.rep.inputSchemaValidation.ok === false);
      rmSync(dir, { recursive: true, force: true }); }
    // F · inget bevis → not run
    { const { dir } = build({ noEvidence: true });
      check('F utan bevis', statusOf(runFinalize(dir).rep, 'CHK-CI-01') === 'not run');
      rmSync(dir, { recursive: true, force: true }); }
    // G · stale LEVERERAD schemafil bevaras genom finaliseringen
    { const { dir } = build({ schemaArtifact: { missing: false, drift: true, deliveredSha256: 'd'.repeat(64) } });
      const r = runFinalize(dir);
      check('G schemaArtifact bevarad', r.rep?.schemaArtifact?.drift === true, JSON.stringify(r.rep?.schemaArtifact));
      check('G CHK-SC-01 failed', statusOf(r.rep, 'CHK-SC-01') === 'failed', String(statusOf(r.rep, 'CHK-SC-01')));
      check('G grinden röd', gate(dir) !== 0);
      rmSync(dir, { recursive: true, force: true }); }
    // H · artefaktytan ändrad efter rapporten → grinden fäller
    { const { dir } = build();
      runFinalize(dir);
      writeFileSync(join(dir, 'x.md'), '# muterad efter rapporten\n');
      check('H stale artefaktyta', gate(dir) !== 0);
      rmSync(dir, { recursive: true, force: true }); }

    // I · ändrad zip:/-fil i delivery-läge → grinden fäller
    {
      const dir = mkdtempSync(join(tmpdir(), 'butlery-dlv-'));
      const pkg = join(dir, 'uploads/p1/p2');
      mkdirSync(join(pkg, 'fas0'), { recursive: true });
      mkdirSync(join(pkg, 'tools'), { recursive: true });
      for (const f of ['tools/gate.mjs', 'tools/controls.mjs', 'tools/report-logic.mjs']) copyFileSync(f, join(pkg, f));
      writeFileSync(join(pkg, 'x.md'), '# x\n');
      writeFileSync(join(dir, 'support.js'), '// support\n');
      const xh = shaOf(readFileSync(join(pkg, 'x.md')));
      const sh2 = shaOf(readFileSync(join(dir, 'support.js')));
      const mfBody = '# m\n<!--manifest:files=2-->\n\n## Reporoten\n\n| Fil | SHA-256 |\n|---|---|\n| \`x.md\` | \`' + xh +
        '\` |\n\n## Leveransytan utanför reporoten\n\n| Fil | SHA-256 |\n|---|---|\n| \`zip:/support.js\` | \`' + sh2 + '\` |\n';
      writeFileSync(join(pkg, 'fas0/andrade-filer.md'), mfBody);
      const fpParts = ['x.md:' + xh, 'zip:/support.js:' + sh2].sort().join('\n') + '\n';
      const rep = fullReport({ failOutsideGate: false });
      rep.packageIdentity.manifestSha256 = shaOf(Buffer.from(mfBody));
      rep.packageIdentity.artifactFingerprint = { sha256: shaOf(Buffer.from(fpParts)), mode: 'delivery', declared: 2, hashed: 2, missing: 0, totalEntries: 2, outsideEntries: 1 };
      rep.ciEvidence.manifestSha256 = rep.packageIdentity.manifestSha256;
      rep.manifestMode = 'delivery';
      // Finaliserad OCH omreducerad efter substitutionen — grinden kräver båda.
      { const wf = rep.finalized, at = rep.finalizedAt;
        reduceInto(rep, CI_ENV);
        rep.finalized = wf; rep.finalizedAt = at; }
      writeFileSync(join(pkg, 'fas0/verify-report.json'), JSON.stringify(rep, null, 2));
      const gateIn = () => {
        return runProc(process.execPath, ['tools/gate.mjs', '--phase=0'], { cwd: pkg, env: { ...CI_ENV } });
      };
      const g1 = gateIn();
      check('I delivery-basfall grönt', g1.code === 0,
        'exit ' + g1.code + ' :: ' + g1.out.split('\n').filter(l => /^✖/.test(l)).slice(0, 2).join(' | '));
      writeFileSync(join(dir, 'support.js'), '// muterad efter rapporten\n');
      check('I ändrad zip:/-fil fäller', gateIn().status !== 0);
      rmSync(dir, { recursive: true, force: true });
    }

    t('M-24 · finaliseringen och grinden prövade som riktiga processer (' + (problems.length ? 'fel: ' + problems.length : '10 fall') + ')',
      problems.length === 0, problems.join(' · '));
});

/* M-25 · schemavalideringen är SCHEMADRIVEN (enhetsprov, inte process) ─────────
   Prövar validateReportSchema() direkt: den traverserar REPORT_SCHEMA, så typer
   och mönster kan inte glida från schemafilen. Processnivån täcks av M-24 E. */
group('M-25', () => {
    // EN kanonisk fixtur — rapportkontraktet dupliceras inte i M-21/23/24/25.
    // Fas 0.15: lokala "giltiga" rapporter saknade sources och artifactFingerprint.
    const good = fullReport({ failOutsideGate: false });
    good.packageIdentity.manifestSha256 = 'a'.repeat(64);
    good.packageIdentity.artifactFingerprint = { sha256: 'a'.repeat(64), mode: 'repo', declared: 1, hashed: 1, missing: 0, totalEntries: 1, outsideEntries: 0 };
    good.ciEvidence.manifestSha256 = 'a'.repeat(64);
    const variants = [
      ['requiredForGate som sträng', r => { r.controls[0].requiredForGate = ['0']; }],
      ['tom packageIdentity', r => { r.packageIdentity = {}; }],
      ['tomt stegobjekt', r => { r.steps = [{}]; }],
      ['saknat mätfält', r => { delete r.measures.coverageErrors; }],
      ['tom controls', r => { r.controls = []; r.tally = { passed: 0, failed: 0, blocked: 0, 'not run': 0, 'not applicable': 0 }; }],
      ['tom steps', r => { r.steps = []; }],
      ['blocked utan blockedBy', r => { r.controls[0].status = 'blocked'; r.tally.passed--; r.tally.blocked++; }],
      ['dubblerat kontroll-id', r => { r.controls.push({ ...r.controls[0] }); r.tally.passed++; }],
      ['icke-heltalig resolutionPhase', r => { r.controls[0].resolutionPhase = '0'; }],
      ['saknat sources', r => { delete r.sources; }],
      ['saknat artifactFingerprint', r => { delete r.packageIdentity.artifactFingerprint; }],
      ['fingeravtryck utan mode', r => { delete r.packageIdentity.artifactFingerprint.mode; }],
      ['fel tallyfördelning, rätt summa', r => { r.tally.passed--; r.tally['not applicable']++; }]
    ];
    const okEmpty = validateReportSchema(good).length === 0;
    let bad = 0;
    for (const [label, mut] of variants) {
      const r = JSON.parse(JSON.stringify(good));
      mut(r);
      if (validateReportSchema(r).length === 0) { console.error('  ✖ "' + label + '" godkändes'); bad++; }
    }
    // Fas 0.13: två deklarerade typfel godkändes av den handskrivna validatorn.
    variants.push(['numeriskt runId', r => { r.runId = 123456; }]);
    variants.push(['numeriskt generatedAt', r => { r.generatedAt = 1234567890; }]);
    variants.push(['okänd tally-nyckel', r => { r.tally.extra = 0; }]);
    variants.push(['exitCode utanför enum', r => { r.exitCode = 7; }]);
    let bad2 = 0;
    for (const [label, mut] of variants.slice(-4)) {
      const r = JSON.parse(JSON.stringify(good));
      mut(r);
      if (validateReportSchema(r).length === 0) { console.error('  ✖ "' + label + '" godkändes'); bad2++; }
    }
    bad += bad2;
    t('M-25 · schemat godkänner en komplett rapport och fäller ' + variants.length + ' trasiga',
      okEmpty && bad === 0, okEmpty ? (bad ? bad + ' släpptes igenom' : '') : 'giltig rapport underkändes: ' + validateReportSchema(good).join('; '));
});

/* M-26 · CHK-SC-01 faller när gen-schema faller eller artefakten driver */
group('M-26', () => {
    const c = ctrl('SC-01', 'schema', { requiredForGate: [0] });
    const okStep = step('gen-schema', 'passed');
    const badStep = step('gen-schema', 'failed');
    const clean = { ok: true, problems: [] };
    const cases = [
      ['allt grönt', { ...base, steps: [okStep], schemaValidation: clean, schemaArtifact: { missing: false, drift: false } }, 'passed'],
      ['gen-schema föll', { ...base, steps: [badStep], schemaValidation: clean, schemaArtifact: { missing: false, drift: false } }, 'blocked'],
      ['steget saknas i kedjan', { ...base, steps: [], schemaValidation: clean, schemaArtifact: { missing: false, drift: false } }, 'failed'],
      ['artefakten driver', { ...base, steps: [okStep], schemaValidation: clean, schemaArtifact: { missing: false, drift: true } }, 'failed'],
      ['artefakten saknas', { ...base, steps: [okStep], schemaValidation: clean, schemaArtifact: { missing: true, drift: false } }, 'failed'],
      ['schemafel i rapporten', { ...base, steps: [okStep], schemaValidation: { ok: false, problems: ['x'] }, schemaArtifact: { missing: false, drift: false } }, 'failed']
    ];
    let bad = 0;
    for (const cs of cases) {
      const got = reduceControls([c], cs[1])[0].status;
      if (got !== cs[2]) { console.error('  ✖ ' + cs[0] + ': ' + got + ', väntade ' + cs[2]); bad++; }
    }
    t('M-26 · CHK-SC-01 kan inte passera med fallen producent eller driftande artefakt (' + cases.length + ' fall)',
      bad === 0, bad ? bad + ' avvikelser' : '');
});

/* M-27 · registertäckning: en beskuren rapport fälls */
group('M-27', () => {
    const full = CONTROLS.map(c => ({ id: c.id, name: c.name, owner: c.owner, source: c.source,
      resolutionPhase: c.resolutionPhase, requiredForGate: c.requiredForGate, status: 'passed' }));
    const okCov = validateRegistryCoverage(full, CONTROLS);
    const trimmed = validateRegistryCoverage(full.filter(c => (c.requiredForGate || []).includes(0)), CONTROLS);
    const extra = validateRegistryCoverage([...full, { id: 'CHK-PAHITT', name: 'x', owner: 'y', source: 'z', resolutionPhase: 0, requiredForGate: [] }], CONTROLS);
    const meta = validateRegistryCoverage(full.map((c, i) => i === 0 ? { ...c, resolutionPhase: 99 } : c), CONTROLS);
    t('M-27 · registertäckning kräver exakt set-likhet och stabil metadata',
      okCov.ok && !trimmed.ok && !extra.ok && !meta.ok,
      'full ' + okCov.ok + ' · beskuren ' + trimmed.ok + ' (' + trimmed.problems.length + ' fel) · extra ' + extra.ok + ' · metadata ' + meta.ok);
});

/* M-28 · rapportrenderaren escapar pipes i tabellceller */
group('M-28', () => {
  // Fas 1: en scope-text med '||' skrev två tabellrader på samma källrad, och
  // T-19 fällde den genererade rapporten på andra körningen.
  const r = fullReport({ failOutsideGate: false });
  r.controls[0].scope = 'A || B och en enkel | pipe';
  r.controls[0].why = 'orsak | med pipe';
  r.controls[1] && (r.controls[1].name = 'namn || med dubbel');
  const md = renderMarkdown(r);
  // Ingen tabellrad får bära en OESCAPAD pipe utöver kolumnavgränsarna.
  // SAMMA maskning och SAMMA radparser som T-19 (tools/lint-core.mjs): en tom
  // cell skrivs legitimt som "| | " och är INTE en dubbel avgränsare.
  // Fas 1 (andra vändan): heuristiken /\|\s*\|\s*\S/ tolkade den tomma cellen i
  // precedenstabellen som ett fel, så M-28 föll medan CHK-T-19 passerade.
  const mask = s => s.replace(/\\\|/g, '\u0000').replace(/`[^`]*`/g, m2 => m2.replace(/\|/g, '\u0000'));
  let offenders = 0, header = null, firstBad = null;
  for (const line of md.split('\n')) {
    if (!line.startsWith('|')) { header = null; continue; }
    const m2 = mask(line);
    if (/^\|[\s:|-]+\|?\s*$/.test(m2)) continue;
    const n = m2.split('|').length;
    if (header === null) { header = n; continue; }
    if (n !== header) { offenders++; if (!firstBad) firstBad = line.slice(0, 120); }
  }
  // De INJICERADE cellerna kontrolleras direkt: varje pipe ska stå escapad.
  const injected = [
    ['scope', 'A \\|\\| B och en enkel \\| pipe'],
    ['why', 'orsak \\| med pipe'],
    ...(r.controls[1] ? [['name', 'namn \\|\\| med dubbel']] : [])
  ];
  const unescaped = injected.filter(([, want]) => !md.includes(want)).map(([f]) => f);
  t('M-28 · pipes i scope, why och name escapas i den genererade rapporten',
    offenders === 0 && unescaped.length === 0,
    offenders ? offenders + ' rader med fel kolumnantal · ' + firstBad
      : (unescaped.length ? 'oescapade celler: ' + unescaped.join(', ') : ''));
});

/* M-29 · TG-01 mäter FAKTISKA värden, inte bara namn */
group('M-29', () => {
  // Fas 1 (tredje vändan): kontrollen såg bara att medlemsnamnen fanns.
  // forestGreen kunde bytas till rent vitt och test-generated gav exit 0.
  const tokens = JSON.parse(readFileSync('tokens.json', 'utf8'));
  const map = JSON.parse(readFileSync('tools/app-theme-map.json', 'utf8'));
  const brand = JSON.parse(readFileSync('assets/brand-colors.json', 'utf8'));
  const colorsSrc = readFileSync('lib/theme/app_colors.dart', 'utf8');
  const textSrc = readFileSync('lib/theme/app_text_styles.dart', 'utf8');
  const legacy = existsSync('legacy-api-contract.json') ? JSON.parse(readFileSync('legacy-api-contract.json', 'utf8')) : null;
  const run1 = (o) => checkAppTheme({ colorsSrc, textSrc, tokens, map, brand, legacy, ...o }).errors;
  const base = run1({});
  const muts = [
    ['vanlig färg', s2 => s2.replace(/(static const Color forestGreen = )Color\(0x[0-9A-F]{8}\)/, '$1Color(0xFFFFFFFF)'), 'colors'],
    ['ljust ColorScheme-värde', s2 => s2.replace(/(lightColorScheme = ColorScheme\(\n\s*brightness: Brightness\.light,\n\s*primary: )Color\(0x[0-9A-F]{8}\)/, '$1Color(0xFF010203)'), 'colors'],
    ['darkOverride', s2 => s2.replace(/(darkColorScheme[\s\S]*?onError: )Color\(0x[0-9A-F]{8}\)/, '$1Color(0xFF040506)'), 'colors'],
    ['varumärkesfärg', s2 => s2.replace(/(static const Color brand[A-Z]\w* = )Color\(0x[0-9A-F]{8}\)/, '$1Color(0xFF00FF00)'), 'colors'],
    ['aliasmål', s2 => s2.replace(/(static const Color textSecondary = )\w+;/, '$1textDark;'), 'colors'],
    ['typroll', s2 => s2.replace(/(get bodyLarge => TextStyle\(\n\s*fontFamily: family,\n\s*fontSize: )[\d.]+/, '$199'), 'text'],
    ['typalias', s2 => s2.replace(/(get buttonText => )\w+;/, '$1labelMedium;'), 'text'],
    ['semantisk variant', s2 => s2.replace(/(get errorText => \w+\.copyWith\(color: )AppColors\.\w+/, '$1AppColors.success'), 'text'],
    // BÅDA riktningarna av mängdlikheten. Fas 1 (femte vändan): sviten provade
    // bara borttagningsriktningen, trots att implementationen fångar båda.
    ['borttagen legacy-medlem', s2 => s2.replace(/\n  static const Color textSecondary = \w+;/, ''), 'colors'],
    ['oanmäld extra legacy-medlem', s2 => s2.replace(/(static const Color transparent = Colors\.transparent;)/, '$1\n  static const Color oanmaldMedlem = Color(0xFF000000);'), 'colors'],
    ['borttagen legacy-getter', s2 => s2.replace(/\n  static TextStyle get buttonText => \w+;/, ''), 'text'],
    ['oanmäld extra legacy-getter', s2 => s2.replace(/(  \/\/ ── Alias · samma stil, historiska namn ──)/, '$1\n  static TextStyle get oanmaldGetter => bodyLarge;'), 'text']
  ];
  const misses = [];
  for (const [label, mut, which] of muts) {
    const c2 = which === 'colors' ? mut(colorsSrc) : colorsSrc;
    const t2 = which === 'text' ? mut(textSrc) : textSrc;
    const changed = which === 'colors' ? c2 !== colorsSrc : t2 !== textSrc;
    if (!changed) { misses.push(label + ' (mutationen kunde inte byggas)'); continue; }
    const errs = run1({ colorsSrc: c2, textSrc: t2 });
    if (errs.length <= base.length) misses.push(label);
  }
  t('M-29 · TG-01 fäller ändrade FÄRGVÄRDEN, schemaslottar, aliasmål och typroller',
    base.length === 0 && misses.length === 0,
    'baslinje ' + base.length + ' fel · ' + (muts.length - misses.length) + '/' + muts.length + ' mutationer fällda' +
    (misses.length ? ' · MISSADE: ' + misses.join(', ') : ''));
});

/* M-30 · GEN-02 fäller en KROPP som inte kommer ur generatorn */
group('M-30', () => {
  // Fas 1 (tredje vändan): preflight jämförde bara headerns tokenversion och
  // källfingeravtryck. Två levererade filer hade helt korrekt header och
  // fingeravtryck men en kropp ur en äldre körning — GEN-02 stod grön.
  const NEED = ['tools/preflight.mjs', 'tools/gen-targets.mjs', 'tools/gen-header.mjs', 'tools/gen-check.mjs',
    ...new Set(Object.values(GENERATED_REGISTER).map(v => v.generator)),
    ...new Set(Object.values(GENERATED_REGISTER).flatMap(v => v.inputs)),
    ...Object.keys(GENERATED_REGISTER)];
  const dir = mkdtempSync(join(tmpdir(), 'butlery-gen02-'));
  for (const f of [...new Set(NEED)]) {
    mkdirSync(join(dir, f.split('/').slice(0, -1).join('/')), { recursive: true });
    copyFileSync(f, join(dir, f));
  }
  const run = () => runProc(process.execPath, ['tools/preflight.mjs'], { cwd: dir });
  const clean = run();
  // Mutera KROPPEN — inte headern. Första raden efter headern som bär ett värde.
  const bodyMutate = (file, re, to) => {
    const p2 = join(dir, file);
    const s2 = readFileSync(p2, 'utf8');
    const n2 = s2.replace(re, to);
    if (n2 === s2) return false;
    writeFileSync(p2, n2);
    return true;
  };
  const cssOk = bodyMutate('assets/generated/tokens.css', /(--butlery-touch-min:\s*)\d+/, '$1999');
  const css = run();
  copyFileSync('assets/generated/tokens.css', join(dir, 'assets/generated/tokens.css'));
  const dartOk = bodyMutate('lib/theme/app_colors.dart', /(static const Color forestGreen = )Color\(0x[0-9A-F]{8}\)/, '$1Color(0xFFFFFFFF)');
  const dart = run();
  rmSync(dir, { recursive: true, force: true });
  const headerIntact = /GEN-CHECK drift/.test(css.out) && !/fingeravtrycket är/.test(css.out);
  t('M-30 · GEN-02 fäller kroppsdrift trots korrekt header och fingeravtryck',
    clean.code === 0 && cssOk && dartOk && css.code === 1 && dart.code === 1 && headerIntact,
    'ren ' + clean.code + ' · css ' + css.code + ' · dart ' + dart.code +
    ' · mutationer ' + [cssOk, dartOk].join(',') + ' · kroppsdiagnostik ' + headerIntact);
});

/* M-31 · KÄLLMUTATIONER följda av regenerering */
group('M-31', () => {
  // Fas 1 (fjärde vändan): M-29 muterade genererad output mot oförändrad källa.
  // Tre mutationer av SJÄLVA MAPPNINGEN passerade hela kedjan efter
  // regenerering: rå färg i darkOverrides, en typeSemantic-färg mot en medlem
  // som inte finns, och ett borttaget legacy-alias.
  const NEED = ['tools/gen-app-theme.mjs', 'tools/gen-header.mjs', 'tools/gen-check.mjs', 'tools/gen-targets.mjs',
    'tools/check-app-theme.mjs', 'tools/test-generated.mjs',
    'tokens.json', 'tools/app-theme-map.json', 'assets/brand-colors.json', 'legacy-api-contract.json',
    ...Object.keys(GENERATED_REGISTER)];
  const build = () => {
    const dir = mkdtempSync(join(tmpdir(), 'butlery-src-'));
    for (const f of [...new Set(NEED)]) {
      const sub = f.split('/').slice(0, -1).join('/');
      mkdirSync(sub ? join(dir, sub) : dir, { recursive: true });
      copyFileSync(f, join(dir, f));
    }
    return dir;
  };
  const mutate = (dir, fn) => {
    const p = join(dir, 'tools/app-theme-map.json');
    const m = JSON.parse(readFileSync(p, 'utf8'));
    if (fn(m) === false) return false;
    writeFileSync(p, JSON.stringify(m, null, 2) + '\n');
    return true;
  };
  const gen = dir => runProc(process.execPath, ['tools/gen-app-theme.mjs'], { cwd: dir });
  const tg = dir => runProc(process.execPath, ['tools/test-generated.mjs'], { cwd: dir });
  const problems = [];

  // 0 · Kontroll: orörd kopia ska regenerera och passera.
  { const dir = build();
    const g = gen(dir), v = tg(dir);
    if (g.code !== 0) problems.push('orörd kopia: generatorn gav ' + g.code);
    if (v.code !== 0) problems.push('orörd kopia: test-generated gav ' + v.code + ' :: ' + v.out.split('\n').filter(l => /^✖/.test(l))[0]);
    rmSync(dir, { recursive: true, force: true }); }

  // 1 · Rå färg i darkOverrides → generatorn får inte skriva något.
  { const dir = build();
    const ok = mutate(dir, m => { m.scheme.darkOverrides[Object.keys(m.scheme.darkOverrides)[0]] = ['raw', 'rgba(1,2,3,0.4)']; });
    const g = gen(dir);
    if (!ok || g.code === 0) problems.push('rå darkOverride: generatorn gav ' + g.code + ' (väntade ≠ 0)');
    rmSync(dir, { recursive: true, force: true }); }

  // 2 · typeSemantic.color mot en medlem som inte finns.
  { const dir = build();
    const ok = mutate(dir, m => {
      const k = Object.keys(m.typeSemantic).find(x => m.typeSemantic[x].color);
      if (!k) return false;
      m.typeSemantic[k].color = 'AppColors.doesNotExist';
    });
    const g = gen(dir);
    if (!ok || g.code === 0) problems.push('okänd AppColors-medlem: generatorn gav ' + g.code + ' (väntade ≠ 0)');
    rmSync(dir, { recursive: true, force: true }); }

  // 3 · Borttaget legacy-alias → generatorn lyckas, men det FRYSTA kontraktet fäller.
  { const dir = build();
    const ok = mutate(dir, m => { delete m.aliases.textSecondary; });
    const g = gen(dir);
    const v = tg(dir);
    if (!ok || g.code !== 0) problems.push('borttaget alias: generatorn gav ' + g.code + ' (väntade 0)');
    else if (v.code === 0 || !/LEGACY-API/.test(v.out))
      problems.push('borttaget alias: test-generated gav ' + v.code + ' utan LEGACY-API-diagnostik');
    rmSync(dir, { recursive: true, force: true }); }

  t('M-31 · källmutationer i mappningen fälls efter regenerering (rå kind, okänd medlem, borttaget legacy-alias)',
    problems.length === 0, problems.join(' · ') || '4 fall: orörd grön, tre mutationer fällda');
});

/* M-32 · processprovens miljö kan inte förgiftas av moderprocessen */
group('M-32', () => {
  // Fas 1 (femte vändan): cleanEnv() sanerade basmiljön men opts.env kunde
  // återinföra BUTLERY_* — och gateEnv() spred process.env rakt igenom. En
  // förgiftad moderprocess kunde därför styra ett barnprovs läge och fas.
  const before = { ...process.env };
  process.env.BUTLERY_MANIFEST_MODE = 'delivery';
  process.env.BUTLERY_PHASE = '7';
  process.env.BUTLERY_PAHITT = 'ja';
  process.env.GITHUB_ACTIONS = 'true';
  process.env.GITHUB_RUN_ID = '999';
  const bare = __cleanEnvForTest({});
  const withCi = __cleanEnvForTest({ ...CI_ENV, BUTLERY_PHASE: '1', BUTLERY_PAHITT: 'nej' });
  // Bevisa dessutom att ett barn FAKTISKT ser den sanerade miljön.
  const seen = runProc(process.execPath, ['-e',
    'process.stdout.write(JSON.stringify({m:process.env.BUTLERY_MANIFEST_MODE??null,p:process.env.BUTLERY_PHASE??null,x:process.env.BUTLERY_PAHITT??null,g:process.env.GITHUB_RUN_ID??null}))'],
    { env: { ...CI_ENV, BUTLERY_PHASE: '1' } });
  let child = {};
  try { child = JSON.parse(seen.out); } catch {}
  for (const k of Object.keys(process.env)) if (!(k in before)) delete process.env[k];
  Object.assign(process.env, before);
  t('M-32 · processprovens miljö bär bara uttryckligen tillåtna värden',
    bare.BUTLERY_MANIFEST_MODE === undefined && bare.BUTLERY_PHASE === undefined && bare.BUTLERY_PAHITT === undefined &&
    bare.GITHUB_RUN_ID === undefined && withCi.BUTLERY_PHASE === '1' && withCi.BUTLERY_PAHITT === undefined &&
    withCi.GITHUB_RUN_ID === CI_ENV.GITHUB_RUN_ID &&
    child.m === null && child.p === '1' && child.x === null && child.g === CI_ENV.GITHUB_RUN_ID,
    'bas: ' + JSON.stringify({ m: bare.BUTLERY_MANIFEST_MODE ?? null, p: bare.BUTLERY_PHASE ?? null, x: bare.BUTLERY_PAHITT ?? null }) +
    ' · tillåtet: ' + JSON.stringify({ p: withCi.BUTLERY_PHASE, x: withCi.BUTLERY_PAHITT ?? null }) +
    ' · barnet såg: ' + JSON.stringify(child));
});

const fail = results.filter(r => !r.ok).length;
console.log('\nMETATEST-SUMMARY pass=' + (results.length - fail) + ' fail=' + fail + ' total=' + results.length);
process.exit(fail ? 1 : 0);