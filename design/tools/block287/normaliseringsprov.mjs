// Kor: node tools/block287/normaliseringsprov.mjs --root=<kallrot> --bygge=<byggkatalog>
//
// NORM-01..NORM-04 · de tva fel som normaliseringen av skrivplanen blottade
// far inte kunna atervanda.
//
//   NORM-01 tva skilda kontroller med egna forekomster far inte hamna pa samma
//           fysiska mal bara for att en gemensam behallare bar ett ankare
//   NORM-02 en anspraklos namnformad agare vars synliga namn tillhor en ankrad
//           kontroll far inte leva vidare som en andra aktiv agare
//   NORM-03 att pensionera en sadan agare far inte ta bort den levande kontrollen
//   NORM-04 varje kallgrundat krav star kvar efter normaliseringen
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root'), BYGGE = arg('bygge');
const b = f => JSON.parse(readFileSync(join(BYGGE, f), 'utf8'));
const POP = b('frys/block287k-population.json');
const PLAN = b('skrivplan.json');
const GRP = b('grupper.json');
const OVL = b('overlay.json');
const IDX = b('bl01/idx-full.json');
const DISC = b('disc-A.json');

const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag == null ? '' : diag) });
const produkt = POP.filter(u => u.CATEGORY === 'PRODUCT_REMEDIATION_REQUIRED');
const perKrav = new Map(GRP.grupper.map(g => [g.GROUP_REQUIREMENT_ID, g]));

/* NORM-01 · egna forekomster far inte kollapsa till ett gemensamt mal */
{
  const fel = [];
  // grupperade per fysiskt mal: vilka krav med EGNA, SKILDA forekomster delar mal?
  const perMal = new Map();
  for (const u of produkt) {
    const egna = u.FOREKOMSTER || u.forekomster;
    if (!Array.isArray(egna) || !egna.length) continue;
    const g = perKrav.get(u.id);
    if (!g) continue;
    for (const t of g.TARGET_ELEMENTS) {
      if (!t.TARGET_SOURCE_KEY) continue;
      const e = perMal.get(t.TARGET_SOURCE_KEY) || [];
      e.push({ id: u.id, egna: egna.slice().sort().join(','), mal: t.DEBUG_FRAME_ORD });
      perMal.set(t.TARGET_SOURCE_KEY, e);
    }
  }
  for (const [nyckel, lista] of perMal) {
    const distinkta = new Set(lista.map(x => x.egna));
    if (lista.length > 1 && distinkta.size > 1)
      fel.push({ NYCKEL: nyckel, KRAV: lista.map(x => x.id.split('::').slice(1, 4).join('::') + ' [' + x.egna + ']') });
  }
  prov('NORM-01', 'skilda kontroller med egna forekomster delar aldrig ett fysiskt mal',
    fel.length === 0, fel.slice(0, 2).map(f => f.NYCKEL.slice(-40) + ': ' + f.KRAV.join(' | ')).join('  //  '));

  // och malet ar faktiskt enhetens egen forekomst
  const oense = [];
  for (const u of produkt) {
    const egna = u.FOREKOMSTER || u.forekomster;
    if (!Array.isArray(egna) || !egna.length) continue;
    const g = perKrav.get(u.id);
    if (!g || !g.TARGET_ELEMENTS.length) continue;
    const mal = g.TARGET_ELEMENTS.map(t => t.DEBUG_FRAME_ORD).slice().sort().join(',');
    if (mal !== egna.slice().sort().join(',')) oense.push({ id: u.id, egna: egna.join(','), mal });
  }
  prov('NORM-01b', 'ett krav med egna forekomster pekar pa exakt dem',
    oense.length === 0, oense.slice(0, 3).map(x => x.id.split('::').slice(1, 3).join('::') + ' evidens=' + x.egna + ' mal=' + x.mal).join(' | '));
}

