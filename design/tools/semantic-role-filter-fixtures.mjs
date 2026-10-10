#!/usr/bin/env node
// F2-R04 · METODPROV FOR DET SEMANTISKA ROLLFILTRET.  SR-01 … SR-09
//
// Felet som inte far uppsta igen: ett varde slapps in i en beslutsenhets
// kandidatmangd enbart darfor att det finns i den globala morkpaletten.
//
// Och motsatsen, lika viktig: filtret far INTE bli en forklad regel om att
// ljusa farger inte kan vara appbakgrunder i morkt lage. SR-02 och SR-09
// bevisar att ljushet aldrig lases.

import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { ROLLFAMILJ, familjAvRoll, rollstod, semantiskBehorighet, kandidatkedja }
  from './semantic-role-filter.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

/* Observerad mork population — samma form som den verkliga matningen. */
const POSTER = [
  ...Array(63).fill({ varde: '#17251d', roll: 'yta-app' }),
  ...Array(56).fill({ varde: '#17251d', roll: 'yta-upphojd' }),
  ...Array(101).fill({ varde: '#24382c', roll: 'yta-upphojd' }),
  ...Array(46).fill({ varde: '#24382c', roll: 'yta-kontroll' }),
  ...Array(1).fill({ varde: '#4a5c43', roll: 'yta-upphojd' }),
  ...Array(21).fill({ varde: '#e6ead9', roll: 'yta-platshallare' }),
  ...Array(56).fill({ varde: '#f5f4ed', roll: 'text-innehall' }),
  ...Array(9).fill({ varde: '#fffdf7', roll: 'yta-app' }) ];   // ljus, men observerad SOM appyta
const STOD = rollstod(POSTER);
const PALETT = [...new Set(POSTER.map(p => p.varde))].map(v => ({ varde: v }));

/* SR-01 · palettmedlem men obehorig for enheten */
{ const r = semantiskBehorighet('yta-app', '#e6ead9', STOD.get('#e6ead9'));
  const iPaletten = PALETT.some(p => p.varde === '#e6ead9');
  prov('SR-01', 'palettmedlemskap ger inte behorighet for en annan semantisk roll',
    iPaletten && r.utfall === 'INELIGIBLE' && r.klass === 'ANNAN_SEMANTISK_ROLL',
    'PALETTE_MEMBER=true · APP_BACKGROUND_ELIGIBILITY=false · ' + r.skal); }

/* SR-02 · ingen generell regel mot ljusa appbakgrunder */
{ const ljus = semantiskBehorighet('yta-app', '#fffdf7', STOD.get('#fffdf7'));
  const mork = semantiskBehorighet('yta-app', '#17251d', STOD.get('#17251d'));
  prov('SR-02', 'ett ljust varde ar behorigt om det faktiskt observerats som appyta',
    ljus.utfall === 'ELIGIBLE' && ljus.klass === 'OBSERVERAD_I_SAMMA_ROLL' && mork.utfall === 'ELIGIBLE',
    '#fffdf7 ar ljusare an #e6ead9 och slapps anda igenom — filtret laser observerad roll, aldrig luminans'); }

/* SR-03 · forgrundsvarde ar obehorigt for en yta */
{ const r = semantiskBehorighet('yta-app', '#f5f4ed', STOD.get('#f5f4ed'));
  prov('SR-03', 'ett rent forgrundsvarde ar obehorigt for en ythierarkienhet',
    r.utfall === 'INELIGIBLE' && r.klass === 'ANNAN_SEMANTISK_ROLL',
    '#f5f4ed observerat som FORGRUND x56 — inte YTHIERARKI'); }

/* SR-04 · samma familj racker, samma roll kravs inte */
{ const r = semantiskBehorighet('yta-app', '#24382c', STOD.get('#24382c'));
  prov('SR-04', 'observation i samma rollfamilj racker och redovisas som svagare evidens',
    r.utfall === 'ELIGIBLE' && r.klass === 'OBSERVERAD_I_SAMMA_ROLLFAMILJ' &&
    r.evidens === 'SAME_FAMILY_OBSERVED',
    '#24382c ar observerat som yta-upphojd och yta-kontroll, aldrig som yta-app — behorigt, men evidensen ar SAME_FAMILY_OBSERVED'); }

