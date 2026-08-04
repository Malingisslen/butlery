#!/usr/bin/env node
// Butlery · verifierar att genererad kod är körbar, inte bara skriven.
// Kör EFTER gen-css och gen-flutter. Exit 1 vid fel.
// dart analyze körs separat i CI — det här testet fångar det som går att fånga utan Dart.
import { readFileSync, existsSync } from 'node:fs';
import { checkAppTheme } from './check-app-theme.mjs';

const errors = [];
const fail = m => errors.push(m);
const TOKENS = JSON.parse(readFileSync('tokens.json', 'utf8'));
const MAP = JSON.parse(readFileSync('tools/app-theme-map.json', 'utf8'));
const BRAND = JSON.parse(readFileSync('assets/brand-colors.json', 'utf8'));
const LEGACY = existsSync('legacy-api-contract.json') ? JSON.parse(readFileSync('legacy-api-contract.json', 'utf8')) : null;

// Genereringskontraktet: varje genererad fil måste bära systemversion,
// tokenversion, generatorversion, källfingeravtryck och datum. Fas 1.
function checkHeader(file, label) {
  const head = readFileSync(file, 'utf8').split('\n').slice(0, 12).join('\n');
  const need = [
    [/GENERERAD FIL/, 'raden "GENERERAD FIL"'],
    [/\bsystem\s+\d+\.\d+/, 'systemversion'],
    [/\btokens\s+\d+\.\d+/, 'tokenversion'],
    [/\bgenerator\s+\S+\s+v\d+\.\d+/, 'generatorversion'],
    [/källfingeravtryck sha256:[0-9a-f]{64}/, 'källfingeravtryck'],
    [/\bkälldatum\s+\d{4}-\d{2}-\d{2}/, 'källdatum (tokens.date)']
  ];
  for (const [re, what] of need) if (!re.test(head)) fail(label + ': headern saknar ' + what);
  return head;
}
const CSS = 'assets/generated/tokens.css';
const DART = 'lib/theme/butlery_tokens.dart';
// Fas 1: app-temat granskades inte alls, trots att generatorn nu ingår i kedjan.
const APP_COLORS = 'lib/theme/app_colors.dart';
const APP_TEXT = 'lib/theme/app_text_styles.dart';

for (const f of [CSS, DART, APP_COLORS, APP_TEXT]) if (!existsSync(f)) fail(f + ' finns inte — kör generatorerna först');
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

/* ---------- Genereringskontrakt · alla fyra filer ---------- */
for (const [f, label] of [[CSS, 'CSS'], [DART, 'butlery_tokens.dart'],
  [APP_COLORS, 'app_colors.dart'], [APP_TEXT, 'app_text_styles.dart']]) checkHeader(f, label);

/* ---------- app_colors.dart · struktur ---------- */
{
  const src = readFileSync(APP_COLORS, 'utf8');
  if (!/class AppColors\b/.test(src)) fail('app_colors.dart: klassen AppColors saknas');
  if (src.includes('[object Object]')) fail('app_colors.dart: [object Object]');
  if (/(undefined|NaN|null)\b/.test(src.replace(/\/\/[^\n]*/g, ''))) fail('app_colors.dart: odefinierat värde i utdata');
  const o = (src.match(/{/g) || []).length, c2 = (src.match(/}/g) || []).length;
  if (o !== c2) fail('app_colors.dart: obalanserade klamrar (' + o + ' mot ' + c2 + ')');
  const members = [...src.matchAll(/static const Color (\w+)\s*=/g)].map(x => x[1]);
  const dup = members.filter((x, i) => members.indexOf(x) !== i);
  for (const d of [...new Set(dup)]) fail('app_colors.dart: medlemmen ' + d + ' är dubblerad');
  for (const x of src.matchAll(/Color\(0x([0-9A-Fa-f]+)\)/g))
    if (x[1].length !== 8) fail('app_colors.dart: Color(0x' + x[1] + ') har ' + x[1].length + ' siffror, ska ha 8');
  // Inga andra medlemmar än mappade + varumärken + alias + Flutter-konstanter.
  const cap = s2 => s2.charAt(0).toUpperCase() + s2.slice(1);
  const brandNames = new Set(Object.entries(BRAND.brands).flatMap(([n, v]) => [
    'brand' + cap(n), ...(v.background ? ['brand' + cap(n) + 'Background'] : []), ...(v.text ? ['brand' + cap(n) + 'Text'] : [])]));
  const FLUTTER_CONST = new Set(['transparent']);   // Colors.transparent — Flutters egen, inte en designfärg
  const mapped = Object.keys(MAP.colors || {});
  const aliasNames = new Set(Object.keys(MAP.aliases || {}));
  const extra = members.filter(x => !mapped.includes(x) && !brandNames.has(x) && !aliasNames.has(x) && !FLUTTER_CONST.has(x));
  if (extra.length) fail('app_colors.dart: ' + extra.length + ' medlemmar utan källa: ' + extra.slice(0, 4).join(', '));
  console.log('app_colors.dart: ' + members.length + ' medlemmar (' + mapped.length + ' mappade + ' + brandNames.size + ' varumärken + ' + aliasNames.size + ' alias)');
}

