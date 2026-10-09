#!/usr/bin/env node
// F2-ID01 · IDENTITETSREVISION för R-03.
//
// Kör: node tools/identity-audit.mjs --raw=<render-raw.json> [--out=<fil>] [--fixtures=<fil>]
//
// VARFÖR. nav-add-fixen visade att den normaliserade elementnyckeln inte alltid
// är unik inom en artefakt: sel:div>svg[0] betecknade åtta olika DOM-noder i
// ritningen hem. De åtta nya observationerna slogs därför samman till netto +1.
//
// DENNA REVISION MÄTER. Den ändrar ingenting — inte findingId, inte instansId,
// inte hopslagningen, inte klassificeringsreglerna. Den räknar.
//
// Domsluten ligger i identity-audit-lib.mjs och delas med de negativa proven.
import { readFileSync, writeFileSync } from 'node:fs';
import { revidera, FIXTUR_HTML } from './identity-audit-lib.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const RAW = arg('raw'), OUT = arg('out'), FIXTURES = arg('fixtures');
if (!RAW) { console.error('✖ ange --raw=<render-raw.json>'); process.exit(2); }

const rapport = revidera(JSON.parse(readFileSync(RAW, 'utf8')), RAW);
if (OUT) writeFileSync(OUT, JSON.stringify(rapport, null, 1));
if (FIXTURES) writeFileSync(FIXTURES, FIXTUR_HTML, 'utf8');

const m = rapport.matning;
console.log('IDENTITY-AUDIT unika_nycklar=' + m.unika_elementKeys_st +
  ' kolliderande=' + m.kolliderande_elementKeys_st +
  ' berorda_noder=' + m.berorda_domnoder_st +
  ' verifierade=' + m.verifierade_kollisioner_st +
  ' observationer=' + m.observationskollisioner_st +
  ' avsiktliga=' + m.avsiktliga_kollisioner_st +
  ' flera_metoder=' + m.samma_nod_flera_metoder_st +
  ' forfader_barn=' + m.forfader_barn_par_st +
  ' status=' + (m.kolliderande_elementKeys_st ? 'failed' : 'passed'));
console.log('  ' + rapport.paverkan_pa_kanoniskt_resultat.slutsats);
console.log('  diskriminatorer: ' + JSON.stringify(rapport.rekommenderad_identitetsmodell.beläggFranMatningen));
process.exit(m.kolliderande_elementKeys_st ? 1 : 0);
