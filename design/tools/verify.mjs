#!/usr/bin/env node
// Butlery · ETT kanoniskt kommando: node tools/verify.mjs
// Kör hela kedjan en gång, särredovisar felklasser (spec-fel, spec-varningar,
// geometriavvikelser) utan att summera över klassgränser, och skriver
// fas0/verify-report.json + fas0/kontrollstatus.md ur SAMMA kontrollregister.
import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync, readFileSync, existsSync, renameSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { CONTROLS } from './controls.mjs';
import { GENERATED_OUTPUTS } from './gen-targets.mjs';
import { renderMarkdown } from './gen-report.mjs';
import { classifyStep, reduceControls, computeTotals, countRequirements, validateRegistry, validateReport, validateRegistryCoverage, parseEvidence, validateReportSchema, checkNamespaces, REPORT_SCHEMA, artifactFingerprint } from './report-logic.mjs';

const REPORT_DIR = 'fas0';
const steps = [
  ['Rapportschema ur källan', 'tools/gen-schema.mjs', 'gen-schema'],
  ['Preflight: incheckad genererad kod', 'tools/preflight.mjs', 'preflight'],
  ['Ikonräkning', 'tools/gen-icons.mjs', 'gen-icons'],
  ['Ram- och kontrollräkning', 'tools/gen-counts.mjs', 'gen-counts'],
  ['CSS ur tokens', 'tools/gen-css.mjs', 'gen-css'],
  ['Flutter-tema ur tokens', 'tools/gen-flutter.mjs', 'gen-flutter'],
  // Fas 1: app_colors.dart och app_text_styles.dart stod kvar på tokens 1.3
  // eftersom generatorn aldrig ingick i kedjan.
  ['App-tema ur tokens', 'tools/gen-app-theme.mjs', 'gen-app-theme'],
  // Fas 1 (femte vändan): registret var handskrivet och drev. Det genereras nu
  // ur source-authority.json och vaktas av GEN-01.
  ['Källauktoritetsregister ur source-authority.json', 'tools/gen-authority.mjs', 'gen-authority'],
  // F1-H08/H09: manifestet var handskrivet. Kedjan SKRIVER det inte — då hade
  // ett stale manifest tyst reparerats i stället för att rapporteras — men den
  // kräver att den incheckade listan är byteidentisk med vad enumeratorn ger.
  // I repo-läge bärs zip:/-posterna vidare oförändrade; att de stämmer bevisas
  // i delivery-läge av CHK-MF-01.
  ['Manifestet mot enumeratorn', 'tools/gen-manifest.mjs --check', 'gen-manifest-check'],
  ['Genererad kod', 'tools/test-generated.mjs', 'test-generated'],
  ['Kontrollgeometri', 'tools/lint-controls.mjs', 'lint-controls'],
  ['Spec-lint', 'tools/spec-lint.mjs', 'spec-lint'],
  ['Verifierarens egna mutationsprov', 'tools/selftest.mjs', 'selftest'],
  ['Metatester för verktygskedjan', 'tools/metatest.mjs', 'metatest']
];

const SRC = ['tokens.json', 'icons.json', 'assets-manifest.json'];
const sha = f => existsSync(f) ? createHash('sha256').update(readFileSync(f)).digest('hex') : null;
const ver = f => { try { return JSON.parse(readFileSync(f, 'utf8')).version; } catch { return null; } };

const report = {
  schema: 'butlery-verify-report/2',
  command: 'node tools/verify.mjs',
  generated: new Date().toISOString(),
  node: process.version,
  cwd: process.cwd(),
  // Källor hashas FÖRE och EFTER kedjan: generatorerna skriver i flera av dem.
  sources: Object.fromEntries(SRC.map(f => [f, { version: ver(f), inputSha256: sha(f) }])),
  ranControls: [],
  // Wrappern kör manifestkontrollen FÖRE kedjan och skickar in utfallet.
  // Utan detta kunde JSON säga passed medan det kanoniska kommandot gav exit 1.
  manifest: {
    status: process.env.BUTLERY_MANIFEST_STATUS || 'not run',
    files: Number(process.env.BUTLERY_MANIFEST_FILES || 0),
    parsed: Number(process.env.BUTLERY_MANIFEST_PARSED || 0),
    verified: Number(process.env.BUTLERY_MANIFEST_VERIFIED || 0),
    bad: Number(process.env.BUTLERY_MANIFEST_BAD || 0),
    missing: Number(process.env.BUTLERY_MANIFEST_MISSING || 0),
    duplicates: Number(process.env.BUTLERY_MANIFEST_DUP || 0),
    unlisted: Number(process.env.BUTLERY_MANIFEST_UNLISTED || 0),
    outsideAbsent: Number(process.env.BUTLERY_MANIFEST_OUTSIDE || 0),
    exitCode: process.env.BUTLERY_MANIFEST_EXIT === undefined ? null : Number(process.env.BUTLERY_MANIFEST_EXIT),
    why: process.env.BUTLERY_MANIFEST_STATUS ? null : 'kördes inte — verify.mjs anropades direkt i stället för via fas0/run-verify.sh'
  },
  steps: [],
  measures: { specErrors: 0, specWarnings: 0, geometryDeviations: 0, coverageErrors: 0 },
  perControl: {},
  metrics: {},
  controls: []
};

