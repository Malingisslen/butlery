// Butlery · REN rapportlogik. Ingen filsystem-, process- eller tidsberoende.
// Bruten ut ur verify.mjs i Fas 0.8 så att metatesterna kan mata in konstruerade
// rapporter och pröva slutsatsen — tidigare var MT-01 källtextssökningar, vilket
// inte upptäckte att en manifestkrasch av fel orsak ändå passerade.

// Beroenden per KONSUMENT. En kontroll vars producent fallit blir 'blocked'
// oavsett om den råkar passera mot en kvarliggande artefakt.
export const DEPENDS_ON = {
  'CHK-T-06a': ['gen-icons'],
  'CHK-TG-01': ['gen-css', 'gen-flutter'],
  // Fas 0.13: CHK-SC-01 stod passed medan gen-schema.mjs hade kraschat.
  'CHK-SC-01': ['gen-schema']
};

// Ett steg fälls av exitkod ELLER av fällande diagnostik i utdata. Ett verktyg
// som skriver ✖ till stderr och returnerar 0 får aldrig passera.
export function classifyStep(out, exitCode) {
  const fatalLines = String(out || '').split('\n').filter(l => /^\s*✖/u.test(l));
  const machineFail = /SELFTEST-SUMMARY[^\n]*fail=[1-9]/.test(out) ||
    /METATEST-SUMMARY[^\n]*fail=[1-9]/.test(out) ||
    /LC-SUMMARY[^\n]*deviations=[1-9]/.test(out) ||
    /MANIFEST-SUMMARY[^\n]*(bad|missing|duplicates|unlisted)=[1-9]/.test(out);
  if (exitCode !== 0) return { status: 'failed', reason: 'exitkod ' + exitCode };
  if (fatalLines.length) return { status: 'failed', reason: fatalLines.length + ' fällande rader trots exit 0', integrity: true };
  if (machineFail) return { status: 'failed', reason: 'fällande maskinsummering trots exit 0', integrity: true };
  return { status: 'passed', reason: null };
}

