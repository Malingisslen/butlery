// Kor: node tools/block287/reproprov.mjs --a=<byggkatalog A> --b=<byggkatalog B> [--root=<kallrot>]
//
// S/N · Tva korningar av kedjan maste ge byteidentiska kanoniska artefakter.
// Filordningen far inte synas nagonstans i resultatet.
import { readFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join } from 'node:path';
import { bind } from './frysvalidator.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
const A = arg('a'), B = arg('b'), ROT = arg('root') || '.';
const h = s => createHash('sha256').update(s).digest('hex').slice(0, 16);

// Kanoniska artefakter. bas.json, snap.json och ut.json bar matklockor och
// sokvagar och ar avsiktligt inte med.
const KANONISKA = [
  'overlay.json', 'extra-krav.json',
  'frys/block287k-population.json', 'frys/block287k-status.json',
  'frys/block287k-forekomster.json', 'frys/block287k-ankarkarta.json',
  'grupper.json', 'skrivplan.json', 'fynd.json', 'm2.json', 'mork.json'
];
const rader = [];
for (const f of KANONISKA) {
  const pa = join(A, f), pb = join(B, f);
  if (!existsSync(pa) || !existsSync(pb)) { rader.push({ FIL: f, STATUS: 'SAKNAS', A: existsSync(pa), B: existsSync(pb) }); continue; }
  const sa = readFileSync(pa, 'utf8'), sb = readFileSync(pb, 'utf8');
  rader.push({ FIL: f, STATUS: sa === sb ? 'IDENTISK' : 'SKILJER', HASH_A: h(sa), HASH_B: h(sb), BYTE_A: sa.length, BYTE_B: sb.length });
}
// upptacktens fingeravtryck jamfors pa sina egna falt
for (const f of ['disc-A.json', 'disc-B.json']) {
  const pa = join(A, f), pb = join(B, f);
  if (!existsSync(pa) || !existsSync(pb)) continue;
  const a = JSON.parse(readFileSync(pa, 'utf8')), b = JSON.parse(readFileSync(pb, 'utf8'));
  rader.push({ FIL: f + ' (FINGERAVTRYCK)', STATUS: JSON.stringify(a.FINGERAVTRYCK) === JSON.stringify(b.FINGERAVTRYCK) ? 'IDENTISK' : 'SKILJER',
    HASH_A: h(JSON.stringify(a.FINGERAVTRYCK)), HASH_B: h(JSON.stringify(b.FINGERAVTRYCK)) });
}
const ba = bind(ROT, A), bb = bind(ROT, B);
const bindAvvik = Object.keys(ba).filter(k => String(ba[k]) !== String(bb[k]));

for (const r of rader) console.log((r.STATUS === 'IDENTISK' ? 'GRON ' : 'ROD  ') + r.FIL.padEnd(42) + r.STATUS
  + (r.STATUS === 'SKILJER' ? '  ' + r.HASH_A + ' != ' + r.HASH_B : ''));
console.log('\nbindningens nycklar som skiljer: ' + bindAvvik.length + (bindAvvik.length ? '  ' + bindAvvik.join(', ') : ''));
const ok = rader.every(r => r.STATUS === 'IDENTISK') && bindAvvik.length === 0;
console.log('BYTE_IDENTICAL ' + (ok ? 'YES' : 'NO') + '  (' + rader.filter(r => r.STATUS === 'IDENTISK').length + '/' + rader.length + ')');
process.exit(ok ? 0 : 1);