const bump = (id, kind) => {
  const e = report.perControl[id] || (report.perControl[id] = { errors: 0, warnings: 0 });
  e[kind]++;
};

// KANONISKT register över allt generatorerna skriver — EN källa, delad med
// metatest M-18. gen-counts skriver fyra dokument som inte hashades: ett stale
// räkneankare rättades tyst och GEN-01 rapporterade passed med tom drift.
// Fas 0.9. Fas 1: listan flyttad till tools/gen-targets.mjs.
// (listan ligger i tools/gen-targets.mjs och importeras ovan)
// SCHEMAARTEFAKTEN mäts FÖRE gen-schema.mjs. Fas 0.14: mätningen låg efter
// generatorn, som hann reparera en stale leverans innan kontrollen tittade —
// drift: false på en fil som körningen just skrivit om.
const deliveredSchema = (() => {
  const p = 'fas0/verify-report.schema.json';
  const want = JSON.stringify(REPORT_SCHEMA, null, 2) + '\n';
  if (!existsSync(p)) return { missing: true, drift: false, deliveredSha256: null };
  const onDisk = readFileSync(p, 'utf8');
  return { missing: false, drift: onDisk !== want,
    deliveredSha256: createHash('sha256').update(onDisk).digest('hex') };
})();
if (deliveredSchema.missing) console.error('✖ SC-01  fas0/verify-report.schema.json saknas i leveransen');
else if (deliveredSchema.drift) console.error('✖ SC-01  den LEVERERADE fas0/verify-report.schema.json motsvarade inte REPORT_SCHEMA — kör node tools/gen-schema.mjs och committa resultatet');

