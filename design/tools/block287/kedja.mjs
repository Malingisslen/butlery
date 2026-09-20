// Kor: node tools/block287/kedja.mjs --root=<kallrot> --ut=<byggkatalog> [--filordning=fallande]
//      [--hoppa-skord] [--krom=<sokvag>]
//
// Hela Block 287-kedjan fran noll, enbart ur repot. Ingen arbetsmapp, inget
// externt underlag, ingen chatthistorik. Samma anrop ger samma artefakter.
//
//   1 elementindex        renderat i huvudlost Chrome
//   2 censusomprovning    H/I, reglerna R1-R5 till fixpunkt
//   3 overlagg            korrigeringsrunda 2, harlett
//   4 extrakrav           korrigeringsrunda 1 och 2, harledda
//   5 upptackt            forekomster, klassning, familjer, agare
//   6 skord               detektorns primitiver
//   7 baslinjebygge       ogonblicksbild av Block 282-286
//   8 population          enheter och status
//   9 mork matning        den patvingade morklagesmatningen
//  10 frysning            population, status, skrivplan, ankarkarta
//  11 gruppexpansion      varje krav till exakta kallelement
//  12 skrivplan           en rad per fysisk skrivning
//  13 fyndstangning       M1 och M5 mot faktiska artefakter
//  14 m2prov              kravet far aldrig vara sitt eget bevis
import { mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const flagga = n => process.argv.includes('--' + n);
const ROT = arg('root') || process.cwd();
const UT = arg('ut');
if (!UT) { console.error('kedja.mjs kraver --ut=<byggkatalog>'); process.exit(2); }
const ORDNING = arg('filordning') || 'stigande';
mkdirSync(join(UT, 'bl01'), { recursive: true });

const steg = [];
function kor(namn, fil, argv, env) {
  const t0 = Date.now();
  const ut = execFileSync(process.execPath, [join(ROT, fil), ...argv],
    { cwd: ROT, encoding: 'utf8', maxBuffer: 1 << 28, env: { ...process.env, ...(env || {}) } });
  steg.push({ STEG: namn, SEKUNDER: Math.round((Date.now() - t0) / 1000) });
  return ut;
}
const p = f => join(UT, f);

// 1 · elementindex
kor('elementindex', 'tools/bl01-elementindex.mjs', [ROT, p('bl01/idx-full.json')]);
// 2 · censusomprovning (laser <ut>/bl01/idx-full.json, skriver <ut>/bl01/census-reopen.json)
kor('censusomprovning', 'tools/block287-censusomprovning.mjs', [UT, ROT]);
// 3 · overlagget for korrigeringsrunda 2
kor('overlagg', 'tools/block287/overlay-r2.mjs',
  ['--root=' + ROT, '--index=' + p('bl01/idx-full.json'), '--omprovning=' + p('bl01/census-reopen.json'), '--ut=' + p('overlay.json')]);
// 4 · extrakraven
kor('extrakrav', 'tools/block287/extrakrav-r2.mjs',
  ['--root=' + ROT, '--index=' + p('bl01/idx-full.json'), '--ut=' + p('extra-krav.json')]);
// 5 · upptackten, tva ganger med omvand filordning
kor('upptackt-A', 'tools/discovery-population.mjs',
  ['--ut=' + p('disc-A.json'), '--historisk=d0c86f6', '--historisk-population=fas2/kandidatklustring.json']);
kor('upptackt-B', 'tools/discovery-population.mjs',
  ['--ut=' + p('disc-B.json'), '--filordning=' + (ORDNING === 'fallande' ? 'stigande' : 'fallande'),
   '--historisk=d0c86f6', '--historisk-population=fas2/kandidatklustring.json']);
// 6 · skorden
if (!flagga('hoppa-skord') || !existsSync(p('skord.json')))
  kor('skord', 'tools/block287/skorda.mjs', ['--root=' + ROT, '--ut=' + p('skord.json'), '--filordning=' + ORDNING]);
// 7-8 · baslinje och population
const miljo = { MAT: join(ROT, 'fas2', 'matning'), TMPUT: UT, UPPTACKT_A: p('disc-A.json'), UPPTACKT_B: p('disc-B.json'), OVERLAY: p('overlay.json') };
kor('baslinje', 'tools/block287/bas-build.mjs', ['--root=' + ROT, '--snapshot-ut=' + p('bas.json')], miljo);
// build.mjs skriver sitt resultat till stdout: en gang for bygget, en gang for enheterna
writeFileSync(p('ut.json'), kor('population', 'tools/block287/build.mjs',
  ['--root=' + ROT, '--snapshot-ut=' + p('snap.json'), '--skord=' + p('skord.json')], miljo));
writeFileSync(p('enheter.json'), kor('enheter', 'tools/block287/build.mjs',
  ['--root=' + ROT, '--snapshot-in=' + p('snap.json'), '--skord=' + p('skord.json'), '--detalj=enheter'], miljo));
// 9 · mork matning
kor('mork-matning', 'tools/bl01-morkprob.mjs', [ROT, p('mork.json')]);
// 10 · frysning
mkdirSync(p('frys'), { recursive: true });
kor('frysning', 'tools/block287/frys.mjs',
  ['--root=' + ROT, '--bygge=' + p('ut.json'), '--enheter=' + p('enheter.json'), '--overlay=' + p('overlay.json'),
   '--extra=' + p('extra-krav.json'), '--index=' + p('bl01/idx-full.json'), '--skord=' + p('skord.json'),
   '--ut=' + p('frys')]);
// 11 · gruppexpansion
kor('gruppexpansion', 'tools/block287/gruppexpansion.mjs',
  ['--root=' + ROT, '--index=' + p('bl01/idx-full.json'), '--population=' + p('frys/block287k-population.json'),
   '--snapshot=' + p('snap.json'), '--overlay=' + p('overlay.json'), '--bygge=' + p('ut.json'),
   '--skord=' + p('skord.json'), '--mork=' + p('mork.json'), '--tokens=' + join(ROT, 'tokens.json'),
   '--ut=' + p('grupper.json')]);

// 12 · slutlig skrivplan
kor('skrivplan', 'tools/block287/skrivplan.mjs',
  ['--population=' + p('frys/block287k-population.json'), '--grupper=' + p('grupper.json'),
   '--index=' + p('bl01/idx-full.json'), '--ut=' + p('skrivplan.json')]);
// 13 · fyndstangning M1 och M5
kor('fyndstangning', 'tools/block287/fyndstangning.mjs',
  ['--population=' + p('frys/block287k-population.json'), '--grupper=' + p('grupper.json'),
   '--skrivplan=' + p('skrivplan.json'), '--mork=' + p('mork.json'), '--root=' + ROT, '--ut=' + p('fynd.json')]);
// 14 · M2-regressionen
kor('m2prov', 'tools/block287/m2prov.mjs',
  ['--root=' + ROT, '--overlay=' + p('overlay.json'), '--population=' + p('frys/block287k-population.json'),
   '--index=' + p('bl01/idx-full.json'), '--ut=' + p('m2.json')]);

writeFileSync(p('kedja.json'), JSON.stringify({ $om: 'Block 287 · hela kedjan ur repot', ROT, UT, FILORDNING: ORDNING, steg }, null, 1) + '\n');
console.log(JSON.stringify({ KEDJA_KLAR: true, FILORDNING: ORDNING, steg }, null, 1));
