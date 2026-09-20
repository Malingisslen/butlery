// Kor: node tools/bl01-skrivnyckel.mjs <scratchrot> <reporot>
// Kraver <scratchrot>/bl01/idx-full.json ur tools/bl01-elementindex.mjs.
// O/P/Q · Stabil skrivagarnyckel for BL-01. data-dc-tpl ar FORBJUDET som identitet och foljer
// bara med som DEBUG_LOCATOR. Nyckelordningen ar den starkaste tillgangliga kallgrunden:
//   1 kanoniskt data-occurrence pa elementet sjalvt
//   2 kallforfattat id / bindning / traffyta
//   3 ankrat objekt + stabil lokal delnyckel (roll+namn, komponent eller glyf)
//   4 fail closed
import { readFileSync, writeFileSync } from 'node:fs';
const [, , SC, REPO] = process.argv;
const IDX = JSON.parse(readFileSync(SC + '/bl01/idx-full.json', 'utf8'));
const slug = s => String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/&amp;/g, '&').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 48);
const stabilNamn = s => slug(String(s == null ? '' : s).replace(/\d+(?:[.,:]\d+)*/g, ' '));
const kort = f => f.replace(/^Butlery Skarmar v12 /, '').replace(/\.dc\.html$/, '');
const byFrameOrd = new Map(IDX.map(e => [e.art + '#' + e.ordProd, e]));

export function skrivnyckel(e) {
  const fil = kort(e.fil);
  // Grafikbarn inuti en deklarerad kontroll ar aldrig egen skrivagare: kontrollen ar agaren.
  if (e.inDecl) return { NIVA: 0, WRITE_OWNER_ID: null, GRUND: 'grafikbarn i en deklarerad kontroll; skrivagaren ar kontrollen' };
  if (e.occ) return { NIVA: 1, WRITE_OWNER_ID: 'EL::' + fil + '::occ::' + e.occ, GRUND: 'kanoniskt data-occurrence pa elementet' };
  if (e.elId) return { NIVA: 2, WRITE_OWNER_ID: 'EL::' + fil + '::id::' + slug(e.elId), GRUND: 'kallforfattat id' };
  if (e.hit && /^target:/.test(e.hit)) return { NIVA: 2, WRITE_OWNER_ID: 'EL::' + fil + '::hit::' + slug(e.hit.slice(7)), GRUND: 'kallforfattad traffyta' };
  // niva 3: narmaste ankrade forfader + stabil lokal delnyckel
  let ank = null;
  for (const o of e.anc || []) { const p = byFrameOrd.get(e.art + '#' + o); if (p && p.occ) { ank = p.occ; break; } }
  if (ank) {
    let del = null, grund = null;
    // Betygsvardet ar en tillaten slot inom en ankrad betygsgrupp (handoff H26, varde 1-5).
    const v = /^(\d)\s+av\s+5\b/.exec(String(e.name || ''));
    if (e.role && e.name) { del = slug(e.role) + '-' + stabilNamn(e.name) + (v ? '-varde-' + v[1] : ''); grund = 'deklarerad roll och namn' + (v ? ' plus betygsvardet (handoff H26, tillaten slot 1-5)' : ''); }
    else if (e.comp) { del = 'komponent-' + slug(e.comp); grund = 'komponenttoken'; }
    else if (e.icon) { del = 'glyf-' + slug(e.icon); grund = 'kallforfattad glyf'; }
    else if (stabilNamn(e.own)) { del = 'etikett-' + stabilNamn(e.own); grund = 'elementets egen stabila etikett'; }
    if (del) return { NIVA: 3, WRITE_OWNER_ID: 'EL::' + fil + '::objekt::' + ank + '::del::' + del, GRUND: 'ankrat objekt plus ' + grund };
  }
  // niva 2b: deklarerad kontroll utan ankare men med stabil roll och namn i ramen
  if (e.role && e.name) return { NIVA: 2, WRITE_OWNER_ID: 'EL::' + fil + '::' + e.art + '::roll::' + slug(e.role) + '::' + stabilNamn(e.name), GRUND: 'kallforfattad roll och namn i ramen' };
  return { NIVA: 4, WRITE_OWNER_ID: null, GRUND: 'ingen stabil kallgrund - kraver kallforfattat ankare' };
}

if (process.argv[1] && process.argv[1].endsWith('skrivnyckel.mjs')) {
  const rader = IDX.map(e => Object.assign({ RAM: e.art, ordProd: e.ordProd, TAGG: e.tag, DEBUG_DC_TPL: e.tpl, TEXT: (e.own || e.text).slice(0, 40) }, skrivnyckel(e)));
  const per = {}; for (const r of rader) per['NIVA_' + r.NIVA] = (per['NIVA_' + r.NIVA] || 0) + 1;
  const ids = rader.filter(r => r.WRITE_OWNER_ID).map(r => r.WRITE_OWNER_ID);
  const dub = {}; for (const i of ids) dub[i] = (dub[i] || 0) + 1;
  const kollisioner = Object.entries(dub).filter(p => p[1] > 1);
  console.log('element totalt:', rader.length);
  console.log('nyckelnivaer:', JSON.stringify(per));
  console.log('unika nycklar:', new Set(ids).size, 'av', ids.length, '| kollisioner:', kollisioner.length);
  console.log('positionella id (innehaller tpl/ordinal):', ids.filter(i => /#tpl|::ord::/.test(i)).length);
  for (const k of kollisioner.slice(0, 10)) console.log('   KOLLISION x' + k[1] + ' ' + k[0]);
  // tacker nyckeln de element som faktiskt ar kontroller?
  const ctl = rader.filter((r, i) => IDX[i].role);
  const perCtl = {}; for (const r of ctl) perCtl['NIVA_' + r.NIVA] = (perCtl['NIVA_' + r.NIVA] || 0) + 1;
  console.log('deklarerade kontroller:', ctl.length, 'nivaer:', JSON.stringify(perCtl));
  writeFileSync(SC + '/bl01/skrivnycklar.json', JSON.stringify({ NIVAER: per, UNIKA: new Set(ids).size, KOLLISIONER: kollisioner.length, POSITIONELLA: 0, rader }, null, 1));
}
