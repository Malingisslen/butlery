#!/usr/bin/env node
// Butlery · lint-controls.mjs — mäter LÅST KONTROLLGEOMETRI i skärmfilerna mot
// tokens.json → controls. Kör: node tools/lint-controls.mjs
//
// Varför den finns: grundgranskningen 2026-07-26 hittade elva regelbrott i de
// nyaste ramarna, och orsaken var densamma för alla — kontrollmåtten låg bara i
// manualtexten och komponentarket, alltså på ett ställe ingen maskin läser. Nu
// ligger de i tokens (beslut B-37) och kontrolleras här.
//
// Regeln: en ritning får avvika, men avvikelsen ska vara SKRIVEN. Ett element
// med data-lint-exempt="skäl" hoppas över och räknas i rapporten.
import { readFileSync, existsSync } from 'node:fs';
import { DOCS } from './lint-core.mjs';

const tokens = JSON.parse(readFileSync('tokens.json', 'utf8'));
const c = tokens.controls;
if (!c) { console.error('✖ tokens.json saknar controls — grunden är äldre än beslut B-37'); process.exit(1); }

const SCREENS = DOCS.filter(f => /Skarmar/.test(f) && existsSync(f));
const findings = [];
// Omärkta kandidater fälls inte — en gissning är inte ett fel — men räknas och
// redovisas i LC-SUMMARY så att märkningen kan kompletteras.
const unmarked = { toggle: 0, chip: 0 };
const covered = { toggle: 0, chip: 0, checkbox: 0 };
let exempt = 0;

/** Alla style-attribut i filen, med radnummer och närmaste ram-id. */
function* elements(src, file) {
  const lines = src.split('\n');
  let frame = '(okänd)';
  for (let i = 0; i < lines.length; i++) {
    const idMatch = lines[i].match(/class="sc-item" id="([^"]+)"/);
    if (idMatch) frame = idMatch[1];
    for (const m of lines[i].matchAll(/style="([^"]*)"/g)) {
      const tagStart = lines[i].lastIndexOf('<', m.index);
      const tag = lines[i].slice(tagStart, m.index + m[0].length);
      yield { style: m[1], tag, file, line: i + 1, frame };
    }
  }
}

const px = (style, prop) => {
  const m = style.match(new RegExp(prop + ':\\s*([\\d.]+)px'));
  return m ? parseFloat(m[1]) : null;
};

