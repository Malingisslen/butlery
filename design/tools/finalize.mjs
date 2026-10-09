#!/usr/bin/env node
// Butlery · FINALISERING. Kör: node tools/finalize.mjs
//
// Rent och ICKE-MUTERANDE: kör inga generatorer och ingen lint. Läser den
// färdiga rapporten plus det KOMPLETTA fas0/ci-evidence.json, reducerar om
// CI-kontrollen och totalerna, och skriver atomiskt om båda rapportfilerna.
//
// Fas 0.12: workflowen skrev beviset före kedjan (utan completedAt och
// verifyExitCode), verify.mjs läste den ofullständiga filen och satte CHK-CI-01
// till failed. Beviset kompletterades efteråt, men ingen räknade om — så gate.mjs
// läste en gammal sanning.
import { readFileSync, writeFileSync, existsSync, renameSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { CONTROLS } from './controls.mjs';
import { renderMarkdown } from './gen-report.mjs';
import { reduceControls, computeTotals, validateReport, validateRegistryCoverage, validateReportSchema } from './report-logic.mjs';

const DIR = 'fas0';
const RP = DIR + '/verify-report.json';
if (!existsSync(RP)) { console.error('✖ ingen rapport på ' + RP + ' — kör bash fas0/run-verify.sh först'); process.exit(2); }
const report = JSON.parse(readFileSync(RP, 'utf8'));

// INGÅNGSVALIDERING före varje normalisering. Fas 0.14: finalizeraren skrev ett
// nytt giltigt runId innan valideringen, så en ogiltig ingångsrapport (numeriskt
// runId eller generatedAt) blev giltig genom finalisering.
{
  const inProblems = validateReportSchema(report);
  if (inProblems.length) {
    console.error('✖ INGÅNGSRAPPORT  ' + inProblems.length + ' schemafel i ' + RP + ' — finalisering kan inte tvätta bort dem:');
    for (const p of inProblems.slice(0, 8)) console.error('   · ' + p);
    // Utfallet bevaras i rapporten och gör totalen röd; runId skrivs INTE om.
    report.inputSchemaValidation = { ok: false, problems: inProblems };
  } else {
    report.inputSchemaValidation = { ok: true, problems: [] };
  }
}
// Den levererade schemaartefaktens utfall mäts av verify.mjs FÖRE generatorn och
// får inte tappas här.
const deliveredSchemaArtifact = report.schemaArtifact ?? null;
// Fingeravtrycket togs efter kedjan och beskriver samma yta — finaliseringen
// ändrar bara rapportfilerna, som inte ingår i ytan. Det bevaras alltså orört.
const deliveredFingerprint = report.packageIdentity && report.packageIdentity.artifactFingerprint;

let ciEvidence = null;
if (existsSync(DIR + '/ci-evidence.json')) {
  try { ciEvidence = JSON.parse(readFileSync(DIR + '/ci-evidence.json', 'utf8')); }
  catch { console.error('✖ ci-evidence.json går inte att tolka'); }
}
// Kedjans FAKTISKA slutkod, skriven av wrappern efter att manifest och verify
// vägts samman. CI-bevisets exitkod jämförs mot den.
const chainExitCode = existsSync(DIR + '/verify-exit')
  ? Number(String(readFileSync(DIR + '/verify-exit', 'utf8')).trim()) : (report.finalExitCode ?? null);

// STALE INGÅNGSRAPPORT: den ofinaliserade rapporten måste gälla samma paket och,
// i CI, samma körning som det färdiga beviset. Fas 0.13.
const pre = [];
if (ciEvidence) {
  const pk = report.packageIdentity || {};
  if (pk.manifestSha256 && ciEvidence.manifestSha256 && pk.manifestSha256 !== ciEvidence.manifestSha256)
    pre.push('rapportens manifesthash ' + String(pk.manifestSha256).slice(0, 12) + '… ≠ bevisets ' + String(ciEvidence.manifestSha256).slice(0, 12) + '…');
  if (pk.commit && ciEvidence.commit && pk.commit !== ciEvidence.commit)
    pre.push('rapporten kördes på commit ' + String(pk.commit).slice(0, 8) + ' men beviset avser ' + String(ciEvidence.commit).slice(0, 8));
  const rt = Date.parse(report.generatedAt || '');
  const st = Date.parse(ciEvidence.startedAt || '');
  const ct = Date.parse(ciEvidence.completedAt || '');
  if (rt && st && rt < st - 60000) pre.push('rapporten skrevs före CI-körningens start — den är från en tidigare körning');
  if (rt && ct && rt > ct + 60000) pre.push('rapporten skrevs efter att CI-körningen avslutades');
}
if (pre.length) { for (const p of pre) console.error('✖ FINALIZE  ' + p); }
report.finalizeProblems = pre;

// sources bär in/ut-hashar per källfil och är obligatoriskt i schemat.
report.sources = report.sources || {};
report.ciEvidence = ciEvidence;
report.chainExitCode = chainExitCode;
report.finalizedAt = new Date().toISOString();
if (Date.parse(report.finalizedAt) < Date.parse(report.generatedAt || 0))
  pre.push('finaliseringstiden ligger före rapportens generatedAt');

// Samma reducering och samma totaler som verify.mjs — ingen egen logik här.
report.controls = reduceControls(CONTROLS, {
  ciEvidence,
  packageIdentity: report.packageIdentity,
  chainExitCode,
  ciEnv: { GITHUB_ACTIONS: process.env.GITHUB_ACTIONS, GITHUB_RUN_ID: process.env.GITHUB_RUN_ID,
    GITHUB_RUN_ATTEMPT: process.env.GITHUB_RUN_ATTEMPT, GITHUB_SHA: process.env.GITHUB_SHA,
    GITHUB_REPOSITORY: process.env.GITHUB_REPOSITORY, GITHUB_WORKFLOW: process.env.GITHUB_WORKFLOW },
  selftestSummary: report.selftestSummary,
  selftestCoverage: report.selftestCoverage,
  metatestSummary: report.metatestSummary,
  preflightSummary: report.preflightSummary,
  perControl: report.perControl,
  measures: report.measures,
  steps: report.steps,
  ranControls: report.ranControls || [],
  manifest: report.manifest,
  manifestMode: report.manifestMode || process.env.BUTLERY_MANIFEST_MODE || 'repo',
  generatedDrift: report.generatedDrift || [],
  schemaArtifact: deliveredSchemaArtifact,
  schemaValidation: { ok: true, problems: [] }
});

report.tally = { passed: 0, failed: 0, blocked: 0, 'not run': 0, 'not applicable': 0 };
for (const c of report.controls) report.tally[c.status] = (report.tally[c.status] || 0) + 1;

const totals = computeTotals({
  steps: report.steps, controls: report.controls, manifest: report.manifest,
  generatedDrift: report.generatedDrift || [],
  manifestMode: report.manifestMode || 'repo',
  currentPhase: Number(process.env.BUTLERY_PHASE ?? report.currentPhase ?? 0)
});
Object.assign(report, totals);
report.overallBlockers = totals.blockers;
report.result = report.overallResult;

const rv = validateReport(report.controls, report.tally);
report.reportValidation = rv;
if (!rv.ok) for (const p of rv.problems) console.error('✖ RAPPORT  ' + p);
const cov = validateRegistryCoverage(report.controls, CONTROLS);
report.registryCoverage = cov;
if (!cov.ok) { for (const p of cov.problems) console.error('✖ TÄCKNING  ' + p); pre.push('registertäckning: ' + cov.problems.length + ' avvikelser'); }

// Nytt runId för den finaliserade rapporten, bundet till CI-körningen när den finns.
if (report.inputSchemaValidation && !report.inputSchemaValidation.ok) {
  pre.push('ingångsrapporten hade ' + report.inputSchemaValidation.problems.length + ' schemafel — de kan inte finaliseras bort');
}
report.schemaArtifact = deliveredSchemaArtifact;
if (deliveredFingerprint && report.packageIdentity) report.packageIdentity.artifactFingerprint = deliveredFingerprint;
// Ett ogiltigt underlag får INTE normaliseras. Fas 0.15: kommentaren sa att
// runId inte skrevs om, men koden gjorde det ovillkorligt — och grinden såg en
// giltig rapport. Nu bevaras ingångens runId och integritetsfelet grindar.
if (report.inputSchemaValidation && !report.inputSchemaValidation.ok) {
  report.finalizeAborted = true;
  console.error('✖ FINALIZE  ingångsrapporten är ogiltig — normaliseringen avbryts, runId bevaras');
} else report.runId = createHash('sha256')
  .update(String(Date.now()) + ':' + (report.packageIdentity?.manifestSha256 || '') + ':' + (ciEvidence?.runId || process.pid))
  .digest('hex').slice(0, 16);
report.finalized = !report.finalizeAborted;
report.generatedAt = report.finalizedAt;

const sp = validateReportSchema(report);
report.schemaValidation = { ok: sp.length === 0, problems: sp };
// CHK-SC-01 sattes tidigare om här ur bara schemavalideringen, vilket gjorde en
// stale LEVERERAD schemafil grön efter finalisering. Statusen kommer nu enbart ur
// reduceControls(), som väger alla tre villkoren. Fas 0.15.
if (sp.length) { for (const p of sp) console.error('✖ SCHEMA  ' + p); report.overallResult = 'failed'; report.result = 'failed'; report.exitCode = 1; report.finalExitCode = 1; }
if (!rv.ok || pre.length) { report.overallResult = 'failed'; report.result = 'failed'; report.exitCode = 1; report.finalExitCode = 1; }
if (pre.length) report.overallBlockers = [...(report.overallBlockers || []), 'finalisering: ' + pre.join('; ')];

const jt = DIR + '/.verify-report.json.' + report.runId + '.tmp';
const mt = DIR + '/.kontrollstatus.md.' + report.runId + '.tmp';
writeFileSync(jt, JSON.stringify(report, null, 2));
writeFileSync(mt, renderMarkdown(report));
const back = JSON.parse(readFileSync(jt, 'utf8'));
if (back.runId !== report.runId || !Array.isArray(back.controls)) { console.error('✖ ofullständig temporärfil — byter inte in'); process.exit(3); }
renameSync(jt, RP);
renameSync(mt, DIR + '/kontrollstatus.md');

const ci = report.controls.find(c => c.id === 'CHK-CI-01');
console.log('FINALIZE-SUMMARY runId=' + report.runId + ' ciStatus=' + (ci ? ci.status : '?') +
  ' gate=' + report.phaseGateResult + ' overall=' + report.overallResult + ' schemaOk=' + report.schemaValidation.ok);
if (ci && ci.status !== 'passed') console.error('· CHK-CI-01: ' + ci.why);
// Ett avbrott får inte rapporteras som framgång. Fas 0.16: finalizeAborted gav
// exit 0 och skrev "✔ rapporten finaliserad" trots finalized: false.
const aborted = report.finalizeAborted === true || report.finalized !== true || pre.length > 0;
if (aborted) {
  console.error('✖ finaliseringen AVBRÖTS — rapporten är inte finaliserad (' +
    (report.finalizeAborted ? 'ogiltig ingångsrapport' : pre.join('; ') || 'okänt skäl') + ')');
  console.error('  rapporten är ändå skriven så att grinden kan dokumentera avslaget: ' + RP);
  process.exit(1);
}
console.log('✔ rapporten finaliserad · ' + RP);
process.exit(0);
