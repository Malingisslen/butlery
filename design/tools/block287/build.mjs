#!/usr/bin/env node
// Block 287 omgang 8 — remedieringspopulationen ombyggd fran noll pa
// integrationskandidaten, med besluten BL-01…BL-14 registrerade.
//
//   HARLED   mater pa kandidatens rot (--root). Block 282-286:s verktyg via
//            den forra byggarens ogonblicksbild, plus kontrollgeometri,
//            A11Y-02-kontrollerna, farg-familjerna och flodesspecen.
//   KLASSA   ren funktion av ogonblicksbild + inventering + matfiler.
//
// Identitet: RP::<fasett>::<agare>. Aldrig farg, geometri, index, radnummer,
// PASS/FAIL eller status. Oforandrade 282-286-enheter behaller exakt sitt id.
//
// Kor: node rp287j-build.mjs --root=<kandidat> [--snapshot-in=<fil>] [--snapshot-ut=<fil>]
//      [--detalj=enheter] [--gammal=<old-enheter.json>]

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { agarNyckel, stabilEtikett } from './identitet8.mjs';
import { kontrollFakta, omnyckla } from './omnyckla.mjs';
import { readdirSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const S = process.env.MAT || join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'fas2', 'matning');
const TMP = process.env.TMPUT || S;
const ROOT = resolve(arg('root') || (() => { throw new Error('FAIL CLOSED: ange --root=<kallrot>'); })());
const INV = JSON.parse(readFileSync(arg('inventering') || join(S, 'inventering.json'), 'utf8'));
const las = rel => JSON.parse(readFileSync(join(S, rel), 'utf8'));

const h = x => createHash('sha256').update(JSON.stringify(x)).digest('hex').slice(0, 16);
const fail = m => { throw new Error('FAIL CLOSED: ' + m); };
const fold = s => String(s).normalize('NFD').replace(/[\u0300-\u036f]/g, '');
const slug = s => fold(s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const talfri = s => String(s).replace(/\d+(?:[.,:]\d+)*/g, '').replace(/-+/g, '-').replace(/^-|-$/g, '');
const byId = (a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
const SKARMAR = () => execFileSync('git', ['-C', ROOT, 'ls-files'], { encoding: 'utf8' })
  .split('\n').filter(f => /^Butlery Skarmar.*\.dc\.html$/.test(f)).sort();

/* ═══ STEG 1 · HARLED ═════════════════════════════════════════════════════ */

function harled() {
  // Block 282-286 + lint, via den forra byggarens harledning (samma verktyg, samma rot).
  const tmp = join(TMP, 'bas-tmp.json');
  try {
    execFileSync(process.execPath, [join(dirname(fileURLToPath(import.meta.url)), 'bas-build.mjs'), '--root=' + ROOT, '--snapshot-ut=' + tmp],
      { encoding: 'utf8', maxBuffer: 1 << 28, stdio: ['ignore', 'ignore', 'ignore'] });
  } catch { /* klassningen i den forra byggaren faller pa sina gamla forvantningar; ogonblicksbilden ar redan skriven */ }
  const bas = JSON.parse(readFileSync(tmp, 'utf8'));

  const cof = JSON.parse(execFileSync(process.execPath, [join(ROOT, 'tools/stateflow-population.mjs'), '--root=' + ROOT, '--detalj=cof'],
    { cwd: ROOT, encoding: 'utf8', maxBuffer: 1 << 28 }));

  // Kontrollgeometri: lint-controls utan utskriftstak, las-endast.
  const src = readFileSync(join(ROOT, 'tools/lint-controls.mjs'), 'utf8')
    .replace('findings.slice(0, 200)', 'findings')
    .replace("'./lint-core.mjs'", "'" + 'file:///' + join(ROOT, 'tools/lint-core.mjs').replace(/\\/g, '/').replace(/ /g, '%20') + "'");
  const lcFil = join(TMP, 'lc-patchad.mjs');
  writeFileSync(lcFil, src);
  let lcUt = '';
  try { lcUt = execFileSync(process.execPath, [lcFil], { cwd: ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }); }
  catch (e) { lcUt = String(e.stdout || '') + String(e.stderr || ''); }
  const geo = lcUt.split('\n').filter(l => /^  Butlery/.test(l)).map(l => {
    const m = /^  (.+\.dc\.html):(\d+) \[([^\]]*)\] (.*)$/.exec(l) || fail('ogiltig geometrirad: ' + l);
    return { fil: m[1], rad: Number(m[2]), ram: m[3], text: m[4] };
  });
  const exempt = Number((/(\d+) element hoppade over|(\d+) element hoppade över/.exec(lcUt) || [])[1] || (/(\d+) element hoppade/.exec(lcUt) || [])[1]);

  // A11Y-02: kontroller med inneboende tillstand utan data-a11y-state.
  const a11y02 = [];
  let startRam = false; const ramar = new Set();
  for (const f of SKARMAR()) {
    const s = readFileSync(join(ROOT, f), 'utf8');
    if (/class="sc-item"[^>]*\bid="start"/.test(s)) startRam = true;
    let ram = '(okand)';
    const re = /class="sc-item"[^>]*\bid="([^"]+)"|<[a-z]+[^>]*data-a11y-role="(switch|tab|radio|checkbox)"[^>]*>/g;
    for (let m; (m = re.exec(s));) {
      if (m[1]) { ram = m[1]; ramar.add(m[1]); continue; }
      if (/data-a11y-state=/.test(m[0])) continue;
      a11y02.push({ fil: f, ram, roll: m[2], namn: (/data-a11y-name="([^"]*)"/.exec(m[0]) || [])[1] || '' });
    }
  }

  // Flodesspecen (BL-05): finns varje overgang som rad i den normativa specen?
  const spec = fold(readFileSync(join(ROOT, 'flows-roles-budget.md'), 'utf8')).toLowerCase();
  const trSpec = Object.fromEntries(bas.tr.map(t => [t.id, null]));
  const trFull = JSON.parse(execFileSync(process.execPath, [join(ROOT, 'tools/stateflow-applicability.mjs'), '--root=' + ROOT, '--detalj=tr'],
    { cwd: ROOT, encoding: 'utf8', maxBuffer: 1 << 28 }));
  for (const t of trFull) {
    const rad = spec.split('\n').find(l => l.includes('|') && l.includes(fold(t.FROM).toLowerCase()) && l.includes(fold(t.TRIGGER).toLowerCase().slice(0, 12)));
    trSpec[t.TRANSITION_ID] = rad ? 'flows-roles-budget.md: ' + rad.trim().slice(0, 90) : null;
  }

  const evidensBeslutad = readFileSync(join(ROOT, 'evidensmatris.md'), 'utf8').split('\n')
    .filter(l => /^\| [A-ZÅÄÖ0-9]+-\d+/.test(l)).map(l => l.split('|').slice(1, -1).map(x => x.trim()))
    .filter(c => /beslutad/.test(c[c.length - 1])).map(c => c[0]);

  // Omgang 9: hur manga deklarerade element i varje ram bar ett visst namn (kantagarens
  // entydighet: flera kantdelar av EN agare ar ok, tva agare med samma namn ar en kollision).
  const deklareradeNamn = {};
  for (const f of SKARMAR()) {
    let ram = '(okand)';
    for (const m of readFileSync(join(ROOT, f), 'utf8').matchAll(/class="sc-item"[^>]*\bid="([^"]+)"|<[a-z]+[^>]*data-a11y-role="[^"]+"[^>]*>/g)) {
      if (m[1]) { ram = m[1]; continue; }
      const n = (/data-a11y-name="([^"]*)"/.exec(m[0]) || [])[1]; if (!n) continue;
      const k = ram + '|' + n; deklareradeNamn[k] = (deklareradeNamn[k] || 0) + 1;
    }
  }
  return { ...bas, cof, geo, lcExempt: exempt, a11y02, startRam, trSpec, evidensBeslutad, ramar: [...ramar].sort(), deklareradeNamn };
}

/* ═══ STEG 2 · KLASSA ═════════════════════════════════════════════════════ */

export const KATEGORIER = ['PRODUCT_REMEDIATION_REQUIRED', 'SPEC_SYNC_REQUIRED', 'LINT_SYNC_REQUIRED',
  'COMPONENT_COVERAGE_REQUIRED', 'FUTURE_PHASE_3_IMPLEMENTATION_CONTRACT', 'DOWNSTREAM_APP_IMPLEMENTATION_REQUIREMENTS',
  'ALREADY_SATISFIED', 'NOT_REQUIRED', 'UNSPECIFIED_NO_ACTION', 'UNVERIFIABLE', 'HUMAN_DECISION_REQUIRED',
  'HISTORICAL_OR_SUPERSEDED', 'METHOD_TOOLING_REQUIRED', 'OWNER_IDENTITY_UNRESOLVED', 'UNKNOWN_SEMANTICS'];