/* ---------- app_text_styles.dart · struktur ---------- */
{
  const src = readFileSync(APP_TEXT, 'utf8');
  if (!/class AppTextStyles\b/.test(src)) fail('app_text_styles.dart: klassen AppTextStyles saknas');
  if (src.includes('[object Object]')) fail('app_text_styles.dart: [object Object]');
  const o = (src.match(/{/g) || []).length, c2 = (src.match(/}/g) || []).length;
  if (o !== c2) fail('app_text_styles.dart: obalanserade klamrar (' + o + ' mot ' + c2 + ')');
  const p = (src.match(/\(/g) || []).length, pc = (src.match(/\)/g) || []).length;
  if (p !== pc) fail('app_text_styles.dart: obalanserade parenteser (' + p + ' mot ' + pc + ')');
  const getters = [...src.matchAll(/static TextStyle get (\w+)/g)].map(x => x[1]);
  const dup = getters.filter((x, i) => getters.indexOf(x) !== i);
  for (const d of [...new Set(dup)]) fail('app_text_styles.dart: ' + d + ' är dubblerad');
  if (!getters.length) fail('app_text_styles.dart: inga TextStyle-medlemmar');
  const blocks = [...src.matchAll(/static TextStyle get (\w+) => (?:const )?TextStyle\(([\s\S]*?)\);/g)];
  for (const [, name, body] of blocks) {
    if (!/fontSize:/.test(body)) fail('app_text_styles.dart: ' + name + ' saknar fontSize');
    if (!/height:/.test(body)) fail('app_text_styles.dart: ' + name + ' saknar height — radhöjd är normativ sedan Fas 1');
  }
  console.log('app_text_styles.dart: ' + getters.length + ' medlemmar, ' + blocks.length + ' stilar');
}

/* ---------- app-temat mot KÄLLORNA · faktiska värden ---------- */
// Fas 1 (tredje vändan): kontrollen mätte bara att medlemsnamnen fanns, så
// forestGreen kunde bytas till vitt utan att något föll. Värdena räknas nu om ur
// tokens + mappningen i tools/check-app-theme.mjs — samma rena funktion som
// metatest M-29 muterar för att bevisa att den kan fälla.
{
  const { errors: problems, counts } = checkAppTheme({
    colorsSrc: readFileSync(APP_COLORS, 'utf8'),
    textSrc: readFileSync(APP_TEXT, 'utf8'),
    tokens: TOKENS, map: MAP, brand: BRAND, legacy: LEGACY
  });
  for (const p of problems) fail(p);
  // ANTALEN räknas av kontrollen själv, per kategori. Fas 1 (fjärde vändan): den
  // handskrivna totalen 230 utelämnade de 21 varumärkesvärdena och var därför
  // missvisande — ett tal om täckning får inte skrivas för hand.
  const total = Object.values(counts).reduce((a, b) => a + b, 0);
  if (!problems.length) console.log('app-temat: ' + total + ' jämförda värden · ' +
    Object.entries(counts).map(([k, v]) => k + ' ' + v).join(' · '));
}

if (errors.length) { errors.forEach(e => console.error('✖ ' + e)); console.error('\n' + errors.length + ' fel'); process.exit(1); }
console.log('\nGenererad kod OK — fyra filer, genereringskontrakt uppfyllt.');
