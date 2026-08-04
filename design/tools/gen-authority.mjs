#!/usr/bin/env node
// Butlery · source-authority.json → fas0/kallauktoritetsregister.md
// Kör: node tools/gen-authority.mjs   ·   Verifieras av T-20 och GEN-01
//
// Fas 1 (femte vändan): registret var handskrivet och drev. icons.json stod som
// 1.6 och "ej regenererad" när den var 1.8 och regenererad; de fyra genererade
// filerna stod som tokens 1.3/1.4 ur 1.9 när alla var på 1.12; och två skilda
// kontrollstatusar (blocked, not run) låg ihopslagna på samma rad. Registret
// GENERERAS nu ur en maskinläsbar källa och får inte redigeras för hand.
import { readFileSync, existsSync } from 'node:fs';
import { emit } from './gen-check.mjs';

const A = JSON.parse(readFileSync('source-authority.json', 'utf8'));
const tokens = JSON.parse(readFileSync('tokens.json', 'utf8'));
const cell = v => String(v ?? '').replace(/\\/g, '\\\\').replace(/\|/g, '\\|').replace(/\r?\n/g, ' ');
const dash = v => (v === null || v === undefined || v === '' ? '—' : cell(v));

// Tokenversionen i en genererad fils header — läses, inte påstås.
function headerTokenVersion(file) {
  if (!existsSync(file)) return null;
  const head = readFileSync(file, 'utf8').split('\n').slice(0, 12).join('\n');
  return (head.match(/^[^\n]*\btokens\s+v?(\d+\.\d+(?:\.\d+)?)/im) || [])[1] || null;
}

const L = [];
L.push('# Källauktoritetsregister');
L.push('');
L.push('**GENERERAD FIL — ändra `source-authority.json`, inte den här.** Renderad av `tools/gen-authority.mjs` ur `source-authority.json` ' + A.version + ' (' + A.date + '). Valideras av T-20: exakt en aktiv auktoritet per domän, varje deklarerad fil finns, statusarna hör till ordboken, och `supersededBy` bildar ingen cykel.');
L.push('');
for (const s of A.sections.filter(s => s.heading === 'Precedens' || s.heading === 'Maskin-id')) {
  L.push('**' + s.heading + '.** ' + s.body);
  L.push('');
}
L.push('## Normativa källor');
L.push('');
L.push('| Domän | Normativ källa | Version | Status | Ägare | Anmärkning |');
L.push('|---|---|---|---|---|---|');
for (const a of A.authorities)
  L.push('| ' + cell(a.domain) + ' | ' + (a.file ? '`' + cell(a.file) + '`' : '*saknas*') + ' | ' + dash(a.version) +
    ' | ' + cell(a.status) + ' | ' + cell(a.owner) + ' | ' + dash(a.note) + ' |');
L.push('');
{
  const s = A.sections.find(x => x.heading.startsWith('Genererade'));
  L.push('## Genererade artefakter — ingen egen auktoritet');
  L.push('');
  if (s) { L.push(s.body); L.push(''); }
  L.push('| Fil | Generator | Tokenversion i headern | Aktuell mot `tokens.json` ' + tokens.version + ' |');
  L.push('|---|---|---|---|');
  for (const g of A.generatedArtifacts) {
    const v = headerTokenVersion(g.file);
    const state = v === null ? 'ingen tokenrad (renderas ur annan källa)' : (v === tokens.version ? '**ja**' : '**NEJ — ' + cell(v) + '**');
    L.push('| `' + cell(g.file) + '` | `' + cell(g.generator) + '` | ' + dash(v) + ' | ' + state + ' |');
  }
  L.push('');
}
L.push('## Superseded och frysta');
L.push('');
L.push('| Fil | Var | Status | Ersatt av | Anmärkning |');
L.push('|---|---|---|---|---|');
for (const s of A.superseded)
  L.push('| `' + cell(s.file) + '` | ' + cell(s.where) + ' | ' + cell(s.status) + ' | ' +
    (s.supersededBy ? '`' + cell(s.supersededBy) + '`' : '—') + ' | ' + dash(s.note) + ' |');
L.push('');
L.push('## Statusordbok för kontroller');
L.push('');
L.push('| Status | Betyder | Får uppfylla ett godkännandekriterium? |');
L.push('|---|---|---|');
for (const c of A.controlStatusVocabulary)
  L.push('| `' + cell(c.status) + '` | ' + cell(c.means) + ' | ' + (c.satisfies ? 'ja' : '**nej**') + ' |');
L.push('');
L.push('`not applicable` får aldrig användas för något som bara ännu inte körts. Samma ordbok gäller i styrdokumentets § 15, `tools/controls.mjs` och den genererade `fas0/kontrollstatus.md`.');
L.push('');
L.push('## Statusordbok för källor');
L.push('');
L.push('| Status | Betyder |');
L.push('|---|---|');
for (const [k, v] of Object.entries(A.statusVocabulary)) L.push('| `' + cell(k) + '` | ' + cell(v) + ' |');
L.push('');
for (const s of A.sections.filter(s => !['Precedens', 'Maskin-id'].includes(s.heading) && !s.heading.startsWith('Genererade'))) {
  L.push('## ' + s.heading);
  L.push('');
  L.push(s.body);
  L.push('');
}
const out = L.join('\n');
emit({ 'fas0/kallauktoritetsregister.md': out }, { label: 'gen-authority' });
console.log('kallauktoritetsregister.md skrivet · ' + A.authorities.length + ' domäner · ' +
  A.generatedArtifacts.length + ' genererade artefakter · ' + A.superseded.length + ' superseded');
