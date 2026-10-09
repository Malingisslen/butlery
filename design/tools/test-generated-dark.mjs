#!/usr/bin/env node
// Butlery · kontroll av den MÖRKA Flutter-leveransen.
// Kör: node tools/test-generated-dark.mjs
//
// GD-01..GD-08. Provet läser filen på disk, kontraktet och tokens.json och
// räknar om allt självt. Muteringsproven (GD-06..GD-08) kör generatorns
// population mot en riggad token-källa och kräver att den faller stängt.
import { readFileSync } from 'node:fs';
import { darkPopulation } from './gen-app-theme-dark.mjs';

const t = JSON.parse(readFileSync('tokens.json', 'utf8'));
const kontrakt = JSON.parse(readFileSync('legacy-api-contract.json', 'utf8')).appColorsDark;
const src = readFileSync(kontrakt.artifact, 'utf8');

const res = [];
const prov = (id, vad, ok, diag) => res.push({ id, vad, ok: !!ok, diag: String(diag == null ? '' : diag) });

/* medlemmar som filen faktiskt bär */
const filMedlemmar = [];
for (const m of src.matchAll(/static const Color (\w+)\s*=\s*(Color\(0x[0-9A-Fa-f]{8}\)|\w+);/g))
  filMedlemmar.push({ namn: m[1], varde: m[2] });
const filNamn = filMedlemmar.map(r => r.namn);
const rader = darkPopulation();

/* GD-01 · varje förväntad medlem finns */
{
  const vantade = [...kontrakt.members, ...kontrakt.aliases];
  const saknade = vantade.filter(n => !filNamn.includes(n));
  prov('GD-01', 'varje kontrakterad mork medlem finns i filen', saknade.length === 0, saknade.join(', '));
}

/* GD-02 · ingen oväntad medlem */
{
  const vantade = new Set([...kontrakt.members, ...kontrakt.aliases]);
  const extra = filNamn.filter(n => !vantade.has(n));
  prov('GD-02', 'ingen omork medlem har smugit in', extra.length === 0, extra.join(', '));
}

/* GD-03 · varje värde är exakt tokens.json:s mörka värde */
{
  const hx = n => Number(n).toString(16).padStart(2, '0').toUpperCase();
  const argb = v => {
    if (v.startsWith('#')) return 'Color(0xFF' + v.slice(1).toUpperCase() + ')';
    const m = v.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)/);
    const a = Math.round((m[4] === undefined ? 1 : parseFloat(m[4])) * 255);
    return 'Color(0x' + hx(a) + hx(m[1]) + hx(m[2]) + hx(m[3]) + ')';
  };
  const fel = [];
  for (const r of rader.filter(x => x.KIND === 'CANONICAL')) {
    const i = filMedlemmar.find(x => x.namn === r.FLUTTER_MEMBER);
    const vantat = argb(t.semantic[r.SEMANTIC_TOKEN].dark);
    if (!i || i.varde !== vantat) fel.push(r.FLUTTER_MEMBER + ' ar ' + (i ? i.varde : 'saknad') + ', tokens ger ' + vantat);
  }
  prov('GD-03', 'varje varde ar exakt tokens.json:s morka varde', fel.length === 0, fel.slice(0, 3).join(' | '));
}

/* GD-04 · ingen dubblerad medlem */
prov('GD-04', 'ingen medlem forekommer tva ganger', filNamn.length === new Set(filNamn).size,
  filNamn.length + ' medlemmar, ' + new Set(filNamn).size + ' unika');

/* GD-05 · ljus och mörk leverans är inte hopblandade */
{
  const ljus = readFileSync('lib/theme/app_colors.dart', 'utf8');
  const morkKlassILjus = /class AppColorsDark\b/.test(ljus);
  const ljusKlassIMork = /class AppColors\b(?!Dark)/.test(src);
  const egenKlass = /class AppColorsDark\b/.test(src);
  prov('GD-05', 'de tva leveranserna ar skilda filer med var sin klass',
    !morkKlassILjus && !ljusKlassIMork && egenKlass,
    'morkklass i ljus fil=' + morkKlassILjus + ' ljusklass i mork fil=' + ljusKlassIMork);
}

/* GD-06 · ett andrat morkt token andrar bara sin egen medlem */
{
  const fore = darkPopulation();
  const valj = fore.find(r => r.KIND === 'CANONICAL');
  const riggad = JSON.parse(JSON.stringify(t));
  riggad.semantic[valj.SEMANTIC_TOKEN].dark = '#010203';
  const efter = darkPopulation(riggad);
  const andrade = efter.filter((r, i) => r.DARK_VALUE !== fore[i].DARK_VALUE).map(r => r.FLUTTER_MEMBER);
  const forvantadeAndringar = fore.filter(r => r.SEMANTIC_TOKEN === valj.SEMANTIC_TOKEN).map(r => r.FLUTTER_MEMBER);
  prov('GD-06', 'ett andrat morkt token andrar bara medlemmarna som bar det',
    andrade.length > 0 && andrade.every(n => forvantadeAndringar.includes(n)),
    'andrade=' + andrade.join(', ') + ' vantade=' + forvantadeAndringar.join(', '));
}

/* GD-07 · ett saknat morkt varde faller stangt */
{
  const valj = rader.find(r => r.KIND === 'CANONICAL');
  const riggad = JSON.parse(JSON.stringify(t));
  delete riggad.semantic[valj.SEMANTIC_TOKEN].dark;
  const efter = darkPopulation(riggad);
  const kvar = efter.some(r => r.FLUTTER_MEMBER === valj.FLUTTER_MEMBER);
  prov('GD-07', 'ett token utan morkt varde ger ingen medlem i stallet for en gissad',
    !kvar, 'medlemmen ' + valj.FLUTTER_MEMBER + ' fanns kvar');
}

/* GD-08 · ett okant token faller stangt */
{
  let foll = false;
  const riggad = JSON.parse(JSON.stringify(t));
  delete riggad.semantic['text.primary'];
  try { darkPopulation(riggad); } catch { foll = true; }
  process.exitCode = 0;
  prov('GD-08', 'en mappning mot ett token som inte finns faller stangt', foll, 'foll=' + foll);
}

for (const r of res) console.log((r.ok ? 'GRON ' : 'ROD  ') + r.id.padEnd(8) + r.vad + (r.ok ? '' : '  -> ' + r.diag));
console.log('\nGD ' + res.filter(r => r.ok).length + '/' + res.length);
process.exit(res.every(r => r.ok) ? 0 : 1);
