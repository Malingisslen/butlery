#!/usr/bin/env node
// Butlery · FAS-GRINDENS exitkod. Kör: node tools/gate.mjs --phase=0
//
// FAIL-CLOSED. Fas 0.12: grinden gav exit 0 för en rapport med fel schema och
// controls: [], och '--phase=not-a-phase' blev "Fas NaN-grinden passerad".
// Nu valideras fasargumentet, rapportens schema, paketidentiteten och att
// grindmängden är exakt den som CONTROLS deklarerar.
//
// Kör INTE kedjan — läser bara rapporten.
import { readFileSync, existsSync, statSync } from 'node:fs';
import { isDeepStrictEqual } from 'node:util';
import { createHash } from 'node:crypto';
import { CONTROLS } from './controls.mjs';
import { validateReportSchema, validateReport, validateRegistryCoverage, artifactFingerprint, reduceControls } from './report-logic.mjs';

const arg = k => (process.argv.find(a => a.startsWith('--' + k + '=')) || '').split('=')[1];
const RP = arg('report') || 'fas0/verify-report.json';
const raw = arg('phase') ?? '0';

const fatal = [];
const fail = m => { console.error('✖ ' + m); fatal.push(m); };

// 1 · Fasargumentet.
if (!/^\d+$/.test(String(raw))) {
  console.error('✖ ogiltig fas "' + raw + '" — ange ett heltal, t.ex. --phase=0');
  process.exit(2);
}
const phase = Number(raw);
const KNOWN_PHASES = [...new Set(CONTROLS.flatMap(c => c.requiredForGate || []))].sort((a, b) => a - b);
if (!KNOWN_PHASES.includes(phase)) {
  console.error('✖ fas ' + phase + ' har inga grindkontroller i tools/controls.mjs (kända: ' + (KNOWN_PHASES.join(', ') || 'inga') + ')');
  process.exit(2);
}

// 2 · Rapporten.
if (!existsSync(RP)) { console.error('✖ ingen rapport på ' + RP + ' — kör bash fas0/run-verify.sh först'); process.exit(2); }
let r;
try { r = JSON.parse(readFileSync(RP, 'utf8')); }
catch (e) { console.error('✖ ' + RP + ' går inte att tolka: ' + e.message); process.exit(2); }

// 3 · Schema och rapportintegritet — samma validering som verify.mjs.
const sp = validateReportSchema(r);
for (const p of sp) fail('rapportschema: ' + p);
const rv = validateReport(r.controls || [], r.tally);
for (const p of rv.problems) fail('rapportintegritet: ' + p);
// Hela registret, inte bara grindens delmängd.
const cov = validateRegistryCoverage(r.controls || [], CONTROLS);
for (const p of cov.problems) fail('registertäckning: ' + p);
console.log('· registertäckning: ' + cov.reportCount + ' rapporterade av ' + cov.registryCount + ' i registret');

// 4 · Paketidentitet: rapporten måste gälla DETTA paket.
const mfPath = 'fas0/andrade-filer.md';
if (!existsSync(mfPath)) fail('manifestet saknas — paketidentiteten kan inte verifieras');
else {
  const now = createHash('sha256').update(readFileSync(mfPath)).digest('hex');
  const said = r.packageIdentity && r.packageIdentity.manifestSha256;
  if (!said) fail('rapporten saknar packageIdentity.manifestSha256');
  else if (said !== now) fail('rapporten gäller ett annat paket (manifest ' + String(said).slice(0, 12) + '… mot ' + now.slice(0, 12) + '…) — kör om kedjan');
}
if (!r.runId) fail('rapporten saknar runId');
// En ogiltig INGÅNGSRAPPORT är ett grindande integritetsfel — den kan inte
// finaliseras till giltighet. Fas 0.15.
if (r.inputSchemaValidation && r.inputSchemaValidation.ok !== true)
  fail('ingångsrapporten hade ' + (r.inputSchemaValidation.problems || []).length +
    ' schemafel: ' + (r.inputSchemaValidation.problems || []).slice(0, 3).join('; '));
