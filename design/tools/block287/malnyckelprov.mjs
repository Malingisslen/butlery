// Kor: node tools/block287/malnyckelprov.mjs <elementindex.json>
// G · TK-01..TK-12 · malnyckeln far aldrig bero pa position, text, namn, farg eller ordning.
import { readFileSync } from 'node:fs';
import { malnyckel, delnyckel, agandeElement, nollstall, TARGET_KEY_CONTRACT_VERSION } from './malnyckel.mjs';
import { ramIndex } from '../bl01-skrivnyckel.mjs';

const IDX = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag == null ? '' : diag) });
const kopia = o => JSON.parse(JSON.stringify(o));

// en agare med flera delar: valj en deklarerad kontroll som har barn med egen text
const RAM0 = ramIndex(IDX);
const kandidater = IDX.filter(e => e.inDecl && (e.icon || e.own));
const del = kandidater.find(e => { nollstall(); const k = malnyckel(e, RAM0); return !!k.TARGET_SOURCE_KEY; });
if (!del) { console.log('ROD  TK-00 hittar ingen delnyckelbar del'); process.exit(1); }
const agare = agandeElement(del, RAM0);

/** bygger ett index ur en muterad elementlista */
const medIndex = lista => ramIndex(lista);
const nyckelAv = (e, lista) => { nollstall(); const r = malnyckel(e, medIndex(lista)); nollstall(); return r.TARGET_SOURCE_KEY || ('OLOST: ' + r.SKAL); };

const bas = nyckelAv(del, IDX);

{ // TK-01/02/03/08/12: positionsoberoende
  // Ett infogat eller raderat syskon flyttar ALLA senare ordinaler i ramen, inklusive
  // forfaderkedjans. Provet maste darfor skifta hela ramen konsekvent.
  const skifta = (lista, ram, fran, delta) => lista.map(e => {
    if (e.art !== ram) return e;
    const k = kopia(e);
    if (k.ordProd >= fran) k.ordProd += delta;
    k.anc = (k.anc || []).map(o => (o >= fran ? o + delta : o));
    return k;
  });
  const grans = Math.max(0, del.ordProd - 1);
  const infogad = skifta(IDX, del.art, grans, 1);
  const malEfter = infogad.find(e => e.art === del.art && e.ordProd === del.ordProd + 1);
  prov("TK-01", "orelaterat syskon infogas fore malet -> malnyckeln oforandrad", nyckelAv(malEfter, infogad) === bas, nyckelAv(malEfter, infogad));
  const raderad = skifta(IDX, del.art, grans, -1);
  const malEfter2 = raderad.find(e => e.art === del.art && e.ordProd === del.ordProd - 1);
  prov("TK-02", "orelaterat syskon raderas -> oforandrad", nyckelAv(malEfter2, raderad) === bas, nyckelAv(malEfter2, raderad));
  const omkastad = IDX.slice().reverse();
  prov("TK-03", "syskon kastas om -> oforandrad", nyckelAv(del, omkastad) === bas, bas);
  const tpl = IDX.map(e => Object.assign(kopia(e), { tpl: String(Number(e.tpl) + 999) }));
  prov("TK-08", "radnummer och dc-tpl flyttar sig -> oforandrad", nyckelAv(tpl.find(e => e.art === del.art && e.ordProd === del.ordProd), tpl) === bas, bas);
  const nyttBarn = IDX.concat([Object.assign(kopia(del), { ordProd: 99999, own: "nytt orelaterat barn", icon: null, partOcc: null })]);
  prov("TK-12", "nytt orelaterat barn -> befintligt mal byter inte namn", nyckelAv(del, nyttBarn) === bas, bas);
}
{ // TK-04..TK-07: innehalls- och utseendeoberoende
  const byt = (f, v) => IDX.map(e => (e.art === del.art && e.ordProd === del.ordProd) ? Object.assign(kopia(e), f(e, v)) : e);
  const text = byt(e => ({ own: 'helt annan synlig text', text: 'helt annan synlig text' }));
  prov('TK-04', 'synlig text andras -> oforandrad', nyckelAv(text.find(e => e.art === del.art && e.ordProd === del.ordProd), text) === bas, bas);
  const namn = IDX.map(e => (e.art === agare.art && e.ordProd === agare.ordProd) ? Object.assign(kopia(e), { name: String(e.name || '') + ', rattat' }) : e);
  prov('TK-05', 'agarens tillgangliga namn andras -> oforandrad', nyckelAv(del, namn) === bas, bas);
  const roll = IDX.map(e => (e.art === agare.art && e.ordProd === agare.ordProd) ? Object.assign(kopia(e), { role: e.role === 'button' ? 'link' : 'button' }) : e);
  prov('TK-06', 'rollremediering pa agaren -> oforandrad', nyckelAv(del, roll) === bas, bas);
  const farg = byt(e => ({ bgC: 'rgb(9, 9, 9)', fgC: 'rgb(8, 8, 8)', style: String(e.style || '') + ';background:#090909' }));
  prov('TK-07', 'farg, token och varde andras -> oforandrad', nyckelAv(farg.find(e => e.art === del.art && e.ordProd === del.ordProd), farg) === bas, bas);
}
{ // TK-09/10/11
  const tvaAgare = [...new Set(IDX.filter(e => e.inDecl && e.icon).map(e => { const a = agandeElement(e, RAM0); return a ? a.art + '#' + a.ordProd : null; }).filter(Boolean))].slice(0, 2);
  const delarA = IDX.filter(e => { const a = agandeElement(e, RAM0); return a && (a.art + '#' + a.ordProd) === tvaAgare[0] && e !== a; });
  const delarB = IDX.filter(e => { const a = agandeElement(e, RAM0); return a && (a.art + '#' + a.ordProd) === tvaAgare[1] && e !== a; });
  const kA = delarA.map(e => nyckelAv(e, IDX)).filter(k => !/^OLOST/.test(k));
  const kB = delarB.map(e => nyckelAv(e, IDX)).filter(k => !/^OLOST/.test(k));
  prov('TK-09', 'likadana delar under skilda ankrade agare far skilda malnycklar',
    kA.length && kB.length && !kA.some(x => kB.includes(x)), kA[0] + ' / ' + kB[0]);
  // tva omojliga att skilja: tva identiska syskon utan glyf, text eller komponent
  const tvilling = Object.assign(kopia(del), { ordProd: del.ordProd + 1 });
  const medTvilling = IDX.concat([tvilling]);
  const r = (() => { nollstall(); const x = malnyckel(tvilling, medIndex(medTvilling)); nollstall(); return x; })();
  prov('TK-10', 'tva semantiskt oskiljbara delar i samma agare faller stangt', !!r.PART_METADATA_REQUIRED, r.SKAL || r.TARGET_SOURCE_KEY);
  const flera = delarA.map(e => ({ e, k: nyckelAv(e, IDX) })).filter(x => !/^OLOST/.test(x.k));
  const agarnycklar = new Set(flera.map(x => x.k.split('::del::')[0]));
  prov('TK-11', 'en agare med flera deklarationsbarare ger en agarnyckel och flera malnycklar',
    flera.length >= 2 ? agarnycklar.size === 1 && new Set(flera.map(x => x.k)).size === flera.length : true,
    flera.length + ' delar, ' + agarnycklar.size + ' agarnyckel');
}
console.log('TARGET_KEY_CONTRACT_VERSION =', TARGET_KEY_CONTRACT_VERSION);
for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id + '  ' + r.vad + (r.ok ? '' : '  -> ' + r.diag));
console.log('\nPROV ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
