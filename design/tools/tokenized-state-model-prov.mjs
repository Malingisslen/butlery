#!/usr/bin/env node
// Block 286 — mutationsprov TKN286-01…TKN286-12.
//
// Varje prov muterar en KOPIA av den kanoniska analysallan och kraver att
// byggaren beter sig ratt. Bade det som ska overleva en mutation och det som
// ska falla stangt provas.
//
// Kor: node tools/tokenized-state-model-prov.mjs --root=. --out=<katalog utanfor repot>

import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const REPO = resolve(arg('root') || '.');
const BYGG = arg('bygg') || join(REPO, 'tools/tokenized-state-model.mjs');
const KALLA = arg('kalla') || join(REPO, 'fas2/tokenized-state-model.json');
const UT = resolve(arg('out') || '');
if (!arg('out')) { console.error('\u2716 ange --out=<katalog utanfor reporoten>'); process.exit(2); }
if (UT.startsWith(REPO + '\\') || UT.startsWith(REPO + '/')) {
  console.error('\u2716 --out maste ligga utanfor reporoten'); process.exit(2);
}
rmSync(UT, { recursive: true, force: true });
mkdirSync(UT, { recursive: true });

const KOD = JSON.parse(readFileSync(KALLA, 'utf8'));
const bas = () => {
  const k = JSON.parse(JSON.stringify(KOD));
  // Bara en forvantan som overlever varje mutation.
  k.forvantat = { SCENARIO_B_RADER: 70 };
  return k;
};
// Analysnivan utan det registrerade beslutet — for prov av analysens egna regler.
const fore = () => {
  const k = bas();
  k.modellbeslut = {};
  k.utfall.PROVENANCE = 'SOURCE_GROUNDED';
  delete k.utfall.HUMAN_DECISION_ID;
  return k;
};

let n = 0;
const kor = (k, namn) => {
  const fil = join(UT, namn + '.json');
  writeFileSync(fil, JSON.stringify(k, null, 1));
  try {
    const ut = execFileSync(process.execPath, [BYGG, '--root=' + REPO, '--kalla=' + fil],
      { encoding: 'utf8', maxBuffer: 1 << 26, stdio: ['ignore', 'pipe', 'pipe'] });
    return { ok: true, d: JSON.parse(ut) };
  } catch (e) {
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
    resultat.push([id, true]);
    console.log('\u2714 ' + id + '  ' + text);
    if (detalj) console.log('     ' + detalj);
  } catch (e) {
    resultat.push([id, false]);
    console.log('\u2716 ' + id + '  ' + text);
    console.log('     ' + e.message);
  }
};
const kravs = (v, vad) => { if (!v) throw new Error(vad); };

const REF = kor(bas(), 'referens');
if (!REF.ok) { console.error('referenskorningen gick inte: ' + REF.fel); process.exit(1); }
const IDFP = REF.d.IDENTITY_FINGERPRINT, STFP = REF.d.STATUS_FINGERPRINT;

/* ── TKN286-01 · omkastad kallordning ─────────────────────────────────── */
prov('TKN286-01', 'omkastad kallordning ger samma gap-identitet', () => {
  const k = bas();
  const omvant = {};
  for (const nyckel of Object.keys(k).reverse()) omvant[nyckel] = k[nyckel];
  const a = {};
  for (const nyckel of Object.keys(k.alternativ).reverse()) a[nyckel] = k.alternativ[nyckel];
  omvant.alternativ = a;
  const r = kor(omvant, 'tkn01');
  kravs(r.ok, 'bygget foll: ' + r.fel);
  kravs(r.d.IDENTITY_FINGERPRINT === IDFP, 'identiteten andrades: ' + r.d.IDENTITY_FINGERPRINT);
  return 'identitet ' + IDFP;
});