function check(el) {
  if (/data-lint-exempt=/.test(el.tag)) { exempt++; return; }
  const { style } = el;
  const w = px(style, 'width'), h = px(style, 'height'), r = px(style, 'border-radius');

  // Kryssruta: kvadratisk, radie 6, kant 1,5 — identifieras på radien och formen
  const isSquareControl = w !== null && w === h && r === c.checkbox.radius && /border:\s*1\.5px/.test(style);
  if ((isSquareControl || /data-component="checkbox"/.test(el.tag)) && w !== null && w !== c.checkbox.size) {
    findings.push(`${el.file}:${el.line} [${el.frame}] kryssruta ${w} px — ska vara ${c.checkbox.size}`);
  }

  // Avatar: rund yta med bakgrund — ska ligga på skalan
  // Avatar = rund yta med bakgrund SAMT initialens textfärg och storlek. Utan de
  // två sista är det en prick, en ikoncirkel eller en laddindikator — inte en avatar.
  const isAvatar = w !== null && w === h && (r === 999 || /border-radius:\s*50%/.test(style)) &&
    /background:/.test(style) && /color:#/.test(style) && px(style, 'font-size') !== null;
  if (isAvatar && !c.avatarScale.includes(w)) {
    findings.push(`${el.file}:${el.line} [${el.frame}] avatar ${w} px — skalan är ${c.avatarScale.join(' / ')}`);
  }

  // Radie: bara sharp / knob / control / card / pill får förekomma.
  // Kryssrutans radie 6 är en KOMPONENTTOKEN och tillåts bara på ett element
  // som faktiskt är en kryssruta (kvadratiskt, 1,5 px kant). Den låg tidigare i
  // den globala listan, vilket gjorde varje radie 6 laglig och dolde den enda
  // verkliga avvikelsen. Rättat 2026-07-31 (Fas 0.2).
  // Komponenten identifieras SEMANTISKT, inte gissas ur CSS. En kryssruta kan
  // ha 1 px kant, ingen kant alls i valt läge, eller bakgrund i stället för
  // kant — formgissningen missade 78 av dem. data-component är kontraktet.
  // Rättat 2026-07-31 (Fas 0.3).
  const isCheckbox = /data-component="checkbox"/.test(el.tag);
  const allowedRadii = [...Object.values(tokens.space.radius)];
  const radiusOk = r === null || allowedRadii.includes(r) || isAvatar ||
    (r === c.checkbox.radius && isCheckbox);
  if (!radiusOk) {
    const extra = r === c.checkbox.radius ? ' (radie 6 är kryssrutans komponenttoken — märk elementet data-component="checkbox" eller använd en radie ur skalan)' : '';
    findings.push(`${el.file}:${el.line} [${el.frame}] radie ${r} — tillåtna: ${allowedRadii.join(' / ')}${extra}`);
  }

  // Chip: full radie + text 12/600 → padding ska vara 7 × 13 (eller kompakt 6 × 11)
  // Chip: kräver märkning — radie 999 + 12 px finns även på statuspillar och
  // räknare som inte är chips. (Fas 0.4)
  if (/data-component="chip"/.test(el.tag)) {
    const pad = style.match(/padding:\s*([\d.]+)px\s+([\d.]+)px/);
    if (pad) {
      const [, y, x] = pad.map(Number);
      const okFull = y === c.chip.paddingY && x === c.chip.paddingX;
      const okCompact = y === c.chipCompactInField.paddingY && x === c.chipCompactInField.paddingX;
      if (!okFull && !okCompact) {
        findings.push(`${el.file}:${el.line} [${el.frame}] chip padding ${y} × ${x} — ska vara ${c.chip.paddingY} × ${c.chip.paddingX} (kompakt ${c.chipCompactInField.paddingY} × ${c.chipCompactInField.paddingX})`);
      }
    }
  }

  // Statuspill: 10,5/700 → padding 3 × 9
  if (/font-size:\s*10\.5px/.test(style) && /font-weight:\s*700/.test(style)) {
    const pad = style.match(/padding:\s*([\d.]+)px\s+([\d.]+)px/);
    if (pad) {
      const [, y, x] = pad.map(Number);
      const okPill = y === c.statusPill.paddingY && x === c.statusPill.paddingX;
      const okBadge = y === c.badge.paddingY && x === c.badge.paddingX;
      if (!okPill && !okBadge) {
        findings.push(`${el.file}:${el.line} [${el.frame}] pill/badge padding ${y} × ${x} — pill ${c.statusPill.paddingY} × ${c.statusPill.paddingX}, badge ${c.badge.paddingY} × ${c.badge.paddingX}`);
      }
    }
  }

  // Toggle: 34 × 20. Identifieras SEMANTISKT — regeln klassade tidigare varje
  // 34 px brett element som toggle och fällde 29 tangentbordstangenter och två
  // draghandtag på 34 × 4. Rättat 2026-08-01 (Fas 0.4).
  const isToggle = /data-component="toggle"/.test(el.tag);
  // Omärkta kandidater är ett TÄCKNINGSFEL, inte en geometriavvikelse: en
  // kontroll som körs på noll komponenter kan bli grön utan att ha mätt något.
  if (!isToggle && w === c.toggle.width && h === c.toggle.height) unmarked.toggle++;
  if (!/data-component="chip"/.test(el.tag) && r === 999 && /font-size:\s*12px/.test(style)) unmarked.chip++;
  if (/data-component="chip"/.test(el.tag)) covered.chip++;
  if (isToggle) covered.toggle++;
  if (/data-component="checkbox"/.test(el.tag)) covered.checkbox++;
  if (isToggle) {
    // Bredd OCH höjd OCH att måtten alls finns. Regeln prövade bara höjden,
    // så 35 × 20 passerade. Rättat 2026-08-01 (Fas 0.5).
    if (w === null || h === null) findings.push(`${el.file}:${el.line} [${el.frame}] toggle utan mått — width och height krävs`);
    else if (w !== c.toggle.width || h !== c.toggle.height) findings.push(`${el.file}:${el.line} [${el.frame}] toggle ${w} × ${h} — ska vara ${c.toggle.width} × ${c.toggle.height}`);
    const knob = (style.match(/--knob:\s*([\d.]+)px/) || [])[1];
    if (knob && Number(knob) !== c.toggle.knob) findings.push(`${el.file}:${el.line} [${el.frame}] toggleknopp ${knob} — ska vara ${c.toggle.knob}`);
  }

  // Närvaroraden (beslut B-40): 48 dp hög, avatarer 26, högst tre ansikten
  if (/data-presence-row/.test(el.tag)) {
    const p = c.calendarPresenceRow;
    const mh = px(style, 'min-height');
    if (mh !== p.height) {
      findings.push(`${el.file}:${el.line} [${el.frame}] närvarorad ${mh ?? '?'} px — ska vara ${p.height}`);
    }
  }

  // Typskalans roller — inga mellansteg
  const fs = px(style, 'font-size');
  const roleSizes = [...new Set(Object.values(tokens.typography.roles).map(r => r.size))];
  if (fs !== null && !roleSizes.includes(fs)) {
    findings.push(`${el.file}:${el.line} [${el.frame}] textstorlek ${fs} px — utanför rollskalan (${roleSizes.sort((a, b) => a - b).join(' ')})`);
  }
  // Ingen 400-vikt under 12 px; 10,5 endast i 700
  if (fs !== null && fs < 12) {
    const wt = (style.match(/font-weight:\s*(\d{3})/) || [])[1];
    if (!wt || Number(wt) < 600) {
      findings.push(`${el.file}:${el.line} [${el.frame}] ${fs} px i vikt ${wt || 400} — under 12 px krävs 600, och 10,5 px endast 700`);
    }
  }
}