// Reducerar EN kontroll. ctx = { perControl, measures, steps, ranControls,
// manifest, generatedDrift }.
export function reduceControl(c, ctx) {
  const stepOf = key => (ctx.steps || []).find(s => s.script && s.script.includes(key + '.mjs'));
  const hit = (ctx.perControl || {})[c.legacyId || c.id] || (ctx.perControl || {})[c.id] || { errors: 0, warnings: 0 };
  const out = { errors: hit.errors || 0, warnings: hit.warnings || 0, deviations: hit.deviations || undefined, why: c.why || null, blockedBy: null };
  const measures = ctx.measures || {};

  if (c.legacyId === 'GEN-01') {
    const drift = ctx.generatedDrift || [];
    return { ...out, status: drift.length ? 'failed' : 'passed', errors: drift.length,
      why: drift.length ? 'drift i: ' + drift.join(', ') : null };
  }
  if (c.source === 'ci-evidence') {
    // CHK-CI-01 = "kedjan HAR körts i CI mot detta paket, i den här körningen".
    // Fas 0.12: formvalidering räckte — ett bevis med annan giltig commit, annat
    // repository och completedAt före startedAt passerade. Nu jämförs beviset mot
    // packageIdentity OCH mot den levande CI-miljön.
    const ev = ctx.ciEvidence;
    if (!ev) return { ...out, status: 'not run', why: 'inget körbevis i fas0/ci-evidence.json — kedjan har inte körts i CI' };
    const bad = [];
    if (ev.schema !== 'butlery-ci-evidence/2') bad.push('okänt bevisschema "' + ev.schema + '"');
    if (String(ev.githubActions) !== 'true') bad.push('GITHUB_ACTIONS är inte "true" — beviset kommer inte från en CI-körning');
    if (ev.ciProvider !== 'github-actions') bad.push('okänd ciProvider "' + ev.ciProvider + '"');
    if (!/^\d{4,}$/.test(String(ev.runId || ''))) bad.push('runId "' + ev.runId + '" är inget GitHub-run-id');
    if (!/^[0-9a-f]{40}$/.test(String(ev.commit || ''))) bad.push('commit "' + String(ev.commit).slice(0, 12) + '" är ingen full git-sha');
    if (!/^[\w.-]+\/[\w.-]+$/.test(String(ev.repository || ''))) bad.push('repository "' + ev.repository + '" saknar owner/name-form');
    const t0 = Date.parse(ev.startedAt), t1 = Date.parse(ev.completedAt);
    for (const pair of [['startedAt', t0], ['completedAt', t1]]) {
      if (!pair[1]) bad.push(pair[0] + ' "' + ev[pair[0]] + '" är inget giltigt ISO-datum');
      else if (pair[1] > Date.now() + 86400000) bad.push(pair[0] + ' ligger i framtiden');
    }
    if (t0 && t1 && t1 < t0) bad.push('completedAt ligger före startedAt');
    if (!Number.isInteger(ev.verifyExitCode) || ev.verifyExitCode < 0 || ev.verifyExitCode > 255)
      bad.push('verifyExitCode "' + ev.verifyExitCode + '" är ingen processexitkod');

    const want = ctx.packageIdentity && ctx.packageIdentity.manifestSha256;
    if (want && ev.manifestSha256 !== want)
      bad.push('beviset gäller ett annat paket (manifesthash ' + String(ev.manifestSha256).slice(0, 12) + '… mot ' + String(want).slice(0, 12) + '…)');
    const pkgCommit = ctx.packageIdentity && ctx.packageIdentity.commit;
    if (pkgCommit && ev.commit !== pkgCommit)
      bad.push('beviset avser commit ' + String(ev.commit).slice(0, 8) + ' men paketet kördes på ' + String(pkgCommit).slice(0, 8));

    // Exitkoden i beviset måste vara körningens FAKTISKA slutkod. Fas 0.13: ett
    // bevis med verifyExitCode 0 mot en rapport med finalExitCode 1 passerade.
    if (ctx.chainExitCode !== undefined && ctx.chainExitCode !== null &&
        Number(ev.verifyExitCode) !== Number(ctx.chainExitCode))
      bad.push('verifyExitCode ' + ev.verifyExitCode + ' ≠ körningens faktiska slutkod ' + ctx.chainExitCode);

    // Bindning till den LEVANDE CI-körningen. ALLA obligatoriska fält krävs —
    // tidigare jämfördes bara de miljöfält som råkade finnas, så ett ciEnv med
    // enbart GITHUB_ACTIONS godkände vilket bevis som helst.
    const envCi = ctx.ciEnv || {};
    if (String(envCi.GITHUB_ACTIONS) === 'true') {
      const pairs = [['runId', 'GITHUB_RUN_ID'], ['runAttempt', 'GITHUB_RUN_ATTEMPT'],
        ['commit', 'GITHUB_SHA'], ['repository', 'GITHUB_REPOSITORY'], ['workflow', 'GITHUB_WORKFLOW']];
      for (const p of pairs) {
        const got = envCi[p[1]];
        if (got === undefined || got === null || got === '') { bad.push('den levande CI-miljön saknar ' + p[1] + ' — bindningen kan inte göras'); continue; }
        if (String(ev[p[0]]) !== String(got))
          bad.push(p[0] + ' "' + ev[p[0]] + '" ≠ den levande körningens ' + p[1] + ' "' + got + '"');
      }
    } else {
      bad.push('kontrollen körs utanför CI (GITHUB_ACTIONS saknas) — ett incheckat bevis kan inte verifieras mot en levande körning');
    }
    if (bad.length) return { ...out, status: 'failed', errors: bad.length, why: bad.join(' · ') };
    return { ...out, status: 'passed', errors: 0,
      why: 'CI-körning ' + ev.runId + '.' + (ev.runAttempt ?? '?') + ' i ' + ev.repository + ' på ' + String(ev.commit).slice(0, 8) +
        ' avslutades med exit ' + ev.verifyExitCode + ' (' + ev.completedAt +
        ') · bunden till paketets manifesthash och den levande CI-miljön · bevisar att kedjan kördes i CI, inte att den blev grön' };
  }
  if (c.source === 'schema') {
    const sv = ctx.schemaValidation;
    const probs = [];
    // Producenten måste ha lyckats — annars är schemafilen inte den som
    // REPORT_SCHEMA beskriver. Kaskaden i DEPENDS_ON gör resten.
    const gen = (ctx.steps || []).find(s => String(s.script).includes('gen-schema'));
    if (!gen) probs.push('gen-schema-steget ingick inte i kedjan');
    else if (gen.status !== 'passed') probs.push('gen-schema.mjs föll (exit ' + gen.exitCode + ') — schemafilen kan inte antas motsvara REPORT_SCHEMA');
    // Artefaktdrift: filen på disk måste vara exakt REPORT_SCHEMA.
    if (ctx.schemaArtifact && ctx.schemaArtifact.drift) probs.push('fas0/verify-report.schema.json avviker från REPORT_SCHEMA — kör node tools/gen-schema.mjs');
    if (ctx.schemaArtifact && ctx.schemaArtifact.missing) probs.push('fas0/verify-report.schema.json saknas');
    if (!sv) probs.push('schemavalideringen har inte körts');
    else if (!sv.ok) probs.push(...sv.problems);
    if (!probs.length) return { ...out, status: 'passed', errors: 0 };
    return { ...out, status: 'failed', errors: probs.length,
      why: probs.slice(0, 4).join('; ') + (probs.length > 4 ? ' (+' + (probs.length - 4) + ' fler)' : '') };
  }
  if (c.legacyId === 'MF-01') {
    const m = ctx.manifest || { status: 'not run' };
    // SAMMA integritetsprövning som totalen använder — MF-01 kunde tidigare stå
    // passed medan totalen underkände manifestet för saknat expected. Fas 0.10.
    const mi = manifestIntegrity(m, ctx.manifestMode || 'repo');
    const st = m.status === 'not run' ? 'not run' : (m.status === 'passed' && mi.ok ? 'passed' : 'failed');
    return { ...out,
      status: st,
      integrity: mi,
      errors: st === 'failed' ? Math.max(1, mi.problems.length) : 0,
      why: st === 'failed' && mi.problems.length ? mi.problems.join('; ') : (m.why ?? out.why),
      parsed: m.parsed ?? null, verified: m.verified ?? null, bad: m.bad ?? null,
      missing: m.missing ?? null, duplicates: m.duplicates ?? null,
      unlisted: m.unlisted ?? null, outsideAbsent: m.outsideAbsent ?? null,
      expected: m.expected ?? null, mode: ctx.manifestMode || 'repo' };
  }
  if (c.status) return { ...out, status: c.status };

  if (c.legacyId === 'LC-01') {
    const s = stepOf('lint-controls');
    out.deviations = measures.geometryDeviations || 0;
    out.coverageErrors = measures.coverageErrors || 0;
    out.status = !s ? 'not run' : (s.status === 'failed' || out.deviations || out.coverageErrors) ? 'failed' : 'passed';
    if (out.coverageErrors) out.why = out.coverageErrors + ' täckningsfel — en regel som körts på noll komponenter får inte bli grön';
    return out;
  }
  if (c.legacyId === 'TG-01') { const s = stepOf('test-generated'); return { ...out, status: !s ? 'not run' : s.status }; }
  if (c.legacyId === 'MT-01') {
    const s = stepOf('metatest');
    const sum = ctx.metatestSummary || null;
    if (sum) { out.errors = sum.fail || 0; out.passedTests = sum.pass || 0; if (out.errors) out.why = sum.fail + ' av ' + sum.total + ' metatester föll'; }
    if (!s) return { ...out, status: 'not run', why: 'metatesterna ingick inte i körningen' };
    const st = (s.status === 'failed' || out.errors) ? 'failed' : 'passed';
    if (st === 'failed' && !out.errors && !out.why) out.why = 'steget föll med exit ' + s.exitCode + ' men skrev ingen METATEST-SUMMARY';
    return { ...out, status: st };
  }
  if (c.legacyId === 'GEN-02') {
    const s = stepOf('preflight');
    if (!s) return { ...out, status: 'not run', why: 'preflight ingick inte i körningen' };
    if (s.status === 'failed') {
      const stale = /stale=(\d+)/.exec(ctx.preflightSummary || '');
      out.errors = stale ? Number(stale[1]) : (out.errors || 1);
      out.why = out.why || (stale ? stale[1] + ' incheckad(e) genererad(e) fil(er) är stale mot tokens.json' : 'preflight föll med exit ' + s.exitCode);
    }
    return { ...out, status: s.status };
  }
  if (c.legacyId === 'ST-01') {
    const s = stepOf('selftest');
    // Summeringen läses ur den STRUKTURERADE rapporten, inte ur de sista tolv
    // rader — där stod den inte, och ST-01 blev failed med errors: 0 och tom
    // motivering. Fas 0.10: en failed kontroll MÅSTE ha diagnostik eller orsak.
    const sum = ctx.selftestSummary || null;
    if (sum) {
      out.errors = (sum.fail || 0) + (sum.skipped || 0);
      out.passedTests = sum.pass || 0;
      out.skipped = sum.skipped || 0;
      out.coverage = ctx.selftestCoverage || null;
      if (out.errors) out.why = sum.fail + ' fällda prov · ' + (sum.skipped || 0) + ' hoppade' +
        (ctx.selftestCoverage && ctx.selftestCoverage.uncovered ? ' · ' + ctx.selftestCoverage.uncovered + ' kontroller utan negativt prov' : '');
    }
    if (!s) return { ...out, status: 'not run', why: 'självtestet ingick inte i körningen' };
    const st = (s.status === 'failed' || out.errors) ? 'failed' : 'passed';
    if (st === 'failed' && !out.errors && !out.why) out.why = 'steget föll med exit ' + s.exitCode + ' men skrev ingen SELFTEST-SUMMARY — utfallet är okänt';
    return { ...out, status: st };
  }

  if (c.source === 'spec-lint') {
    if (!(ctx.ranControls || []).includes(c.legacyId || c.id)) {
      const s = stepOf('spec-lint');
      const crashed = s && s.status === 'failed' && !s.specErrors;
      return { ...out, status: crashed ? 'failed' : 'not run',
        why: crashed
          ? 'spec-lint kraschade utan parsad diagnostik — utfallet är okänt och räknas som fel'
          : 'kontrollen registrerade inget körbevis i lint-core' };
    }
    return { ...out, status: out.errors ? 'failed' : 'passed' };
  }

  return { ...out, status: 'not run', why: out.why || 'kontrollen ingår inte i kedjan' };
}

