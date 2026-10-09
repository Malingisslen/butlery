#!/usr/bin/env node
// F2-R04 · METODPROV FOR KANALVIS KOLLATERALKLASSIFICERING.  CB-01 … CB-04
//
// Felklassen: atta element flaggades som kollaterala nar de arvde en avsedd
// andring. Deras ramfarger ar currentColor och foljde den injicerade texten.

import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { kanalvis, KANAL } from './preview-simulation.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (OUT) { const o = resolve(OUT);
  if (o.startsWith(resolve('.') + '\\') || o.startsWith(resolve('.') + '/')) {
    console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
  mkdirSync(o, { recursive: true }); }
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });
const A = 'prov';
const rad = (color, bg, ram, grafik) => color + '|' + bg + '|' + ram + '|' + grafik;
const fyra = c => [c, c, c, c].join(',');
const LJUS = 'rgb(245, 244, 237)', MORK = 'rgb(201, 211, 196)';

/* CB-01 · avsedd textagare far lagligt andra beroende ram */
{ const fore = { [A]: [rad(LJUS, 'rgba(0, 0, 0, 0)', fyra(LJUS), 'none,none'),
    rad(LJUS, 'rgba(0, 0, 0, 0)', fyra(LJUS), 'none,none')] };
  const efter = { [A]: [rad(MORK, 'rgba(0, 0, 0, 0)', fyra(MORK), 'none,none'),
    rad(MORK, 'rgba(0, 0, 0, 0)', fyra(MORK), 'none,none')] };
  const r = kanalvis(fore, efter, [{ art: A, ordinal: 0, egenskap: 'color' }], A);
  prov('CB-01', 'en avsedd textagare far lagligt andra en beroende ramfarg',
    r.avsedda === 1 && r.arvda === 1 && r.kollaterala === 0,
    'ordinal 0 avsedd · ordinal 1 arvd via currentColor · 0 kollaterala'); }

/* CB-02 · beroende kanal rapporteras som arvd, inte kollateral */
{ const fore = { [A]: [rad(LJUS, 'x', fyra(LJUS), 'none,none'), rad(LJUS, 'x', fyra(LJUS), 'none,none')] };
  const efter = { [A]: [rad(MORK, 'x', fyra(MORK), 'none,none'), rad(MORK, 'x', fyra(MORK), 'none,none')] };
  const r = kanalvis(fore, efter, [{ art: A, ordinal: 0, egenskap: 'color' }], A);
  const arvd = r.rader.find(x => x.ordinal === 1);
  prov('CB-02', 'den beroende kanalen rapporteras som ARVD_BEROENDE med skal',
    arvd.klass === 'ARVD_BEROENDE' && arvd.kanaler.includes(KANAL.COLOR) &&
    arvd.kanaler.includes(KANAL.RAM) && /currentColor/.test(arvd.skal),
    arvd.klass + ' · kanaler ' + JSON.stringify(arvd.kanaler) + ' · ' + arvd.skal); }

/* CB-03 · orelaterad ramandring forblir kollateral */
{ const fore = { [A]: [rad(LJUS, 'x', fyra(LJUS), 'none,none'),
    rad(LJUS, 'x', fyra('rgb(1, 2, 3)'), 'none,none')] };
  const efter = { [A]: [rad(MORK, 'x', fyra(MORK), 'none,none'),
    rad(LJUS, 'x', fyra('rgb(9, 9, 9)'), 'none,none')] };
  const r = kanalvis(fore, efter, [{ art: A, ordinal: 0, egenskap: 'color' }], A);
  const x = r.rader.find(y => y.ordinal === 1);
  prov('CB-03', 'en ramandring som inte foljer color forblir kollateral',
    x.klass === 'KOLLATERAL' && r.kollaterala === 1 && !r.ok,
    'ordinal 1: color oforandrad men ramen bytte -> ' + x.klass); }

/* CB-04 · tvetydigt agarskap faller stangt */
{ const fore = { [A]: [rad(LJUS, 'x', fyra(LJUS), 'none,none'),
    rad(LJUS, 'x', fyra('rgb(1, 2, 3)'), 'none,none')] };
  const efter = { [A]: [rad(MORK, 'x', fyra(MORK), 'none,none'),
    rad(MORK, 'x', fyra('rgb(9, 9, 9)'), 'none,none')] };
  const r = kanalvis(fore, efter, [{ art: A, ordinal: 0, egenskap: 'color' }], A);
  const x = r.rader.find(y => y.ordinal === 1);
  prov('CB-04', 'tvetydigt agarskap faller stangt i stallet for att gissa',
    x.klass === 'OKAND' && r.okanda === 1 && !r.ok,
    'color OCH ram andrades men ramen foljer inte color -> ' + x.klass + ' · ' + x.skal); }

const ANTAL = 4;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('KANALPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
if (OUT) writeFileSync(join(resolve(OUT), 'kanalprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