const preHashes = Object.fromEntries(GENERATED_OUTPUTS.map(f => [f, sha(f)]));
let failed = null;
for (const [name, script, key] of steps) {
  process.stdout.write('\n── ' + name + ' (' + script + ')\n');
  // spawnSync: BÅDA strömmarna samlas oavsett exitkod. execFileSync gav bara
  // stdout vid exit 0, så ett verktyg som skrev fällande diagnostik till stderr
  // och av misstag returnerade 0 blev osynligt — hela kedjan kunde stå grön med
  // 0 rapporterade fel. Fas 0.8. Ett steg fälls av exitkod ELLER diagnostik.
  // Ett steg får bära argument ("tools/gen-manifest.mjs --check").
  const proc = spawnSync(process.execPath, script.split(' '), { encoding: 'utf8' });
  const out = (proc.stdout || '') + (proc.stderr || '');
  const code = proc.status ?? 1;
  const verdict = classifyStep(out, code);
  let status = verdict.status;
  process.stdout.write(out);
  const lines = out.split('\n');
  let specErrors = 0, specWarnings = 0, geometry = 0;

  if (key === 'spec-lint') {
    for (const l of lines) {
      let m = l.match(/^\s*✖\s+([A-ZÅÄÖ0-9]+-\d+[a-z]?)/u);
      if (m) { specErrors++; bump(m[1], 'errors'); continue; }
      m = l.match(/^\s*[⚠◐!]\s*([A-ZÅÄÖ0-9]+-\d+[a-z]?)/u);
      if (m) { specWarnings++; bump(m[1], 'warnings'); }
    }
  } else if (key === 'lint-controls') {
    // Geometriavvikelser är en EGEN mätklass och summeras aldrig med spec-fel.
    // Maskinläsbar rad först. Verktyget skriver "avvikelse(r)", inte
    // "avvikelser" — den gamla parsern föll igenom till reservlogiken och
    // rapporterade "… och N fler" som totalen (217 i stället för 417).
    const machine = out.match(/^LC-SUMMARY deviations=(\d+)/m);
    const sum = machine || out.match(/(\d+)\s+avvikelse/);
    if (sum) geometry = Number(sum[1]);
    else {
      const shown = lines.filter(l => /^\s+\S+\.dc\.html:\d+/.test(l)).length;
      const more = out.match(/och\s+(\d+)\s+fler/);
      geometry = shown + (more ? Number(more[1]) : 0);
    }
    const cov = out.match(/coverage_errors=(\d+)/);
    report.measures.coverageErrors = cov ? Number(cov[1]) : 0;
    if (geometry || report.measures.coverageErrors) report.perControl['LC-01'] = { errors: 0, warnings: 0, deviations: geometry };
  }

  // Fällande diagnostik i utdata fäller steget även vid exit 0.
  if (verdict.integrity) {
    report.integrityWarnings = report.integrityWarnings || [];
    report.integrityWarnings.push(script + ' returnerade exit 0 men ' + verdict.reason + ' — steget fälls på diagnostiken, inte på exitkoden');
  }
  if (status === 'failed') failed = failed || name;

  if (key === 'spec-lint') {
    const m = out.match(/^KÖRDA:\s*(.*)$/m);
    report.ranControls = m ? m[1].trim().split(/\s+/).filter(Boolean) : [];
  }
  report.measures.specErrors += specErrors;
  report.measures.specWarnings += specWarnings;
  report.measures.geometryDeviations += geometry;
  // MÄTVÄRDEN läses bara ur STEGETS EGEN maskinsummering, med proveniens.
  if (key === 'gen-counts') {
    const cs = out.match(/^COUNT-SUMMARY (.*)$/m);
    if (cs) {
      for (const pair of cs[1].trim().split(/\s+/)) {
        const [k, val] = pair.split('=');
        if (k && /^\d+$/.test(val || '')) report.metrics[k] = { value: Number(val), source: 'gen-counts.mjs · COUNT-SUMMARY' };
      }
    } else {
      report.integrityWarnings = report.integrityWarnings || [];
      report.integrityWarnings.push('gen-counts.mjs skrev ingen COUNT-SUMMARY — mätvärdena kan inte läsas maskinellt');
    }
  }
  for (const [k, re] of [['selftestSummary', /^SELFTEST-SUMMARY (.*)$/m], ['selftestCoverage', /^SELFTEST-COVERAGE (.*)$/m], ['metatestSummary', /^METATEST-SUMMARY (.*)$/m]]) {
    const mm = out.match(re);
    if (mm) report[k] = Object.fromEntries(mm[1].trim().split(/\s+/).map(p => p.split('=')).map(([a, b2]) => [a, /^\d+$/.test(b2 || '') ? Number(b2) : b2]));
  }
  report.steps.push({ step: name, script, status, exitCode: code, specErrors, specWarnings, geometryDeviations: geometry, tail: lines.filter(Boolean).slice(-12) });
}

// GEN-01 · genererade filer får inte ändras av en verifieringskörning. Ändras
// de var de incheckade filerna stale, och CI reparerade tyst arbetskopian.
report.generatedDrift = [];
for (const f of GENERATED_OUTPUTS) {
  const now = sha(f);
  const before = preHashes[f];
  if (before && now && before !== now) report.generatedDrift.push(f);
}
if (report.generatedDrift.length) console.log('◐ GEN-01  generatorerna ändrade ' + report.generatedDrift.length + ' incheckad(e) fil(er): ' + report.generatedDrift.join(', ') + ' — committa dem');

// Sluthashar efter generering — generatorerna skriver i icons.json m.fl.
for (const f of SRC) { report.sources[f].outputSha256 = sha(f); report.sources[f].version = ver(f); }
report.sources.$note = 'inputSha256 är filen före kedjan, outputSha256 efter. Skiljer de sig har en generator skrivit i filen, vilket betyder att den incheckade versionen var stale — GEN-01 fäller på det. Drift är alltså förväntad som mätning, aldrig godtagbar som tillstånd.';