/* SR-05 · uttryckligt designforslag blir ny kandidat, aldrig ELIGIBLE */
{ const r = semantiskBehorighet('yta-app', '#e6ead9', STOD.get('#e6ead9'),
    { positivIntention: 'ljus appbakgrund som medvetet designval' });
  prov('SR-05', 'ett uttryckligt designforslag ger en ny kandidat utan evidens, inte behorighet',
    r.utfall === 'NY_KANDIDAT_MED_POSITIV_INTENTION' && r.evidens === 'NONE',
    'utfall ' + r.utfall + ' · evidens ' + r.evidens + ' — maste avgoras som VISUAL_CHOICE_REQUIRED'); }

/* SR-06 · okand malroll faller stangt */
{ const r = semantiskBehorighet('yta-hittepa', '#17251d', STOD.get('#17251d'));
  prov('SR-06', 'okand malroll faller stangt', r.utfall === 'INELIGIBLE' && r.klass === 'OKAND_MALROLL',
    r.skal); }

/* SR-07 · samma varde, olika enheter, olika svar */
{ const somYta = semantiskBehorighet('yta-app', '#f5f4ed', STOD.get('#f5f4ed'));
  const somText = semantiskBehorighet('text-innehall', '#f5f4ed', STOD.get('#f5f4ed'));
  prov('SR-07', 'behorighet ar enhetsspecifik, inte global for vardet',
    somYta.utfall === 'INELIGIBLE' && somText.utfall === 'ELIGIBLE',
    '#f5f4ed obehorigt som appyta, behorigt som innehallstext — samma varde, tva svar'); }

/* SR-08 · kedjan summerar i varje steg */
{ const tekniskt = v => ({ ok: v !== '#4a5c43', skal: v === '#4a5c43' ? 'faller pa ett matbart krav' : null });
  const k = kandidatkedja(PALETT, 'yta-app', STOD, tekniskt);
  const sum2 = k.SEMANTIC_ROLE_FILTER.summerar, sum3 = k.TECHNICAL_CONSTRAINT_FILTER.summerar;
  prov('SR-08', 'kedjan summerar i varje steg och inget varde forsvinner tyst',
    sum2 && sum3 && k.VISUAL_CANDIDATES.antal === k.TECHNICAL_CONSTRAINT_FILTER.behallna.length,
    k.GLOBAL_DARK_PALETTE.antal + ' -> ' + k.SEMANTIC_ROLE_FILTER.behallna.length +
    ' -> ' + k.VISUAL_CANDIDATES.antal + '  (bortfall ' + k.SEMANTIC_ROLE_FILTER.bortfallna.length +
    ' semantiskt, ' + k.TECHNICAL_CONSTRAINT_FILTER.bortfallna.length + ' tekniskt)'); }

/* SR-09 · filtret raknar aldrig pa luminans */
{ const kalla = String(await import('node:fs').then(fs => fs.readFileSync(
    new URL('./semantic-role-filter.mjs', import.meta.url), 'utf8')));
  /* Kommentarer bort forst — vi provar koden, inte prosan om koden. */
  const kod = kalla.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  const harLuminans = /lum\(|luminans|relativeLuminance|0\.2126|0\.7152|rgbAv|kvot\(/.test(kod);
  prov('SR-09', 'filtret innehaller ingen luminansberkning', !harLuminans,
    harLuminans ? 'koden raknar pa ljushet' :
      'ingen luminans- eller fargkanalberkning i koden (' + kod.split('\n').filter(l => l.trim()).length +
      ' kodrader provade) — regeln kan inte ha blivit en forklad ljushetsregel'); }

const ANTAL = 9;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('ROLLFILTERPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'rollfilterprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
