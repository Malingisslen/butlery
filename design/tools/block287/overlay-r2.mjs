// Kor: node tools/block287/overlay-r2.mjs --root=<kallrot> --index=<idx-full.json>
//      --omprovning=<census-reopen.json> --ut=<overlay14.json>
//
// Harleder korrigeringsrunda 2:s overlagg ur repots egna artefakter, sa att
// ingen handbyggd fil behover folja med. Tva klasser av andring:
//
//   H/I  de 60 forekomster som censusomprovningen tar tillbaka till kontroll
//        (tools/block287-censusomprovning.mjs, reglerna R1-R5 till fixpunkt)
//   J/K/L de 17 itemiserade raderna i fas2/block287-censuskorrigering.json
//
// Agaren skrivs om ur kallans ankare: efter varje ankarvag kan agarstrangen
// byta varde, och overlagget maste folja kallan - aldrig tvartom.
import { readFileSync, writeFileSync } from 'node:fs';
const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root');
const IDX = JSON.parse(readFileSync(arg('index'), 'utf8'));
const OMP = JSON.parse(readFileSync(arg('omprovning'), 'utf8'));
const BAS = JSON.parse(readFileSync(ROT + '/fas2/matning/overlay13.json', 'utf8'));
const KOR = JSON.parse(readFileSync(ROT + '/fas2/block287-censuskorrigering.json', 'utf8'));

const slug = s => String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
  .replace(/&amp;/g, '&').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 48);
const occId = e => 'OCC::' + slug(e.fil) + '::' + e.art + '::' + e.ordProd;
const perOcc = new Map(IDX.map(e => [occId(e), e]));

// BL-01 pensionerade pf-a-ankarena. Overlagget bar dem fortfarande i sina
// agarstrangar, och ett pensionerat ankare pekar inte pa nagot element langre.
// Rekoncilieringen ar kanonisk: samma karta som frysningen anvander.
const R1 = JSON.parse(readFileSync(ROT + '/fas2/bl01-ankarrekonciliering.json', 'utf8'));
const pfaMap = new Map(R1.PF_A_IDENTITY_MAPPING.map(m => [m.OLD_PF_A_ANCHOR, m.CANONICAL_BL01_ANCHOR]));
const byt = x => (x == null ? x : String(x).replace(/occ-[a-z]{12}/g, m => pfaMap.get(m) || m));
let migrerade = 0;

const ut = JSON.parse(JSON.stringify(BAS));
const F = ut.forekomst;
const rapport = { HI: 0, JKL: 0, SAKNAD_FOREKOMST: [], UTAN_ANKARE: [] };

/** Agarstrangen for en aterupptagen kontroll: ramen plus elementets eget ankare. */
function agareFor(id) {
  const e = perOcc.get(id);
  if (!e) { rapport.SAKNAD_FOREKOMST.push(id); return null; }
  if (!e.occ) { rapport.UTAN_ANKARE.push(id); return null; }
  return 'OWNER::' + e.art + '::objekt::' + e.occ;
}

// H/I · censusomprovningens 60
for (const k of OMP.KONTROLLER) {
  const id = k.OCCURRENCE_ID;
  if (!F[id]) { rapport.SAKNAD_FOREKOMST.push(id); continue; }
  F[id] = {
    klass: k.NY_KLASS,
    kalla: 'KORRIGERINGSRUNDA_2',
    grund: 'censusomprovning mot BL-01: ' + k.REGLER.map(r => r.rule).join('+') + ' - ' + k.REGLER[0].bevis,
    sg: k.SUBGROUP,
    roll: k.ROLL,
    namn: null,
    agare: agareFor(id)
  };
  rapport.HI++;
}

// J/K/L · de itemiserade raderna, agaren oforandrad
for (const sek of ['J_ACTION_TEXT_OMPROVAD', 'K_PROTOTYPLANKAR', 'L_UNDANTAG_I_BREDA_DELGRUPPER'])
  for (const r of (KOR[sek].rader || [])) {
    const id = r.OCCURRENCE_ID;
    const fore = F[id];
    if (!fore) { rapport.SAKNAD_FOREKOMST.push(id); continue; }
    F[id] = {
      klass: r.NY_KLASS,
      kalla: 'KORRIGERINGSRUNDA_2',
      grund: r.AVSNITT + ': ' + r.SKAL,
      sg: r.SUBGROUP,
      roll: r.ROLL,
      namn: null,
      // M7: blir raden en kontroll ar elementets eget ankare agaridentiteten, och
      // den gamla namnbaserade strangen far inte overleva omklassningen. Tappar
      // raden sin kontrollstatus ar den inte langre nagon agare: da star den
      // omslutande objektagaren kvar orord.
      agare: r.NY_KLASS === 'KNOWN_CONTROL' ? (agareFor(id) || fore.agare || null) : (fore.agare || null)
    };
    rapport.JKL++;
  }

// migrera alla kvarvarande pf-a-ankare i overlaggets agarstrangar
for (const v of Object.values(F)) if (v && v.agare) { const n = byt(v.agare); if (n !== v.agare) { v.agare = n; migrerade++; } }
if (ut.agare) { const nytt = {}; for (const [k, v] of Object.entries(ut.agare)) nytt[byt(k)] = v; ut.agare = nytt; }
// Agarkartan ar historisk data och rensas INTE har: den bar ocksa radagare vars
// forekomst star under en annan agarstrang. Vilka av dem som fortfarande ar
// kontroller avgor byggaren, ur klassningen - se tools/block287/build.mjs.

writeFileSync(arg('ut'), JSON.stringify(ut, null, 1) + '\n');
console.log(JSON.stringify({
  $om: 'Korrigeringsrunda 2:s overlagg, harlett ur repot',
  OVERLAY_ENTRIES: Object.keys(F).length,
  HI_REOPENED_TO_CONTROL: rapport.HI,
  ITEMISED_ROWS: rapport.JKL,
  TOTAL_CHANGED: rapport.HI + rapport.JKL,
  MISSING_OCCURRENCES: rapport.SAKNAD_FOREKOMST.length,
  WITHOUT_OWN_ANCHOR: rapport.UTAN_ANKARE.length,
  RETIRED_PF_A_ANCHORS_MIGRATED: migrerade,
  OWNER_MAP_ENTRIES: Object.keys(ut.agare || {}).length,
  DIAG: { SAKNAD: rapport.SAKNAD_FOREKOMST.slice(0, 5), UTAN_ANKARE: rapport.UTAN_ANKARE.slice(0, 5) }
}, null, 1));