// Kontrollregistret: statiska rader + körningens utfall
// Reduceringen och totalerna ligger i tools/report-logic.mjs som RENA
// funktioner, så metatesterna kan mata in konstruerade rapporter. Fas 0.8.
// ── SLUTFAS · en ordning, en skrivning ────────────────────────────────────
// Fas 0.10: paketidentiteten beräknades EFTER reduceringen (så CI-01 fick
// undefined att jämföra mot), och rapporten skrevs FÖRE validateReport (så den
// sparade JSON saknade reportValidation och kunde se grön ut medan processen gav
// exit 1). Nu: identitet → register → reducering → krav → tally → totaler →
// validering → EN atomisk skrivning.

// 1 · Paketidentitet. Vilket komplett paket kördes? cwd och tre källhashar
// räcker inte; manifesthashen identifierar hela artefaktytan.
// ARTEFAKTFINGERAVTRYCK över hela den bedömda ytan, taget EFTER kedjan. Grinden
// jämför om ytan ändrats efter rapportskrivningen. Fas 0.14: grinden mätte bara
// manifestfilens hash och mtime på tre filer, så en ändrad tokens.json passerade.
const MODE = process.env.BUTLERY_MANIFEST_MODE || 'repo';
const fpIo = {
  exists: p => existsSync(p),
  sha256: p => createHash('sha256').update(readFileSync(p)).digest('hex'),
  hashString: s => createHash('sha256').update(s).digest('hex')
};
const fingerprint = existsSync('fas0/andrade-filer.md')
  ? artifactFingerprint(readFileSync('fas0/andrade-filer.md', 'utf8'), MODE, fpIo)
  : { mode: MODE, sha256: fpIo.hashString(''), declared: 0, hashed: 0, missing: 0, totalEntries: 0, outsideEntries: 0 };

report.packageIdentity = {
  artifactFingerprint: fingerprint,
  manifestSha256: existsSync('fas0/andrade-filer.md') ? createHash('sha256').update(readFileSync('fas0/andrade-filer.md')).digest('hex') : null,
  manifestExpected: existsSync('fas0/andrade-filer.md')
    ? Number((readFileSync('fas0/andrade-filer.md', 'utf8').match(/<!--manifest:files=(\d+)-->/) || [])[1] || 0) : 0,
  commit: process.env.GITHUB_SHA || process.env.BUTLERY_COMMIT || null,
  cwd: process.cwd(),
  node: process.version
};
// expected kommer från wrappern när den finns, annars ur manifestet självt.
report.manifest.expected = Number(process.env.BUTLERY_MANIFEST_EXPECTED || 0) || report.packageIdentity.manifestExpected;

// 2 · Registret mot schemat.
const reg = validateRegistry(CONTROLS);
report.registryValidation = reg;
if (!reg.ok) for (const p of reg.problems) console.error('✖ REGISTER  ' + p);

// 3 · CI-körbevis.
let ciEvidence = null;
if (existsSync('fas0/ci-evidence.json')) {
  try { ciEvidence = JSON.parse(readFileSync('fas0/ci-evidence.json', 'utf8')); }
  catch { console.error('✖ fas0/ci-evidence.json går inte att tolka'); }
}
report.ciEvidence = ciEvidence;

// 4 · Kravmatrisen — före reduceringen, så T-18:s diagnostik finns när
// kontrollen reduceras.
if (existsSync('evidensmatris.md')) {
  report.requirements = countRequirements(readFileSync('evidensmatris.md', 'utf8'));
  // Diagnostiken registreras EN gång. Fas 0.11: spec-lints T-18-rader räknades
  // redan i perControl, och den här raden ADDERADE dem igen — 32 problem blev 64,
  // och kontrollernas felsumma sköt över measures.specErrors.
  report.requirements.integrityProblems = report.requirements.integrityProblems || [];
  report.evidenceIntegrity = {
    problems: report.requirements.integrityProblems,
    countedBy: 'spec-lint (CHK-T-18) — räknas inte om här'
  };
}

// 4b · Namnrymderna måste vara disjunkta: CHK-* mot REQ-*.
{
  const rows = existsSync('evidensmatris.md') ? parseEvidence(readFileSync('evidensmatris.md', 'utf8')).rows : [];
  report.namespaces = checkNamespaces(CONTROLS, rows);
  if (!report.namespaces.ok) for (const p of report.namespaces.problems) console.error('✖ NAMNRYMD  ' + p);
}

// 4b2 · Schemaartefaktens utfall kommer från mätningen FÖRE generatorn.
report.schemaArtifact = deliveredSchema;