// Reducerar HELA registret: kaskad och sanity ingår.
export function reduceControls(controls, ctx) {
  ctx = { manifestMode: 'repo', ...ctx };
  const failedSteps = new Set((ctx.steps || []).filter(s => s.status === 'failed')
    .map(s => String(s.script).replace(/^tools\//, '').replace(/\.mjs$/, '')));
  const rows = [];
  for (const c of controls) {
    const r = reduceControl(c, ctx);
    const blocker = (DEPENDS_ON[c.id] || []).find(d => failedSteps.has(d));
    if (blocker) {
      r.blockedBy = blocker;
      r.status = 'blocked';
      r.why = 'producenten ' + blocker + ' föll — kontrollen kördes mot en kvarliggande artefakt och utfallet (' +
        (r.errors ? r.errors + ' fel' : 'inga fel') + ') är inte självständigt';
    }
    // En FAILED kontroll måste bära diagnostik eller en uttrycklig orsak.
    if (r.status === 'failed' && !(r.errors || 0) && !(r.deviations || 0) && !(r.coverageErrors || 0) && !r.why)
      r.why = 'kontrollen fälldes utan parsad diagnostik — orsaken går inte att härleda ur utdata, vilket i sig är ett fel i rapporteringen';
    // Diagnostik kan ALDRIG ge passed.
    if (r.status === 'passed' && ((r.errors || 0) > 0 || (r.deviations || 0) > 0 || (r.coverageErrors || 0) > 0)) {
      r.status = 'failed';
      r.why = (r.why ? r.why + ' · ' : '') + 'statusreducering: diagnostik kan aldrig ge passed';
    }
    rows.push({ id: c.id, legacyId: c.legacyId ?? null, name: c.name, owner: c.owner, source: c.source,
      resolutionPhase: c.resolutionPhase ?? null,
      requiredForGate: c.requiredForGate ?? [],
      scope: c.scope || null, ...r });
  }
  return rows;
}

// Manifestets integritet prövas av rapporten SJÄLV — ett syntetiskt manifest med
// status passed, exit 0 och parsed 0 godkändes tidigare rakt igenom. Fas 0.9.
export function manifestIntegrity(m = {}, mode = 'repo') {
  const problems = [];
  const num = v => (typeof v === 'number' ? v : null);
  if (m.status === 'not run') return { ok: false, problems: ['manifestet kördes inte'] };
  const expected = num(m.expected), parsed = num(m.parsed), verified = num(m.verified);
  if (!expected || expected <= 0) problems.push('expected saknas eller är 0 — manifestet deklarerar inget antal');
  if (parsed === null) problems.push('parsed saknas');
  else if (expected && parsed !== expected) problems.push('parsed ' + parsed + ' ≠ expected ' + expected);
  const outsideAbsent = num(m.outsideAbsent) || 0;
  if (verified !== null && parsed !== null && verified + outsideAbsent !== parsed)
    problems.push('verified ' + verified + ' + outsideAbsent ' + outsideAbsent + ' ≠ parsed ' + parsed);
  for (const k of ['bad', 'missing', 'duplicates', 'unlisted']) if (num(m[k])) problems.push(k + '=' + m[k]);
  if (mode === 'delivery' && outsideAbsent) problems.push('delivery-läge: ' + outsideAbsent + ' leveransfil(er) saknas — varje zip:/-post är obligatorisk');
  if ((m.exitCode ?? 0) !== 0) problems.push('exitkod ' + m.exitCode);
  return { ok: problems.length === 0, problems };
}

// Tre resultatnivåer plus totalen. 'not run' och 'blocked' godkänner aldrig.
//
// FASMODELL (Fas 0.9). Tre skilda begrepp, aldrig ett implicit tal:
//   resolutionPhase  — när fyndet ska vara LÖST (ett baslinjefynd kan höra till
//                      Fas 3 utan att blockera Fas 0)
//   requiredForGate  — vilka grindar kontrollen BLOCKERAR (0 = Fas 0-grinden)
//   currentPhase     — vilken grind rapporten just nu beräknar
// Implicit fas 0 är borta: en kontroll utan requiredForGate blockerar ingen grind.
export function computeTotals({ steps = [], controls = [], manifest = { status: 'not run' }, generatedDrift = [], manifestMode = 'repo', currentPhase = 0 }) {
  const failedStep = steps.find(s => s.status === 'failed');
  // Endast passed och motiverat not applicable uppfyller ett kriterium.
  // Fas 0.16: 'not run' räknades inte som fel, så en kontroll utanför grinden
  // kunde stå not run i ett grönt totalresultat.
  const OK_STATUS = new Set(['passed', 'not applicable']);
  const bad = controls.filter(c => !OK_STATUS.has(c.status));
  // Grindscope = kontroller som uttryckligen blockerar den aktuella grinden.
  const gate = controls.filter(c => Array.isArray(c.requiredForGate) && c.requiredForGate.includes(currentPhase));
  const mi = manifestIntegrity(manifest, manifestMode);
  const manifestOk = manifest.status === 'passed' && mi.ok;
  const pipelineResult = failedStep ? 'failed' : 'passed';
  const controlsResult = bad.length ? 'failed' : 'passed';
  const gateBad = gate.filter(c => c.status !== 'passed' && c.status !== 'not applicable');
  const phaseGateResult = gateBad.length ? 'failed' : 'passed';
  // INVARIANT: overallResult är passed endast om varje uttryckligen nödvändigt
  // delresultat är godkänt. phaseGateResult räknades tidigare ut men ingick inte
  // i totalen — en trasig grind kunde ge exit 0 med tom blockerarlista.
  const required = {
    pipelineResult: pipelineResult === 'passed',
    controlsResult: controlsResult === 'passed',
    phaseGateResult: phaseGateResult === 'passed',
    manifest: manifestOk,
    generatedDrift: generatedDrift.length === 0
  };
  const overallResult = Object.values(required).every(Boolean) ? 'passed' : 'failed';
  return {
    pipelineResult, stepsResult: pipelineResult, controlsResult, phaseGateResult, overallResult,
    controlsSummary: {
      failed: bad.filter(c => c.status === 'failed').map(c => c.id),
      blocked: bad.filter(c => c.status === 'blocked').map(c => c.id),
      notRun: bad.filter(c => c.status === 'not run').map(c => c.id)
    },
    required, currentPhase, manifestMode,
    manifestIntegrity: mi,
    gateBlockers: gateBad.map(c => c.id + '(' + c.status + ')'),
    exitCode: overallResult === 'passed' ? 0 : 1,
    finalExitCode: overallResult === 'passed' ? 0 : 1,
    blockers: [
      ...steps.filter(s => s.status === 'failed').map(s => 'steg: ' + s.step),
      ...(manifestOk ? [] : ['manifest: ' + manifest.status + (mi.problems.length ? ' — ' + mi.problems.join('; ') : '')]),
      ...(gateBad.length ? ['Fas ' + currentPhase + '-grinden: ' + gateBad.map(c => c.id + '(' + c.status + ')').join(', ')] : []),
      ...(generatedDrift.length ? ['GEN-01: ' + generatedDrift.length + ' genererade filer drev'] : []),
      ...(bad.length ? ['kontroller: ' + bad.map(c => c.id + '(' + c.status + ')').join(', ')] : [])
    ]
  };
}

// Kravstatus ur evidensmatrisens rader. Ren funktion — texten skickas in.
// Räknar ur den GEMENSAMMA parsern och redovisar dess integritetsproblem.
export function countRequirements(text) {
  const { rows, problems } = parseEvidence(text);
  const byStatus = {};
  for (const r of rows) byStatus[r.status || 'okänd'] = (byStatus[r.status || 'okänd'] || 0) + 1;
  return { total: rows.length, byStatus, integrityProblems: problems };
}

// Schemavalidering av kontrollregistret. En okänd status i en senare fas kunde
// tidigare ge grönt resultat. Fas 0.9.
export const STATUSES = ['passed', 'failed', 'blocked', 'not run', 'not applicable'];
export function validateRegistry(controls) {
  const problems = [];
  const seen = new Set();
  for (const c of controls) {
    if (!c.id) { problems.push('kontroll utan id'); continue; }
    if (seen.has(c.id)) problems.push(c.id + ': dubblerat id i registret');
    seen.add(c.id);
    if (!c.name) problems.push(c.id + ': saknar namn');
    if (!c.owner) problems.push(c.id + ': saknar ägare');
    if (!c.source) problems.push(c.id + ': saknar källa');
    if (c.status && !STATUSES.includes(c.status)) problems.push(c.id + ': okänt statusvärde "' + c.status + '"');
    if (c.status === 'not applicable' && !c.why) problems.push(c.id + ': not applicable utan motivering');
    if (c.resolutionPhase === undefined || c.resolutionPhase === null) problems.push(c.id + ': saknar resolutionPhase');
    if (!Array.isArray(c.requiredForGate)) problems.push(c.id + ': requiredForGate måste vara en lista (tom = blockerar ingen grind)');
  }
  return { ok: problems.length === 0, problems };
}

// Validerar en FÄRDIGREDUCERAD rapport: bara tillåtna statusvärden, och tallyn
// måste summera till registrets storlek.
// Rapportens kontrollmängd måste vara EXAKT registret — inte bara grindens
// delmängd. Fas 0.13: en rapport beskuren till de åtta grindkontrollerna gav
// exit 0, och M-23:s gröna fixtur institutionaliserade luckan.
export function validateRegistryCoverage(reportControls, registry) {
  const problems = [];
  const inReport = new Map((reportControls || []).map(c => [c.id, c]));
  const inRegistry = new Map((registry || []).map(c => [c.id, c]));
  for (const id of inRegistry.keys()) if (!inReport.has(id)) problems.push('rapporten saknar kontrollen ' + id);
  for (const id of inReport.keys()) if (!inRegistry.has(id)) problems.push('rapporten har kontrollen ' + id + ', som inte finns i tools/controls.mjs');
  // Stabil metadata måste stämma — en rapport får inte omdefiniera en kontroll.
  for (const [id, reg] of inRegistry) {
    const rep = inReport.get(id);
    if (!rep) continue;
    if (rep.source !== reg.source) problems.push(id + ': source "' + rep.source + '" ≠ registrets "' + reg.source + '"');
    if (Number(rep.resolutionPhase) !== Number(reg.resolutionPhase))
      problems.push(id + ': resolutionPhase ' + rep.resolutionPhase + ' ≠ registrets ' + reg.resolutionPhase);
    const a = JSON.stringify(rep.requiredForGate ?? []), b = JSON.stringify(reg.requiredForGate ?? []);
    if (a !== b) problems.push(id + ': requiredForGate ' + a + ' ≠ registrets ' + b);
    if (rep.owner !== reg.owner) problems.push(id + ': owner "' + rep.owner + '" ≠ registrets "' + reg.owner + '"');
  }
  return { ok: problems.length === 0, problems, reportCount: inReport.size, registryCount: inRegistry.size };
}

export function validateReport(controls, tally) {
  const problems = [];
  for (const c of controls) if (!STATUSES.includes(c.status)) problems.push(c.id + ': okänt statusvärde "' + c.status + '" i rapporten');
  if (tally) {
    for (const k of Object.keys(tally)) if (!STATUSES.includes(k)) problems.push('okänt statusvärde i tallyn: ' + k);
    // FÖRDELNINGEN, inte bara summan. Fas 0.14: en tally med rätt totalsumma men
    // fel fördelning mellan passed och not applicable gav ok = true.
    const actual = {};
    for (const s of STATUSES) actual[s] = 0;
    for (const c of controls) if (STATUSES.includes(c.status)) actual[c.status]++;
    for (const s of STATUSES) {
      const said = tally[s];
      if (said === undefined) { problems.push('tallyn saknar "' + s + '"'); continue; }
      if (!Number.isInteger(said) || said < 0) { problems.push('tally.' + s + ' = ' + said + ' är inget icke-negativt heltal'); continue; }
      if (said !== actual[s]) problems.push('tally.' + s + ' säger ' + said + ' men ' + actual[s] + ' kontroller har den statusen');
    }
    const sum = Object.values(tally).reduce((a, b) => a + (Number.isInteger(b) ? b : 0), 0);
    if (sum !== controls.length) problems.push('tallyn summerar till ' + sum + ', registret har ' + controls.length);
  }
  return { ok: problems.length === 0, problems };
}

// ── Gemensam evidensmatrisparser ─────────────────────────────────────────────
// EN parser för både T-14 och countRequirements. Tidigare hade de skilda regler,
// vilket lät tre mutationer passera: <!--hist--> på aktiv rad, statusstavfel och
// dubblerat krav-id. Bär rubrikkontext och radnummer. Fas 0.9.
export const REQ_STATUSES = ['verifierad', 'implementerad', 'beslutad', 'ersatt', 'öppen'];
// Strukturella problem hindrar krav från att ens räknas — de hör till grinden.
// Innehållsproblem (fel status, dubblett-id) är baslinjefynd.
export const STRUCTURAL_EVIDENCE = /utan tabellhuvud|kolumner, tabellhuvudet|hittades inte|utanför historikavsnitt/;
export function splitEvidenceProblems(problems = []) {
  return {
    structural: problems.filter(p => STRUCTURAL_EVIDENCE.test(p)),
    content: problems.filter(p => !STRUCTURAL_EVIDENCE.test(p))
  };
}

export function parseEvidence(text, { historySections = /historik|changelog|ändringslogg|tidigare|arkiv|superseded/i } = {}) {
  const rows = [];
  const problems = [];
  const seen = new Map();
  const lines = String(text || '').split('\n');
  let heading = '', inHistory = false;
  let fence = false;
  // TABELLGRÄNSER, inte rubrikord. Fas 0.9 krävde ord som källan inte använder
  // och låste flaggan permanent — 282 normala kravrader flaggades "utanför
  // kravsektion". Nu identifieras varje tabell av sitt HUVUD: en rad med minst
  // fem celler där första cellen heter Id/Krav-id, följd av en skiljelinje.
  // Kolumnantalet låses av huvudet och gäller till tabellens slut.
  let table = null;   // { cols, headerLine, idCol, statusCol }
  const cellsOf = l => l.split('|').slice(1, -1).map(s => s.trim());

  for (let k = 0; k < lines.length; k++) {
    const line = lines[k];
    const lineNo = k + 1;
    if (/^\s*```/.test(line)) { fence = !fence; continue; }
    if (fence) continue;
    if (/^#{2,}\s/.test(line)) {
      heading = line.replace(/^#+\s*/, '').trim();
      inHistory = historySections.test(heading);
      table = null;
      continue;
    }
    if (!line.startsWith('|')) { table = null; continue; }
    const cells = cellsOf(line);
    // skiljelinje
    if (cells.every(c => /^:?-{2,}:?$/.test(c))) {
      if (table && table.pending) { table.pending = false; table.cols = cells.length; }
      continue;
    }
    // tabellhuvud?
    if (!table && /^(id|krav[- ]?id|krav|nr)$/i.test(cells[0] || '')) {
      table = { pending: true, cols: cells.length, headerLine: lineNo, heading, inHistory,
        statusCol: cells.findIndex(c => /^status$/i.test(c)),
        evidenceCol: cells.findIndex(c => /skärmbevis|bevis/i.test(c)) };
      continue;
    }
    const id = cells[0] || '';
    if (!/^[A-ZÅÄÖ]{1,3}-\d+[a-z]?$/.test(id)) continue;
    if (!table) { problems.push('rad ' + lineNo + ' (' + id + '): kravrad utan tabellhuvud — tabellen saknar en Id-rubrikrad'); continue; }

    const hist = line.includes('<!--hist-->');
    if (hist && !(inHistory || table.inHistory)) {
      problems.push('rad ' + lineNo + ' (' + id + '): <!--hist--> utanför historikavsnitt — markören får inte dölja en aktiv kravrad (rubrik: "' + heading + '")');
    }
    if (hist && (inHistory || table.inHistory)) continue;
    if (inHistory || table.inHistory) continue;

    // EXAKT kolumnantal mot huvudet.
    if (cells.length !== table.cols)
      problems.push('rad ' + lineNo + ' (' + id + '): ' + cells.length + ' kolumner, tabellhuvudet på rad ' + table.headerLine + ' har ' + table.cols);

    // Status läses ur STATUSKOLUMNEN och måste matcha EXAKT — 'implementeradx'
    // och 'ej verifierad' godkändes tidigare av en lös delstämningsmatchning.
    const rawStatus = (table.statusCol >= 0 ? cells[table.statusCol] : cells[cells.length - 1] || '');
    const cleaned = String(rawStatus).replace(/\*\*/g, '').replace(/[✅✔◐✖⛔]/gu, '').trim().toLowerCase();
    const bare = cleaned.split(/[—–·(]/)[0].trim();
    let status = REQ_STATUSES.includes(bare) ? bare : null;
    if (!status) {
      const neg = /\b(ej|inte|icke)\s+(verifierad|implementerad|beslutad)\b/.exec(cleaned);
      if (neg) problems.push('rad ' + lineNo + ' (' + id + '): "' + neg[0] + '" är ingen giltig status — använd beslutad eller öppen');
      else problems.push('rad ' + lineNo + ' (' + id + '): okänd eller saknad status "' + String(rawStatus).slice(0, 40) + '" — tillåtna: ' + REQ_STATUSES.join(', '));
    }
    if (seen.has(id)) problems.push('rad ' + lineNo + ': krav-id ' + id + ' är dubblerat (först på rad ' + seen.get(id) + ')');
    else seen.set(id, lineNo);

    rows.push({ id, machineId: 'REQ-' + id, lineNo, heading, status,
      evidence: (table.evidenceCol >= 0 ? cells[table.evidenceCol] : cells[3]) || '',
      cells, table: { headerLine: table.headerLine, cols: table.cols } });
  }
  return { rows, problems };
}


// Bevisar att kontroll- och kravmängderna är DISJUNKTA. Fas 0.11: CHK-* fanns i
// rapporten men REQ-* bara i prosa, och parsern returnerade fortfarande råa id.
export function checkNamespaces(controls, requirementRows) {
  const chk = new Set(controls.map(c => c.id));
  const req = new Set(requirementRows.map(r => r.machineId));
  const problems = [];
  for (const id of chk) if (!/^CHK-/.test(id)) problems.push('kontroll-id "' + id + '" saknar CHK-prefix');
  for (const id of req) if (!/^REQ-/.test(id)) problems.push('krav-id "' + id + '" saknar REQ-prefix');
  const overlap = [...chk].filter(id => req.has(id));
  if (overlap.length) problems.push('överlapp mellan namnrymderna: ' + overlap.join(', '));
  return { ok: problems.length === 0, problems, controls: chk.size, requirements: req.size };
}

// ── RAPPORTSCHEMA butlery-verify-report/2 ────────────────────────────────────
// Versionssatt och validerbart. Höj versionen när den maskinläsbara strukturen
// ändras. Fas 0.11.
export const REPORT_SCHEMA_VERSION = 'butlery-verify-report/2';
export const REPORT_SCHEMA = {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  $id: 'butlery-verify-report/2',
  type: 'object',
  required: ['schema', 'runId', 'generatedAt', 'canonicalCommand', 'packageIdentity', 'sources',
    'steps', 'controls', 'tally', 'measures', 'manifest',
    'pipelineResult', 'controlsResult', 'phaseGateResult', 'overallResult',
    'exitCode', 'finalExitCode', 'currentPhase', 'requirements'],
  properties: {
    schema: { const: 'butlery-verify-report/2' },
    runId: { type: 'string', pattern: '^[0-9a-f]{16}$' },
    generatedAt: { type: 'string' },
    sources: { type: 'object' },
    packageIdentity: { type: 'object', required: ['manifestSha256', 'manifestExpected', 'cwd', 'node', 'artifactFingerprint'],
      properties: { manifestSha256: { type: ['string', 'null'], pattern: '^[0-9a-f]{64}$' },
        manifestExpected: { type: 'integer' }, cwd: { type: 'string' }, node: { type: 'string' },
        artifactFingerprint: { type: 'object', required: ['sha256', 'mode', 'declared', 'hashed'],
          properties: { sha256: { type: 'string', pattern: '^[0-9a-f]{64}$' },
            mode: { enum: ['repo', 'delivery'] }, declared: { type: 'integer' }, hashed: { type: 'integer' },
            missing: { type: 'integer' }, totalEntries: { type: 'integer' }, outsideEntries: { type: 'integer' } } },
        commit: { type: ['string', 'null'] } } },
    steps: { type: 'array', items: { type: 'object', required: ['step', 'script', 'status', 'exitCode'],
      properties: { step: { type: 'string' }, script: { type: 'string' },
        status: { enum: ['passed', 'failed'] }, exitCode: { type: 'integer' } } } },
    controls: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'name', 'owner', 'source', 'status', 'resolutionPhase', 'requiredForGate'],
        properties: {
          id: { type: 'string', pattern: '^CHK-' },
          name: { type: 'string' }, owner: { type: 'string' }, source: { type: 'string' },
          status: { enum: ['passed', 'failed', 'blocked', 'not run', 'not applicable'] },
          resolutionPhase: { type: 'integer' },
          requiredForGate: { type: 'array', items: { type: 'integer' } }
        }
      }
    },
    tally: {
      type: 'object',
      required: ['passed', 'failed', 'blocked', 'not run', 'not applicable'],
      additionalProperties: false,
      properties: {
        passed: { type: 'integer' }, failed: { type: 'integer' }, blocked: { type: 'integer' },
        'not run': { type: 'integer' }, 'not applicable': { type: 'integer' }
      }
    },
    measures: { type: 'object', required: ['specErrors', 'specWarnings', 'geometryDeviations', 'coverageErrors'],
      properties: { specErrors: { type: 'integer' }, specWarnings: { type: 'integer' },
        geometryDeviations: { type: 'integer' }, coverageErrors: { type: 'integer' } } },
    requirements: { type: 'object', required: ['total', 'byStatus'],
      properties: { total: { type: 'integer' }, byStatus: { type: 'object' } } },
    pipelineResult: { enum: ['passed', 'failed'] },
    controlsResult: { enum: ['passed', 'failed'] },
    phaseGateResult: { enum: ['passed', 'failed'] },
    overallResult: { enum: ['passed', 'failed'] },
    exitCode: { enum: [0, 1] },
    finalExitCode: { enum: [0, 1] },
    currentPhase: { type: 'integer' },
    manifest: { type: 'object', required: ['status'] }
  }
};

// Kompakt validator för just det här schemat — inget npm-beroende.
// GENERELL validator som traverserar REPORT_SCHEMA. Fas 0.13: den handskrivna
// implementationen godkände numeriskt runId och generatedAt trots att schemat
// kräver string — validator och schema kunde alltså glida isär. Nu läses schemat.
function typeOk(v, t) {
  if (t === undefined) return true;
  const types = Array.isArray(t) ? t : [t];
  return types.some(x =>
    x === 'string' ? typeof v === 'string' :
    x === 'integer' ? Number.isInteger(v) :
    x === 'number' ? typeof v === 'number' :
    x === 'boolean' ? typeof v === 'boolean' :
    x === 'array' ? Array.isArray(v) :
    x === 'object' ? (v !== null && typeof v === 'object' && !Array.isArray(v)) :
    x === 'null' ? v === null : true);
}

function walkSchema(value, schema, path, p) {
  if (!schema || typeof schema !== 'object') return;
  if (schema.const !== undefined && value !== schema.const)
    p.push(path + ' = ' + JSON.stringify(value) + ', schemat kräver ' + JSON.stringify(schema.const));
  if (schema.enum && !schema.enum.includes(value))
    p.push(path + ' = ' + JSON.stringify(value) + ', tillåtna: ' + schema.enum.map(x => JSON.stringify(x)).join(', '));
  if (schema.type && !typeOk(value, schema.type)) {
    p.push(path + ' är ' + (Array.isArray(value) ? 'array' : value === null ? 'null' : typeof value) +
      ', schemat kräver ' + (Array.isArray(schema.type) ? schema.type.join('|') : schema.type));
    return;   // fel typ → djupare kontroller är meningslösa
  }
  if (schema.pattern && typeof value === 'string' && !new RegExp(schema.pattern).test(value))
    p.push(path + ' = "' + value + '" matchar inte ' + schema.pattern);
  if (Array.isArray(schema.required) && value && typeof value === 'object')
    for (const k of schema.required)
      if (value[k] === undefined || value[k] === null || value[k] === '')
        p.push(path + ' saknar "' + k + '"');
  if (schema.properties && value && typeof value === 'object' && !Array.isArray(value)) {
    for (const [k, sub] of Object.entries(schema.properties))
      if (value[k] !== undefined) walkSchema(value[k], sub, path + '.' + k, p);
    if (schema.additionalProperties === false)
      for (const k of Object.keys(value))
        if (!(k in schema.properties)) p.push(path + ' har okänd nyckel "' + k + '"');
  }
  if (schema.items && Array.isArray(value))
    value.forEach((el, i2) => walkSchema(el, schema.items, path + '[' + i2 + ']', p));
}

const STATUSES2 = ['passed', 'failed', 'blocked', 'not run', 'not applicable'];
export function validateReportSchema(r) {
  const p = [];
  // 1 · Schemadriven traversering — allt som REPORT_SCHEMA deklarerar.
  walkSchema(r, REPORT_SCHEMA, 'report', p);

  // 2 · Invarianter som JSON Schema inte kan uttrycka.
  const isInt = v => Number.isInteger(v);
  if (r.generatedAt !== undefined && typeof r.generatedAt === 'string' && !Date.parse(r.generatedAt))
    p.push('report.generatedAt är inget giltigt datum');
  if (Array.isArray(r.steps) && !r.steps.length) p.push('report.steps är tom — ingen körning har registrerats');
  if (Array.isArray(r.controls)) {
    if (!r.controls.length) p.push('report.controls är tom — ingen kontroll har reducerats');
    for (const c of r.controls) {
      if (c.status === 'blocked' && !c.blockedBy) p.push(c.id + ': blocked utan blockedBy');
      if (c.status === 'not applicable' && !c.why) p.push(c.id + ': not applicable utan motivering');
      if (c.errors !== undefined && !isInt(c.errors)) p.push(c.id + ': errors är inget heltal');
    }
    const ids = r.controls.map(c => c.id);
    const dup = ids.filter((x, i2) => ids.indexOf(x) !== i2);
    for (const d of [...new Set(dup)]) p.push('kontroll-id ' + d + ' förekommer flera gånger');
  }
  // EXAKT tallyinvariant, samma som validateReport() — Fas 0.16: schemat prövade
  // bara summan, så en tally med rätt total men fel fördelning godkändes och
  // kunde tvättas bort av finaliseringen.
  if (r.tally && Array.isArray(r.controls)) {
    const actual = {};
    for (const s of STATUSES2) actual[s] = 0;
    for (const c of r.controls) if (STATUSES2.includes(c.status)) actual[c.status]++;
    for (const s of STATUSES2) {
      const said = r.tally[s];
      if (said === undefined) continue;                       // saknad nyckel fångas av additionalProperties/required
      if (Number.isInteger(said) && said !== actual[s])
        p.push('tally.' + s + ' säger ' + said + ' men ' + actual[s] + ' kontroller har den statusen');
    }
    const sum = Object.values(r.tally).reduce((a, b) => a + (isInt(b) ? b : 0), 0);
    if (sum !== r.controls.length) p.push('tallyn summerar till ' + sum + ', registret har ' + r.controls.length);
  }
  if (r.measures && Array.isArray(r.controls)) {
    const specSum = r.controls.filter(c => c.source === 'spec-lint').reduce((a, c) => a + (c.errors || 0), 0);
    if (specSum > (r.measures.specErrors || 0))
      p.push('spec-kontrollernas felsumma ' + specSum + ' överstiger measures.specErrors ' + r.measures.specErrors + ' — diagnostik räknas dubbelt');
  }
  return p;
}

// ── GEMENSAM manifestparser och fingeravtryck ────────────────────────────────
// Fas 0.15: fingeravtrycket filtrerade bort de sju zip:/-posterna, så en ändrad
// zip:/support.js passerade grinden. Verifierare, grind och manifestkontroll
// använder nu samma parser och samma sökvägsupplösning.
export function manifestEntries(manifestText) {
  const rows = [];
  for (const m of String(manifestText || '').matchAll(/^\|\s*`([^`]+)`\s*\|\s*`([0-9a-f]{64})`/gm)) {
    const raw = m[1];
    const outside = raw.startsWith('zip:/');
    rows.push({ key: raw, sha256: m[2], outside, rel: outside ? raw.slice('zip:/'.length) : raw });
  }
  return rows;
}

// Löser en manifestpost till en sökväg RELATIVT reporoten. Leveransytan ligger
// tre nivåer upp (paket → design-katalog → uploads → ZIP-rot).
export function resolveEntry(entry) {
  return entry.outside ? '../../../' + entry.rel : entry.rel;
}

// LÄGESMEDVETET fingeravtryck. repo: reporotsytan. delivery: reporotsytan PLUS
// samtliga zip:/-poster. Läge, deklarerat antal och hashat antal sparas och
// kontrolleras av grinden.
export function artifactFingerprint(manifestText, mode, io) {
  const entries = manifestEntries(manifestText);
  const scope = mode === 'delivery' ? entries : entries.filter(e => !e.outside);
  const parts = [];
  let hashed = 0, missing = 0;
  for (const e of scope.slice().sort((a, b) => a.key.localeCompare(b.key))) {
    const p = resolveEntry(e);
    if (!io.exists(p)) { parts.push(e.key + ':MISSING'); missing++; continue; }
    parts.push(e.key + ':' + io.sha256(p));
    hashed++;
  }
  return {
    mode, sha256: io.hashString(parts.join('\n') + '\n'),
    declared: scope.length, hashed, missing,
    totalEntries: entries.length, outsideEntries: entries.filter(e => e.outside).length
  };
}