if (r.finalizeAborted) fail('finaliseringen avbröts på ogiltigt underlag');
// FINALISERAD rapport krävs. Fas 0.16: en rapport utan finalized/finalizedAt/
// inputSchemaValidation gav exit 0.
if (r.finalized !== true) fail('rapporten är inte finaliserad (finalized !== true) — kör node tools/finalize.mjs');
if (!r.finalizedAt || !Date.parse(r.finalizedAt)) fail('rapporten saknar giltig finalizedAt');
if (!r.inputSchemaValidation) fail('rapporten saknar inputSchemaValidation — den kan inte bedömas som finaliserad');
// Ingen passed-kontroll får bära diagnostik.
for (const c of r.controls || []) {
  if (c.status !== 'passed') continue;
  const bits = [];
  if (c.errors) bits.push(c.errors + ' fel');
  if (c.deviations) bits.push(c.deviations + ' avvikelser');
  if (c.coverageErrors) bits.push(c.coverageErrors + ' täckningsfel');
  if (bits.length) fail(c.id + ' står passed med ' + bits.join(', '));
}
// Kontrollstatus får inte motsäga stegens maskinsummeringar.
{
  const mt = r.metatestSummary, st = r.selftestSummary;
  const mtRow = (r.controls || []).find(c => c.id === 'CHK-MT-01');
  const stRow = (r.controls || []).find(c => c.id === 'CHK-ST-01');
  if (mt && mtRow && mtRow.status === 'passed' && (mt.fail || 0) > 0)
    fail('CHK-MT-01 står passed men metatestSummary.fail = ' + mt.fail);
  if (st && stRow && stRow.status === 'passed' && ((st.fail || 0) > 0 || (st.skipped || 0) > 0))
    fail('CHK-ST-01 står passed men selftestSummary säger fail=' + st.fail + ' skipped=' + st.skipped);
}
if (Array.isArray(r.finalizeProblems) && r.finalizeProblems.length)
  fail('finaliseringen rapporterade ' + r.finalizeProblems.length + ' problem: ' + r.finalizeProblems.slice(0, 2).join('; '));

// STALE för samma paket: rapporten måste vara nyare än artefakterna den bedömer,
// och i CI måste den vara skriven i den LEVANDE körningen. Fas 0.13: en rapport
// från 2020 med rätt manifesthash gav exit 0.
{
  const t = Date.parse(r.finalizedAt || r.generatedAt || '');
  if (!t) fail('rapporten saknar giltig tidsstämpel (generatedAt/finalizedAt)');
  else {
    const ageH = (Date.now() - t) / 3600000;
    if (ageH > 24) fail('rapporten är ' + Math.round(ageH) + ' h gammal — kör om kedjan (grinden godtar inte en rapport äldre än 24 h)');
    if (t > Date.now() + 3600000) fail('rapportens tidsstämpel ligger i framtiden');
  }
  // HELA artefaktytan, inte tre filer. Rapporten bär ett fingeravtryck taget
  // efter kedjan; skiljer det sig har ytan ändrats efter rapportskrivningen.
  const fp = r.packageIdentity && r.packageIdentity.artifactFingerprint;
  if (!fp || !fp.sha256) fail('rapporten saknar packageIdentity.artifactFingerprint');
  else if (!existsSync(mfPath)) fail('manifestet saknas — fingeravtrycket kan inte räknas om');
  else {
    // SAMMA funktion, parser och sökvägsupplösning som verifieraren.
    const io = { exists: p => existsSync(p),
      sha256: p => createHash('sha256').update(readFileSync(p)).digest('hex'),
      hashString: s => createHash('sha256').update(s).digest('hex') };
    const mode = fp.mode || 'repo';
    const now = artifactFingerprint(readFileSync(mfPath, 'utf8'), mode, io);
    if (!['repo', 'delivery'].includes(mode)) fail('fingeravtryckets läge "' + mode + '" är okänt');
    if (now.declared !== fp.declared) fail('fingeravtrycket deklarerade ' + fp.declared + ' filer, manifestet ger nu ' + now.declared);
    if (now.hashed !== fp.hashed) fail('fingeravtrycket hashade ' + fp.hashed + ' filer, nu ' + now.hashed + ' — filer har tillkommit eller försvunnit');
    if (now.sha256 !== fp.sha256)
      fail('artefaktytan (' + mode + ') har ändrats efter att rapporten skrevs (' +
        String(fp.sha256).slice(0, 12) + '… mot ' + now.sha256.slice(0, 12) + '…, ' + now.hashed + ' filer) — kör om kedjan');
    else console.log('· artefaktfingeravtryck: ' + mode + ' · ' + now.hashed + '/' + now.declared + ' filer · oförändrat');
  }
  if (String(process.env.GITHUB_ACTIONS) === 'true') {
    const ev = r.ciEvidence;
    if (!ev) fail('CI-körning men rapporten bär inget ciEvidence');
    else {
      const pairs = [['runId', 'GITHUB_RUN_ID'], ['runAttempt', 'GITHUB_RUN_ATTEMPT'],
        ['commit', 'GITHUB_SHA'], ['repository', 'GITHUB_REPOSITORY'], ['workflow', 'GITHUB_WORKFLOW']];
      for (const p of pairs) {
        const want = process.env[p[1]];
        if (!want) { fail('den levande CI-miljön saknar ' + p[1]); continue; }
        if (String(ev[p[0]]) !== String(want))
          fail('rapportens ciEvidence.' + p[0] + ' "' + ev[p[0]] + '" ≠ den levande körningens ' + p[1] + ' "' + want + '"');
      }
    }
  }
}
if (r.currentPhase !== undefined && Number(r.currentPhase) !== phase)
  fail('rapporten beräknades för fas ' + r.currentPhase + ', grinden anropas för fas ' + phase);

