#!/usr/bin/env node
// F2 · METODPROV FOR KONTROLLDEKLARATIONSSKRIVAREN.  CW-01 … CW-19
//
// FELKLASSEN PROVEN FINNS FOR
// En skrivare som "nastan" traffar ratt element ar varre an ingen skrivare:
// den flyttar semantik till fel objekt och baslinjen ser anda gron ut. Proven
// laser att ankaret ar exakt, att befintliga varden aldrig skrivs over, och
// att inget annat an de utpekade attributen och den utpekade stilegenskapen
// kan roras.

import { writeFileSync, mkdirSync, readFileSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { skrivAttribut, skrivStil, migreraFil, jamforAnkare, TILLATNA_ATTRIBUT,
  TILLATNA_STILEGENSKAPER } from './control-declaration-writer.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag: String(diag) });

const HTML = '<div class="sc-item" id="prov">' +
  '<div style="display:flex;gap:8px">' +
  '<span style="border:1px solid #000">Ett</span>' +
  '<span style="border:1px solid #000">Tva</span>' +
  '</div>' +
  '<span data-a11y-role="button" data-a11y-name="Redan">Tre</span>' +
  '<span style="min-height:40px">Fyra</span>' +
  '</div>';
const tmp = join(outAbs, 'cw-prov.dc.html');
const nyFil = () => { writeFileSync(tmp, HTML); return tmp; };

/* CW-01 · attributet skrivs i ratt tagg */
{ const r = skrivAttribut('<span style="a">', 'data-a11y-role', 'button');
  prov('CW-01', 'attributet laggs sist i oppningstaggen och ror inget annat',
    r.ok && r.ny && r.text === '<span style="a" data-a11y-role="button">', r.text); }

/* CW-02 · identiskt varde ar idempotent */
{ const r = skrivAttribut('<span data-a11y-role="button">', 'data-a11y-role', 'button');
  prov('CW-02', 'samma varde skrivs inte om — idempotent',
    r.ok && r.ny === false, r.skal); }

/* CW-03 · annat varde ar konflikt */
{ const r = skrivAttribut('<span data-a11y-role="link">', 'data-a11y-role', 'button');
  prov('CW-03', 'ett befintligt annat varde ger konflikt och skrivs aldrig over',
    r.ok === false && /finns redan/.test(r.skal), r.skal); }

/* CW-04 · otillatet attribut */
{ const r = skrivAttribut('<span>', 'style', 'color:red');
  const s = skrivAttribut('<span>', 'data-component', 'x');
  prov('CW-04', 'bara de fem tillatna attributen kan skrivas',
    r.ok === false && s.ok === false && TILLATNA_ATTRIBUT.length === 5,
    'tillatna: ' + TILLATNA_ATTRIBUT.join(', ')); }

/* CW-05 · stilegenskapen laggs till utan att rora ovriga */
{ const r = skrivStil('<span style="padding:8px;color:#000">', 'min-height', '48px');
  prov('CW-05', 'stilegenskapen laggs till sist och lamnar ovriga deklarationer ororda',
    r.ok && r.ny && r.text === '<span style="padding:8px;color:#000;min-height:48px">',
    r.text); }

/* CW-06 · befintlig stilegenskap med annat varde ar konflikt */
{ const r = skrivStil('<span style="min-height:40px">', 'min-height', '48px');
  const q = skrivStil('<span style="min-height:48px">', 'min-height', '48px');
  prov('CW-06', 'befintligt annat stilvarde ger konflikt; samma varde ar idempotent',
    r.ok === false && q.ok === true && q.ny === false, r.skal + ' | ' + q.skal); }

/* CW-07 · PENSIONERAT — RETIRED_SCOPE_EXTENDED.
 * Ursprunglig lydelse (0884b25): "ingen annan stilegenskap an min-height kan
 * skrivas", med assertionen TILLATNA_STILEGENSKAPER.length === 1. Utsagan var
 * sann for sitt scope men ar inte en metodregel: listan ar en beslutslista, och
 * ett godkant beslut (VAG 2, saffransramen) pekade ut border, box-sizing och de
 * tva sidospecifika paddingarna. Assertionen far INTE tyst skrivas om under
 * samma id. Den levande garantin — att farg och bakgrund aldrig kan skrivas —
 * bars nu av CW-17, och att kortformen padding aldrig kan skrivas av CW-14. */
{ const r = skrivStil('<span style="a:b">', 'background', '#fff');
  prov('CW-07', 'PENSIONERAT — RETIRED_SCOPE_EXTENDED: listan ar en beslutslista, ' +
    'inte ett metodpastaende om antalet',
    r.ok === false,
    'lydelse bevarad: "ingen annan stilegenskap an min-height kan skrivas" (0884b25). ' +
    'Provet gor numera ingen utsaga om listans langd. Nuvarande lista: ' +
    TILLATNA_STILEGENSKAPER.join(', ') + '. Ersatt av CW-14 och CW-17.'); }

/* CW-08 · ordinalankaret traffar samma element som DOM-ordningen */
{ const fil = nyFil();
  const r = migreraFil(fil, [{ art: 'prov', ordinal: 1,
    attribut: { 'data-a11y-role': 'button', 'data-a11y-name': 'Ett' } }], { torr: true });
  const rad = r.logg[0];
  prov('CW-08', 'ordinal 1 ar samma element som querySelectorAll("*")[1]',
    rad.utfall === 'SKRIVEN' &&
    rad.efter === '<span style="border:1px solid #000" data-a11y-role="button" ' +
      'data-a11y-name="Ett">',
    rad.efter); }

/* CW-09 · fel forvantad tagg stoppar skrivningen */
{ const fil = nyFil();
  const r = migreraFil(fil, [{ art: 'prov', ordinal: 1, attribut: { 'data-hit': 'self' },
    ankare: { tagg: 'div', attribut: {} } }], { torr: true });
  prov('CW-09', 'ett ankare som inte stammer ger konflikt och ingen skrivning',
    r.logg[0].utfall === 'KONFLIKT' && r.skrivningar === 0, r.logg[0].skal); }

/* CW-10 · saknad ordinal hoppas over */
{ const fil = nyFil();
  const r = migreraFil(fil, [{ art: 'prov', ordinal: 999, attribut: { 'data-hit': 'self' } }],
    { torr: true });
  prov('CW-10', 'en ordinal som inte finns i kallan hoppas over utan skrivning',
    r.logg[0].utfall === 'HOPPAD' && r.skrivningar === 0, r.logg[0].skal); }

/* CW-11 · befintlig deklaration rors inte */
{ const fil = nyFil();
  const r = migreraFil(fil, [{ art: 'prov', ordinal: 3,
    attribut: { 'data-a11y-role': 'link' } }], { torr: true });
  prov('CW-11', 'ett element som redan bar en annan roll skrivs aldrig over',
    r.logg[0].utfall === 'KONFLIKT' && r.skrivningar === 0, r.logg[0].skal); }

/* CW-12 · torrkorning ror inte filen, och skarp korning skriver exakt det den loggar */
{ const fil = nyFil();
  const fore = readFileSync(fil, 'utf8');
  migreraFil(fil, [{ art: 'prov', ordinal: 1, attribut: { 'data-hit': 'self' },
    stil: { 'min-height': '48px' } }], { torr: true });
  const efterTorr = readFileSync(fil, 'utf8');
  const r = migreraFil(fil, [{ art: 'prov', ordinal: 1, attribut: { 'data-hit': 'self' },
    stil: { 'min-height': '48px' } }]);
  const efter = readFileSync(fil, 'utf8');
  const diff = efter.length - fore.length;
  prov('CW-12', 'torrkorning ror inte filen; skarp korning andrar bara den utpekade taggen',
    efterTorr === fore && r.skrivningar === 1 &&
    efter.replace(' data-hit="self"', '').replace(';min-height:48px', '') === fore,
    'skillnad ' + diff + ' tecken, ett enda element rort');
  rmSync(fil, { force: true }); }

/* CW-13 · ankaret talar normaliserad style men inte andrade attribut */
{ const kalla = '<span style="border:1px solid #000" data-id="a">';
  /* runtime-attribut far finnas i DOM utan att finnas i kallan */
  const extraIDom = jamforAnkare(kalla, { tagg: 'span',
    attribut: { 'data-id': 'a', 'data-dc-tpl': '60' } }, 'Ett');
  const felVarde = jamforAnkare(kalla, { tagg: 'span', attribut: { 'data-id': 'b' } }, 'Ett');
  const okantIKallan = jamforAnkare(kalla, { tagg: 'span', attribut: {} }, 'Ett');
  const taggfel = jamforAnkare(kalla, { tagg: 'div', attribut: { 'data-id': 'a' } }, 'Ett');
  const textfel = jamforAnkare(kalla, { tagg: 'span', attribut: { 'data-id': 'a' },
    text: 'Tva' }, 'Ett');
  prov('CW-13', 'ankaret talar runtime-tillagda attribut och normaliserad style, men aldrig ' +
    'andrad kalla',
    extraIDom.ok && !felVarde.ok && !okantIKallan.ok && !taggfel.ok && !textfel.ok,
    'extra i DOM: ok | annat varde: ' + felVarde.skal + ' | okant i kallan: ' +
      okantIKallan.skal + ' | fel tagg: ' + taggfel.skal + ' | fel text: ' + textfel.skal); }

/* CW-14 · nya stilegenskaper skrivs, kortformen padding gor det inte */
{ const bs = skrivStil('<span style="width:48px">', 'box-sizing', 'border-box');
  const br = skrivStil('<span style="width:48px">', 'border', '1.5px solid #3F5145');
  const kort = skrivStil('<span style="padding:8px">', 'padding', '6.5px');
  prov('CW-14', 'box-sizing och border far skrivas, kortformen padding far det aldrig',
    bs.ok && bs.text === '<span style="width:48px;box-sizing:border-box">' &&
    br.ok && br.text === '<span style="width:48px;border:1.5px solid #3F5145">' &&
    !kort.ok,
    'box-sizing ok, border ok, padding avvisad: ' + kort.skal); }

/* CW-15 · en sidospecifik padding laggs EFTER kortformen och ror den inte */
{ const r = skrivStil('<span style="padding:10px 18px;color:#111">', 'padding-left', '16.5px');
  prov('CW-15', 'padding-left laggs sist och lamnar kortformen orord',
    r.ok && r.ny &&
    r.text === '<span style="padding:10px 18px;color:#111;padding-left:16.5px">',
    r.text); }

/* CW-16 · border-radius ar inte border och far aldrig forvaxlas */
{ const r = skrivStil('<span style="border-radius:999px">', 'border', '1.5px solid #3F5145');
  const konflikt = skrivStil('<span style="border:1px solid #000">', 'border', '1.5px solid #3F5145');
  prov('CW-16', 'border-radius blockerar inte border, men en befintlig border gor det',
    r.ok && r.ny && r.text === '<span style="border-radius:999px;border:1.5px solid #3F5145">' &&
    !konflikt.ok,
    'radius: skrev igenom | befintlig border: ' + konflikt.skal); }

/* CW-17 · fargskrivning ar fortfarande omojlig genom skrivaren */
{ const c = skrivStil('<span style="color:#24382C">', 'color', '#17251D');
  const bg = skrivStil('<span style="a">', 'background', '#CE7C1E');
  prov('CW-17', 'color och background star inte i listan och kan darfor inte skrivas',
    !c.ok && !bg.ok, 'color: ' + c.skal + ' | background: ' + bg.skal); }

/* CW-18 · flera stilegenskaper i samma jobb skrivs alla eller ingen */
{ const fil = nyFil();
  const r = migreraFil(fil, [{ art: 'prov', ordinal: 4,
    stil: { 'box-sizing': 'border-box', 'border': '1.5px solid #3F5145' },
    ankare: { tagg: 'span', attribut: {} } }], { torr: true });
  const rFel = migreraFil(fil, [{ art: 'prov', ordinal: 4,
    stil: { 'box-sizing': 'border-box', 'min-height': '99px' },
    ankare: { tagg: 'span', attribut: {} } }], { torr: true });
  prov('CW-18', 'ett jobb med flera stilegenskaper faller helt om en enda krockar',
    r.logg[0].utfall === 'SKRIVEN' && r.logg[0].skrivna.length === 2 &&
    rFel.logg[0].utfall === 'KONFLIKT' && rFel.skrivningar === 0,
    'tva skrivna: ' + JSON.stringify(r.logg[0].skrivna) + ' | krock: ' + rFel.logg[0].skal);
  rmSync(fil, { force: true }); }

/* CW-19 · border-color skrivs som egen deklaration och ror aldrig bredd eller stil */
{ const r = skrivStil('<span style="border:1.5px solid rgba(245, 244, 237, 0.35)">',
    'border-color', 'rgba(245, 244, 237, 0.6)');
  const krock = skrivStil('<span style="border-color:#111">', 'border-color', '#788477');
  const bredd = /border:1\.5px solid/.test(r.text);
  prov('CW-19', 'border-color laggs efter kortformen och lamnar bredd och stil ororda',
    r.ok && r.ny && bredd &&
    r.text === '<span style="border:1.5px solid rgba(245, 244, 237, 0.35);' +
      'border-color:rgba(245, 244, 237, 0.6)">' &&
    !krock.ok,
    r.text + ' | befintlig border-color: ' + krock.skal); }

const ANTAL = 19;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('SKRIVARPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') +
  ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'skrivarprov.json'), JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
