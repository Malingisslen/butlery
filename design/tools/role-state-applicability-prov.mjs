#!/usr/bin/env node
// Block 285 — mutationsprov RS285-01…RS285-12.
//
// Varje prov muterar en KOPIA av den kanoniska kallan och kraver att byggaren
// beter sig ratt. Ett prov som passerar for att bygget rakar ga igenom ar inget
// prov: darfor provas bade det som ska overleva och det som ska falla stangt.
//
// Kor: node tools/role-state-applicability-prov.mjs --root=. --out=<katalog utanfor repot>

import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const REPO = resolve(arg('root') || '.');
const BYGG = arg('bygg') || join(REPO, 'tools/role-state-applicability.mjs');
const KALLA = arg('kalla') || join(REPO, 'fas2/role-state-applicability.json');
const UT = resolve(arg('out') || '');
if (!arg('out')) { console.error('\u2716 ange --out=<katalog utanfor reporoten>'); process.exit(2); }
if (UT.startsWith(REPO + '\\') || UT.startsWith(REPO + '/')) {
  console.error('\u2716 --out maste ligga utanfor reporoten'); process.exit(2);
}
rmSync(UT, { recursive: true, force: true });
mkdirSync(UT, { recursive: true });

const KOD = JSON.parse(readFileSync(KALLA, 'utf8'));

// Nyckelordning ar inte data — jamfor aggregat ordningsokansligt.
const bas = () => {
  const k = JSON.parse(JSON.stringify(KOD));
  // Bara en forvantan som overlever varje mutation: antalet rader.
  k.forvantat = { ROLE_STATE_ROWS: 24 };
  return k;
};
const rad = (k, id) => k.rollstate.find(r => r.ROW_ID === id);

let n = 0;
const kor = (k, namn) => {
  const fil = join(UT, namn + '.json');
  writeFileSync(fil, JSON.stringify(k, null, 1));
  try {
    const ut = execFileSync(process.execPath, [BYGG, '--root=' + REPO, '--kalla=' + fil],
      { encoding: 'utf8', maxBuffer: 1 << 26, stdio: ['ignore', 'pipe', 'pipe'] });
    return { ok: true, d: JSON.parse(ut) };
  } catch (e) {
    // Meddelandet, inte kodraden ur stacksparet: Node ekar sjalva throw-raden
    // forst, och den innehaller ocksa strangen FAIL CLOSED.
    const rader = String(e.stderr || e.message).split('\n');
    const msg = rader.find(l => /^\s*(Error: )?FAIL CLOSED:/.test(l))
      || rader.find(l => l.includes('FAIL CLOSED:') && !l.includes('throw new Error'));
    return { ok: false, fel: (msg || 'okant fel').replace(/^\s*Error:\s*/, '').trim() };
  }
};

const resultat = [];
const prov = (id, text, fn) => {
  n++;
  try {
    const detalj = fn();
    resultat.push([id, true, text, detalj]);
    console.log('\u2714 ' + id + '  ' + text);
    if (detalj) console.log('     ' + detalj);
  } catch (e) {
    resultat.push([id, false, text, e.message]);
    console.log('\u2716 ' + id + '  ' + text);
    console.log('     ' + e.message);
  }
};
const kravs = (villkor, vad) => { if (!villkor) throw new Error(vad); };

/* referenskorning — allt mats mot den */
const REF = kor(bas(), 'referens');
if (!REF.ok) { console.error('referenskorningen gick inte: ' + REF.fel); process.exit(1); }
const IDFP = REF.d.IDENTITY_FINGERPRINT, STFP = REF.d.STATUS_FINGERPRINT;

/* ── RS285-01 · omkastad kallordning ──────────────────────────────────── */
prov('RS285-01', 'omkastad kallordning ger samma radidentiteter', () => {
  const k = bas();
  k.rollstate.reverse();
  const r = kor(k, 'rs01');
  kravs(r.ok, 'bygget foll: ' + r.fel);
  kravs(r.d.IDENTITY_FINGERPRINT === IDFP,
    'identiteten andrades: ' + r.d.IDENTITY_FINGERPRINT + ' != ' + IDFP);
  return 'identitet ' + IDFP;
});

