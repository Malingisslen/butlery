#!/usr/bin/env node
// Block 287 — kandidat till den slutliga remedieringspopulationen.
//
// Tva steg, strikt atskilda:
//   HARLED   kor block 282-286:s egna verktyg och lint vid HEAD, mater nulaget
//            i korpusen och skriver en ogonblicksbild. Ingenting klassas har.
//   KLASSA   en ren funktion av ogonblicksbilden och inventeringen. Samma
//            indata ger alltid samma utdata, oavsett ordning.
//
// Identiteten bygger pa semantisk agare: vy+tillstand, roll+tillstand,
// skarm+tillgangligt namn. Aldrig farg, geometri, index, radnummer, varde,
// PASS/FAIL eller remedieringsstatus.
//
// Kor:  node rp287-build.mjs [--root=.] [--inventering=<fil>]
//       [--snapshot-ut=<fil>] [--snapshot-in=<fil>] [--detalj=enheter]

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROOT = resolve(arg('root') || '.');
const S = process.env.MAT || join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'fas2', 'matning');
const INV = JSON.parse(readFileSync(arg('inventering') || join(S, 'bas-inventering.json'), 'utf8'));

const h = x => createHash('sha256').update(JSON.stringify(x)).digest('hex').slice(0, 16);
const fail = m => { throw new Error('FAIL CLOSED: ' + m); };
const fold = s => String(s).normalize('NFD').replace(/[\u0300-\u036f]/g, '');
const slug = s => fold(s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const byId = (a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);

/* ═══ STEG 1 · HARLED ═════════════════════════════════════════════════════ */

function harled() {
  const kor = (rel, extra = []) => JSON.parse(execFileSync(process.execPath,
    [join(ROOT, rel), '--root=' + ROOT, ...extra], { cwd: ROOT, encoding: 'utf8', maxBuffer: 1 << 28 }));
  const B282 = kor('tools/stateflow-population.mjs');
  const B283 = kor('tools/stateflow-applicability.mjs');
  const B284 = kor('tools/role-vocabulary-reconciliation.mjs');
  const B285 = kor('tools/role-state-applicability.mjs');
  const B286 = kor('tools/tokenized-state-model.mjs');
  const baslinje = {
    '282_POPULATION': B282.POPULATION_FINGERPRINT, '282_IDENTITY': B282.IDENTITY_FINGERPRINT,
    '282_MAPPING': B284.BLOCK_282_283_READONLY['282_MAPPING'],
    '283_IDENTITY': B283.IDENTITY_FINGERPRINT, '283_STATUS': B283.STATUS_FINGERPRINT,
    '284_OCCURRENCE_IDENTITY': B284.OCCURRENCE_IDENTITY_FINGERPRINT,
    '284_OCCURRENCE_STATUS': B284.OCCURRENCE_STATUS_FINGERPRINT,
    '285_IDENTITY': B285.IDENTITY_FINGERPRINT, '285_STATUS': B285.STATUS_FINGERPRINT,
    '286_IDENTITY': B286.IDENTITY_FINGERPRINT, '286_STATUS': B286.STATUS_FINGERPRINT
  };
  const fsr = kor('tools/stateflow-population.mjs', ['--detalj=fsr'])
    .map(r => ({ id: r.id, relevans: r.relevans, representation: r.representation }));
  const csr = kor('tools/stateflow-applicability.mjs', ['--detalj=csr'])
    .map(r => ({ id: r.ROW_ID, status: r.NEW_STATUS, repr: r.REPRESENTATION_OCCURRENCES }));
  const tr = kor('tools/stateflow-applicability.mjs', ['--detalj=tr'])
    .map(r => ({ id: r.TRANSITION_ID, repr: r.REPRESENTATION_STATUS }));
  const K285 = JSON.parse(readFileSync(join(ROOT, 'fas2/role-state-applicability.json'), 'utf8'));
  const rs = K285.rollstate.map(r => ({ id: r.ROW_ID, status: r.PROPOSED_STATUS,
    provenance: r.PROVENANCE, repr: r.REPRESENTATION_OCCURRENCES }));

  // Agarkartan (skarm + namn + fil) tas ur Block 284 vid baslinjen.
  // Nulaget (aktuell roll) mats sedan har, direkt ur korpusen.
  const K284 = JSON.parse(readFileSync(join(ROOT, 'fas2/role-vocabulary-reconciliation.json'), 'utf8'));
  const occ = kor('tools/role-vocabulary-reconciliation.mjs', ['--detalj=occ']);
  const roller = K284.forekomster.map(f => {
    const o = occ.find(x => x.OCCURRENCE_ID === f.OCCURRENCE_ID) || fail('Block 284-forekomsten saknar agare: ' + f.OCCURRENCE_ID);
    const fil = o.SOURCE_LOCATION.split(' \u00b7 ')[0];
    return { id: f.OCCURRENCE_ID, artifact: o.ARTIFACT_ID, name: o.CONTROL_NAME, fil,
      final: f.FINAL_ROLE, ...matAktuellRoll(fil, o.ARTIFACT_ID, o.CONTROL_NAME) };
  });

  // Lint vid HEAD — lasande verktyg. Hela felutskriften sparas.
  const lint = kortext('tools/spec-lint.mjs').split('\n').filter(l => l.startsWith('\u2716 '));
  const lcText = kortext('tools/lint-controls.mjs');
  const lc = Object.fromEntries(((/LC-SUMMARY (.*)/.exec(lcText) || [])[1] || '').split(' ')
    .filter(Boolean).map(kv => kv.split('=')).map(([k, v]) => [k, Number(v)]));
  if (typeof lc.deviations !== 'number') fail('lint-controls gav ingen LC-SUMMARY');

  // A11Y-01: agaren ar ram + synlig text, aldrig radnummer.
  const a11y01 = lint.filter(l => /^\u2716 A11Y-01/.test(l)).map(l => {
    const m = /^\u2716 A11Y-01\s+(.+\.dc\.html):(\d+)/.exec(l) || fail('A11Y-01 utan plats: ' + l);
    const rader = readFileSync(join(ROOT, m[1]), 'utf8').split('\n');
    const nr = Number(m[2]);
    let ram = null;
    for (let i = nr - 1; i >= 0 && !ram; i--) {
      const x = /class="sc-item"[^>]*\bid="([^"]+)"/.exec(rader[i]) || /\bid="([^"]+)"[^>]*class="sc-item"/.exec(rader[i]);
      if (x) ram = x[1];
    }
    const text = (/>([^<]+)</.exec(rader[nr - 1]) || [])[1];
    if (!ram || !text) fail('A11Y-01-agaren kan inte faststallas: ' + l);
    return { fil: m[1], ram, text: text.trim() };
  });

  return { baslinje, fsr, csr, tr, rs, roller, lint, lc, a11y01,
    scope: B282.SCOPE_FYND ? [{ id: 'start', fynd: 'VIEW_TAXONOMY_GAP_STARTUP' }] : [] };
}

function kortext(rel) {
  try {
    return execFileSync(process.execPath, [join(ROOT, rel)], { cwd: ROOT, encoding: 'utf8', maxBuffer: 1 << 28 });
  } catch (e) { return String(e.stdout || '') + String(e.stderr || ''); }
}

function matAktuellRoll(fil, artifact, namn) {
  const p = join(ROOT, fil);
  if (!existsSync(p)) return { current: 'NOT_FOUND', currentState: null };
  const t = readFileSync(p, 'utf8');
  const start = t.search(new RegExp('class="sc-item"[^>]*\\bid="' + artifact + '"'));
  if (start < 0) return { current: 'NOT_FOUND', currentState: null };
  const slut = t.indexOf('class="sc-item"', start + 20);
  const ram = t.slice(start, slut < 0 ? undefined : slut);
  for (const m of ram.matchAll(/<[a-z]+[^>]*>/g)) {
    const n = (/data-a11y-name="([^"]*)"/.exec(m[0]) || [])[1];
    if (n !== namn) continue;
    return { current: (/data-a11y-role="([^"]*)"/.exec(m[0]) || [])[1] || 'NONE',
      currentState: (/data-a11y-state="([^"]*)"/.exec(m[0]) || [])[1] || null };
  }
  return { current: 'NOT_FOUND', currentState: null };
}