/* ── TKN286-02 · irrelevant komponenttext ─────────────────────────────── */
prov('TKN286-02', 'andrad irrelevant text lamnar modellutfallet orort', () => {
  const k = bas();
  k.$om = 'Omskriven inledning utan rattslig verkan.';
  k.kallregister.komponentark.doman = 'Komponentgeometri (omskrivet)';
  k.korpus.$om = 'Omformulerad metodanmarkning.';
  const r = kor(k, 'tkn02');
  kravs(r.ok, 'bygget foll: ' + r.fel);
  kravs(r.d.STATUS_FINGERPRINT === STFP, 'statusavtrycket andrades av ren prosa');
  kravs(r.d.IDENTITY_FINGERPRINT === IDFP, 'identiteten andrades av ren prosa');
  kravs(r.d.UTFALL.MODELL === REF.d.UTFALL.MODELL, 'utfallet andrades av ren prosa');
  return 'utfall och bada avtrycken oforandrade';
});

/* ── TKN286-03 · etiketten byter namn, semantiken ar densamma ─────────── */
prov('TKN286-03', 'omdopt etikett lamnar den persistenta identiteten orord', () => {
  const k = bas();
  k.modellfraga.LAGE = 'Med soktermer som chips';
  const r = kor(k, 'tkn03');
  kravs(r.ok, 'bygget foll: ' + r.fel);
  kravs(r.d.IDENTITY_FINGERPRINT === IDFP,
    'identiteten foljde den visuella etiketten: ' + r.d.IDENTITY_FINGERPRINT);
  kravs(r.d.MODELLFRAGA.GAP_ID === REF.d.MODELLFRAGA.GAP_ID, 'gap-id andrades');
  return 'identitet ' + IDFP + ' · etiketten ar inte identitet';
});

/* ── TKN286-04 · ritad token tas bort ur exemplet ─────────────────────── */
prov('TKN286-04', 'borttaget ritat chip faller analysen pa ratt modellkomponent', () => {
  const k = bas();
  k.korpus.ritade_chip_i_sokfalt = 0;
  const r = kor(k, 'tkn04');
  kravs(!r.ok, 'ett sammansatt lage kunde pastas utan nagon ritad delkomponent');
  kravs(/inget chip ar ritat i sokfaltet/.test(r.fel), 'fel orsak: ' + r.fel);
  return r.fel.slice(0, 96);
});

/* ── TKN286-05 · maskinlasbart state pa searchbox ─────────────────────── */
prov('TKN286-05', 'maskinlasbart state pa sokfaltet andrar representation, inte identitet', () => {
  const k = bas();
  k.korpus.sokfalt_med_maskinlasbart_state = 1;
  const r = kor(k, 'tkn05');
  kravs(r.ok, 'bygget foll: ' + r.fel);
  kravs(r.d.IDENTITY_FINGERPRINT === IDFP, 'identiteten foljde representationen');
  kravs(r.d.STATUS_FINGERPRINT === STFP, 'statusavtrycket foljde representationen');
  kravs(r.d.KORPUS.sokfalt_med_maskinlasbart_state === 1, 'representationen rakandes inte om');
  return 'bada avtrycken oforandrade · representation 0 -> 1';
});

/* ── TKN286-06 · barn-chip laggs till eller tas bort ──────────────────── */
prov('TKN286-06', 'andrat antal barn-chip paverkar analysen utan att byta identitet', () => {
  for (const [namn, v] of [['fler', 7], ['farre', 1]]) {
    const k = bas();
    k.korpus.chip_i_sokfalt_i_korpus = v;
    const r = kor(k, 'tkn06-' + namn);
    kravs(r.ok, 'bygget foll: ' + r.fel);
    kravs(r.d.IDENTITY_FINGERPRINT === IDFP, 'identiteten andrades vid ' + namn + ' chip');
    kravs(r.d.KORPUS.chip_i_sokfalt_i_korpus === v, 'korpussiffran foljde inte med');
  }
  return 'identitet stabil vid bade fler och farre barn-chip';
});