/* ── RS285-02 · omkastad rollordning ──────────────────────────────────── */
prov('RS285-02', 'omkastad rollordning ger samma radidentiteter', () => {
  const k = bas();
  const roller = ['link', 'menuitem', 'searchbox', 'combobox'].reverse();
  k.rollstate = roller.flatMap(roll => k.rollstate.filter(r => r.ROLE === roll));
  kravs(k.rollstate.length === 24, 'omgrupperingen tappade rader');
  const r = kor(k, 'rs02');
  kravs(r.ok, 'bygget foll: ' + r.fel);
  kravs(r.d.IDENTITY_FINGERPRINT === IDFP, 'identiteten andrades');
  return 'identitet ' + IDFP;
});

/* ── RS285-03 · en andrad applicability ───────────────────────────────── */
prov('RS285-03', 'andrad applicability pa exakt en rad flyttar exakt en rad', () => {
  // Maltavlan ar en beslutsrad, inte en last kallbelagd rad: lasningen ar en
  // egen invariant och provas av RS285-16.
  const k = bas();
  const x = rad(k, 'CSR::ROLE::combobox::EXPANDED');
  x.PROPOSED_STATUS = 'UNSPECIFIED';
  x.PROVENANCE = 'UNSPECIFIED_FROM_SOURCE_SILENCE';
  delete x.HUMAN_DECISION_ID;
  const r = kor(k, 'rs03');
  kravs(r.ok, 'bygget foll: ' + r.fel);
  kravs(r.d.IDENTITY_FINGERPRINT === IDFP, 'identiteten andrades vid en ren statusandring');
  kravs(r.d.STATUS_FINGERPRINT !== STFP, 'statusavtrycket stod stilla trots andrad status');
  kravs(r.d.FORDELNING.REQUIRED === 4 && r.d.FORDELNING.UNSPECIFIED === 16,
    'fel antal rader flyttades: ' + JSON.stringify(r.d.FORDELNING));
  return 'REQUIRED 5 -> 4 · identitet stabil · statusavtryck andrat';
});

/* ── RS285-04 · kallan for en REQUIRED-rad tas bort ───────────────────── */
prov('RS285-04', 'kalla borttagen fran en REQUIRED-rad faller stangt i stallet for att gissa', () => {
  const k = bas();
  const x = rad(k, 'CSR::ROLE::searchbox::FOCUSED');
  x.SOURCE = [];
  x.SOURCE_LOCATION = '\u2014';
  x.EVIDENCE = '\u2014';
  const r = kor(k, 'rs04');
  kravs(!r.ok, 'bygget gick igenom trots att kravet tappat sin kalla');
  kravs(/tappat sin kalla|bar ingen kalla/.test(r.fel), 'fel orsak: ' + r.fel);
  return r.fel.slice(0, 96);
});

/* ── RS285-05 · irrelevant normativ text ──────────────────────────────── */
prov('RS285-05', 'andrad irrelevant text andrar ingen applicability', () => {
  const k = bas();
  k.$om = 'Omskriven inledning som inte ar en dom.';
  k.generella_fynd.$tystnadens_form = 'Omformulerad iakttagelse utan rattslig verkan.';
  k.kallregister.tokens.doman = 'Designvarden (omskrivet)';
  const r = kor(k, 'rs05');
  kravs(r.ok, 'bygget foll: ' + r.fel);
  kravs(r.d.STATUS_FINGERPRINT === STFP, 'statusavtrycket andrades av ren prosa');
  kravs(r.d.IDENTITY_FINGERPRINT === IDFP, 'identiteten andrades av ren prosa');
  return 'bada avtrycken oforandrade';
});