// 4c · Preliminär schemavalidering av rapportstommen, så CHK-SC-01 kan reduceras.
// Den slutliga valideringen körs efter totalerna och kan skärpa utfallet.
report.schema = 'butlery-verify-report/2';
report.runId = createHash('sha256').update(String(Date.now()) + ':' + (report.packageIdentity.manifestSha256 || '') + ':' + process.pid).digest('hex').slice(0, 16);
report.generatedAt = new Date().toISOString();

// 5 · Reducering.
report.controls = reduceControls(CONTROLS, {
  ciEvidence,
  packageIdentity: report.packageIdentity,
  chainExitCode: existsSync('fas0/verify-exit') ? Number(String(readFileSync('fas0/verify-exit', 'utf8')).trim()) : null,
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
  manifestMode: process.env.BUTLERY_MANIFEST_MODE || 'repo',
  generatedDrift: report.generatedDrift,
  schemaArtifact: report.schemaArtifact,
  schemaValidation: { ok: true, problems: [] }   // sätts om nedan efter slutvalideringen
});

// 6 · Tally med ALLA fem nycklar initierade — blocked och not applicable
// saknades när värdet var noll, trots kontraktet att alla fem ingår.
report.tally = { passed: 0, failed: 0, blocked: 0, 'not run': 0, 'not applicable': 0 };
for (const c of report.controls) report.tally[c.status] = (report.tally[c.status] || 0) + 1;

// 7 · Totaler.
const totals = computeTotals({
  steps: report.steps, controls: report.controls, manifest: report.manifest,
  generatedDrift: report.generatedDrift,
  manifestMode: process.env.BUTLERY_MANIFEST_MODE || 'repo',
  currentPhase: Number(process.env.BUTLERY_PHASE ?? 0)
});
Object.assign(report, totals);
report.canonicalCommand = 'bash fas0/run-verify.sh';
report.overallBlockers = totals.blockers;
report.firstFailingStep = failed;

// 8 · Validering — före skrivningen.
const rv = validateReport(report.controls, report.tally);
report.reportValidation = rv;
// Rapporten måste bära HELA registret, inte en delmängd.
const cov = validateRegistryCoverage(report.controls, CONTROLS);
report.registryCoverage = cov;
if (!cov.ok) for (const p of cov.problems) console.error('✖ TÄCKNING  ' + p);
if (!rv.ok) for (const p of rv.problems) console.error('✖ RAPPORT  ' + p);
if (!reg.ok) report.overallBlockers.push('kontrollregistret: ' + reg.problems.length + ' schemafel');
if (report.namespaces && !report.namespaces.ok) report.overallBlockers.push('namnrymder: ' + report.namespaces.problems.length + ' fel');
if (!rv.ok) report.overallBlockers.push('rapportvalidering: ' + rv.problems.join('; '));
if (!cov.ok) report.overallBlockers.push('registertäckning: ' + cov.problems.length + ' avvikelser');
if (!reg.ok || !rv.ok || !cov.ok || (report.namespaces && !report.namespaces.ok)) { report.overallResult = 'failed'; report.exitCode = 1; report.finalExitCode = 1; }
report.result = report.overallResult;