// 4c · OMREDUCERING ur rapportens rådata: grinden litar inte på de lagrade
// statusraderna, den räknar om dem med samma funktion som verifieraren och
// jämför exakt. Fas 0.16: en handredigerad CHK-MT-01 = passed gav exit 0.
{
  try {
    const recomputed = reduceControls(CONTROLS, {
      ciEvidence: r.ciEvidence,
      packageIdentity: r.packageIdentity,
      chainExitCode: r.chainExitCode ?? null,
      ciEnv: { GITHUB_ACTIONS: process.env.GITHUB_ACTIONS, GITHUB_RUN_ID: process.env.GITHUB_RUN_ID,
        GITHUB_RUN_ATTEMPT: process.env.GITHUB_RUN_ATTEMPT, GITHUB_SHA: process.env.GITHUB_SHA,
        GITHUB_REPOSITORY: process.env.GITHUB_REPOSITORY, GITHUB_WORKFLOW: process.env.GITHUB_WORKFLOW },
      selftestSummary: r.selftestSummary, selftestCoverage: r.selftestCoverage,
      metatestSummary: r.metatestSummary, preflightSummary: r.preflightSummary,
      perControl: r.perControl || {}, measures: r.measures || {}, steps: r.steps || [],
      ranControls: r.ranControls || [], manifest: r.manifest || {},
      manifestMode: (r.packageIdentity?.artifactFingerprint?.mode) || r.manifestMode || 'repo',
      generatedDrift: r.generatedDrift || [],
      schemaArtifact: r.schemaArtifact, schemaValidation: r.schemaValidation
    });
    // DJUPJÄMFÖRELSE av hela den serialiserbara raden. Fas 0.18: en hårdkodad
    // fältlista missade legacyId, scope, passedTests, skipped, coverage,
    // integrity, parsed, verified, bad, missing, duplicates, unlisted,
    // outsideAbsent, expected och mode — sex av dem gick att handredigera utan
    // att grinden märkte det. Nu fäller varje extra, borttaget och ändrat fält.
    const rt = v => JSON.parse(JSON.stringify(v ?? null));   // bort med undefined
    const diffFields = (a, b, prefix = '') => {
      const out = [];
      const ka = a && typeof a === 'object' ? Object.keys(a) : [];
      const kb = b && typeof b === 'object' ? Object.keys(b) : [];
      for (const k of new Set([...ka, ...kb])) {
        const va = a ? a[k] : undefined, vb = b ? b[k] : undefined;
        if (isDeepStrictEqual(rt(va), rt(vb))) continue;
        if (va === undefined) { out.push(prefix + k + ': saknas i rapporten (omreducering ger ' + JSON.stringify(rt(vb)).slice(0, 40) + ')'); continue; }
        if (vb === undefined) { out.push(prefix + k + ': finns bara i rapporten (' + JSON.stringify(rt(va)).slice(0, 40) + ')'); continue; }
        if (va && vb && typeof va === 'object' && typeof vb === 'object' && !Array.isArray(va) && !Array.isArray(vb)) {
          out.push(...diffFields(va, vb, prefix + k + '.'));
          continue;
        }
        out.push(prefix + k + ': ' + JSON.stringify(rt(va)).slice(0, 50) + ' ≠ ' + JSON.stringify(rt(vb)).slice(0, 50));
      }
      return out;
    };
    const said = new Map((r.controls || []).map(c => [c.id, c]));
    let drift = 0;
    for (const rc of recomputed) {
      const s = said.get(rc.id);
      if (!s) continue;                                     // saknad rad fångas av täckningskontrollen
      if (isDeepStrictEqual(rt(s), rt(rc))) continue;
      const diffs = diffFields(s, rc);
      fail('kontrollraden ' + rc.id + ' skiljer sig från omreduceringen — ' +
        (diffs.length ? diffs.slice(0, 3).join(' · ') + (diffs.length > 3 ? ' (+' + (diffs.length - 3) + ' fler)' : '') : 'okänd skillnad'));
      drift++;
    }
    if (!drift) console.log('· omreducering: samtliga ' + recomputed.length + ' kontrollrader är djupidentiska med rapportens rådata');
  } catch (e) {
    fail('omreduceringen kunde inte köras: ' + e.message);
  }
}