/* ── RS285-06 · ett tillstand laggs till i en rolls normativa definition ─ */
prov('RS285-06', 'nytt normativt tillstand paverkar exakt ratt rad', () => {
  const k = bas();
  const x = rad(k, 'CSR::ROLE::menuitem::SELECTED');
  x.PROPOSED_STATUS = 'REQUIRED';
  x.PROVENANCE = 'SOURCE_GROUNDED';
  x.SOURCE = ['komponentark'];
  x.SOURCE_LOCATION = 'pahittad provrad';
  x.EVIDENCE = 'Provtext som bara finns i mutationen.';
  const r = kor(k, 'rs06');
  kravs(r.ok, 'bygget foll: ' + r.fel);
  // Rakna mot referenskorningen, inte mot handskrivna tal: baslinjen andras
  // nar beslut registreras, men invarianten ar densamma.
  kravs(r.d.FORDELNING.REQUIRED === REF.d.FORDELNING.REQUIRED + 1,
    'fel antal REQUIRED: ' + r.d.FORDELNING.REQUIRED);
  kravs(r.d.PER_ROLL.menuitem.REQUIRED === (REF.d.PER_ROLL.menuitem.REQUIRED || 0) + 1,
    'fel roll paverkades');
  for (const roll of ['link', 'searchbox', 'combobox'])
    kravs(JSON.stringify(r.d.PER_ROLL[roll]) === JSON.stringify(REF.d.PER_ROLL[roll]),
      'den ororda rollen ' + roll + ' paverkades');
  kravs(r.d.IDENTITY_FINGERPRINT === IDFP, 'identiteten andrades');
  return 'menuitem REQUIRED ' + (REF.d.PER_ROLL.menuitem.REQUIRED || 0) + ' -> ' +
    r.d.PER_ROLL.menuitem.REQUIRED + ' · ovriga roller ororda';
});

/* ── RS285-07 · status ingar inte i identiteten ───────────────────────── */
prov('RS285-07', 'status och proveniens ingar inte i persistent identitet', () => {
  const k = bas();
  // Lasningen av kallbelagda rader ar en egen invariant (RS285-16). Har provas
  // bara att identiteten inte foljer med statusen.
  k.lasta_kallbelagda = [];
  for (const x of k.rollstate) {
    x.PROPOSED_STATUS = 'UNSPECIFIED';
    x.PROVENANCE = 'UNSPECIFIED_FROM_SOURCE_SILENCE';
    delete x.HUMAN_DECISION_ID;
  }
  const r = kor(k, 'rs07');
  kravs(r.ok, 'bygget foll: ' + r.fel);
  kravs(r.d.IDENTITY_FINGERPRINT === IDFP,
    'identiteten foljde med statusen: ' + r.d.IDENTITY_FINGERPRINT);
  kravs(r.d.STATUS_FINGERPRINT !== STFP, 'statusavtrycket stod stilla trots 24 andrade rader');
  return 'identitet ' + IDFP + ' (oforandrad) · status andrad';
});

/* ── RS285-08 · Block 282 oforandrat ──────────────────────────────────── */
prov('RS285-08', 'Block 282:s fingerprints oforandrade', () => {
  const g = REF.d.BASELINE_READONLY;
  kravs(g['282_POPULATION'] === '5ede5a7c9ab3dfef', 'population: ' + g['282_POPULATION']);
  kravs(g['282_IDENTITY'] === 'd0c7b88913b45f18', 'identitet: ' + g['282_IDENTITY']);
  kravs(g['282_MAPPING'] === '639a14d6afb84664', 'mappning: ' + g['282_MAPPING']);
  return 'population 5ede5a7c9ab3dfef · mappning 639a14d6afb84664';
});

/* ── RS285-09 · Block 283 oforandrat ──────────────────────────────────── */
prov('RS285-09', 'Block 283:s identitetsavtryck oforandrat', () => {
  const g = REF.d.BASELINE_READONLY;
  kravs(g['283_IDENTITY'] === '2e7816936df8d602', 'identitet: ' + g['283_IDENTITY']);
  kravs(g['283_STATUS'] === '48182cf827ccfb6b', 'status: ' + g['283_STATUS']);
  return 'identitet 2e7816936df8d602 · status 48182cf827ccfb6b';
});