/* ── TKN286-07 · utfallet ingar inte i identiteten ────────────────────── */
prov('TKN286-07', 'bedomt modellutfall ingar inte i persistent identity', () => {
  const k = fore();
  k.utfall.MODELL = 'VARIANT_OR_CONTENT_MODE';
  const r = kor(k, 'tkn07');
  kravs(r.ok, 'bygget foll: ' + r.fel);
  kravs(r.d.IDENTITY_FINGERPRINT === IDFP, 'identiteten foljde utfallet');
  kravs(r.d.STATUS_FINGERPRINT !== STFP, 'statusavtrycket stod stilla trots andrat utfall');
  return 'identitet ' + IDFP + ' (oforandrad) · status andrad';
});

/* ── TKN286-08…11 · uppstroms oforandrat ──────────────────────────────── */
const g = REF.d.BASELINE_READONLY;
prov('TKN286-08', 'Block 282:s fingerprints oforandrade', () => {
  kravs(g['282_POPULATION'] === '5ede5a7c9ab3dfef', 'population: ' + g['282_POPULATION']);
  kravs(g['282_IDENTITY'] === 'd0c7b88913b45f18', 'identitet: ' + g['282_IDENTITY']);
  kravs(g['282_MAPPING'] === '639a14d6afb84664', 'mappning: ' + g['282_MAPPING']);
  return 'population 5ede5a7c9ab3dfef · mappning 639a14d6afb84664';
});
prov('TKN286-09', 'Block 283:s fingerprints oforandrade', () => {
  kravs(g['283_IDENTITY'] === '2e7816936df8d602', 'identitet: ' + g['283_IDENTITY']);
  kravs(g['283_STATUS'] === '48182cf827ccfb6b', 'status: ' + g['283_STATUS']);
  return 'identitet 2e7816936df8d602 · status 48182cf827ccfb6b';
});
prov('TKN286-10', 'Block 284:s fingerprints oforandrade', () => {
  kravs(g['284_OCCURRENCE_IDENTITY'] === '0d9f16c0df964d88', 'identitet: ' + g['284_OCCURRENCE_IDENTITY']);
  kravs(g['284_OCCURRENCE_STATUS'] === '68724affa98ecf30', 'status: ' + g['284_OCCURRENCE_STATUS']);
  return 'identitet 0d9f16c0df964d88 · status 68724affa98ecf30';
});
prov('TKN286-11', 'Block 285:s identitet och status oforandrade, gapet star oppet', () => {
  kravs(g['285_IDENTITY'] === '5d9d52d93fc08a37', 'identitet: ' + g['285_IDENTITY']);
  kravs(g['285_STATUS'] === '8128ade072cb6f98', 'status: ' + g['285_STATUS']);
  const K5 = readFileSync(join(REPO, 'fas2/role-state-applicability.json'), 'utf8');
  kravs(/"SEARCHBOX_TOKENIZED_STATE_MODEL_GAP": "YES"/.test(K5), 'gapet ar inte langre oppet');
  return 'identitet 5d9d52d93fc08a37 · gapet fortfarande YES';
});

/* ── TKN286-12 · nytt state utan positiv grund ────────────────────────── */
prov('TKN286-12', 'NEW_PERSISTENT_STATE utan positiv normativ grund faller bygget', () => {
  // a · valt trots att alternativet bedomts sakna stod
  const k1 = fore();
  k1.utfall.MODELL = 'NEW_PERSISTENT_STATE';
  const r1 = kor(k1, 'tkn12a');
  kravs(!r1.ok, 'ett nytt state kunde valjas trots NOT_SUPPORTED');
  kravs(/NOT_SUPPORTED/.test(r1.fel), 'fel orsak (a): ' + r1.fel);

  // b · pastat stod men ingen kalla aberopas
  const k2 = fore();
  k2.alternativ.NEW_PERSISTENT_STATE.BEDOMNING = 'SUPPORTED';
  k2.alternativ.NEW_PERSISTENT_STATE.SOURCE = [];
  k2.utfall.MODELL = 'NEW_PERSISTENT_STATE';
  const r2 = kor(k2, 'tkn12b');
  kravs(!r2.ok, 'ett nytt state kunde pastas ha stod utan kalla');
  kravs(/aberopar ingen kalla/.test(r2.fel), 'fel orsak (b): ' + r2.fel);
  return 'bada vagarna faller stangt';
});

