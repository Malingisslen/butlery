#!/usr/bin/env node
// Butlery · verifierar att genererad kod är körbar, inte bara skriven.
// Kör EFTER gen-css och gen-flutter. Exit 1 vid fel.
// dart analyze körs separat i CI — det här testet fångar det som går att fånga utan Dart.
import { readFileSync, existsSync } from 'node:fs';

const errors = [];
const fail = m => errors.push(m);
const CSS = 'assets/generated/tokens.css';
const DART = 'lib/theme/butlery_tokens.dart';

for (const f of [CSS, DART]) if (!existsSync(f)) fail(f + ' finns inte — kör generatorerna först');
if (errors.length) { errors.forEach(e => console.error('✖ ' + e)); process.exit(1); }

/* ---------- CSS ---------- */
{
  const css = readFileSync(CSS, 'utf8');
  if (css.includes('[object Object]')) fail('CSS: [object Object] — ett objekt har serialiserats som värde');
  if (/--butlery--/.test(css)) fail('CSS: dubbelt bindestreck i variabelnamn');
  const open = (css.match(/{/g) || []).length, close = (css.match(/}/g) || []).length;
  if (open !== close) fail('CSS: obalanserade klamrar (' + open + ' mot ' + close + ')');

  const declared = new Set();
  for (const m of css.matchAll(/(--butlery-[a-z0-9-]+)\s*:/g)) declared.add(m[1]);
  for (const m of css.matchAll(/var\((--butlery-[a-z0-9-]+)\)/g))
    if (!declared.has(m[1])) fail('CSS: var(' + m[1] + ') refererar en variabel som inte deklareras');

  // Varje deklarationsrad ska vara "--namn: värde;" och värdet får inte vara tomt.
  for (const line of css.split('\n')) {
    const l = line.trim();
    if (!l.startsWith('--')) continue;
    if (!/^--[a-z0-9-]+:\s*[^;]+;$/.test(l)) fail('CSS: ogiltig deklaration: ' + l);
    if (/:\s*(undefined|null|NaN)/.test(l)) fail('CSS: odefinierat värde: ' + l);
  }
  const n = declared.size;
  if (n < 80) fail('CSS: bara ' + n + ' variabler — generatorn har tappat en grupp');
  console.log('CSS: ' + n + ' variabler, ' + open + ' block');
}

/* ---------- Dart ---------- */
{
  const dart = readFileSync(DART, 'utf8');
  if (dart.includes('[object Object]')) fail('Dart: [object Object]');
  if (/(undefined|NaN)/.test(dart)) fail('Dart: odefinierat värde i utdata');
  const open = (dart.match(/{/g) || []).length, close = (dart.match(/}/g) || []).length;
  if (open !== close) fail('Dart: obalanserade klamrar (' + open + ' mot ' + close + ')');
  const par = (dart.match(/\(/g) || []).length, parc = (dart.match(/\)/g) || []).length;
  if (par !== parc) fail('Dart: obalanserade parenteser (' + par + ' mot ' + parc + ')');

  for (const line of dart.split('\n')) {
    const l = line.trim();
    if (!l.startsWith('static const') && !l.startsWith('static final')) continue;
    if (!l.endsWith(';')) fail('Dart: oavslutad deklaration: ' + l);
  }
  for (const m of dart.matchAll(/Color\(0x([0-9A-F]+)\)/g))
    if (m[1].length !== 8) fail('Dart: Color(0x' + m[1] + ') har ' + m[1].length + ' siffror, ska ha 8 (ARGB)');

  // Varje klass som refereras ska också definieras i filen.
  const defined = new Set([...dart.matchAll(/class (\w+)/g)].map(m => m[1]));
  for (const m of dart.matchAll(/\b(Butlery[A-Z]\w+)\./g))
    if (!defined.has(m[1])) fail('Dart: ' + m[1] + ' refereras men definieras inte');

  const nClasses = defined.size;
  const nColors = (dart.match(/Color\(0x/g) || []).length;
  if (nClasses < 6) fail('Dart: bara ' + nClasses + ' klasser — förväntar Colors, Space, Radius, Touch, Motion, Type, Theme');
  if (nColors < 40) fail('Dart: bara ' + nColors + ' färger');
  console.log('Dart: ' + nClasses + ' klasser, ' + nColors + ' färger');
}

if (errors.length) { errors.forEach(e => console.error('✖ ' + e)); console.error('\n' + errors.length + ' fel'); process.exit(1); }
console.log('\nGenererad kod OK.');