/* ── RS285-10 · Block 284 oforandrat ──────────────────────────────────── */
prov('RS285-10', 'Block 284:s forekomstidentitet och FINAL_ROLE oforandrade', () => {
  const g = REF.d.BASELINE_READONLY;
  kravs(g['284_OCCURRENCE_IDENTITY'] === '0d9f16c0df964d88', 'identitet: ' + g['284_OCCURRENCE_IDENTITY']);
  kravs(g['284_OCCURRENCE_STATUS'] === '68724affa98ecf30', 'status: ' + g['284_OCCURRENCE_STATUS']);
  const ut = execFileSync(process.execPath,
    [join(REPO, 'tools/role-vocabulary-reconciliation.mjs'), '--root=' + REPO],
    { encoding: 'utf8', maxBuffer: 1 << 26 });
  const d = JSON.parse(ut);
  kravs(d.FINAL_ROLE_COUNT === 26 && d.FINAL_ROLE_NULL_COUNT === 0, 'FINAL_ROLE-tackningen andrad');
  kravs(JSON.stringify(d.FINAL_ROLE_FORDELNING) ===
    JSON.stringify({ button: 7, combobox: 1, link: 14, menuitem: 3, searchbox: 1 }),
    'slutrollsfordelningen andrad: ' + JSON.stringify(d.FINAL_ROLE_FORDELNING));
  return 'identitet 0d9f16c0df964d88 · FINAL_ROLE 26/26 · fordelning oforandrad';
});

/* ── RS285-11 · representation ar en egen axel ────────────────────────── */
prov('RS285-11', 'andrad representation paverkar varken identitet eller status', () => {
  const k = bas();
  const x = rad(k, 'CSR::ROLE::searchbox::DISABLED');
  x.REPRESENTATION = 'PRESENT';
  x.REPRESENTATION_OCCURRENCES = 2;
  const r = kor(k, 'rs11');
  kravs(r.ok, 'bygget foll: ' + r.fel);
  kravs(r.d.IDENTITY_FINGERPRINT === IDFP, 'identiteten foljde representationen');
  kravs(r.d.STATUS_FINGERPRINT === STFP, 'statusavtrycket foljde representationen');
  kravs(r.d.REPRESENTATION.REQUIRED_PRESENT === REF.d.REPRESENTATION.REQUIRED_PRESENT + 1 &&
    r.d.REPRESENTATION.REQUIRED_ABSENT === REF.d.REPRESENTATION.REQUIRED_ABSENT - 1,
    'representationen rakandes inte om: ' + JSON.stringify(r.d.REPRESENTATION));
  return 'bada avtrycken oforandrade · PRESENT ' + REF.d.REPRESENTATION.REQUIRED_PRESENT +
    ' -> ' + r.d.REPRESENTATION.REQUIRED_PRESENT;
});

/* ── RS285-12 · REQUIRED utan kalla ───────────────────────────────────── */
prov('RS285-12', 'rad som pastas REQUIRED pa kallgrund utan kalla faller bygget', () => {
  const k = bas();
  const x = rad(k, 'CSR::ROLE::link::PRESSED');
  x.PROPOSED_STATUS = 'REQUIRED';
  x.PROVENANCE = 'SOURCE_GROUNDED';
  const r = kor(k, 'rs12');
  kravs(!r.ok, 'bygget accepterade ett krav utan kalla');
  kravs(/bar ingen kalla/.test(r.fel), 'fel orsak: ' + r.fel);
  return r.fel.slice(0, 96);
});

/* ── RS285-13 · beslutad status andrar inte identiteten ───────────────── */
prov('RS285-13', 'link::FOCUSED byter status utan att identiteten ror sig', () => {
  const k = bas();
  const x = rad(k, 'CSR::ROLE::link::FOCUSED');
  kravs(x.PROPOSED_STATUS === 'REQUIRED' && x.PROVENANCE === 'HUMAN_APPROVED',
    'utgangslaget ar inte det registrerade beslutet');
  x.PROPOSED_STATUS = 'UNSPECIFIED';
  x.PROVENANCE = 'UNSPECIFIED_FROM_SOURCE_SILENCE';
  delete x.HUMAN_DECISION_ID;
  const r = kor(k, 'rs13');
  kravs(r.ok, 'bygget foll: ' + r.fel);
  kravs(r.d.IDENTITY_FINGERPRINT === IDFP, 'identiteten foljde med statusen');
  kravs(r.d.STATUS_FINGERPRINT !== STFP, 'statusavtrycket stod stilla');
  kravs(r.d.FORDELNING.REQUIRED === 4, 'fel antal REQUIRED: ' + r.d.FORDELNING.REQUIRED);
  return 'identitet ' + IDFP + ' (oforandrad) · REQUIRED 5 -> 4';
});