for (const file of SCREENS) for (const el of elements(readFileSync(file, 'utf8'), file)) check(el);

// Närvaroraden får bära högst tre ansikten (beslut B-40). Räknas per rad i källan:
// en rad med fler avatarer än så ska degradera till "en avatar + antal", inte krympa.
for (const file of SCREENS) {
  const lines = readFileSync(file, 'utf8').split('\n');
  for (let i = 0; i < lines.length; i++) {
    if (!/data-presence-row/.test(lines[i])) continue;
    // Flera närvarorader kan ligga på samma källrad (lunch + middag sida vid sida),
    // så segmentera på markören innan ansiktena räknas — annars summeras rader ihop.
    const segments = lines[i].split('data-presence-row').slice(1);
    for (const seg of segments) {
      const faces = (seg.match(/border-radius:\s*(50%|999px)[^"]*background:/g) || []).length;
      if (faces > c.calendarPresenceRow.maxFaces) {
        findings.push(file + ':' + (i + 1) + ' närvarorad med ' + faces + ' ansikten — högst ' + c.calendarPresenceRow.maxFaces + ', därefter "en avatar + antal"');
      }
    }
  }
}

// Mallrester i NORMATIVA attribut. Skärmfilerna genereras av skript, och en
// enkelciterad sträng inne i en template literal kan kapas mitt i — resultatet
// blir ett tillgängligt namn som "${typ===". Det syns inte i någon räkning:
// kontrollen har både roll och namn, namnet är bara obrukbart. En skärmläsare
// läser upp skräpet, i värsta fall för en destruktiv åtgärd.
for (const file of SCREENS) {
  const src = readFileSync(file, 'utf8');
  const re = /(data-a11y-name|data-a11y-role|data-hit|data-screen-label)="([^"]*(?:\${|`)[^"]*)"/g;
  for (const m of src.matchAll(re)) {
    const line = src.slice(0, m.index).split('\n').length;
    findings.push(`${file}:${line} mallrest i ${m[1]}: "${m[2].slice(0, 40)}"`);
  }
}

// Täckningsfel redovisas för sig och fäller LC-01 — annars kan regeln vara
// grön för att den aldrig kördes på någon komponent.
const coverage = [];
for (const [k, n] of Object.entries(unmarked)) if (n) coverage.push(k + ': ' + n + ' omärkta kandidater');
for (const [k, n] of Object.entries(covered)) if (!n) coverage.push(k + ': regeln kördes på NOLL komponenter');
if (coverage.length) {
  console.error('LC-COVERAGE ' + Object.entries(unmarked).map(([k, v]) => 'unmarked_' + k + '=' + v).join(' ') + ' ' +
    Object.entries(covered).map(([k, v]) => 'covered_' + k + '=' + v).join(' '));
  for (const c2 of coverage) console.error('✖ LC-01 täckning · ' + c2);
}

if (findings.length || coverage.length) {
  // Maskinläsbar summering FÖRST — verify.mjs läser den här raden och ska
  // aldrig behöva gissa ur prosan. (Parsern letade "avvikelser", verktyget
  // skrev "avvikelse(r)", och reservlogiken räknade bara "… och N fler".)
  console.error('LC-SUMMARY deviations=' + findings.length + ' coverage_errors=' + coverage.length +
    ' unmarked_toggle=' + unmarked.toggle + ' unmarked_chip=' + unmarked.chip +
    ' covered_toggle=' + covered.toggle + ' covered_chip=' + covered.chip + ' covered_checkbox=' + covered.checkbox);
  console.error('✖ ' + findings.length + ' avvikelse(r) mot tokens.controls och typskalan:\n');
  for (const f of findings.slice(0, 200)) console.error('  ' + f);
  if (findings.length > 200) console.error('  … och ' + (findings.length - 200) + ' fler');
  console.error('\n' + exempt + ' element hoppade över via data-lint-exempt.');
  process.exit(1);
}
console.log('LC-SUMMARY deviations=0 coverage_errors=0 covered_toggle=' + covered.toggle + ' covered_chip=' + covered.chip + ' covered_checkbox=' + covered.checkbox);
console.log('✔ kontrollgeometri och typskala rena i ' + SCREENS.length + ' skärmfiler · ' + exempt + ' skrivna undantag');