// 5 · Grindmängden härleds ur CONTROLS och måste stämma EXAKT.
const expected = CONTROLS.filter(c => (c.requiredForGate || []).includes(phase)).map(c => c.id);
if (!expected.length) fail('inga grindkontroller deklarerade för fas ' + phase);
const rows = (r.controls || []).filter(c => Array.isArray(c.requiredForGate) && c.requiredForGate.includes(phase));
const seen = rows.map(c => c.id);
const dupes = seen.filter((x, i) => seen.indexOf(x) !== i);
for (const d of [...new Set(dupes)]) fail('grindkontrollen ' + d + ' förekommer flera gånger i rapporten');
for (const id of expected) if (!seen.includes(id)) fail('grindkontrollen ' + id + ' saknas i rapporten');
for (const id of seen) if (!expected.includes(id)) fail('rapporten har grindkontrollen ' + id + ' som inte är deklarerad i tools/controls.mjs');
if (!rows.length) fail('rapporten innehåller inga grindkontroller för fas ' + phase);

// 6 · Utfallet.
const OK = new Set(['passed', 'not applicable']);
const bad = rows.filter(c => !OK.has(c.status));
console.log('# Fas ' + phase + '-grinden · rapport runId ' + (r.runId || '?') + (r.finalized ? ' (finaliserad)' : ''));
for (const c of rows) console.log((OK.has(c.status) ? '✔ ' : '✖ ') + c.id + '  ' + c.status + '  ' + c.name + (c.why ? ' — ' + c.why : ''));

// 7 · Den lagrade grindstatusen får inte motsäga den omräknade.
const recomputed = bad.length ? 'failed' : 'passed';
if (r.phaseGateResult && r.phaseGateResult !== recomputed)
  fail('rapporten lagrar phaseGateResult=' + r.phaseGateResult + ' men grindmängden räknas om till ' + recomputed);

console.log('');
console.log('GATE-SUMMARY phase=' + phase + ' expected=' + expected.length + ' found=' + rows.length +
  ' passed=' + (rows.length - bad.length) + ' blocking=' + bad.length +
  ' integrity=' + (fatal.length ? 'failed' : 'ok') +
  ' gateResult=' + (fatal.length || bad.length ? 'failed' : 'passed') +
  ' overallResult=' + (r.overallResult || '?') +
  ' specErrors=' + (r.measures?.specErrors ?? '?') + ' geometry=' + (r.measures?.geometryDeviations ?? '?'));

if (fatal.length) { console.error('✖ Fas ' + phase + '-grinden kan inte bedömas: ' + fatal.length + ' integritetsfel i rapporten'); process.exit(1); }
if (bad.length) { console.error('✖ Fas ' + phase + '-grinden är INTE passerad: ' + bad.map(c => c.id).join(', ')); process.exit(1); }
console.log('✔ Fas ' + phase + '-grinden är passerad. Innehållsbaslinjen är ' + r.overallResult + ' och får vara röd.');
process.exit(0);