export function klassa(snap, inv, M) {
  for (const [k, v] of Object.entries(inv.fryst_baslinje))
    if (snap.baslinje[k] !== v) fail('baslinjen har andrats: ' + k);

  const blockerIds = new Set(inv.blockerare.map(b => b.BLOCKER_ID));
  const URSPR = new Set(inv.roller_ursprungliga), UTVID = new Set(inv.roller_utvidgade_BL03);
  const SLUTNA = new Set([...URSPR, ...UTVID]);
  const enheter = [];
  const lagg = e => {
    if (!KATEGORIER.includes(e.CATEGORY)) fail('okand kategori ' + e.CATEGORY);
    for (const b of e.BLOCKERS || []) if (!blockerIds.has(b)) fail(e.id + ' pekar pa okand blockerare ' + b);
    if (e.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED' && /UNKNOWN|UNSPECIFIED/.test(e.CURRENT_STATUS))
      fail('okant eller ospecificerat far aldrig bli remediering: ' + e.id);
    enheter.push(e);
  };

  // ── Vytillstand (282) + uppstartsvyn (BL-12, registrerad nedstroms)
  for (const r of snap.fsr) {
    const base = { id: 'RP::FLOW_STATE::' + r.id, OWNER_ID: r.id, REQUIREMENT_ID: r.id, REQUIREMENT_SOURCE: 'SRC-282',
      PROVENANCE: 'SOURCE_GROUNDED', CURRENT_EVIDENCE: 'representation=' + r.representation };
    if (r.relevans === 'NOT_APPLICABLE') lagg({ ...base, CATEGORY: 'NOT_REQUIRED', CURRENT_STATUS: 'NOT_APPLICABLE' });
    else if (r.representation === 'PRESENT') lagg({ ...base, CATEGORY: 'ALREADY_SATISFIED', CURRENT_STATUS: 'SATISFIED' });
    else if (r.representation === 'ABSENT') lagg({ ...base, CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED', CURRENT_STATUS: 'UNSATISFIED',
      REMEDIATION_FACET: 'DRAW_VIEW_STATE', WRITE_OWNER: 'VIEW::' + r.id.split('::')[2] + '::' + r.id.split('::')[3], WRITE_READY: false,
      BLOCKING_REASON: 'Vantar pa beslutet om produktbaslinjen (kandidaten ar inte committad).' });
    else fail('vytillstand utan kand representation: ' + r.id);
  }
  const STATES = [...new Set(snap.fsr.map(r => r.id.split('::')[3]))];
  if (STATES.length !== 7) fail('vytaxonomin har inte sju tillstand');
  for (const st of STATES) {
    const id = 'FSR::VIEW::start::' + st;
    const base = { id: 'RP::FLOW_STATE::' + id, OWNER_ID: id, REQUIREMENT_ID: id, REQUIREMENT_SOURCE: 'BL-12 (nedstroms)',
      PROVENANCE: 'HUMAN_APPROVED BL-12' };
    if (st === 'DEFAULT') lagg({ ...base, CATEGORY: snap.startRam ? 'ALREADY_SATISFIED' : 'PRODUCT_REMEDIATION_REQUIRED',
      CURRENT_STATUS: snap.startRam ? 'SATISFIED' : 'UNSATISFIED', CURRENT_EVIDENCE: 'ram #start ' + (snap.startRam ? 'finns' : 'saknas'),
      ...(snap.startRam ? {} : { WRITE_OWNER: 'VIEW::start::DEFAULT', WRITE_READY: false }) });
    else lagg({ ...base, CATEGORY: 'UNSPECIFIED_NO_ACTION', CURRENT_STATUS: 'NOT_EVALUATED', CURRENT_EVIDENCE: 'ingen positiv grund' });
  }
  lagg({ id: 'RP::VIEW_TAXONOMY::start', OWNER_ID: 'start', REQUIREMENT_ID: 'VIEW_TAXONOMY_EXTENSION_STARTUP',
    REQUIREMENT_SOURCE: 'BL-12', PROVENANCE: 'HUMAN_APPROVED BL-12', CATEGORY: 'SPEC_SYNC_REQUIRED', CURRENT_STATUS: 'SPEC_LAGS',
    CURRENT_EVIDENCE: 'vytaxonomin har 17 vyer; uppstart ar normativ vy enligt BL-12' });

  // ── Kontrolltillstand (283/285) + komponentarket (BL-04)
  const rs = new Map(snap.rs.map(r => [r.id, r]));
  for (const r of snap.csr) {
    const x = rs.get(r.id), status = x ? x.status : r.status, repr = x ? x.repr : r.repr;
    const base = { id: 'RP::CONTROL_STATE::' + r.id, OWNER_ID: r.id, REQUIREMENT_ID: r.id,
      REQUIREMENT_SOURCE: x ? 'SRC-285' : 'SRC-283', PROVENANCE: x ? x.provenance : 'SOURCE_GROUNDED',
      CURRENT_EVIDENCE: 'maskinlasbar representation = ' + repr };
    if (status === 'UNSPECIFIED') lagg({ ...base, CATEGORY: 'UNSPECIFIED_NO_ACTION', CURRENT_STATUS: 'NOT_EVALUATED' });
    else if (status === 'NOT_REQUIRED') lagg({ ...base, CATEGORY: 'NOT_REQUIRED', CURRENT_STATUS: 'NOT_EVALUATED' });
    else if (status === 'REQUIRED' && repr > 0) lagg({ ...base, CATEGORY: 'ALREADY_SATISFIED', CURRENT_STATUS: 'SATISFIED' });
    else if (status === 'REQUIRED') {
      if (!(r.id in inv.komponentark_csr)) fail(r.id + ' saknar komponentarksmatning');
      const ka = inv.komponentark_csr[r.id];
      lagg({ ...base, CURRENT_EVIDENCE: base.CURRENT_EVIDENCE + '; komponentark: ' + (ka || 'inte ritat'),
        CATEGORY: ka ? 'ALREADY_SATISFIED' : 'COMPONENT_COVERAGE_REQUIRED',
        CURRENT_STATUS: ka ? 'STATE_VISUALLY_COVERED' : 'STATE_VISUALLY_MISSING' });
    } else fail(r.id + ' har okand status ' + status);
  }

  // ── Overgangar (283) mot den normativa flodesspecen (BL-05)
  for (const r of snap.tr) {
    const base = { id: 'RP::TRANSITION::' + r.id, OWNER_ID: r.id, REQUIREMENT_ID: r.id, REQUIREMENT_SOURCE: 'SRC-283',
      PROVENANCE: 'SOURCE_GROUNDED' };
    if (r.repr === 'PRESENT') lagg({ ...base, CATEGORY: 'ALREADY_SATISFIED', CURRENT_STATUS: 'SATISFIED', CURRENT_EVIDENCE: 'skarmankare' });
    else {
      const rad = snap.trSpec[r.id];
      if (!rad) fail(r.id + ' finns inte i flodesspecen');
      lagg({ ...base, CATEGORY: 'ALREADY_SATISFIED', CURRENT_STATUS: 'SATISFIED_IN_NORMATIVE_FLOW_SPEC',
        CURRENT_EVIDENCE: 'skarm=' + r.repr + '; ' + rad });
    }
  }

  // ── Omgang 8: levande tal (raknare, antal, mangder, artal) ar aldrig identitet. Ett tal far
  //    bara sta kvar nar det ar ett alternativs varde i en grupp (betyg 1–5, aldersintervall) —
  //    bevisat av att namnen annars kolliderar. Uppstroms-id:t (282–286) finns kvar som referens.
  const stabilaNamn = (poster, gruppNyckel, fulltNamn, arAlternativ, facett) => {
    const g = new Map();
    for (const p of poster) { const k = gruppNyckel(p) + '|' + talfri(fulltNamn(p)); if (!g.has(k)) g.set(k, new Set()); g.get(k).add(fulltNamn(p)); }
    return p => { const full = fulltNamn(p), t = talfri(full), namn = g.get(gruppNyckel(p) + '|' + t);
      if (namn.size === 1) return t || fail(facett + ': namnet ar bara tal: ' + full);
      if (arAlternativ(p)) { M.identitetsundantag.push({ facett, segment: full, undantag: 'OPTION_VALUE' }); return full; }
      return fail(facett + ': ' + [...namn].join(' / ') + ' skiljs bara av ett tal men ar inga alternativ'); };
  };
  M.identitetsundantag = [];
  // ── Slutroller (284) med utvidgad vokabular (BL-03)
  const rollSegment = stabilaNamn(snap.roller, r => r.id.split('::').slice(0, -1).join('::'), r => r.id.split('::').pop(), r => r.final === 'radio', 'ROLE');
  // Omgang 9 (F/G): Block 284:s id ar historik. Ett namn som bar kontrollens VALDA VARDE
  // ("Enhet, deciliter") eller ett levande antal ar instabilt som agare; den nedstroms agaren
  // ar kontrollen sjalv (etiketten). Historiskt id bevaras som proveniens, aldrig som agare.
  const VARDEROLL = new Set(['combobox', 'listbox', 'spinbutton']);
  const seg284 = s => talfri(String(s).toLowerCase().replace(/[^\p{L}\p{N}]+/gu, '-').replace(/^-|-$/g, ''));
  M.block284Alias = [];
  for (const r of snap.roller) {
    if (/TOKEN_MULTISELECT|PATTERN/i.test(String(r.final))) fail('monster som roll: ' + r.id);
    const harVarde = VARDEROLL.has(r.current) || VARDEROLL.has(r.final);
    const etikett = stabilEtikett(r.name, harVarde);
    const instabil = (harVarde && etikett !== r.name) || (/\d/.test(r.name) && r.final !== 'radio');
    const persistent = agarNyckel({ art: r.artifact, namn: etikett }) || fail('Block 284-agare utan stabil etikett: ' + r.id);
    const rid = r.id.split('::').slice(0, -1).join('::') + '::' + (instabil && harVarde ? seg284(etikett) : rollSegment(r));
    M.block284Alias.push({ BLOCK284_HISTORICAL_ID: r.id, PERSISTENT_OWNER_ID: persistent, UNIT_ID: 'RP::ROLE::' + rid,
      KLASS: instabil ? 'HISTORICAL_ONLY_UNSTABLE_AS_OWNER' : 'STABLE_AS_OWNER',
      REASON: !instabil ? 'namnet bar bara kontrollens etikett' : harVarde ? 'namnet bar valt varde efter etiketten "' + etikett.replace(/[0-9]+/g, '').trim() + '" (' + r.current + ')' : 'namnet bar ett levande antal',
      PROVENANCE: 'SRC-284 · Block 284 (skrivskyddad), namn "' + r.name + '"' });
    const base = { id: 'RP::ROLE::' + rid, OWNER_ID: rid, PERSISTENT_OWNER_ID: persistent, UPSTREAM_ID: r.id, REQUIREMENT_ID: r.id + '::FINAL_ROLE', REQUIREMENT_SOURCE: 'SRC-284',
      PROVENANCE: 'SOURCE_GROUNDED eller HUMAN_APPROVED (Block 284)', CURRENT_EVIDENCE: 'aktuell roll=' + r.current + ', slutroll=' + r.final,
      WRITE_OWNER: r.fil + '::' + r.artifact + '::' + slug(r.name) };
    if (!SLUTNA.has(r.final)) fail('slutroll utanfor den harledda listan: ' + r.final);
    if (r.current === 'NOT_FOUND') lagg({ ...base, CATEGORY: 'UNVERIFIABLE', CURRENT_STATUS: 'UNVERIFIABLE', BLOCKING: true });
    else if (r.current === r.final && URSPR.has(r.final)) lagg({ ...base, CATEGORY: 'ALREADY_SATISFIED', CURRENT_STATUS: 'SATISFIED' });
    else if (r.current === r.final) lagg({ ...base, CATEGORY: 'SPEC_SYNC_REQUIRED', CURRENT_STATUS: 'SPEC_AND_LINT_LAG',
      SYNC_FACETS: ['SPEC_SYNC', 'LINT_SYNC'] });
    else lagg({ ...base, CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED', CURRENT_STATUS: 'UNSATISFIED', REMEDIATION_FACET: 'ASSIGN_FINAL_ROLE',
      WRITE_READY: false, BLOCKING_REASON: 'Vantar pa beslutet om produktbaslinjen.' });
  }
  for (const roll of UTVID)
    lagg({ id: 'RP::ROLE_VOCABULARY::' + roll, OWNER_ID: roll, REQUIREMENT_ID: 'ROLE_VOCABULARY_POLICY', REQUIREMENT_SOURCE: 'BL-03',
      PROVENANCE: 'HUMAN_APPROVED BL-03', CATEGORY: 'SPEC_SYNC_REQUIRED', CURRENT_STATUS: 'SPEC_AND_LINT_LAG',
      SYNC_FACETS: ['SPEC_SYNC', 'LINT_SYNC'], CURRENT_EVIDENCE: 'rollen saknas i den slutna listan i spec och T-08' });

  // ── A11Y-01 (tillstand utan roll)
  const a1Segment = stabilaNamn(snap.a11y01, a => a.ram, a => slug(a.text), () => false, 'STATE_WITHOUT_ROLE');
  for (const a of snap.a11y01)
    lagg({ id: 'RP::STATE_WITHOUT_ROLE::' + a.ram + '::' + a1Segment(a), OWNER_ID: a.ram + '::' + a1Segment(a), REQUIREMENT_ID: 'A11Y-01',
      REQUIREMENT_SOURCE: 'SRC-LINT', PROVENANCE: 'SOURCE_GROUNDED', CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED', CURRENT_STATUS: 'UNSATISFIED',
      CURRENT_EVIDENCE: 'tillstand utan roll och namn pa kandidaten', REMEDIATION_FACET: 'COMPLETE_A11Y_CONTRACT',
      WRITE_OWNER: a.fil + '::' + a.ram + '::' + slug(a.text), WRITE_READY: false });

  // ── A11Y-02 → Fas 3 (BL-10). En enhet per agare; samma agare flera ganger = forekomster.
  const a2 = new Map();
  const a2Segment = stabilaNamn(snap.a11y02, x => x.ram + '::' + x.roll, x => slug(x.namn || '(utan-namn)'), x => x.roll === 'radio', 'A11Y_STATE_ANNOTATION');
  for (const x of snap.a11y02) {
    const k = x.ram + '::' + x.roll + '::' + a2Segment(x);
    a2.set(k, (a2.get(k) || 0) + 1);
  }
  for (const [k, n] of a2)
    lagg({ id: 'RP::A11Y_STATE_ANNOTATION::' + k, OWNER_ID: k, REQUIREMENT_ID: 'A11Y-02', REQUIREMENT_SOURCE: 'SRC-LINT · BL-10',
      PROVENANCE: 'HUMAN_APPROVED BL-10', CATEGORY: 'FUTURE_PHASE_3_IMPLEMENTATION_CONTRACT', CURRENT_STATUS: 'DEFERRED_PHASE_3',
      OCCURRENCES: n, CURRENT_EVIDENCE: 'data-a11y-state saknas' });

  // ── Kontrollgeometri (BL-11). Enhet = regel + ram. Vardet och radnumret ar forekomstdata,
  //    aldrig identitet — en rattning andrar vardet, inte enheten.
  const geoRegel = t => /^textstorlek/.test(t) ? 'TYPE_SCALE' : /^radie/.test(t) ? 'RADIUS' : /vikt/.test(t) ? 'WEIGHT_UNDER_12'
    : /^pill/.test(t) ? 'PILL_BADGE_PADDING' : /^avatar/.test(t) ? 'AVATAR_SCALE' : /^chip/.test(t) ? 'CHIP_PADDING' : fail('okand geometriregel: ' + t);
  const gg = new Map();
  // Avatarer med farg via var(--r04slot-*) ar osynliga for lint-controls (kraver color:#).
  // Uppmatta med samma avatarregel; de utanfor skalan ar geometriforekomster som alla andra.
  const avatarVar = M.avatar.varUtanforSkala.map(a => ({ fil: 'Butlery Skarmar v12 ' + a.fil, ram: a.ram,
    text: 'avatar ' + a.storlek + ' px (farg via var(), osynlig for lint-controls)' }));
  for (const g of [...snap.geo, ...avatarVar]) {
    const v = (/[\d.]+( × [\d.]+)?/.exec(g.text) || [''])[0].replace(/ × /, 'x');
    const k = geoRegel(g.text) + '::' + g.ram;
    const e = gg.get(k) || { n: 0, fil: g.fil, varden: {} };
    if (e.fil !== g.fil) fail('ramen ' + g.ram + ' finns i tva filer');
    e.n++; e.varden[v] = (e.varden[v] || 0) + 1; gg.set(k, e);
  }
  for (const [k, e] of gg)
    lagg({ id: 'RP::GEOMETRY::' + k, OWNER_ID: k, REQUIREMENT_ID: 'BL-11 · tokens.controls/typography', REQUIREMENT_SOURCE: 'SRC-LINT · LC',
      PROVENANCE: 'SOURCE_GROUNDED', CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED', CURRENT_STATUS: 'UNSATISFIED', OCCURRENCES: e.n,
      CURRENT_EVIDENCE: 'uppmatta varden ' + Object.keys(e.varden).sort().map(v => v + ' (' + e.varden[v] + ')').join(', ') + ' — ingen skriven undantagsgrund (data-lint-exempt 0, inget beslut, ingen variantmarkering, B-51 galler layout)',
      REMEDIATION_FACET: 'CONFORM_GEOMETRY_OR_WRITE_EXCEPTION', WRITE_OWNER: e.fil + '::' + k, WRITE_READY: false,
      BLOCKING_REASON: 'Vantar pa beslutet om produktbaslinjen.' });
  // K: den omarkta chipkandidaten ar avatarinitialerna "SE" i rcblaser — ingen roll, ingen
  // traffyta, syskon till den deklarerade knappen. Chip-kravet ar inte tillampligt.
  if (snap.lc.unmarked_chip !== 1) fail('antalet omarkta chipkandidater har andrats: ' + snap.lc.unmarked_chip);
  lagg({ id: 'RP::LINT_COVERAGE::LC-01::chip', OWNER_ID: 'LC-01::chip', REQUIREMENT_ID: 'LC-01', REQUIREMENT_SOURCE: 'SRC-LINT · LC',
    PROVENANCE: 'SOURCE_GROUNDED', CATEGORY: 'NOT_REQUIRED', CURRENT_STATUS: 'NOT_APPLICABLE_NOT_A_CHIP', OCCURRENCES: 1,
    CURRENT_EVIDENCE: 'rcblaser: <span> 34x34, radie 999, text "SE" = agarens avatarinitialer i banderollen "Sara Eks recept"; ingen data-a11y-role, ingen data-hit, ingen data-component; kontrollen i raden ar syskonknappen "Spara till mitt kok"' });
  lagg({ id: 'RP::LINT_RULE::LC::avatar-var-farger', OWNER_ID: 'LC::avatar', REQUIREMENT_ID: 'LC', REQUIREMENT_SOURCE: 'SRC-LINT · LC',
    PROVENANCE: 'MEASURED', CATEGORY: 'LINT_SYNC_REQUIRED', CURRENT_STATUS: 'TOOL_OR_SPEC_LAGS', OCCURRENCES: M.avatar.var,
    CURRENT_EVIDENCE: 'avatarregeln kraver color:# men ' + M.avatar.var + ' avatarer bar color:var(--r04slot-*) efter R-04-migreringen; ' + M.avatar.varUtanforSkala.length + ' av dem ligger utanfor skalan' });

  // ── Color-only-familjer (BL-13) mot komponentarket
  for (const c of snap.cof.filter(c => c.testbar === 'OTESTBAR_SINGLE_STATE')) {
    const nycklar = c.roller.flatMap(r => c.states.map(s => r + ':' + s));
    const saknas = nycklar.filter(k => !(k in inv.komponentark_cof) ? fail('omatt roll:tillstand ' + k) : !inv.komponentark_cof[k]);
    lagg({ id: 'RP::COLOR_ONLY_FAMILY::' + c.familj, OWNER_ID: c.familj, REQUIREMENT_ID: 'CHK-COLOR-ONLY', REQUIREMENT_SOURCE: 'SRC-282 · BL-13',
      PROVENANCE: 'SOURCE_GROUNDED', CATEGORY: saknas.length ? 'COMPONENT_COVERAGE_REQUIRED' : 'ALREADY_SATISFIED',
      CURRENT_STATUS: saknas.length ? 'STATE_VISUALLY_MISSING' : 'STATE_VISUALLY_COVERED',
      CURRENT_EVIDENCE: nycklar.map(k => k + ' → ' + (inv.komponentark_cof[k] || 'saknas i komponentarket')).join('; ') });
  }

  // ── Evidensmatrisens appkrav (BL-02)
  // Kallverifiering: evidensmatrisens rader med status "beslutad" ska vara exakt matfilens.
  const kallRader = snap.evidensBeslutad || fail('ogonblicksbilden saknar evidensmatrisens beslutade rader');
  if (JSON.stringify([...kallRader].sort()) !== JSON.stringify(M.downstream.map(d => d.id).sort()))
    fail('downstream-matfilen stammer inte med evidensmatris.md');
  for (const d of M.downstream) {
    if (!/beslutad/.test(d.status) || d.agare !== 'dev') fail('downstream-krav utan beslutad/dev: ' + d.id);
    lagg({ id: 'RP::DOWNSTREAM_APP::' + d.id, OWNER_ID: d.id, REQUIREMENT_ID: d.id, REQUIREMENT_SOURCE: 'evidensmatris.md',
      PROVENANCE: 'SOURCE_GROUNDED', CATEGORY: 'DOWNSTREAM_APP_IMPLEMENTATION_REQUIREMENTS', CURRENT_STATUS: 'DOWNSTREAM',
      CURRENT_EVIDENCE: 'agare ' + d.agare + ' · ' + d.regel });
  }

  // ── Kontrastpar i specen (BL-07)
  for (const [par, token] of Object.entries(inv.bl07_unik).filter(([k]) => !k.startsWith('$')))
    lagg({ id: 'RP::CONTRAST_PAIR::' + slug(par), OWNER_ID: par, REQUIREMENT_ID: 'T-02', REQUIREMENT_SOURCE: 'tokens.json contrastPairs · BL-07',
      PROVENANCE: 'SOURCE_GROUNDED', CATEGORY: 'SPEC_SYNC_REQUIRED', CURRENT_STATUS: 'UNIQUE_SAFE_CANDIDATE',
      CURRENT_EVIDENCE: 'deklarationen pekar om till befintlig token ' + token + '; ingen ny farg' });

  // ── R-04 pa KANDIDATENS partition (inte f4daf7f). Beslut A, C, D gor enheten till en
  //    produktskrivning; B stannade pa en tredje yta; nya grupper saknar beslut.
  const p1 = M.r04p1, p2 = M.r04p2;
  for (const k of ['CANONICAL_UNITS', 'DECIDED', 'HELD_UNRESOLVED', 'QUEUE_FINGERPRINT', 'POPULATION_FINGERPRINT', 'MEASUREMENT_FINGERPRINT'])
    if (p1.resultat[k] !== p2[k]) fail('R-04-partitionen pa kandidaten reproduceras inte mot 7351ff0: ' + k);
  const B = inv.beslut_omgang3;
  const r01 = M.kontrast.fynd || fail('kontrastbaslinjen saknar fynd');
  const krock = r01.filter(f => f.kvot < 3);
  if (krock.length !== r01.length) fail('R-01-fynd som inte ar krocken: ' + r01.map(f => f.artifactId).join(','));
  const SEP = '‖';
  const r04 = { TOTAL: p1.resultat.CANONICAL_UNITS, DECIDED_I_REGISTRET: p1.resultat.DECIDED, HELD: p1.resultat.HELD_UNRESOLVED, BESLUTADE_NU: 0, KVAR: 0 };
  for (const g of p1.resultat.QUEUE_GROUP_KEYS) {
    const g0 = inv.r04_grupper[g] || fail('okand R-04-grupp ' + g);
    const nycklar = p1.resultat.QUEUE_UNIT_KEYS.filter(u => u.startsWith(g + SEP));
    // Delning: en kogrupp kan bara flera semantiska delar med olika beslut (t.ex. bock vs chevron).
    const delar = g0.delning ? Object.entries(g0.delning).map(([k, d]) => ({ ...d, nycklar: nycklar.filter(u => u.split(SEP)[1].split(' · ')[0] === k) })) : [{ ...g0, nycklar }];
    if (delar.reduce((s2, d) => s2 + d.nycklar.length, 0) !== nycklar.length) fail('delningen av ' + g + ' tappar enheter');
    for (const gr of delar) {
    const n = gr.nycklar.length;
    const rotter = p1.agare.filter(a => gr.nycklar.includes(a.nyckel));
    const agarText = [...new Set(rotter.map(a => a.art + '#' + a.ordinal + (a.kontrollnamn ? ' (' + a.kontrollnamn + ')' : '')))].join(', ');
    const base = { id: 'RP::DARK_MODE::' + gr.agare, OWNER_ID: gr.agare, R04_GROUP_KEY: g, REQUIREMENT_ID: 'R-04',
      REQUIREMENT_SOURCE: 'r04-partition pa kandidaten (pf-a:s register)', PROVENANCE: 'SOURCE_GROUNDED' };
    if (gr.beslut && gr.skrivsVia) {
      r04.BESLUTADE_NU += n; r04.SKRIVS_VIA = (r04.SKRIVS_VIA || []).concat(gr.agare + ' → ' + gr.skrivsVia);
    } else if (gr.beslut && gr.komponentbindning) {
      const b = B[gr.beslut];
      lagg({ id: 'RP::COMPONENT_BINDING::' + gr.komponentbindning.id, OWNER_ID: gr.komponentbindning.id, R04_GROUP_KEY: g, REQUIREMENT_ID: 'R-04 + komponentsemantik',
        REQUIREMENT_SOURCE: gr.komponentbindning.kalla, PROVENANCE: 'HUMAN_APPROVED beslut ' + gr.beslut, CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED',
        CURRENT_STATUS: 'DECIDED_NOT_WRITTEN', OCCURRENCES: gr.komponentbindning.ramar.length, REMEDIATION_FACET: 'BIND_COMPONENT_TOKENS_BOTH_THEMES',
        WRITE_OWNER: 'COMPONENT::' + gr.komponentbindning.id, WRITE_READY: false,
        CURRENT_EVIDENCE: 'ramar ' + gr.komponentbindning.ramar.join(', ') + '; ' + b.LIGHT_BEFORE + ' → ' + b.LIGHT_AFTER + '; ' + b.DARK_BEFORE + ' → ' + b.DARK_AFTER + '; #7D4704 ' + b.CHAT_SEND_RAW_DARK_VALUE_STATUS });
      r04.BESLUTADE_NU += n;
    } else if (gr.beslut) {
      const b = B[gr.beslut];
      const extra = gr.beslut === 'A' ? '; dessutom ' + krock.map(f => f.artifactId + ' ' + f.kontrollnyckel + ' ' + f.kvot + ':1').join('; ') + ' (beslutad i registret men fel)' : '';
      const forek = gr.beslut === 'A' ? new Set([...rotter.map(a => a.art), ...krock.map(f => f.artifactId)]).size : new Set(rotter.map(a => a.art + '#' + a.ordinal)).size;
      lagg({ ...base, PROVENANCE: 'HUMAN_APPROVED beslut ' + gr.beslut, CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED', CURRENT_STATUS: 'DECIDED_NOT_WRITTEN',
        OCCURRENCES: forek, REMEDIATION_FACET: 'APPLY_DARK_TOKEN', WRITE_OWNER: 'R04::' + gr.agare, WRITE_READY: false,
        CURRENT_EVIDENCE: 'beslut ' + gr.beslut + ' ' + JSON.stringify(b).slice(0, 160) + '; rotter: ' + agarText + extra });
      r04.BESLUTADE_NU += n;
    } else {
      lagg({ ...base, CATEGORY: 'HUMAN_DECISION_REQUIRED', CURRENT_STATUS: 'HELD_UNRESOLVED', OCCURRENCES: n, BLOCKERS: [gr.blocker],
        CURRENT_EVIDENCE: n + ' enhet(er); rotter: ' + agarText });
      r04.KVAR += n;
    }
    }
  }
  r04.DECIDED = r04.DECIDED_I_REGISTRET + r04.BESLUTADE_NU;
  if (r04.DECIDED + r04.KVAR !== r04.TOTAL) fail('R-04-avstamningen gar inte ihop');
  // Mork text pa kandidaten (renderad, H): pf-a 2df2aca:s ytbyte ger en gemensam krock.
  const mt = M.morktext.fynd, mt2 = M.morktext2.fynd;
  if (JSON.stringify(mt.map(f => [f.findingId, f.kvot]).sort()) !== JSON.stringify(mt2.map(f => [f.findingId, f.kvot]).sort()))
    fail('den morka textmatningen reproduceras inte');
  const par = [...new Set(mt.map(f => f.fallandeRuns[0].foreground + ' pa ' + f.fallandeRuns[0].background))];
  if (par.length !== 1) fail('morka textfynd med fler an ett fargpar: ' + par.join(' | '));
  lagg({ id: 'RP::DARK_MODE::yta-kontroll::sekundartext', OWNER_ID: 'yta-kontroll::sekundartext', REQUIREMENT_ID: 'R-01 (morkt)',
    REQUIREMENT_SOURCE: 'render-probe (patchad) + dark-text-batch pa kandidaten', PROVENANCE: 'HUMAN_APPROVED beslut B4',
    CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED', CURRENT_STATUS: 'DECIDED_NOT_WRITTEN', OCCURRENCES: mt.length,
    REMEDIATION_FACET: 'APPLY_DARK_TOKEN', WRITE_OWNER: 'R04::yta-kontroll::sekundartext', WRITE_READY: false,
    CURRENT_EVIDENCE: par[0] + ' = ' + mt[0].kvot + ':1 idag → ' + B.B4.DARK_CONTROL_SECONDARY_TEXT_TOKEN + ' ' + B.B4.varde + ' = ' + B.B4.kvot + ':1; ytan #4A5C43 behalls; i ' + [...new Set(mt.map(f => f.artifactId))].join(', ') });
  M.r04avstamning = r04;
  r04.KVAR_GRUPPER = enheter.filter(e => e.id.startsWith('RP::DARK_MODE::') && e.CURRENT_STATUS === 'HELD_UNRESOLVED').map(e => e.id + ' (' + e.OCCURRENCES + ')');

  // ── R-03 (BL-09)
  for (const k of M.r03.kort) {
    const kat = /^ALREADY_SATISFIED/.test(k.rekommendation) ? 'ALREADY_SATISFIED' : /^HUMAN_DECISION/.test(k.rekommendation) ? 'SPEC_SYNC_REQUIRED' : null;
    if (!kat) continue; // K3 foljer K2 — samma element, samma beslut
    lagg({ id: 'RP::CLIPPING::' + slug(k.instans.split(' · ')[1]) + '::' + slug(k.symptomGroup.split(' · ')[0]), OWNER_ID: k.instans,
      REQUIREMENT_ID: 'R-03', REQUIREMENT_SOURCE: 'fas2/residual-r03-triage.json', PROVENANCE: kat === 'ALREADY_SATISFIED' ? 'SOURCE_GROUNDED' : 'HUMAN_APPROVED beslut E', CATEGORY: kat,
      CURRENT_STATUS: kat === 'ALREADY_SATISFIED' ? 'NOT_REPRODUCED_ON_CANDIDATE' : 'SATISFIED_AFTER_SPEC_SYNC', OCCURRENCES: kat === 'ALREADY_SATISFIED' ? 1 : 2,
      CURRENT_EVIDENCE: kat === 'ALREADY_SATISFIED' ? k.kandidat : 'onbimport: textnoden bar hela vardet "koket.se/recept/kramig-svamppasta"; ellipsen ar CSS (text-overflow), inte del av vardet; regeln ALLOWED_WHEN_UNFOCUSED ska skrivas i specen' });
  }
  lagg({ id: 'RP::DOWNSTREAM_APP::FIELD-TRUNCATION-BEHAVIOUR', OWNER_ID: 'SINGLE_LINE_FIELD_VALUE_TRUNCATION', REQUIREMENT_ID: 'beslut E villkor 2-4',
    REQUIREMENT_SOURCE: 'beslut E', PROVENANCE: 'HUMAN_APPROVED beslut E', CATEGORY: 'DOWNSTREAM_APP_IMPLEMENTATION_REQUIREMENTS', CURRENT_STATUS: 'DOWNSTREAM',
    CURRENT_EVIDENCE: 'tillgangligt varde = fullvardet, hela vardet natt vid fokus/redigering, kopiering och inskick anvander fullvardet — beteende i appen, ej ritbart i en statisk ram' });

  // ── J: generiska tillgangliga namn "Reglage". Handoffen: toggle-namnet = radens etikett
  //    (tillganglighetshandoff rad 154), data-a11y-name ar namnet "ord for ord" (rad 50).
  for (const r of M.reglage) {
    const etikett = (r.etikett || M.reglageEtikett[r.ram + '|' + r.rad] || fail('reglage utan radetikett: ' + r.ram + ' rad ' + r.rad)).replace(/&amp;/g, '&');
    const agare = r.ram + '::switch::' + slug(etikett);
    lagg({ id: 'RP::A11Y_NAME::' + agare, OWNER_ID: agare, REQUIREMENT_ID: 'A11Y-NAME (handoff rad 50, 154)', REQUIREMENT_SOURCE: 'Butlery tillganglighetshandoff',
      PROVENANCE: 'SOURCE_GROUNDED', CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED', CURRENT_STATUS: 'EFFECTIVE_NAME_FAIL', OCCURRENCES: 1,
      CURRENT_EVIDENCE: 'effektivt namn "Reglage" (data-a11y-name, ingen annan namnkalla); radens etikett finns i kallan',
      REMEDIATION_FACET: 'SET_ACCESSIBLE_NAME', WRITE_OWNER: r.fil + '::' + agare, WRITE_READY: false });
  }
  for (const [art, grund] of [['kompkalla', 'normativt beslut 2026-08-07, affordans 8/8'], ['langavarden', 'evidensmatris rad 20, avsiktlig clamp']])
    lagg({ id: 'RP::CLIPPING::' + art + '::div', OWNER_ID: art, REQUIREMENT_ID: 'R-03', REQUIREMENT_SOURCE: 'fas2/residual-r03-triage.json',
      PROVENANCE: 'SOURCE_GROUNDED', CATEGORY: 'NOT_REQUIRED', CURRENT_STATUS: 'INTENTIONAL', CURRENT_EVIDENCE: grund });

  // ── Profilens grupp-id (BL-14)
  if (B.F.COLLISIONS !== 0) fail('det nya grupp-id:t kolliderar');
  lagg({ id: 'RP::STATE_GROUP::profil', OWNER_ID: 'profil', REQUIREMENT_ID: 'BL-14', REQUIREMENT_SOURCE: 'fas2/profil-stategroup-beslutspaket.json · beslut F',
    PROVENANCE: 'HUMAN_APPROVED beslut F', CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED', CURRENT_STATUS: 'DECIDED_NOT_WRITTEN', OCCURRENCES: 2,
    CURRENT_EVIDENCE: B.F.PROFILE_STATE_GROUP_OLD_ID + ' (REJECTED) → ' + B.F.PROFILE_STATE_GROUP_NEW_ID + '; 0 kollisioner i repot, pf-a och kandidaten',
    REMEDIATION_FACET: 'RENAME_STATE_GROUP', WRITE_OWNER: 'profil::data-state-group', WRITE_READY: false });

  // ── BL-08 och historiska kallfamiljer
  for (const x of inv.historiska_populationer)
    lagg({ id: 'RP::HISTORICAL::' + x.id, OWNER_ID: x.id, IDENTITY_KIND: 'LEDGER', REQUIREMENT_ID: x.id, REQUIREMENT_SOURCE: 'BL-08', PROVENANCE: 'SOURCE_GROUNDED',
      CATEGORY: 'HISTORICAL_OR_SUPERSEDED', CURRENT_STATUS: x.klass, CURRENT_EVIDENCE: x.grund });
  // ── Upptacktspopulationen (metodpaket: tools/discovery-population.mjs, ren utcheckning).
  //    Forekomst, granskningsfamilj och agare ar atskilda. Kand kontroll utan stabil agare
  //    blir OWNER_IDENTITY_UNRESOLVED — aldrig ett pahittat agar-id.
  const U = M.upptackt, U2 = M.upptackt2, O = M.overlay;
  if (U.IMPLICIT_DROPS !== 0 || U.SUMMA_KLASSER !== U.DISCOVERY_TOTAL) fail('upptacktspopulationen har implicita bortfall');
  if (JSON.stringify(U.FINGERAVTRYCK) !== JSON.stringify(U2.FINGERAVTRYCK)) fail('upptackten ar inte ordningsinvariant');
  if (!U.HISTORISK_AVSTAMNING || U.HISTORISK_AVSTAMNING.aterfunna !== U.HISTORISK_AVSTAMNING.historiska) fail('historisk reproduktion ofullstandig');
  // Avgoranden: paket 1 (mansligt + kallagare), chattkontraktet (tvillingar), fristaende grafik.
  const forek = U.forekomster.map(f => { const b = O.forekomst[f.DISCOVERY_OCCURRENCE_ID]; if (!b) return { ...f, kalla: null, forUnknown: f.klass === 'UNKNOWN_SEMANTICS' };
    if (f.klass !== 'UNKNOWN_SEMANTICS' && f.klass !== b.klass) fail('avgorande krockar med tidigare klass: ' + f.DISCOVERY_OCCURRENCE_ID);
    return { ...f, klass: b.klass, grund: b.grund, PERSISTENT_SEMANTIC_OWNER_ID: b.klass === 'KNOWN_CONTROL' ? b.agare : null,
      OWNER_STATUS: b.klass === 'KNOWN_CONTROL' ? 'RESOLVED' : f.OWNER_STATUS, FINAL_ROLE: b.roll || null, kalla: b.kalla, forUnknown: f.klass === 'UNKNOWN_SEMANTICS' }; });
  const kandaId = new Set(U.forekomster.map(f => f.DISCOVERY_OCCURRENCE_ID));
  if (Object.keys(O.forekomst).some(id => !kandaId.has(id))) fail('avgorande utan forekomst');
  const agarIds = forek.filter(f => f.PERSISTENT_SEMANTIC_OWNER_ID).map(f => f.PERSISTENT_SEMANTIC_OWNER_ID);
  if (new Set(agarIds).size !== agarIds.length) fail('agarkollision efter avgorandena');
  const perKlass = forek.reduce((m, f) => (m[f.klass] = (m[f.klass] || 0) + 1, m), {});
  const svg = f => f.mekanismer.includes('STANDALONE_GRAPHIC');
  // Omgang 9-bokforing: UNKNOWN fore = efter omgang 8 (overlay8) pa den forra populationen.
  // Forekomster som den nya tackningen tar med (FUNCTIONAL_SIGNAL, HANDOFF_STEPPER) fanns inte
  // fore; de som forblir okanda redovisas som NEW_UNKNOWN, de avgjorda som tackningsutfall.
  const O6 = M.overlayForra.forekomst;
  const NY_TACKNING = () => false;   // omgang 10: ingen ny tackning; signalforekomsterna fanns i omgang 9
  const efter6 = f => { const b = O6[f.DISCOVERY_OCCURRENCE_ID]; return b ? b.klass : f.klass; };
  const MANSKLIGA_SG = { has: sg => /^HD[34]-/.test(sg) };   // Block 287 slutbeslut: HD3/HD4 ar manskliga avgoranden
  const nu = forek.filter(f => !NY_TACKNING(f) && efter6(U.forekomster.find(x => x.DISCOVERY_OCCURRENCE_ID === f.DISCOVERY_OCCURRENCE_ID)) === 'UNKNOWN_SEMANTICS' && f.klass !== 'UNKNOWN_SEMANTICS');
  const sgAv = f => (O.forekomst[f.DISCOVERY_OCCURRENCE_ID] || {}).sg || '-';
  const perSg = {}; for (const f of nu) { const k = sgAv(f) + ' → ' + f.klass; perSg[k] = (perSg[k] || 0) + 1; }
  const kortForek = forek.filter(f => f.klass === 'UNKNOWN_SEMANTICS' && (O.forekomst[f.DISCOVERY_OCCURRENCE_ID] || {}).beslutskort);
  const nyTackning = forek.filter(NY_TACKNING);
  M.tackning = { NYA_FOREKOMSTER: nyTackning.length, perMekanism: nyTackning.reduce((m, f) => (m[f.mekanismer[0] + ' → ' + f.klass] = (m[f.mekanismer[0] + ' → ' + f.klass] || 0) + 1, m), {}),
    forekomster: nyTackning.map(f => f.art + ' · ' + f.mekanismer[0] + ' · ' + f.klass + ' · ' + String(f.text).slice(0, 30)) };
  M.upptacktUtfall = {
    UNKNOWN_BEFORE: U.forekomster.filter(f => !NY_TACKNING(f) && efter6(f) === 'UNKNOWN_SEMANTICS').length,
    SOURCE_RESOLVED: nu.filter(f => !MANSKLIGA_SG.has(sgAv(f))).length,
    HUMAN_DECISION_RESOLVED: nu.filter(f => MANSKLIGA_SG.has(sgAv(f))).length,
    HUMAN_DECISION_REQUIRED: kortForek.length, NEW_UNKNOWN: nyTackning.filter(f => f.klass === 'UNKNOWN_SEMANTICS').length,
    UNKNOWN_AFTER: perKlass.UNKNOWN_SEMANTICS || 0, perSubgrupp: perSg, perKlass,
    HISTORICAL_SCOPE_REPRODUCTION: U.HISTORISK_AVSTAMNING.aterfunna + '/' + U.HISTORISK_AVSTAMNING.historiska,
    CURRENT_EXTENDED_SCOPE_POPULATION: U.DISCOVERY_TOTAL, DETEKTOR_SCOPE: U.DETEKTOR_SCOPE, GRAFIK_SCOPE: U.GRAFIK_SCOPE,
    NEW_UNKNOWN_FROM_EXTENDED_SVG_SCOPE: forek.filter(f => svg(f) && f.klass === 'UNKNOWN_SEMANTICS').length };
  if (M.upptacktUtfall.UNKNOWN_BEFORE - M.upptacktUtfall.SOURCE_RESOLVED - M.upptacktUtfall.HUMAN_DECISION_RESOLVED + M.upptacktUtfall.NEW_UNKNOWN !== M.upptacktUtfall.UNKNOWN_AFTER)
    fail('UNKNOWN-bokforingen gar inte ihop');
  const olosta = new Map();
  for (const f of forek.filter(f => f.klass === 'KNOWN_CONTROL' && !f.PERSISTENT_SEMANTIC_OWNER_ID)) {
    const k = f.art + '::' + f.DISCOVERY_REVIEW_FAMILY_ID; olosta.set(k, (olosta.get(k) || []).concat(f)); }
  for (const [k, fs] of olosta) lagg({ id: 'RP::OWNER_IDENTITY_UNRESOLVED::' + k, OWNER_ID: null, IDENTITY_KIND: 'LEDGER', NON_PERSISTENT_HANDLES: fs.map(f => f.DISCOVERY_OCCURRENCE_ID),
    REQUIREMENT_ID: 'A11Y-01 (roll och namn)', REQUIREMENT_SOURCE: 'upptackt + registrerat verdikt', PROVENANCE: 'SOURCE_GROUNDED',
    CATEGORY: 'OWNER_IDENTITY_UNRESOLVED', CURRENT_STATUS: 'KNOWN_CONTROL_WITHOUT_STABLE_OWNER', OCCURRENCES: fs.length,
    CURRENT_EVIDENCE: fs.map(f => f.grund).join('; ') + '; ingen kallforfattad agargrund (id, occurrence, binding, text)' });
  // Kontrollagare: forekomster med agare + radagare (rutan eller pillret ar grafikbarn).
  const agarEnheter = new Map();
  for (const f of forek.filter(f => f.klass === 'KNOWN_CONTROL' && f.PERSISTENT_SEMANTIC_OWNER_ID))
    agarEnheter.set(f.PERSISTENT_SEMANTIC_OWNER_ID, { fil: f.fil, grund: f.grund, roll: f.FINAL_ROLE });
  for (const [a, v] of Object.entries(O.agare)) if (!agarEnheter.has(a)) agarEnheter.set(a, { fil: v.fil, grund: v.grund, roll: v.roll, radagare: true });
  // Omgang 8: fasetten heter efter kravet (roll och namn, A11Y-01), inte efter dagens tillstand
  // ("odeklarerad") — samma enhet ar kvar nar kontrollen deklareras.
  for (const [a, v] of agarEnheter) {
    lagg({ id: 'RP::ROLE_AND_NAME::' + a.replace(/^OWNER::/, ''), OWNER_ID: a, REQUIREMENT_ID: 'A11Y-01 (roll och namn)',
      REQUIREMENT_SOURCE: 'upptackt + kallgrund / mansligt beslut', PROVENANCE: 'SOURCE_GROUNDED',
      CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED', CURRENT_STATUS: 'UNDECLARED_KNOWN_CONTROL',
      OCCURRENCES: 1, FINAL_ROLE: v.roll || null, BLOCKERS: [], CURRENT_EVIDENCE: (v.radagare ? 'radagare (rutan eller pillret ar grafikbarn); ' : '') + v.grund,
      REMEDIATION_FACET: 'DECLARE_ROLE_AND_NAME', WRITE_OWNER: v.fil + '::' + a, WRITE_READY: false });
  }
  // Beslutskort (omgang 8): kallan uttommd, produktfragan ar kvar. Forekomsterna stannar i UNKNOWN.
  const perKort = new Map(); for (const f of kortForek) { const k = O.forekomst[f.DISCOVERY_OCCURRENCE_ID].beslutskort; perKort.set(k, (perKort.get(k) || []).concat(f)); }
  for (const [kort, fs] of perKort)
    lagg({ id: 'RP::SEMANTIC_DECISION::' + kort, OWNER_ID: null, NON_PERSISTENT_HANDLES: fs.map(f => f.DISCOVERY_OCCURRENCE_ID), REQUIREMENT_ID: 'BL-08 upptackt · beslutskort',
      REQUIREMENT_SOURCE: 'overlay8 (kallan uttommd)', PROVENANCE: 'SOURCE_GROUNDED', CATEGORY: 'HUMAN_DECISION_REQUIRED', CURRENT_STATUS: 'AWAITING_PRODUCT_DECISION',
      BLOCKERS: [kort], OCCURRENCES: fs.length, CURRENT_EVIDENCE: fs.map(f => f.art + ': ' + String(O.forekomst[f.DISCOVERY_OCCURRENCE_ID].grund).slice(-120)).join(' | ') + ' (samma forekomster ingar i UNKNOWN_SEMANTICS tills beslutet finns)' });
  // Klassreskontra: raknar forekomster per klass. Inte agaridentitet (IDENTITY_KIND LEDGER).
  for (const kl of ['KNOWN_NON_CONTROL', 'DECORATIVE_OR_STRUCTURAL', 'OUT_OF_SCOPE', 'DUPLICATE_OF_CANONICAL_OWNER', 'KNOWN_COMPONENT'])
    lagg({ id: 'RP::DISCOVERY::' + kl, OWNER_ID: null, IDENTITY_KIND: 'LEDGER', REQUIREMENT_ID: 'BL-08 upptackt', REQUIREMENT_SOURCE: 'tools/discovery-population.mjs',
      PROVENANCE: 'MEASURED', CATEGORY: 'NOT_REQUIRED', CURRENT_STATUS: kl, OCCURRENCES: perKlass[kl] || 0, CURRENT_EVIDENCE: (perKlass[kl] || 0) + ' forekomster' });
  lagg({ id: 'RP::DISCOVERY::UNKNOWN_SEMANTICS', OWNER_ID: null, IDENTITY_KIND: 'LEDGER', REQUIREMENT_ID: 'BL-08 upptackt', REQUIREMENT_SOURCE: 'tools/discovery-population.mjs (utokad med fristaende grafik)',
    PROVENANCE: 'MEASURED', ...((perKlass.UNKNOWN_SEMANTICS || 0) > 0 ? { CATEGORY: 'UNKNOWN_SEMANTICS', CURRENT_STATUS: 'ACTIVE_UNKNOWN_SEMANTICS', BLOCKING: true, BLOCKERS: ['UV-DISCOVERY'] }
      : { CATEGORY: 'NOT_REQUIRED', CURRENT_STATUS: 'NO_UNKNOWN_SEMANTICS', BLOCKING: false, BLOCKERS: [] }),   // Block 287 slut: varje forekomst har terminal klass
    OCCURRENCES: perKlass.UNKNOWN_SEMANTICS || 0, CURRENT_EVIDENCE: perKlass.UNKNOWN_SEMANTICS + ' forekomster (' + M.upptacktUtfall.NEW_UNKNOWN_FROM_EXTENDED_SVG_SCOPE + ' fran fristaende grafik)' });

  // ── Morka kanter (beslut B6, A7). Omgang 9: EN enhet per stabil semantisk agare av det
  //    inramade elementet — kantdelar av samma agare ar forekomster. Identiteten laser aldrig
  //    om rollen redan ar deklarerad, klass/verdikt, token, opacitet, PASS/FAIL eller status;
  //    tokenet foljer funktionen och ar status. Nyckeln:
  //      deklarerat namn ELLER rutans synliga etikett → samma agarnyckel som identitet8 (en
  //        odeklarerad kontroll som far sin roll och sitt namn behaller id:t)
  //      annars kallans strukturslag (statuspiller, kort, upplysning, raderingssteg, avdelare)
  //      annars OWNER_IDENTITY_UNRESOLVED — aldrig ett positionellt reservid.
  const K = M.kanter;
  if (K.length !== inv.kantpopulation_omgang9.TOTAL) fail('kantpopulationen har andrats: ' + K.length);
  const occAv = k => forek.find(x => x.art === k.art && x.DISCOVERY_OCCURRENCE_ID.endsWith('::' + k.art + '::' + k.ord));
  const kantAgare = k => {
    if (k.typ === 'avdelare') return { nyckel: k.art + '::slag::avdelare', slag: true };
    const f = occAv(k), r = f && O.rutor[f.DISCOVERY_OCCURRENCE_ID];
    const namn = k.namn || (r && r.etikett);
    if (namn) {
      if ((snap.deklareradeNamn[k.art + '|' + namn] || 0) > 1) return { olost: '"' + namn + '" deklareras av flera element i ramen' };
      const a = agarNyckel({ art: k.art, namn }); return a ? { nyckel: a.replace(/^OWNER::/, '') } : { olost: 'namnet ger ingen stabil nyckel' };
    }
    if (r && r.slag) return { nyckel: k.art + '::slag::' + r.slag, slag: true };
    return { olost: 'ingen stabil semantisk agare' };
  };
  const tokenFor = k => {
    if (k.typ === 'avdelare') return 'border.subtle';
    if (k.typ === 'kontroll') return 'border.control';
    const f = occAv(k) || fail('ruta utan forekomst ' + k.art + '#' + k.ord);
    if (f.klass === 'KNOWN_CONTROL' || f.klass === 'DUPLICATE_OF_CANONICAL_OWNER') return 'border.control';
    if (f.klass === 'KNOWN_NON_CONTROL') return 'border.subtle';
    return fail('ruta med oklar klass ' + f.klass + ' ' + k.art + '#' + k.ord);
  };
  const kantEnh = new Map(), kantOlosta = [];
  for (const k of K) {
    const a = kantAgare(k), token = tokenFor(k);
    if (a.olost) { kantOlosta.push({ k, skal: a.olost }); continue; }
    const e = kantEnh.get(a.nyckel) || { nyckel: a.nyckel, slag: !!a.slag, token, delar: [] };
    if (e.token !== token) fail('kantenhet med blandade token: ' + a.nyckel);
    e.delar.push(k); kantEnh.set(a.nyckel, e);
  }
  for (const e of [...kantEnh.values()].sort((x, y) => (x.nyckel < y.nyckel ? -1 : 1))) {
    const typer = [...new Set(e.delar.map(k => k.typ))].sort().join('+');
    lagg({ id: 'RP::DARK_BORDER::' + e.nyckel, OWNER_ID: (e.slag ? 'SLAG::' : 'OWNER::') + e.nyckel, REQUIREMENT_ID: 'R-04 kant · beslut B6/A7',
      REQUIREMENT_SOURCE: 'border-inventering (kandidat) · beslut B6, A7', PROVENANCE: 'HUMAN_APPROVED beslut B6/A7', CATEGORY: 'PRODUCT_REMEDIATION_REQUIRED',
      CURRENT_STATUS: 'DECIDED_NOT_WRITTEN', OCCURRENCES: e.delar.length, BORDER_TOKEN: e.token,
      REMEDIATION_FACET: e.token === 'border.control' ? 'BIND_BORDER_CONTROL' : 'BIND_BORDER_SUBTLE', WRITE_OWNER: 'BORDER::' + e.nyckel, WRITE_READY: false,
      CURRENT_EVIDENCE: e.delar.length + ' kantdel(ar) [' + typer + '] → ' + e.token + (e.token === 'border.control' ? ' @0,6' : '') + '; ' + e.delar.map(k => k.art + '#' + k.ord).join(', ') });
  }
  const perOlost = new Map(); for (const o of kantOlosta) perOlost.set(o.k.art + '::' + o.skal, (perOlost.get(o.k.art + '::' + o.skal) || []).concat(o.k));
  for (const [k, ks] of perOlost) lagg({ id: 'RP::OWNER_IDENTITY_UNRESOLVED::kant::' + slug(k), OWNER_ID: null, IDENTITY_KIND: 'LEDGER', NON_PERSISTENT_HANDLES: ks.map(x => x.art + '#' + x.ord),
    REQUIREMENT_ID: 'R-04 kant', REQUIREMENT_SOURCE: 'border-inventering', PROVENANCE: 'SOURCE_GROUNDED', CATEGORY: 'OWNER_IDENTITY_UNRESOLVED',
    CURRENT_STATUS: 'BORDER_WITHOUT_STABLE_OWNER', OCCURRENCES: ks.length, CURRENT_EVIDENCE: k });
  if ([...kantEnh.values()].reduce((s, e) => s + e.delar.length, 0) + kantOlosta.length !== K.length) fail('kantdelar tappades i agargrupperingen');
  M.kantagare = { KANTER: K.length, ENHETER: kantEnh.size, OLOSTA: kantOlosta.length,
    perSlag: [...kantEnh.values()].reduce((m, e) => { const t = e.slag ? 'strukturslag' : 'agare'; m[t] = (m[t] || 0) + 1; return m; }, {}) };
  // Inramade rutor (beslut A7) — tabell for rapporten: samma kantenheter, bara rutdelarna.
  const rutor = K.filter(k => k.typ === 'ruta');
  const ramTabell = [...kantEnh.values()].filter(e => e.delar.some(k => k.typ === 'ruta')).map(e => {
    const rd = e.delar.filter(k => k.typ === 'ruta'), f = occAv(rd[0]);
    return { UNIT_ID: 'RP::DARK_BORDER::' + e.nyckel, OCCURRENCE_COUNT: rd.length, OVRIGA_KANTDELAR: e.delar.length - rd.length, SEMANTIC_CLASS: f.klass,
      OWNER_COUNT: e.slag ? 0 : 1, FINAL_ROLE: f.FINAL_ROLE || null, BORDER_TOKEN: e.token, forekomster: rd.map(k => k.art + '#' + k.ord + ' ' + k.varde) }; });
  if (ramTabell.reduce((s, e) => s + e.OCCURRENCE_COUNT, 0) + kantOlosta.filter(o => o.k.typ === 'ruta').length !== rutor.length) fail('inramade rutor tappades i grupperingen');
  M.ramadeRutor = { FRAMED_OCCURRENCE_COUNT: rutor.length, FRAMED_SEMANTIC_UNIT_COUNT: ramTabell.length, enheter: ramTabell };
  lagg({ id: 'RP::TOKEN::border.control::dark', OWNER_ID: 'border.control', REQUIREMENT_ID: 'beslut B6', REQUIREMENT_SOURCE: 'tokens.json', PROVENANCE: 'HUMAN_APPROVED beslut B6',
    CATEGORY: 'SPEC_SYNC_REQUIRED', CURRENT_STATUS: 'SPEC_LAGS', CURRENT_EVIDENCE: 'border.control dark rgba(245,244,237,0.35) → 0,6 (befintligt steg); 0,4 upphor' });

  // ── Metodverktyg som maste in i repot innan populationen kan frysas
  lagg({ id: 'RP::METHOD_TOOL::render-probe-authored-dark', OWNER_ID: 'tools/render-probe.mjs', REQUIREMENT_ID: 'R-04 mork matning',
    REQUIREMENT_SOURCE: 'metodpaket/tools/render-probe.mjs + render-probe-dark-fixtures.mjs', PROVENANCE: 'MEASURED', CATEGORY: 'METHOD_TOOLING_REQUIRED',
    CURRENT_STATUS: 'PATCH_READY_NOT_WRITTEN', CURRENT_EVIDENCE: 'patchad version = verifierad drivrutin (12/12 fall, 65 artefakter, 24 textfynd); regressionsprov 5/5, dagens verktyg 0/5' });
  lagg({ id: 'RP::METHOD_TOOL::discovery-harvest-package', OWNER_ID: 'tools/discovery-*.mjs', REQUIREMENT_ID: 'BL-08 upptackt',
    REQUIREMENT_SOURCE: 'metodpaket/tools/discovery-harvest.mjs, discovery-identity.mjs, discovery-population.mjs, discovery-identity-fixtures.mjs',
    PROVENANCE: 'MEASURED', CATEGORY: 'METHOD_TOOLING_REQUIRED', CURRENT_STATUS: 'PACKAGE_READY_NOT_WRITTEN',
    CURRENT_EVIDENCE: 'historisk reproduktion ' + U.HISTORISK_AVSTAMNING.aterfunna + '/' + U.HISTORISK_AVSTAMNING.historiska + '; filordningsinvariant; identitetsprov 10/10' });
  // Omgang 8 → 9: identitetspatchen ar committad (373ab37). Samma enhet, nu uppfylld — en
  // remediering andrar status, aldrig identitet.
  lagg({ id: 'RP::METHOD_TOOL::discovery-owner-identity', OWNER_ID: 'tools/discovery-identity.mjs', REQUIREMENT_ID: 'Block 287 omgang 8 · E/H',
    REQUIREMENT_SOURCE: 'commit 373ab378bd5d402700af0b348c18dc1aa6b2659a (discovery-identity, discovery-harvest, discovery-identity-fixtures)',
    PROVENANCE: 'MEASURED', CATEGORY: 'ALREADY_SATISFIED', CURRENT_STATUS: 'COMMITTED',
    CURRENT_EVIDENCE: 'D01–D16 16/16 fran ren utcheckning av 373ab37; upptackten byteidentisk med den provade kopian' });
  // Omgang 9: tackning av funktionssignal utan kontrollform (data-hit-target, <a>, binding,
  // handoffens stepper). Forberedd och provad, INTE committad (STOP fore commit).
  lagg({ id: 'RP::METHOD_TOOL::discovery-functional-signal-coverage', OWNER_ID: 'tools/discovery-population.mjs', REQUIREMENT_ID: 'Block 287 omgang 9 · I–L',
    REQUIREMENT_SOURCE: 'commit e6e2f0648f50679ef4297f983a702c9ce313bd6e (discovery-population, discovery-coverage-fixtures)',
    PROVENANCE: 'MEASURED', CATEGORY: 'ALREADY_SATISFIED', CURRENT_STATUS: 'COMMITTED',
    CURRENT_EVIDENCE: 'STEP-01…08 + SIG-01…03 11/11 fran ren utcheckning; +' + (U.SIGNAL_SCOPE || 0) + ' forekomster (detektor ' + U.DETEKTOR_SCOPE + ', grafik ' + U.GRAFIK_SCOPE + '); historisk 2684/2684 oforandrad' });

  // ── Omgang 10 · portionsvaljaren (handoffen ar normativ). Behallarens spinbutton ar en
  //    agarenhet (ROLE_AND_NAME ::namn::portioner, via overlay-agarna). Har: knapparnas namn
  //    for DEKLARERADE knappar — odeklarerade finns redan som ROLE_AND_NAME och raknas inte igen.
  const PN = inv.portionsvaljare_normativ;
  M.portion = [];
  for (const p of O.portion || []) {
    for (const k of p.knappar) {
      const kravnamn = k.del === 'decrement' ? PN.PORTION_DECREMENT_NAME : PN.PORTION_INCREMENT_NAME;
      const agareP = 'OWNER::' + p.ram + '::handling::' + k.del + '-portioner';
      const rad = { ram: p.ram, del: k.del, CURRENT_ROLE: k.deklarerad ? k.roll : 'odeklarerad', REQUIRED_ROLE: 'button', CURRENT_NAME: k.namn, REQUIRED_NAME: kravnamn,
        CURRENT_DISCOVERY_STATUS: k.deklarerad ? 'DECLARED (utanfor upptackten)' : 'KNOWN_CONTROL (upptackt)', OWNER: agareP };
      if (!k.deklarerad) { rad.REMEDIATION_STATUS = 'PRODUCT_REMEDIATION_REQUIRED via RP::ROLE_AND_NAME::' + agareP.replace(/^OWNER::/, ''); M.portion.push(rad); continue; }
      const ok = k.namn === kravnamn && k.roll === 'button';
      rad.REMEDIATION_STATUS = ok ? 'ALREADY_SATISFIED' : 'PRODUCT_REMEDIATION_REQUIRED';
      M.portion.push(rad);
      lagg({ id: 'RP::A11Y_NAME::' + agareP.replace(/^OWNER::/, ''), OWNER_ID: agareP, REQUIREMENT_ID: 'A11Y-NAME (handoff Portionsväljare)', REQUIREMENT_SOURCE: PN.kalla,
        PROVENANCE: 'SOURCE_GROUNDED', CATEGORY: ok ? 'ALREADY_SATISFIED' : 'PRODUCT_REMEDIATION_REQUIRED', CURRENT_STATUS: ok ? 'SATISFIED' : 'NAME_DIVERGES_FROM_HANDOFF',
        FINAL_ROLE: 'button', CURRENT_EVIDENCE: 'deklarerat "' + k.namn + '" (' + k.roll + '), kravet "' + kravnamn + '"', REMEDIATION_FACET: ok ? null : 'SET_ACCESSIBLE_NAME',
        WRITE_OWNER: p.ram + '::' + agareP, WRITE_READY: false });
    }
    M.portion.push({ ram: p.ram, del: 'selector', CURRENT_ROLE: p.spinbutton ? 'spinbutton' : 'ingen', REQUIRED_ROLE: 'spinbutton', CURRENT_NAME: null, REQUIRED_NAME: 'Portioner',
      CURRENT_DISCOVERY_STATUS: 'agare OWNER::' + p.ram + '::namn::portioner', OWNER: 'OWNER::' + p.ram + '::namn::portioner',
      REMEDIATION_STATUS: p.spinbutton ? 'ALREADY_SATISFIED' : 'PRODUCT_REMEDIATION_REQUIRED via RP::ROLE_AND_NAME::' + p.ram + '::namn::portioner' });
    M.portion.push({ ram: p.ram, del: 'value', CURRENT_ROLE: 'text', REQUIRED_ROLE: 'del av spinbutton (aria-valuenow, min, max)', REMEDIATION_STATUS: 'ingar i selector-enheten', OWNER: 'OWNER::' + p.ram + '::namn::portioner' });
  }
  if ((O.portion || []).length && !UTVID.has('spinbutton') && !URSPR.has('spinbutton'))
    lagg({ id: 'RP::ROLE_VOCABULARY::spinbutton', OWNER_ID: 'spinbutton', REQUIREMENT_ID: 'ROLE_VOCABULARY_POLICY', REQUIREMENT_SOURCE: PN.kalla + ' (normativ)',
      PROVENANCE: 'SOURCE_GROUNDED', CATEGORY: 'SPEC_SYNC_REQUIRED', CURRENT_STATUS: 'SPEC_AND_LINT_LAG', SYNC_FACETS: ['SPEC_SYNC', 'LINT_SYNC'],
      CURRENT_EVIDENCE: 'handoffen kraver spinbutton for Portionsväljare och Stepper (mängd); rollen saknas i den slutna listan i spec och T-08' });
  M.identitetslas = inv.identitetslas;

  // ── Identitet
  // ── Omgang 12 · agarsteget: varje kontrollagare harleds ur kallans ankare med den kanoniska metoden
  //    (tools/semantic-owner-identity.mjs i roten). Olost/delning/sammanslagning = fail closed.
  const O2 = M.omnyckling || klassa.OMNYCKLING;   // prov satter klassa.OMNYCKLING (moduler kan inte klonas)
  if (O2) {
    const R2 = omnyckla({ enheter, fakta: O2.fakta, metod: O2.metod, gammalAgare: agarNyckel, discovery: null });
    if (R2.rader.some(r => r.fel)) fail('agarsteget: ' + JSON.stringify(R2.rader.filter(r => r.fel).map(r => [r.gammal, r.fel, r.skal]).slice(0, 5)));
    enheter.splice(0, enheter.length, ...R2.enheter); O2.rader = R2.rader;
    const pmap = new Map(R2.rader.filter(r => r.persistentFore).map(r => [r.persistentFore, r.nyAgare]));
    for (const a of M.block284Alias) if (pmap.has(a.PERSISTENT_OWNER_ID)) a.PERSISTENT_OWNER_ID = pmap.get(a.PERSISTENT_OWNER_ID); }
  enheter.sort(byId);
  for (let i = 1; i < enheter.length; i++) if (enheter[i].id === enheter[i - 1].id) fail('identitetskollision: ' + enheter[i].id);

  // ── Lint: varje fynd far en kategori eller en forklarande enhet
  const lintKlass = {}, oforklarade = [];
  const rollKopp = {};
  for (const r of snap.roller) if (!URSPR.has(r.current)) {
    const k = r.fil + '|' + r.current; rollKopp[k] = rollKopp[k] || { sync: 0, produkt: 0 };
    rollKopp[k][r.current === r.final ? 'sync' : 'produkt']++;
  }
  const rollLint = {};
  for (const l of snap.lint) {
    const f = fold(l);
    const regel = inv.lintregler.find(r => f.startsWith('\u2716 ' + r.REGEL + ' ') && new RegExp(fold(r.MONSTER)).test(f));
    if (!regel) { oforklarade.push(l); continue; }
    if (regel.KATEGORI === 'ROLLKOPPLAD') {
      const m = /^\u2716 T-08\s+(.+?\.dc\.html): ogiltig roll "([^"]+)"/.exec(l) || fail('rollrad utan fil: ' + l);
      rollLint[m[1] + '|' + m[2]] = (rollLint[m[1] + '|' + m[2]] || 0) + 1;
      continue;
    }
    const k = regel.REGEL + ' · ' + regel.KATEGORI;
    lintKlass[k] = (lintKlass[k] || 0) + (regel.REGEL === 'A11Y-02' ? Number((/(\d+) kontroller/.exec(f) || [])[1]) : 1);
  }
  let rollSync = 0, rollProdukt = 0;
  for (const [k, n] of Object.entries(rollLint)) {
    const kk = rollKopp[k] || fail('lintens rollrad saknar forekomst i korpusen: ' + k);
    if (kk.sync + kk.produkt !== n) fail('rollkoppling stammer inte for ' + k);
    rollSync += kk.sync; rollProdukt += kk.produkt;
  }
  if (Object.keys(rollKopp).some(k => !(k in rollLint))) fail('korpusroll utan lintrad');
  lintKlass['T-08 · roll · LINT_SYNC_REQUIRED (BL-03)'] = rollSync;
  lintKlass['T-08 · roll · forklarad av PRODUCT RP::ROLE'] = rollProdukt;
  lintKlass['LC · PRODUCT_REMEDIATION_REQUIRED (RP::GEOMETRY)'] = snap.lc.deviations;
  // Regelandringar i lint och spec — en enhet per regel, fynden ar forekomster.
  const regelEnhet = (kat, id, n, ev) => lagg({ id: (kat === 'LINT_SYNC_REQUIRED' ? 'RP::LINT_RULE::' : 'RP::SPEC_RULE::') + id,
    OWNER_ID: id, REQUIREMENT_ID: id.split('::')[0], REQUIREMENT_SOURCE: 'SRC-LINT', PROVENANCE: 'SOURCE_GROUNDED',
    CATEGORY: kat, CURRENT_STATUS: 'TOOL_OR_SPEC_LAGS', OCCURRENCES: n, CURRENT_EVIDENCE: ev });
  regelEnhet('LINT_SYNC_REQUIRED', 'T-08::data-hit-self-target', lintKlass['T-08 · LINT_SYNC_REQUIRED'],
    'self och target: ar giltiga former i hit-contract sedan 02f10b4; renderad R-02 utan fel');
  regelEnhet('LINT_SYNC_REQUIRED', 'T-08::rollvokabular', rollSync, 'BL-03: link, menuitem, searchbox, combobox ar slutroller');
  regelEnhet('LINT_SYNC_REQUIRED', 'T-02::datascale-tokens', lintKlass['T-02 · LINT_SYNC_REQUIRED'], 'dataScale-tokens finns i tokens.json');
  regelEnhet('SPEC_SYNC_REQUIRED', 'T-11::genererade-raknare', lintKlass['T-11 · SPEC_SYNC_REQUIRED'], 'genererade raknare inaktuella (gen-counts)');
  regelEnhet('SPEC_SYNC_REQUIRED', 'T-14::evidensgrammatik', lintKlass['T-14 · SPEC_SYNC_REQUIRED'], 'implementerad/verifierad utan bevis i evidensmatrisen');
  regelEnhet('SPEC_SYNC_REQUIRED', 'T-21::artefaktklassning', lintKlass['T-21 · SPEC_SYNC_REQUIRED'], 'artefaktregistrets status');
  enheter.sort(byId);
  for (let i = 1; i < enheter.length; i++) if (enheter[i].id === enheter[i - 1].id) fail('identitetskollision: ' + enheter[i].id);

  // LC-SUMMARY bar sedan baslinjerattningen bade lintens egna fynd och de
  // avatarer som bara syns i matfilen. Geometrilistan ar lintens egna, sa den
  // ska stammas av mot just dem.
  const lcLint = snap.lc.lint_deviations !== undefined ? snap.lc.lint_deviations : snap.lc.deviations;
  if (snap.geo.length !== lcLint) fail('geometrilistan ' + snap.geo.length + ' != lintens egna fynd ' + lcLint);
  if (snap.a11y02.length !== lintKlass['A11Y-02 · FUTURE_PHASE_3_IMPLEMENTATION_CONTRACT']) fail('A11Y-02-uppraknaren stammer inte med lint');
  if (lintKlass['T-02 · SPEC_SYNC_REQUIRED'] !== Object.keys(inv.bl07_unik).filter(k => !k.startsWith('$')).length) fail('T-02-paren stammer inte med BL-07');

  /* ── aggregat ── */
  const rakna = (xs, f) => xs.reduce((o, x) => (o[f(x)] = (o[f(x)] || 0) + 1, o), {});
  const perKategori = Object.fromEntries(KATEGORIER.map(k => [k, enheter.filter(e => e.CATEGORY === k).length]));
  const produkt = enheter.filter(e => e.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED');
  // ── Omgang 8 · identitetsskanning. En persistent identitet far inte bara klass, verdikt, status
  //    eller ett levande tal. Reskontrarader (IDENTITY_KIND LEDGER) ar ingen agaridentitet.
  const ramar = new Set(snap.ramar || fail('ogonblicksbilden saknar ramlistan'));
  const FORBJUDNA = /^(control|non[_-]?control|known[_-]?control|known[_-]?non[_-]?control|known[_-]?component|icke[_-]?kontroll|unknown(_semantics)?|duplicate(_of_canonical_owner)?|decorative(_or_structural)?|out[_-]of[_-]scope|satisfied|unsatisfied|remediation|pass|fail|blocked|historical|decided|verdikt|dubblett|okand|a-ruta-[a-z-]+)$/i;
  const FORBJUDNA_DELORD = /(^|[-_])(known[-_]control|known[-_]non[-_]control|icke[-_]kontroll|non[-_]control|a-ruta)([-_]|$)/i;
  const KRAVKOD = /^([A-Z][A-Z0-9_]*(-\d+)?|[A-Z]{1,4}-\d+|RV28\d|BL\d+|\d{2})$/;
  const SPECKONSTANT = new Set(['TRANSITION']);
  const VITLISTA = [{ facett: 'DARK_BORDER', index: 0, segment: 'control', skal: 'kantgrupp for element som i kallan deklarerar en kontrollroll (data-a11y-role) — kallfakta, inte verdikt; se kvarvarande risk R8-KANTGRUPP' }];
  // varde::<n> ar betygsvardet inom en ankrad betygsgrupp (handoff H26: tillaten slot 1–5), inte ett flyktigt tal
  const ankareFore = /^(occ|hit-target|id|bind|varde)$/;
  const tillatnaTal = new Set([...M.identitetsundantag.map(u => u.segment), ...(O.undantag || []).map(u => u.id.split('::').pop())]);
  const skanning = [];
  for (const e of enheter) {
    if (e.IDENTITY_KIND === 'LEDGER') continue;
    const seg = e.id.split('::'), facett = seg[1], rest = seg.slice(2);
    rest.forEach((s, i) => {
      if (VITLISTA.some(v => v.facett === facett && v.index === i && v.segment === s)) return;
      if (FORBJUDNA.test(s) || FORBJUDNA_DELORD.test(s)) skanning.push({ id: e.id, segment: s, fel: 'VERDICT_OR_STATUS_IN_IDENTITY' });
      if (!/\d/.test(s) || ramar.has(s) || KRAVKOD.test(s) || SPECKONSTANT.has(facett) || tillatnaTal.has(s)) return;
      if (i > 0 && ankareFore.test(rest[i - 1])) return;                       // kallforfattat ankare (occ, hit-target ...)
      if ([...ramar].some(r => s.startsWith(r + '-') && !/\d/.test(s.slice(r.length)))) return;   // ramprefixat namn
      skanning.push({ id: e.id, segment: s, fel: 'VOLATILE_NUMBER_IN_IDENTITY' });
    });
  }
  M.identitetsskanning = { VIOLATIONS: skanning, UNDANTAG_OPTION_VALUE: [...tillatnaTal].sort(), VITLISTA,
    LEDGER_RADER: enheter.filter(e => e.IDENTITY_KIND === 'LEDGER').length };
  if (skanning.length) fail('identitetsskanningen hittade ' + skanning.length + ': ' + JSON.stringify(skanning.slice(0, 6)));
  const idAntal = rakna(enheter, e => e.id);
  const grind = {
    HUMAN_DECISION_REQUIRED: inv.blockerare.filter(b => b.TYP === 'HUMAN_DECISION_REQUIRED').length,
    UNVERIFIABLE_BLOCKING: inv.blockerare.filter(b => b.TYP === 'UNVERIFIABLE_BLOCKING').length,
    IDENTITY_COLLISIONS: Object.values(idAntal).filter(n => n > 1).length,
    IDENTITY_SCAN_VIOLATIONS: skanning.length,
    UNEXPLAINED_OCCURRENCES: oforklarade.length,
    PRODUKTENHETER_UTAN_AGARE: produkt.filter(e => !e.OWNER_ID || !e.WRITE_OWNER).length,
    PRODUKTENHETER_UTAN_EVIDENS: produkt.filter(e => !e.CURRENT_EVIDENCE && e.CURRENT_STATUS !== 'UNSATISFIED').length,
    OANVANDA_BLOCKERARE: [...blockerIds].filter(b => !enheter.some(e => (e.BLOCKERS || []).includes(b)))
  };
  if (grind.OANVANDA_BLOCKERARE.length) fail('blockerare utan enhet: ' + grind.OANVANDA_BLOCKERARE.join(','));
  grind.FREEZE_READY = grind.HUMAN_DECISION_REQUIRED === 0 && grind.UNVERIFIABLE_BLOCKING === 0 && grind.UNEXPLAINED_OCCURRENCES === 0;

  const fingeravtryck = {
    IDENTITY_POPULATION: h(enheter.map(e => e.id)),
    PERSISTENT_IDENTITY: h(enheter.filter(e => e.IDENTITY_KIND !== 'LEDGER').map(e => e.id)),
    CLASSIFICATION_STATUS: h(enheter.map(e => [e.id, e.CATEGORY, e.CURRENT_STATUS, (e.BLOCKERS || []).join(',')])),
    OCCURRENCES: h(enheter.map(e => [e.id, e.OCCURRENCES || 1]))
  };
  const perFasett = rakna(enheter, e => e.id.split('::')[1]);
  const produktPerFasett = rakna(produkt, e => e.id.split('::')[1]);
  const produktForekomster = produkt.reduce((s, e) => s + (e.OCCURRENCES || 1), 0);
  return { IDENTITETSLAS: M.identitetslas, PORTION: M.portion, KANTAGARE: M.kantagare, BLOCK284_ALIAS: M.block284Alias, TACKNING: M.tackning, IDENTITETSSKANNING: M.identitetsskanning, RAMADE_RUTOR: M.ramadeRutor, UPPTACKT: M.upptacktUtfall, R04: M.r04avstamning, enheter, perKategori, perFasett, produktPerFasett, produktForekomster, grind, lintKlass, oforklarade, fingeravtryck,
    blockerare: inv.blockerare.map(b => ({ ...b, ENHETER: enheter.filter(e => (e.BLOCKERS || []).includes(b.BLOCKER_ID)).map(e => e.id) })) };
}