/* ═══ STEG 2 · KLASSA ═════════════════════════════════════════════════════ */

const KATEGORIER = ['PRODUCT_REMEDIATION_REQUIRED', 'SPEC_SYNC_REQUIRED', 'LINT_SYNC_REQUIRED',
  'METHOD_TOOLING_REQUIRED', 'DOCUMENTATION_ONLY', 'ALREADY_SATISFIED', 'NOT_REQUIRED',
  'UNSPECIFIED_NO_ACTION', 'UNVERIFIABLE', 'HUMAN_DECISION_REQUIRED', 'HISTORICAL_OR_SUPERSEDED'];

export function klassa(snap, inv) {
  // Grind: block 282-286 ar read-only.
  for (const [k, v] of Object.entries(inv.fryst_baslinje))
    if (snap.baslinje[k] !== v) fail('baslinjen har andrats: ' + k + ' = ' + snap.baslinje[k] + ', fryst ' + v);

  const blockerIds = new Set(inv.blockerare.map(b => b.BLOCKER_ID));
  const SLUTNA = new Set(inv.slutna_roller);
  const enheter = [];
  const lagg = e => {
    if (!KATEGORIER.includes(e.CATEGORY)) fail('okand kategori ' + e.CATEGORY);
    for (const b of e.BLOCKERS || []) if (!blockerIds.has(b)) fail(e.id + ' pekar pa okand blockerare ' + b);
    enheter.push(e);
  };

  // Vytillstand (282)
  for (const r of snap.fsr) {
    const base = { id: 'RP::FLOW_STATE::' + r.id, OWNER_ID: r.id, REQUIREMENT_ID: r.id,
      REQUIREMENT_SOURCE: 'SRC-282 · testmatris.md §1', PROVENANCE: 'SOURCE_GROUNDED',
      CURRENT_EVIDENCE: 'representation=' + r.representation };
    if (r.relevans === 'NOT_APPLICABLE') lagg({ ...base, CATEGORY: 'NOT_REQUIRED', CURRENT_STATUS: 'NOT_APPLICABLE' });
    else if (r.relevans === 'REQUIRED' && r.representation === 'PRESENT')
      lagg({ ...base, CATEGORY: 'ALREADY_SATISFIED', CURRENT_STATUS: 'SATISFIED' });
    else if (r.relevans === 'REQUIRED' && r.representation === 'ABSENT')
      lagg({ ...base, CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED', CURRENT_STATUS: 'UNSATISFIED',
        REMEDIATION_FACET: 'DRAW_VIEW_STATE', PRODUCT_LOCATION: r.id.split('::')[2],
        WRITE_OWNER: 'VIEW::' + r.id.split('::')[2] + '::' + r.id.split('::')[3],
        WRITE_READY: false, BLOCKERS: ['BL-01'],
        BLOCKING_REASON: 'Produktlinjen ar oavgjord: ritningen maste goras pa den linje som blir baslinje.' });
    else lagg({ ...base, CATEGORY: 'UNVERIFIABLE', CURRENT_STATUS: 'UNVERIFIABLE', BLOCKING: true,
      BLOCKERS: ['BL-04'] });
  }

  // Kontrolltillstand (283, med 285:s dom for sina 24 rader)
  const rs = new Map(snap.rs.map(r => [r.id, r]));
  for (const r of snap.csr) {
    if (/TOKEN/i.test(r.id)) fail('en tokeniserad tillstandsrad har uppstatt: ' + r.id);
    const x = rs.get(r.id);
    const status = x ? x.status : r.status;
    const repr = x ? x.repr : r.repr;
    const base = { id: 'RP::CONTROL_STATE::' + r.id, OWNER_ID: r.id, REQUIREMENT_ID: r.id,
      REQUIREMENT_SOURCE: x ? 'SRC-285' : 'SRC-283', PROVENANCE: x ? x.provenance : 'SOURCE_GROUNDED',
      CURRENT_EVIDENCE: 'maskinlasbar representation i korpusen = ' + repr };
    if (status === 'UNSPECIFIED') lagg({ ...base, CATEGORY: 'UNSPECIFIED_NO_ACTION', CURRENT_STATUS: 'NOT_EVALUATED' });
    else if (status === 'NOT_REQUIRED') lagg({ ...base, CATEGORY: 'NOT_REQUIRED', CURRENT_STATUS: 'NOT_EVALUATED' });
    else if (status === 'REQUIRED' && repr > 0) lagg({ ...base, CATEGORY: 'ALREADY_SATISFIED', CURRENT_STATUS: 'SATISFIED' });
    else if (status === 'REQUIRED') {
      const ka = inv.komponentark_representation[r.id];
      if (ka === undefined) fail(r.id + ' saknar uppmatt komponentarksrepresentation');
      lagg({ ...base, CATEGORY: 'HUMAN_DECISION_REQUIRED', CURRENT_STATUS: 'SURFACE_DEPENDENT',
        CURRENT_EVIDENCE: base.CURRENT_EVIDENCE + '; komponentark: ' + (ka || 'inte ritat'),
        BLOCKERS: r.id === 'CSR::ROLE::combobox::EXPANDED' ? ['BL-04', 'BL-03'] : ['BL-04'] });
    } else fail(r.id + ' har okand status ' + status);
  }

  // Overgangar (283)
  for (const r of snap.tr) {
    const base = { id: 'RP::TRANSITION::' + r.id, OWNER_ID: r.id, REQUIREMENT_ID: r.id,
      REQUIREMENT_SOURCE: 'SRC-283 · flows-roles-budget.md', PROVENANCE: 'SOURCE_GROUNDED',
      CURRENT_EVIDENCE: 'representation=' + r.repr };
    if (r.repr === 'PRESENT') lagg({ ...base, CATEGORY: 'ALREADY_SATISFIED', CURRENT_STATUS: 'SATISFIED' });
    else if (r.repr === 'ABSENT') lagg({ ...base, CATEGORY: 'HUMAN_DECISION_REQUIRED', CURRENT_STATUS: 'ABSENT', BLOCKERS: ['BL-05'] });
    else if (r.repr === 'UNVERIFIABLE') lagg({ ...base, CATEGORY: 'UNVERIFIABLE', CURRENT_STATUS: 'UNVERIFIABLE', BLOCKING: true, BLOCKERS: ['BL-05'] });
    else fail(r.id + ' har okand representation ' + r.repr);
  }

  // Slutroller (284) — nulaget matt ur korpusen
  for (const r of snap.roller) {
    if (/TOKEN_MULTISELECT|PATTERN/i.test(String(r.final)))
      fail('ett interaktionsmonster har smugit in som roll: ' + r.id + ' = ' + r.final);
    const agare = r.fil + '::' + r.artifact + '::' + slug(r.name);
    const base = { id: 'RP::ROLE::' + r.id, OWNER_ID: r.id, REQUIREMENT_ID: r.id + '::FINAL_ROLE',
      REQUIREMENT_SOURCE: 'SRC-284', PROVENANCE: 'SOURCE_GROUNDED eller HUMAN_APPROVED (Block 284)',
      CURRENT_EVIDENCE: 'aktuell roll=' + r.current + ', slutroll=' + r.final, WRITE_OWNER: agare };
    if (r.current === 'NOT_FOUND')
      lagg({ ...base, CATEGORY: 'UNVERIFIABLE', CURRENT_STATUS: 'UNVERIFIABLE', BLOCKING: true, BLOCKERS: ['BL-01'] });
    else if (SLUTNA.has(r.final) && r.current === r.final)
      lagg({ ...base, CATEGORY: 'ALREADY_SATISFIED', CURRENT_STATUS: 'SATISFIED' });
    else if (SLUTNA.has(r.final))
      lagg({ ...base, CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED', CURRENT_STATUS: 'UNSATISFIED',
        REMEDIATION_FACET: 'ASSIGN_FINAL_ROLE', PRODUCT_LOCATION: r.fil + ' · ram ' + r.artifact,
        WRITE_READY: false, BLOCKERS: ['BL-01'],
        BLOCKING_REASON: 'Rollen ar entydig, men produktlinjen ar oavgjord.' });
    else lagg({ ...base, CATEGORY: 'HUMAN_DECISION_REQUIRED', CURRENT_STATUS: 'OUTSIDE_CLOSED_VOCABULARY', BLOCKERS: ['BL-03'] });
  }

  // Vytaxonomi (282 scope-fynd)
  for (const s of snap.scope)
    lagg({ id: 'RP::VIEW_TAXONOMY::' + s.id, OWNER_ID: s.id, REQUIREMENT_ID: s.fynd,
      REQUIREMENT_SOURCE: 'SRC-282', PROVENANCE: 'SOURCE_GROUNDED', CATEGORY: 'HUMAN_DECISION_REQUIRED',
      CURRENT_STATUS: 'NO_REQUIREMENT_ROW', CURRENT_EVIDENCE: s.fynd, BLOCKERS: ['BL-12'] });

  // A11Y-01 — tillstand utan roll
  for (const a of snap.a11y01)
    lagg({ id: 'RP::STATE_WITHOUT_ROLE::' + a.ram + '::' + slug(a.text), OWNER_ID: a.ram + '::' + slug(a.text),
      REQUIREMENT_ID: 'A11Y-01', REQUIREMENT_SOURCE: 'SRC-LINT · tillganglighetshandoff rad 30',
      PROVENANCE: 'SOURCE_GROUNDED', CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED', CURRENT_STATUS: 'UNSATISFIED',
      CURRENT_EVIDENCE: 'tillstand utan roll och namn', REMEDIATION_FACET: 'COMPLETE_A11Y_CONTRACT',
      PRODUCT_LOCATION: a.fil + ' · ram ' + a.ram, WRITE_OWNER: a.fil + '::' + a.ram + '::' + slug(a.text),
      WRITE_READY: false, BLOCKERS: ['BL-01'],
      BLOCKING_REASON: 'pf-a har redan andrat samma element — dubbelremedieringsrisk.' });

  // Identitet: kollision faller stangt.
  enheter.sort(byId);
  for (let i = 1; i < enheter.length; i++)
    if (enheter[i].id === enheter[i - 1].id) fail('identitetskollision: ' + enheter[i].id);
  const agare = new Map();
  for (const e of enheter) {
    const k = e.id;
    if (agare.has(k) && agare.get(k) !== e.OWNER_ID) fail('tva agare pa samma identitet: ' + k);
    agare.set(k, e.OWNER_ID);
  }

  // Lintforekomster — varje fynd far en kategori, annars ar det oforklarat.
  const regler = inv.lintregler.filter(r => r.REGEL !== 'LC');
  const lintKlass = {}, oforklarade = [];
  for (const l of snap.lint) {
    const f = fold(l);
    const regel = regler.find(r => f.startsWith('\u2716 ' + r.REGEL + ' ') && new RegExp(fold(r.MONSTER)).test(f));
    if (!regel) { oforklarade.push(l); continue; }
    const k = regel.REGEL + ' · ' + regel.KATEGORI + (regel.BLOCKER ? ' · ' + regel.BLOCKER : '');
    lintKlass[k] = (lintKlass[k] || 0) + (regel.REGEL === 'A11Y-02' ? Number((/(\d+) kontroller/.exec(f) || [])[1] || 1) : 1);
  }
  const lcRegel = inv.lintregler.find(r => r.REGEL === 'LC');
  lintKlass['LC · ' + lcRegel.KATEGORI + ' · ' + lcRegel.BLOCKER] = snap.lc.deviations;

  // Koppling: lintens 'ogiltig roll' ska vara exakt de forekomster som bar rollen i korpusen.
  const lintRoller = {}, korpusRoller = {};
  for (const l of snap.lint) {
    const m = /^\u2716 T-08\s+(.+?\.dc\.html): ogiltig roll "([^"]+)"/.exec(l);
    if (m) lintRoller[m[1] + '|' + m[2]] = (lintRoller[m[1] + '|' + m[2]] || 0) + 1;
  }
  for (const r of snap.roller) if (!SLUTNA.has(r.current) && r.current !== 'NOT_FOUND')
    korpusRoller[r.fil + '|' + r.current] = (korpusRoller[r.fil + '|' + r.current] || 0) + 1;
  const kopplingOk = JSON.stringify(Object.entries(lintRoller).sort()) === JSON.stringify(Object.entries(korpusRoller).sort());

  // Kallinventering: historiska och redan uppfyllda kallor far aldrig bara enheter.
  for (const k of inv.kallor) {
    if (['HISTORICAL', 'SUPERSEDED', 'ALREADY_SATISFIED_SOURCE', 'METHOD_ONLY'].includes(k.KLASS) && k.ENHETER !== 0)
      fail(k.SOURCE_ID + ' ar ' + k.KLASS + ' men pastas bara ' + k.ENHETER + ' remedieringsenheter');
  }
  const okandaKallor = inv.kallor.filter(k => k.KLASS === 'UNKNOWN').map(k => k.SOURCE_ID);

  /* ── aggregat ── */
  const rakna = (xs, f) => xs.reduce((o, x) => (o[f(x)] = (o[f(x)] || 0) + 1, o), {});
  const perKategori = Object.fromEntries(KATEGORIER.map(k => [k, enheter.filter(e => e.CATEGORY === k).length]));
  const produkt = enheter.filter(e => e.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED');
  const skrivagare = new Set(produkt.map(e => e.WRITE_OWNER));
  const koppladeSkrivningar = [...skrivagare].filter(w => produkt.filter(e => e.WRITE_OWNER === w).length > 1);
  const utanProveniens = produkt.filter(e => !e.PROVENANCE).length;
  const utanEvidens = produkt.filter(e => !e.CURRENT_EVIDENCE).length;
  const utanAgare = produkt.filter(e => !e.OWNER_ID || !e.WRITE_OWNER).length;
  const beslutsblockerare = [...new Set(enheter.flatMap(e => e.BLOCKERS || []))].sort();
  const humanBlockerare = inv.blockerare.filter(b => b.TYP === 'HUMAN_DECISION_REQUIRED').map(b => b.BLOCKER_ID);
  const unverifBlockerare = inv.blockerare.filter(b => b.TYP === 'UNVERIFIABLE_BLOCKING').map(b => b.BLOCKER_ID);

  const kedja = {
    KANONISKA_KRAVRADER: enheter.length,
    GALLANDE_KRAV: enheter.filter(e => !['NOT_REQUIRED', 'UNSPECIFIED_NO_ACTION'].includes(e.CATEGORY)).length,
    UPPFYLLDA: enheter.filter(e => e.CURRENT_STATUS === 'SATISFIED').length,
    EJ_UPPFYLLDA: enheter.filter(e => e.CURRENT_STATUS === 'UNSATISFIED').length,
    YTBEROENDE_ELLER_FRANVARANDE: enheter.filter(e => ['SURFACE_DEPENDENT', 'ABSENT', 'OUTSIDE_CLOSED_VOCABULARY', 'NO_REQUIREMENT_ROW'].includes(e.CURRENT_STATUS)).length,
    OVERIFIERBARA: enheter.filter(e => e.CURRENT_STATUS === 'UNVERIFIABLE').length,
    PRODUKTREMEDIERING: produkt.length
  };
  const dedup = {
    REQUIREMENT_COUNT: new Set(produkt.map(e => e.REQUIREMENT_ID)).size,
    OCCURRENCE_COUNT: snap.roller.length + snap.lint.length,
    REMEDIATION_UNIT_COUNT: produkt.length,
    SOURCE_WRITE_COUNT: skrivagare.size,
    KOPPLADE_SKRIVNINGAR: koppladeSkrivningar
  };
  const grind = {
    HUMAN_DECISION_REQUIRED: humanBlockerare.length,
    UNVERIFIABLE_BLOCKING: unverifBlockerare.length + enheter.filter(e => e.BLOCKING).length,
    IDENTITY_COLLISIONS: 0,
    UNEXPLAINED_REQUIREMENTS: okandaKallor.length,
    UNEXPLAINED_OCCURRENCES: oforklarade.length + (kopplingOk ? 0 : 1),
    PRODUKTENHETER_UTAN_PROVENIENS: utanProveniens,
    PRODUKTENHETER_UTAN_EVIDENS: utanEvidens,
    PRODUKTENHETER_UTAN_AGARE: utanAgare,
    WRITE_READY: produkt.filter(e => e.WRITE_READY).length,
    BLOCKED: produkt.filter(e => !e.WRITE_READY).length
  };
  grind.FREEZE_READY = grind.HUMAN_DECISION_REQUIRED === 0 && grind.UNVERIFIABLE_BLOCKING === 0 &&
    grind.IDENTITY_COLLISIONS === 0 && grind.UNEXPLAINED_REQUIREMENTS === 0 &&
    grind.UNEXPLAINED_OCCURRENCES === 0 && grind.BLOCKED === 0;

  const lintNycklar = snap.lint.map(l => fold(l).replace(/:\d+/g, ':').replace(/\s+/g, ' ')).sort();
  const fingeravtryck = {
    REMEDIATION_IDENTITY_POPULATION: h(enheter.map(e => e.id)),
    REMEDIATION_CLASSIFICATION_STATUS: h(enheter.map(e => [e.id, e.CATEGORY, e.CURRENT_STATUS, !!e.WRITE_READY, (e.BLOCKERS || []).join(',')])),
    REQUIREMENT_SOURCE_SET: h(enheter.map(e => e.REQUIREMENT_ID + '|' + e.REQUIREMENT_SOURCE).sort()),
    PRODUCT_OCCURRENCE_SET: h([...snap.roller.map(r => r.id).sort(), ...lintNycklar])
  };

  // Sjalvkontroll mot kallans egna forvantningar — en deklarerad forvantan
  // som aldrig jamfors ar dodvikt, sa varje nyckel i forvantat maste provas.
  const fv = inv.forvantat || {}, avvik = [];
  const norm = v => (v && typeof v === 'object' && !Array.isArray(v))
    ? Object.fromEntries(Object.keys(v).sort().map(k => [k, norm(v[k])])) : v;
  const mat = { PER_KATEGORI: perKategori, KEDJA: kedja, DEDUP: { ...dedup, KOPPLADE_SKRIVNINGAR: dedup.KOPPLADE_SKRIVNINGAR.length },
    GRIND: grind, LINT: lintKlass, FINGERAVTRYCK: fingeravtryck };
  for (const k of Object.keys(fv)) {
    if (!(k in mat)) fail('forvantat deklarerar ' + k + ' som byggaren inte mater');
    if (JSON.stringify(norm(mat[k])) !== JSON.stringify(norm(fv[k])))
      avvik.push(k + ': ' + JSON.stringify(mat[k]) + ' != ' + JSON.stringify(fv[k]));
  }
  if (avvik.length) fail('kallans forvantningar stammer inte:\n  ' + avvik.join('\n  '));
  const sjalvkontroll = { deklarerade: Object.keys(fv).length, avvikelser: 0 };

  return { enheter, perKategori, kedja, dedup, grind, lintKlass, oforklarade, kopplingOk, sjalvkontroll,
    okandaKallor, beslutsblockerare, fingeravtryck,
    perKalla: rakna(enheter, e => e.REQUIREMENT_SOURCE.split(' ')[0]) };
}

/* ═══ HUVUDFLODE ══════════════════════════════════════════════════════════ */

const isMain = !!process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url));
if (isMain) {
  const snap = arg('snapshot-in') ? JSON.parse(readFileSync(arg('snapshot-in'), 'utf8')) : harled();
  if (arg('snapshot-ut')) writeFileSync(arg('snapshot-ut'), JSON.stringify(snap, null, 1) + '\n');
  const R = klassa(snap, INV);
  if (arg('detalj') === 'enheter') { console.log(JSON.stringify(R.enheter, null, 1)); process.exit(0); }
  const { enheter, ...rest } = R;
  console.log(JSON.stringify({ BLOCK: '287', INPUT_COMMIT: INV.input_commit, BASLINJE: snap.baslinje,
    ENHETER: enheter.length, ...rest,
    PRODUKTENHETER: enheter.filter(e => e.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED') }, null, 1));
}