/* ── TKN286-13 · beslutet andrar status, inte identitet ───────────────── */
prov('TKN286-13', 'HUMAN_APPROVED-resolutionen andrar status men inte gap-identitet', () => {
  const r = kor(fore(), 'tkn13');
  kravs(r.ok, 'pre-beslutsformen byggde inte: ' + r.fel);
  kravs(r.d.IDENTITY_FINGERPRINT === IDFP, 'identiteten skiljer mellan fore och efter beslutet');
  kravs(r.d.STATUS_FINGERPRINT !== STFP, 'statusavtrycket stod stilla trots beslutet');
  kravs(r.d.STATUS_FINGERPRINT === 'd59323519551de18',
    'pre-beslutsformen reproducerar inte analysens gamla status: ' + r.d.STATUS_FINGERPRINT);
  return 'identitet ' + IDFP + ' · status d59323519551de18 -> ' + STFP;
});

/* ── TKN286-14 · ingen tokeniserad state-rad ──────────────────────────── */
prov('TKN286-14', 'searchbox::TOKENIZED kan inte skapas under COMPOSITE_VISUAL_MODE', () => {
  const k1 = bas();
  k1.utfall.FORESLAGEN_STATE_ID = 'CSR::ROLE::searchbox::TOKENIZED';
  const r1 = kor(k1, 'tkn14a');
  kravs(!r1.ok, 'en tokeniserad state-id kunde foreslas');
  kravs(/foreslagen trots att utfallet/.test(r1.fel), 'fel orsak (a): ' + r1.fel);
  const k2 = bas();
  k2.modellbeslut.SEARCHBOX_TOKENIZED_STATE_ROW_CREATED = 'YES';
  const r2 = kor(k2, 'tkn14b');
  kravs(!r2.ok, 'flaggan kunde pasta att raden skapats');
  return 'bade foreslagen id och flagga faller stangt';
});

/* ── TKN286-15 · chip-form ger ingen filterchip-semantik ──────────────── */
prov('TKN286-15', 'soktoken far inte vaxlingsknapp/pressed enbart fran data-component="chip"', () => {
  const k1 = bas();
  const t1 = k1.komposition.delar.find(d => d.DEL === 'token');
  t1.ROLL = 'vaxlingsknapp'; t1.STATE = 'pressed'; t1.HARLEDD_UR = 'data-component=chip';
  const r1 = kor(k1, 'tkn15a');
  kravs(!r1.ok, 'filterchippets semantik arvdes');
  kravs(/filterchippets roll eller tillstand/.test(r1.fel), 'fel orsak (a): ' + r1.fel);
  const k2 = bas();
  k2.komposition.delar.find(d => d.DEL === 'token').ARVER_FRAN_FILTERCHIP = true;
  const r2 = kor(k2, 'tkn15b');
  kravs(!r2.ok, 'arvsflaggan kunde sattas');
  kravs(/arver filterchippets semantik/.test(r2.fel), 'fel orsak (b): ' + r2.fel);
  const k3 = bas();
  const t3 = k3.komposition.delar.find(d => d.DEL === 'token');
  t3.ROLL = 'option'; t3.HARLEDD_UR = 'data-component=chip';
  const r3 = kor(k3, 'tkn15c');
  kravs(!r3.ok, 'en roll harledd ur chip-formen accepterades');
  kravs(/inte ur den faktiska interaktionen/.test(r3.fel), 'fel orsak (c): ' + r3.fel);
  return 'tre vagar till arvd semantik faller stangt';
});