/* ═══ Q · identitetsbestandighet mot forsta omgangen ═══════════════════════ */

export function identitetskontroll(gamla, nya) {
  const ny = new Map(nya.map(e => [e.id, e]));
  const kvar = gamla.filter(e => ny.has(e.id));
  const borta = gamla.filter(e => !ny.has(e.id)).map(e => e.id);
  const bytt = kvar.filter(e => ny.get(e.id).CATEGORY !== e.CATEGORY)
    .map(e => ({ id: e.id, fore: e.CATEGORY, efter: ny.get(e.id).CATEGORY }));
  return { GAMLA: gamla.length, BEVARADE: kvar.length, BORTFALLNA: borta, STATUSBYTEN: bytt.length,
    STATUSBYTEN_PER_OVERGANG: bytt.reduce((o, b) => (o[b.fore + ' → ' + b.efter] = (o[b.fore + ' → ' + b.efter] || 0) + 1, o), {}),
    GAMLA_38_KVAR_SOM_PRODUKT: gamla.filter(e => e.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED' && ny.get(e.id)?.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED').length,
    GAMLA_38_BORTFALLNA_PGA_PFA: gamla.filter(e => e.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED' && ny.get(e.id)?.CATEGORY !== 'PRODUCT_REMEDIATION_REQUIRED').map(e => e.id) };
}

export function laddaMatfiler(INV) {
  // Radetikett for de "Reglage" som saknar etikett pa samma kallrad: narmast foregaende
  // textnod inom tre rader i kandidatens kalla (radens synliga etikett = handoffens namnkalla).
  const REGLAGE_ETIKETT = {};
  for (const r of las(INV.matfiler.reglage)) {
    if (r.etikett) continue;
    const rader = readFileSync(join(ROOT, 'Butlery Skarmar v12 ' + r.fil + '.dc.html'), 'utf8').split('\n');
    for (let i = r.rad - 2; i >= r.rad - 4 && !REGLAGE_ETIKETT[r.ram + '|' + r.rad]; i--) {
      const t = [...rader[i].matchAll(/>([^<>]{2,})</g)].map(m => m[1].trim()).filter(Boolean);
      if (t.length) REGLAGE_ETIKETT[r.ram + '|' + r.rad] = t[0];
    }
  }
  return { downstream: las(INV.matfiler.downstream), r03: las(INV.matfiler.r03), bl14: las(INV.matfiler.bl14),
    r04p1: las(INV.matfiler.r04_partition), r04p2: las(INV.matfiler.r04_partition_repro), kontrast: las(INV.matfiler.kontrast),
    morktext: las(INV.matfiler.morktext), morktext2: las(INV.matfiler.morktext_repro), upptackt: JSON.parse(readFileSync(process.env.UPPTACKT_A, 'utf8')), upptackt2: JSON.parse(readFileSync(process.env.UPPTACKT_B, 'utf8')), overlay: JSON.parse(readFileSync(process.env.OVERLAY || join(S, INV.matfiler.overlay), 'utf8')), overlayForra: las(INV.matfiler.overlayForra), kanter: las(INV.matfiler.kanter), paket1: las(INV.matfiler.paket1), paket1Occ: Object.fromEntries(las('paket1-kontext.json').filter(x => x.occ).map(x => [x.occId, x.occ])),
    reglage: las(INV.matfiler.reglage), avatar: las(INV.matfiler.avatar), reglageEtikett: REGLAGE_ETIKETT };
}

/* ═══ HUVUDFLODE ══════════════════════════════════════════════════════════ */

const isMain = !!process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url));
if (isMain) {
  const snap = arg('snapshot-in') ? JSON.parse(readFileSync(arg('snapshot-in'), 'utf8')) : harled();
  if (arg('snapshot-ut')) writeFileSync(arg('snapshot-ut'), JSON.stringify(snap, null, 1) + '\n');
  const M = laddaMatfiler(INV);
  { const metod = await import(pathToFileURL(ROOT + '/tools/semantic-owner-identity.mjs').href);
    const skord = arg('skord') ? JSON.parse(readFileSync(arg('skord'), 'utf8')) : await (await import(pathToFileURL(ROOT + '/tools/discovery-harvest.mjs').href)).skorda(ROOT);
    const etikett = {}; for (const f of readdirSync(ROOT).filter(f => /^Butlery Skarmar.*.dc.html$/.test(f))) for (const m of readFileSync(join(ROOT, f), 'utf8').matchAll(/class="sc-item" id="([^"]+)"[^>]*data-screen-label="([^"]*)"/g)) etikett[m[1]] = m[2];
    M.omnyckling = { metod, fakta: kontrollFakta({ skord, overlay: M.overlay, etikett }).fakta }; }
  const R = klassa(snap, INV, M);
  if (arg('detalj') === 'enheter') { console.log(JSON.stringify(R.enheter, null, 1)); process.exit(0); }
  const Q = arg('gammal') ? identitetskontroll(JSON.parse(readFileSync(arg('gammal'), 'utf8')), R.enheter) : null;
  const { enheter, ...rest } = R;
  console.log(JSON.stringify({ BLOCK: '287-omgang-12', AGARSTEG: M.omnyckling ? { BEROERDA: M.omnyckling.rader.length, NYA_ID: M.omnyckling.rader.filter(r => r.ny && r.ny !== r.gammal).length, rader: M.omnyckling.rader.map(r => ({ FROM: r.gammal, TO: r.ny, REGEL: r.regel, MONSTER: r.monster, ANKARE: r.ankare })) } : null, ROT: ROOT, BASLINJE: snap.baslinje, ENHETER: enheter.length, ...rest, Q,
    PRODUKTENHETER: enheter.filter(e => e.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED').map(e => e.id) }, null, 1));
}