/* ── RS285-14 · NOT_REQUIRED kraver ett uttryckligt beslut ────────────── */
prov('RS285-14', 'menuitem::DISABLED som NOT_REQUIRED utan beslutsproveniens faller', () => {
  const k = bas();
  const x = rad(k, 'CSR::ROLE::menuitem::DISABLED');
  kravs(x.PROPOSED_STATUS === 'NOT_REQUIRED', 'utgangslaget ar inte NOT_REQUIRED');
  x.PROVENANCE = 'UNSPECIFIED_FROM_SOURCE_SILENCE';
  delete x.HUMAN_DECISION_ID;
  const r = kor(k, 'rs14');
  kravs(!r.ok, 'kalltystnad fick bli en dom');
  kravs(/kalltystnad kan aldrig bli en dom/.test(r.fel), 'fel orsak: ' + r.fel);
  return r.fel.slice(0, 96);
});

/* ── RS285-15 · inget implicit arv fran oppnaren ──────────────────────── */
prov('RS285-15', 'menuitem::EXPANDED och COLLAPSED kan inte arva krav fran oppnaren', () => {
  for (const id of ['CSR::ROLE::menuitem::EXPANDED', 'CSR::ROLE::menuitem::COLLAPSED']) {
    const k = bas();
    const x = rad(k, id);
    x.PROPOSED_STATUS = 'REQUIRED';
    x.PROVENANCE = 'SOURCE_GROUNDED';
    delete x.HUMAN_DECISION_ID;
    x.SOURCE = [];
    x.SOURCE_LOCATION = '—';
    x.EVIDENCE = '—';
    const r = kor(k, 'rs15-' + id.split('::').pop());
    kravs(!r.ok, id + ' blev REQUIRED utan egen grund');
    kravs(/bar ingen kalla/.test(r.fel), 'fel orsak for ' + id + ': ' + r.fel);
  }
  return 'bada raderna faller stangt utan egen normativ grund';
});

/* ── RS285-16 · kallbelagt far inte bli beslut ────────────────────────── */
prov('RS285-16', 'searchbox::FOCUSED och DISABLED behaller sin kallgrund', () => {
  for (const id of ['CSR::ROLE::searchbox::FOCUSED', 'CSR::ROLE::searchbox::DISABLED']) {
    const k = bas();
    const x = rad(k, id);
    kravs(x.PROVENANCE === 'SOURCE_GROUNDED', id + ' ar inte kallbelagd i utgangslaget');
    x.PROVENANCE = 'HUMAN_APPROVED';
    x.HUMAN_DECISION_ID = 'HA285-PROV';
    const r = kor(k, 'rs16-' + id.split('::').pop());
    kravs(!r.ok, id + ' kunde relabelas till beslut');
    kravs(/last som kallbelagd/.test(r.fel), 'fel orsak for ' + id + ': ' + r.fel);
  }
  return 'bada raderna ar lasta vid komponentarkets avsnitt 07';
});

/* ── RS285-17 · faktakorrigeringen ar en del av domen ─────────────────── */
prov('RS285-17', 'SEARCHBOX_SPEC_GAP = YES faller sjalvkontrollen', () => {
  const k = bas();
  k.produktbeslut_i_kraft.SEARCHBOX_SPEC_GAP = 'YES';
  const r = kor(k, 'rs17');
  kravs(!r.ok, 'den korrigerade flaggan kunde atergå till YES');
  kravs(/SEARCHBOX_SPEC_GAP/.test(r.fel), 'fel orsak: ' + r.fel);
  return r.fel.slice(0, 96);
});