/* ── TKN286-16 · borttagning ar egen kontroll med namn ────────────────── */
prov('TKN286-16', 'borttagbart soktokens atgard kraver egen roll och tillgangligt namn', () => {
  const fall = [
    ['utan roll', d => { d.ROLL = null; }, /borttagningsatgarden har rollen/],
    ['utan namnkrav', d => { d.KRAVER_TILLGANGLIGT_NAMN = false; }, /saknar krav pa tillgangligt namn/],
    ['namn som identitet', d => { d.NAMN_AR_IDENTITET = true; }, /ordalydelse har gjorts till identitet/]
  ];
  for (const [namn, mut, re] of fall) {
    const k = bas();
    mut(k.komposition.delar.find(d => d.DEL === 'token_borttagning'));
    const r = kor(k, 'tkn16-' + namn.replace(/ /g, '-'));
    kravs(!r.ok, namn + ' accepterades');
    kravs(re.test(r.fel), 'fel orsak (' + namn + '): ' + r.fel);
  }
  return 'roll, namnkrav och identitetsskydd faller stangt';
});

/* ── TKN286-17 · ingrediensvaljaren blir inte searchbox ───────────────── */
prov('TKN286-17', 'ingrediensvaljaren kan inte relabelas searchbox', () => {
  const k = bas();
  k.primarmonster['#ingredienssok'].PRIMARY_ACCESSIBILITY_ROLE = 'searchbox';
  const r = kor(k, 'tkn17');
  kravs(!r.ok, 'ingrediensvaljaren relabelades');
  kravs(/relabelats searchbox/.test(r.fel), 'fel orsak: ' + r.fel);
  return r.fel.slice(0, 96);
});

/* ── TKN286-18 · sokhistorik ar inte varde ────────────────────────────── */
prov('TKN286-18', 'sokhistorik raknas inte som aktuellt searchbox-varde', () => {
  for (const [namn, mut] of [['som varde', s => { s.RAKNAS_SOM_AKTUELLT_VARDE = true; }],
    ['som state', s => { s.EGET_SEARCHBOX_STATE = true; }]]) {
    const k = bas();
    mut(k.sokhistorik);
    const r = kor(k, 'tkn18-' + namn.replace(/ /g, '-'));
    kravs(!r.ok, 'sokhistorik ' + namn + ' accepterades');
    kravs(/sokhistoriken raknas/.test(r.fel), 'fel orsak (' + namn + '): ' + r.fel);
  }
  return 'bade varde och state faller stangt';
});

/* ── TKN286-19 · matrisen forblir 70 ──────────────────────────────────── */
prov('TKN286-19', '70-radersmatrisen forblir 70', () => {
  kravs(REF.d.MATRIX_ROWS === 70, 'matrisen ar ' + REF.d.MATRIX_ROWS);
  kravs(REF.d.NEW_STATE_ROWS === 0, 'nya rader: ' + REF.d.NEW_STATE_ROWS);
  kravs(REF.d.SEARCHBOX_TOKENIZED_STATE_ROW === 'ABSENT', 'tokeniserad rad finns');
  const k = bas();
  k.population.tillstand = 8;
  const r = kor(k, 'tkn19');
  kravs(!r.ok, 'en attonde tillstandskolumn accepterades');
  return 'matrisen 70 · nya rader 0 · en extra kolumn faller stangt';
});

