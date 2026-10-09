#!/usr/bin/env node
// Butlery · tokens.json + tools/app-theme-map.json → lib/theme/app_colors_dark.dart
// Kör: node tools/gen-app-theme-dark.mjs   ·   Verifieras av tools/test-generated-dark.mjs
//
// Den LJUSA leveransen (tools/gen-app-theme.mjs → lib/theme/app_colors.dart) rörs
// aldrig av den här generatorn. Skälet står i beslutet: den ljusa ytan är fryst i
// legacy-api-contract.json, och två försök att pressa in mörkret där föll på
// namnkrockar respektive på att kontrollen läser filen som EN yta. Mörkret får
// därför en egen artefakt med ett eget kontrakt.
//
// Ingen ny färg beslutas här. Varje medlem är det mörka läget av ett semantiskt
// token som redan står i tokens.json, och medlemsnamnet är detsamma som i den
// ljusa leveransen. Palett- och råfärger har inget lägesberoende och hör därför
// inte hemma här — de står kvar i AppColors.
//
// De fyra appspecifika dekorfärgerna (dryck, städ, snacks, konserv) hör INTE
// hit. tokens.json säger dataScale.categorical = null och produktreglerna § 8.3b
// säger att kategorin bärs av namnet och att färgrutan är dekor. De ägs av
// appen, inte av designsystemet.
import { readFileSync } from 'node:fs';
import { header } from './gen-header.mjs';
import { emit } from './gen-check.mjs';

const GENERATOR = 'tools/gen-app-theme-dark.mjs';
const GENERATOR_VERSION = '1.0';
const INPUTS = ['tokens.json', 'tools/app-theme-map.json'];

const t = JSON.parse(readFileSync('tokens.json', 'utf8'));
const map = JSON.parse(readFileSync('tools/app-theme-map.json', 'utf8'));

const die = m => { console.error('✖ ' + m); process.exitCode = 1; throw new Error(m); };
const hx = n => Number(n).toString(16).padStart(2, '0').toUpperCase();

function argb(v) {
  if (typeof v !== 'string') die('Okänt färgvärde: ' + JSON.stringify(v));
  if (v.startsWith('#')) return 'Color(0xFF' + v.slice(1).toUpperCase() + ')';
  const m = v.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)/);
  if (!m) die('Okänt färgformat: ' + v);
  const a = Math.round((m[4] === undefined ? 1 : parseFloat(m[4])) * 255);
  return 'Color(0x' + hx(a) + hx(m[1]) + hx(m[2]) + hx(m[3]) + ')';
}

/** Vilka medlemmar har ett mörkt läge? Endast semantiska token har det. */
export function darkPopulation(tokens = t, mappning = map) {
  const rader = [];
  for (const [name, [kind, key, note]] of Object.entries(mappning.colors)) {
    if (kind !== 'semantic') continue;
    const tok = tokens.semantic[key];
    if (!tok) die('tokens.semantic.' + key + ' finns inte (medlem ' + name + ')');
    if (tok.dark === undefined) continue;
    rader.push({
      FLUTTER_MEMBER: name,
      SEMANTIC_TOKEN: key,
      TOKENS_JSON_PATH: 'semantic["' + key + '"].dark',
      DARK_VALUE: tok.dark,
      NOTE: note || null,
      KIND: 'CANONICAL'
    });
  }
  const direkta = new Set(rader.map(r => r.FLUTTER_MEMBER));
  for (const [a, b] of Object.entries(mappning.aliases)) {
    if (!direkta.has(b)) continue;
    const kalla = rader.find(r => r.FLUTTER_MEMBER === b);
    rader.push({
      FLUTTER_MEMBER: a,
      SEMANTIC_TOKEN: kalla.SEMANTIC_TOKEN,
      TOKENS_JSON_PATH: kalla.TOKENS_JSON_PATH,
      DARK_VALUE: kalla.DARK_VALUE,
      NOTE: 'alias → ' + b,
      KIND: 'ALIAS'
    });
  }
  const namn = rader.map(r => r.FLUTTER_MEMBER);
  if (namn.length !== new Set(namn).size) die('dubblerad medlem i den mörka leveransen');
  return rader;
}

function render(rader) {
  const L = [];
  for (const h of header({ generator: GENERATOR, generatorVersion: GENERATOR_VERSION, tokenVersion: t.version, inputs: INPUTS, date: t.date }).lines) L.push(h);
  L.push('//');
  L.push('// MÖRKA kanoniska färger. Samma medlemsnamn som i AppColors, men det');
  L.push('// mörka lägets värde. Den här filen finns för att appens');
  L.push('// kompatibilitetsytor ska kunna härleda BÅDA lägena ur EN källa i');
  L.push('// stället för att bära en egen mörk palett.');
  L.push('//');
  L.push('// Här finns inga appspecifika färger. Kategorifärgerna är dekor och ägs');
  L.push('// av appen; se produktregler.md § 8.3b och tokens.json dataScale.');
  L.push("import 'package:flutter/material.dart';");
  L.push('');
  L.push('/// Det mörka lägets kanoniska färger, genererade ur tokens.json.');
  L.push('class AppColorsDark {');
  L.push('  AppColorsDark._();');
  L.push('');
  for (const r of rader.filter(x => x.KIND === 'CANONICAL')) {
    L.push('  /// ' + (r.NOTE ? r.NOTE + ' · ' : '') + 'semantic.' + r.SEMANTIC_TOKEN + ' (dark)');
    L.push('  static const Color ' + r.FLUTTER_MEMBER + ' = ' + argb(r.DARK_VALUE) + ';');
  }
  L.push('');
  L.push('  // Alias — oförändrade, pekar på medlemmar ovan. Deklarerade i');
  L.push('  // tools/app-theme-map.json.');
  for (const r of rader.filter(x => x.KIND === 'ALIAS')) {
    L.push('  static const Color ' + r.FLUTTER_MEMBER + ' = ' + r.NOTE.replace('alias → ', '') + ';');
  }
  L.push('}');
  L.push('');
  return L.join('\n');
}

const arAnropad = process.argv[1] && /gen-app-theme-dark\.mjs$/.test(process.argv[1].replace(/\\/g, '/'));
if (arAnropad) {
  const rader = darkPopulation();
  emit({ 'lib/theme/app_colors_dark.dart': render(rader) }, { label: 'gen-app-theme-dark' });
  console.log('app_colors_dark.dart skriven ur tokens ' + t.version + ' · ' +
    rader.filter(r => r.KIND === 'CANONICAL').length + ' kanoniska medlemmar + ' +
    rader.filter(r => r.KIND === 'ALIAS').length + ' alias');
}