/* ── RS285-18 · Vila blir ingen ny rad ────────────────────────────────── */
prov('RS285-18', 'Vila -> DEFAULT skapar ingen 25:e rad och ingen 71:a i matrisen', () => {
  kravs(REF.d.ROLE_STATE_ROWS === 24, 'utgangslaget har inte 24 rader');
  kravs(REF.d.HYPOTETISK_MATRIS.TOTAL === 70, 'matrisen ar inte 70 rader');
  const k = bas();
  k.rollstate.push({
    ROW_ID: 'CSR::ROLE::searchbox::VILA', ROLE: 'searchbox', STATE: 'VILA',
    PREVIOUS_STATUS: 'UNSPECIFIED', PROPOSED_STATUS: 'UNSPECIFIED',
    SOURCE: [], SOURCE_LOCATION: '—', EVIDENCE: '—', SOURCE_AUTHORITY: '—',
    DECISION_BASIS: 'Provrad.', CONFIDENCE: 'HOG',
    PROVENANCE: 'UNSPECIFIED_FROM_SOURCE_SILENCE',
    REPRESENTATION: 'ABSENT', REPRESENTATION_OCCURRENCES: 0, KRAVER_BESLUT: null
  });
  const r = kor(k, 'rs18');
  kravs(!r.ok, 'en taxonomisk benamning blev en egen state-rad');
  kravs(/utanfor de sex/.test(r.fel), 'fel orsak: ' + r.fel);
  return '24 rader · matrisen 70 · ' + r.fel.slice(0, 64);
});

/* ── RS285-19 · tokenized-gapet utokar ingen population ───────────────── */
prov('RS285-19', 'Tokeniserad skapar ingen ny state-rad i detta block', () => {
  const k = bas();
  k.rollstate.push({
    ROW_ID: 'CSR::ROLE::searchbox::TOKENISERAD', ROLE: 'searchbox', STATE: 'TOKENISERAD',
    PREVIOUS_STATUS: 'UNSPECIFIED', PROPOSED_STATUS: 'UNSPECIFIED',
    SOURCE: [], SOURCE_LOCATION: '—', EVIDENCE: '—', SOURCE_AUTHORITY: '—',
    DECISION_BASIS: 'Provrad.', CONFIDENCE: 'HOG',
    PROVENANCE: 'UNSPECIFIED_FROM_SOURCE_SILENCE',
    REPRESENTATION: 'ABSENT', REPRESENTATION_OCCURRENCES: 0, KRAVER_BESLUT: null
  });
  const r = kor(k, 'rs19');
  kravs(!r.ok, 'scope-fyndet blev en rad');
  kravs(/utanfor de sex/.test(r.fel), 'fel orsak: ' + r.fel);
  kravs(REF.d.HYPOTETISK_MATRIS.TOTAL === 70, 'matrisen utokades');
  return 'gapet ar registrerat som flagga, inte som rad';
});

/* ── RS285-20 · stangt lage ar expanded=false ─────────────────────────── */
prov('RS285-20', 'combobox::COLLAPSED kan inte kravas separat under EXPANDED_BOOLEAN', () => {
  const k = bas();
  kravs(k.produktbeslut_i_kraft.COMBOBOX_EXPANSION_MODEL === 'EXPANDED_BOOLEAN',
    'modellen ar inte EXPANDED_BOOLEAN');
  const x = rad(k, 'CSR::ROLE::combobox::COLLAPSED');
  x.PROPOSED_STATUS = 'REQUIRED';
  x.PROVENANCE = 'HUMAN_APPROVED';
  x.HUMAN_DECISION_ID = 'HA285-PROV';
  const r = kor(k, 'rs20');
  kravs(!r.ok, 'ett separat COLLAPSED-krav kunde samexistera med expanded=false');
  kravs(/COMBOBOX_COLLAPSED_SEPARATE_STATE/.test(r.fel), 'fel orsak: ' + r.fel);
  return r.fel.slice(0, 96);
});

const godkanda = resultat.filter(r => r[1]).length;
console.log('\nRS285-PROV status=' + (godkanda === n ? 'godkand' : 'UNDERKAND') +
  ' godkanda=' + godkanda + ' av ' + n);
process.exit(godkanda === n ? 0 : 1);
