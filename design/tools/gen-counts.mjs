#!/usr/bin/env node
// Butlery · räknar ramar, kontroller och roller ur skärmfilen och skriver in
// siffrorna i dokumenten. Kör: node tools/gen-counts.mjs
//
// En handskriven räkning i en spec blir fel nästa gång någon lägger till en vy.
// Därför är varje siffra ankrad i en HTML-kommentar och genereras:
//   <!--n:frames-->98<!--/n-->
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { SCREEN_FILES } from './screen-files.mjs';

// Skärmfilen är delad (2026-07-26, utökad 2026-07-28): en fil på nära en megabyte gick inte
// att öppna. Räknarna summerar över alla delar; indexfilen räknas inte, den har
// inga ramar.
// Fillistan är kanonisk och delas med lint-core, lint-controls och gen-icons.
const SCREENS = SCREEN_FILES;
const TARGETS = [
  'Butlery tillganglighetshandoff.dc.html',
  'evidensmatris.md',
  'testmatris.md',
  '00-spec-index.md'
];

const src = SCREENS.filter(existsSync).map(f => readFileSync(f, 'utf8')).join('\n');
const count = re => (src.match(re) || []).length;

const counts = {
  frames: count(/class="sc-phone"/g),
  items: count(/class="sc-item"/g),
  controls: count(/data-a11y-name=/g),
  roles: count(/data-a11y-role=/g),
  hits: count(/data-hit=/g)
};

if (counts.controls !== counts.roles) {
  console.error('✖ ' + (counts.controls - counts.roles) + ' kontroller saknar data-a11y-role — rätta innan siffrorna skrivs');
  process.exit(1);
}

let touched = 0;
for (const file of TARGETS) {
  if (!existsSync(file)) continue;
  const before = readFileSync(file, 'utf8');
  const after = before.replace(/<!--n:([a-z]+)-->[\s\S]*?<!--\/n-->/g, (m, key) => {
    if (!(key in counts)) { console.warn('◐ okänd räknare "' + key + '" i ' + file); return m; }
    return '<!--n:' + key + '-->' + counts[key] + '<!--/n-->';
  });
  if (after !== before) { writeFileSync(file, after); touched++; }
}

// MASKINSUMMERING först — verify.mjs läser bara den här raden, aldrig prosan.
// En generell regex plockade tidigare "controls=21" ur ett senare stegs
// SELFTEST-COVERAGE och skrev över 1 372. Fas 0.10.
console.log('COUNT-SUMMARY ' + Object.entries(counts).map(([k, v]) => k + '=' + v).join(' '));
console.log('räknat: ' + Object.entries(counts).map(([k, v]) => k + ' ' + v).join(' · '));
console.log(touched + ' fil(er) uppdaterade');