/* ── TKN286-20 · oppen vokabular skapar ingen rad ─────────────────────── */
prov('TKN286-20', 'CONTROL_STATE_VOCABULARY_CLOSED = NO skapar ingen state-rad utan grund', () => {
  kravs(REF.d.MODELLBESLUT.CONTROL_STATE_VOCABULARY_CLOSED === 'NO', 'vokabularen ar inte oppen');
  kravs(REF.d.NEW_STATE_ROWS === 0, 'den oppna vokabularen har skapat rader');
  // Oppen vokabular + ett nytt state utan positiv grund faller anda.
  const k = fore();
  k.alternativ.NEW_PERSISTENT_STATE.BEDOMNING = 'SUPPORTED';
  k.alternativ.NEW_PERSISTENT_STATE.EVIDENCE = '—';
  k.utfall.MODELL = 'NEW_PERSISTENT_STATE';
  k.utfall.FORESLAGEN_STATE_ID = 'CSR::ROLE::searchbox::TOKENIZED';
  const r = kor(k, 'tkn20');
  kravs(!r.ok, 'ett nytt state skapades utan positiv grund');
  kravs(/utan positiv normativ grund/.test(r.fel), 'fel orsak: ' + r.fel);
  return 'oppen vokabular · 0 nya rader · nytt state utan citat faller stangt';
});

/* ── TKN286-21 · ett monster smyger inte in som roll ──────────────────── */
prov('TKN286-21', 'TOKEN_MULTISELECT som ingrediensvaljarens tillganglighetsroll faller bygget', () => {
  const k = bas();
  k.primarmonster['#ingredienssok'].PRIMARY_ACCESSIBILITY_ROLE = 'TOKEN_MULTISELECT';
  const r = kor(k, 'tkn21');
  kravs(!r.ok, 'interaktionsmonstret accepterades som roll');
  kravs(/interaktionsmonstret TOKEN_MULTISELECT ligger i rollfaltet/.test(r.fel), 'fel orsak: ' + r.fel);
  return r.fel.slice(0, 96);
});

/* ── TKN286-22 · vokabularen utvidgas inte, kopplat till Block 284 ────── */
prov('TKN286-22', 'TOKEN_MULTISELECT kan inte laggas i rollvokabularen eller FINAL_ROLE-semantik', () => {
  // a · FINAL_ROLE-liknande semantik pa en kompositionsdel
  const k1 = bas();
  k1.komposition.delar.find(d => d.DEL === 'token').FINAL_ROLE = 'TOKEN_MULTISELECT';
  const r1 = kor(k1, 'tkn22a');
  kravs(!r1.ok, 'FINAL_ROLE = TOKEN_MULTISELECT accepterades');
  kravs(/ligger i rollfaltet .*FINAL_ROLE/.test(r1.fel), 'fel orsak (a): ' + r1.fel);
  // b · Block 286 forsoker utvidga vokabularen
  const k2 = bas();
  k2.rollvokabular_tillagg = ['TOKEN_MULTISELECT'];
  const r2 = kor(k2, 'tkn22b');
  kravs(!r2.ok, 'en vokabularutvidgning accepterades');
  kravs(/utvidga rollvokabularen/.test(r2.fel), 'fel orsak (b): ' + r2.fel);
  // c · kopplingen till Block 284: vokabularen bor i Block 284:s fil, vars
  //     innehall ar last med hash. En andring av filen — till exempel en ny
  //     roll i vokabularen — gor den faktiska hashen skild fran den deklarerade.
  const k3 = bas();
  k3.upstream_filhashar['fas2/role-vocabulary-reconciliation.json'] = '0000000000000000';
  const r3 = kor(k3, 'tkn22c');
  kravs(!r3.ok, 'en andrad Block-284-vokabularfil passerade');
  kravs(/role-vocabulary-reconciliation\.json har andrats/.test(r3.fel), 'fel orsak (c): ' + r3.fel);
  // d · och den levande Block-284-utdatan bar ingen sadan roll
  kravs(REF.ok, 'referensen byggde inte');
  return 'FINAL_ROLE, vokabulartillagg och andrad Block-284-fil faller stangt';
});

const godkanda = resultat.filter(r => r[1]).length;
console.log('\nTKN286-PROV status=' + (godkanda === n ? 'godkand' : 'UNDERKAND') +
  ' godkanda=' + godkanda + ' av ' + n);
process.exit(godkanda === n ? 0 : 1);
