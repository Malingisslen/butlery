// Kor: node tools/block287/frysvalidatorprov.mjs --root=<kallrot> --bygge=<byggkatalog>
// P · FV-01..FV-10 · varje mutation MASTE falla validatorn.
// En validator som star kvar pa PASS efter nagon av dem ar sjalv ett blockerande fel.
import { readFileSync, writeFileSync, mkdtempSync, cpSync, rmSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { bind, validera } from './frysvalidator.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const ROT = arg('root'), BYGGE = arg('bygge');
const MANIFEST = bind(ROT, BYGGE);

const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag == null ? '' : diag) });

/** Kor en mutation i en kopia och kraver att validatorn faller. */
function mutera(id, vad, muteraFn) {
  const tmp = mkdtempSync(join(tmpdir(), 'fv-'));
  try {
    const rot = join(tmp, 'rot'), bygge = join(tmp, 'bygge');
    // bara de filer validatorn laser, sa provet forblir snabbt och exakt
    cpSync(BYGGE, bygge, { recursive: true });
    const filer = readdirSync(ROT).filter(f => /^Butlery .*\.dc\.html$/.test(f));
    cpSync(ROT, rot, { recursive: true, filter: (s) => {
      const b = s.split(/[\\/]/).pop();
      return s === ROT || filer.includes(b);
    } });
    muteraFn(rot, bygge);
    const r = validera(bind(rot, bygge), MANIFEST);
    prov(id, vad, !r.PASS, r.PASS ? 'validatorn stod kvar pa PASS' : r.AVVIKELSER.map(a => a.NYCKEL).join(', '));
  } finally { rmSync(tmp, { recursive: true, force: true }); }
}

const laasJ = (d, f) => JSON.parse(readFileSync(join(d, f), 'utf8'));
const skrivJ = (d, f, o) => writeFileSync(join(d, f), JSON.stringify(o, null, 1) + String.fromCharCode(10));
const forstaFil = rot => readdirSync(rot).filter(f => /^Butlery .*\.dc\.html$/.test(f)).sort()[0];
/** forsta filen som faktiskt bar ett ankare - annars muterar provet ingenting */
const forstaMedAnkare = rot => readdirSync(rot).filter(f => /^Butlery .*\.dc\.html$/.test(f)).sort()
  .find(f => /data-occurrence="occ-[a-z]{12}"/.test(readFileSync(join(rot, f), 'utf8')))
  || (() => { throw new Error('ingen fil bar ett ankare'); })();

prov('FV-00', 'orord bindning ger PASS', validera(bind(ROT, BYGGE), MANIFEST).PASS, '');

mutera('FV-01', 'nytt semantiskt ankare i kallan => FAIL', rot => {
  const f = forstaFil(rot), p = join(rot, f);
  const s = readFileSync(p, 'utf8');
  writeFileSync(p, s.replace('<div', '<div data-occurrence="occ-zzzzzzzzzzzz"'));
});
mutera('FV-02', 'ett semantiskt ankare borttaget => FAIL', rot => {
  const f = forstaMedAnkare(rot), p = join(rot, f);
  const s = readFileSync(p, 'utf8');
  writeFileSync(p, s.replace(/\s?data-occurrence="occ-[a-z]{12}"/, ''));
});
mutera('FV-03', 'ett semantiskt ankare andrat => FAIL', rot => {
  const f = forstaMedAnkare(rot), p = join(rot, f);
  const s = readFileSync(p, 'utf8');
  writeFileSync(p, s.replace(/data-occurrence="occ-[a-z]{12}"/, 'data-occurrence="occ-qqqqqqqqqqqq"'));
});
mutera('FV-04', 'en populationsrad muterad => FAIL', (rot, bygge) => {
  const pop = laasJ(bygge, 'frys/block287k-population.json');
  pop[0] = { ...pop[0], id: pop[0].id + '::MUTERAD' };
  skrivJ(bygge, 'frys/block287k-population.json', pop);
});
mutera('FV-05', 'en status muterad, id oforandrade => FAIL', (rot, bygge) => {
  const pop = laasJ(bygge, 'frys/block287k-population.json');
  const i = pop.findIndex(u => u.CURRENT_STATUS);
  pop[i] = { ...pop[i], CURRENT_STATUS: 'MUTERAD_STATUS' };
  skrivJ(bygge, 'frys/block287k-population.json', pop);
});
mutera('FV-06', 'en malnyckel muterad => FAIL', (rot, bygge) => {
  const g = laasJ(bygge, 'grupper.json');
  const rad = g.grupper.find(x => x.TARGET_ELEMENTS.some(t => t.TARGET_SOURCE_KEY));
  const t = rad.TARGET_ELEMENTS.find(x => x.TARGET_SOURCE_KEY);
  t.TARGET_SOURCE_KEY = t.TARGET_SOURCE_KEY + '::MUTERAD';
  skrivJ(bygge, 'grupper.json', g);
});
mutera('FV-07', 'en skrivagare muterad => FAIL', (rot, bygge) => {
  const p = laasJ(bygge, 'skrivplan.json');
  p.rader[0].WRITE_OWNER_ID = String(p.rader[0].WRITE_OWNER_ID) + '::MUTERAD';
  skrivJ(bygge, 'skrivplan.json', p);
});
mutera('FV-08', 'kallan driver, ankarna ororda => FAIL', rot => {
  const f = forstaFil(rot), p = join(rot, f);
  writeFileSync(p, readFileSync(p, 'utf8').replace('</body>', '<!-- drift --></body>'));
});
mutera('FV-09', 'en gruppmedlem borttagen => FAIL', (rot, bygge) => {
  const g = laasJ(bygge, 'grupper.json');
  const rad = g.grupper.find(x => x.TARGET_ELEMENTS.length > 1);
  rad.TARGET_ELEMENTS.pop();
  skrivJ(bygge, 'grupper.json', g);
});
mutera('FV-10', 'en fysisk delnyckel i kallan muterad => FAIL', rot => {
  const filer = readdirSync(rot).filter(f => /^Butlery .*\.dc\.html$/.test(f));
  for (const f of filer) {
    const p = join(rot, f), s = readFileSync(p, 'utf8');
    if (/data-part-occurrence="/.test(s)) {
      writeFileSync(p, s.replace(/data-part-occurrence="([^"]+)"/, 'data-part-occurrence="$1-muterad"'));
      return;
    }
  }
  throw new Error('ingen delnyckel att mutera');
});

for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id + '  ' + r.vad + '  -> ' + r.diag);
const fv = res.filter(r => r.id !== 'FV-00');
console.log('\nFV01_FV10 ' + fv.filter(r => r.ok).length + '/' + fv.length
  + (res.find(r => r.id === 'FV-00').ok ? '' : '  (VARNING: orord bindning gav inte PASS)'));
process.exit(res.every(r => r.ok) ? 0 : 1);