// 9 · TVÅ ATOMISKA FILBYTEN, bundna av samma runId. Varje fil skrivs till en
// temporärfil i samma katalog, JSON läses tillbaka och kontrolleras, och båda
// byts in med renameSync. Fas 0.13: paret är INTE transaktionellt atomiskt —
// processen kan dö mellan bytena. Det som garanteras är att ingen fil är
// halvskriven, och att filerna hör ihop om deras runId är samma.
const schemaProblems = validateReportSchema(report);
report.schemaValidation = { ok: schemaProblems.length === 0, problems: schemaProblems };
// CHK-SC-01 reduceras EN gång, ur alla tre villkoren (levererad artefakt,
// gen-schema-steget, slutrapportens schemavalidering). Fas 0.15: en separat
// slutöverskrivning satte status ur bara schemavalideringen och gjorde en stale
// levererad schemafil grön. Reduceringen körs om med det slutliga utfallet.
report.controls = reduceControls(CONTROLS, {
  ciEvidence,
  packageIdentity: report.packageIdentity,
  chainExitCode: existsSync('fas0/verify-exit') ? Number(String(readFileSync('fas0/verify-exit', 'utf8')).trim()) : null,
  ciEnv: { GITHUB_ACTIONS: process.env.GITHUB_ACTIONS, GITHUB_RUN_ID: process.env.GITHUB_RUN_ID,
    GITHUB_RUN_ATTEMPT: process.env.GITHUB_RUN_ATTEMPT, GITHUB_SHA: process.env.GITHUB_SHA,
    GITHUB_REPOSITORY: process.env.GITHUB_REPOSITORY, GITHUB_WORKFLOW: process.env.GITHUB_WORKFLOW },
  selftestSummary: report.selftestSummary, selftestCoverage: report.selftestCoverage,
  metatestSummary: report.metatestSummary, preflightSummary: report.preflightSummary,
  perControl: report.perControl, measures: report.measures, steps: report.steps,
  ranControls: report.ranControls || [], manifest: report.manifest,
  manifestMode: process.env.BUTLERY_MANIFEST_MODE || 'repo',
  generatedDrift: report.generatedDrift,
  schemaArtifact: report.schemaArtifact,
  schemaValidation: report.schemaValidation
});
report.tally = { passed: 0, failed: 0, blocked: 0, 'not run': 0, 'not applicable': 0 };
for (const c of report.controls) report.tally[c.status] = (report.tally[c.status] || 0) + 1;
{
  const totals2 = computeTotals({
    steps: report.steps, controls: report.controls, manifest: report.manifest,
    generatedDrift: report.generatedDrift,
    manifestMode: process.env.BUTLERY_MANIFEST_MODE || 'repo',
    currentPhase: Number(process.env.BUTLERY_PHASE ?? 0)
  });
  Object.assign(report, totals2);
  report.overallBlockers = totals2.blockers;
  report.result = report.overallResult;
}
if (schemaProblems.length) {
  for (const p of schemaProblems) console.error('✖ SCHEMA  ' + p);
  report.overallResult = 'failed'; report.result = 'failed';
  report.exitCode = 1; report.finalExitCode = 1;
  report.overallBlockers.push('rapportschema: ' + schemaProblems.length + ' fel');
}

mkdirSync(REPORT_DIR, { recursive: true });
{
  const jsonTmp = REPORT_DIR + '/.verify-report.json.' + report.runId + '.tmp';
  const mdTmp = REPORT_DIR + '/.kontrollstatus.md.' + report.runId + '.tmp';
  writeFileSync(jsonTmp, JSON.stringify(report, null, 2));
  writeFileSync(mdTmp, renderMarkdown(report));
  // Läs tillbaka och verifiera att JSON är komplett innan den byts in.
  const back = JSON.parse(readFileSync(jsonTmp, 'utf8'));
  if (back.runId !== report.runId || !Array.isArray(back.controls)) {
    console.error('✖ den temporära rapporten är inte komplett — byter inte in den');
    process.exit(3);
  }
  renameSync(jsonTmp, REPORT_DIR + '/verify-report.json');
  renameSync(mdTmp, REPORT_DIR + '/kontrollstatus.md');
}
console.log('\nRapport: ' + REPORT_DIR + '/verify-report.json · ' + REPORT_DIR + '/kontrollstatus.md · schema ' + report.schema + ' · runId ' + report.runId);

console.log('Kedjan: ' + report.pipelineResult + ' · kontrollerna: ' + report.controlsResult + ' · Fas ' + report.currentPhase + '-grinden: ' + report.phaseGateResult + ' · TOTALT: ' + report.overallResult);
console.log('Manifest: ' + report.manifest.status + ' · läge ' + report.manifestMode + ' · parsed ' + report.manifest.parsed + '/' + report.manifest.expected + ' · verified ' + report.manifest.verified);
console.log('Spec-fel: ' + report.measures.specErrors + ' · spec-varningar: ' + report.measures.specWarnings + ' · geometriavvikelser: ' + report.measures.geometryDeviations + '  (tre skilda mätklasser, summeras inte)');
if (report.metrics && report.metrics.controls) console.log('Räknade kontroller i ritningarna: ' + report.metrics.controls.value + ' (' + report.metrics.controls.source + ')');

if (failed) console.error('\n✖ Första fällande steg: ' + failed + ' — hela kedjan kördes ändå.');
if (report.overallResult === 'passed') console.log('\n✔ Kedjan, manifestet, grinden och samtliga kontroller är gröna.');
else console.error('\n✖ Totalt: failed — ' + report.overallBlockers.join(' · '));
process.exit(report.finalExitCode);