/* NORM-02 · ingen anspraklos namnform lever kvar som andra agare */
{
  const slug = t => String(t || '').normalize('NFD').replace(/[̀-ͯ]/g, '')
    .toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  // vilka texter ags av en ankrad kontroll?
  const agdText = new Map();
  for (const f of (DISC.forekomster || [])) {
    const o = OVL.forekomst[f.DISCOVERY_OCCURRENCE_ID];
    const agare = (o && o.klass === 'KNOWN_CONTROL' && o.agare) ? o.agare : null;
    if (!agare || !/::objekt::occ-[a-z]{12}$/.test(agare)) continue;
    const t = slug((o && o.namn) || f.text || '');
    if (f.art && t) agdText.set(f.art + '|' + t, agare);
  }
  const kvarlevande = [];
  for (const u of produkt) {
    const m = /^RP::[A-Z_0-9]+::([a-z0-9-]+)::(?:namn|text)::(.+)$/.exec(u.id);
    if (!m) continue;
    const annan = agdText.get(m[1] + '|' + m[2]);
    if (annan && annan !== u.OWNER_ID) kvarlevande.push({ id: u.id, agsAv: annan });
  }
  prov('NORM-02', 'ingen anspraklos namnform lever kvar som en andra agare',
    kvarlevande.length === 0, kvarlevande.slice(0, 3).map(x => x.id + ' <- ' + x.agsAv).join(' | '));
}

/* NORM-03 · den levande kontrollen finns kvar */
{
  // exakt det ankare som namnformen pensionerades till forman for
  const ankrad = produkt.filter(u => u.id === 'RP::ROLE_AND_NAME::kontosakerhet::objekt::occ-nlifsylrmkvj');
  const namnform = produkt.filter(u => /^RP::ROLE_AND_NAME::kontosakerhet::namn::bekrafta-nytt-losenord$/.test(u.id));
  const el = IDX.find(x => x.art === 'kontosakerhet' && x.ordProd === 12);
  prov('NORM-03', 'den ankrade kontrollen star kvar sedan namnformen pensionerades',
    ankrad.length === 1 && namnform.length === 0 && !!el && !!el.occ,
    'ankrad=' + ankrad.length + ' namnform=' + namnform.length + ' element=' + (el ? el.art + '#' + el.ordProd + ' ankare=' + el.occ : 'saknas'));
  const roll = ankrad[0] ? (ankrad[0].FINAL_ROLE || null) : null;
  prov('NORM-03b', 'den kvarvarande enheten kraver rollen ur Block 284, inte den olosta markoren',
    roll === 'textbox', 'FINAL_ROLE=' + roll);
}

/* NORM-04 · inget kallgrundat krav forsvann */
{
  const kravIPlan = new Set(PLAN.rader.flatMap(r => r.REQUIREMENT_IDS));
  const nyaRamar = new Set(PLAN.NYA_RAMAR.map(r => r.REQUIREMENT_ID));
  const terminala = new Set(PLAN.TERMINALA.map(r => r.REQUIREMENT_ID));
  const utan = produkt.filter(u => !kravIPlan.has(u.id) && !nyaRamar.has(u.id) && !terminala.has(u.id));
  prov('NORM-04', 'varje produktkrav har ett mal, en ny vy eller en skriven slutpunkt',
    utan.length === 0, utan.slice(0, 3).map(u => u.id).join(' | '));
  const kallgrundade = produkt.filter(u => /SOURCE_GROUNDED/.test(String(u.PROVENANCE || '')));
  prov('NORM-04b', 'inget kallgrundat krav saknar tackning',
    kallgrundade.every(u => kravIPlan.has(u.id) || nyaRamar.has(u.id) || terminala.has(u.id)),
    kallgrundade.filter(u => !kravIPlan.has(u.id) && !nyaRamar.has(u.id) && !terminala.has(u.id)).length + ' utan tackning');
}

for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id.padEnd(10) + r.vad + (r.ok ? '' : '  -> ' + r.diag));
console.log('\nNORM ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
