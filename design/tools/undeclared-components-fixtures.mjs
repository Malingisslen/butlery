#!/usr/bin/env node
// F2 · METODPROV FOR DEN RIKTADE ODEKLARERADE-KOMPONENT-KONTROLLEN.
//      UD-01 … UD-08  ·  SEM-01 … SEM-05
//
// UD-01  de tva profil-toggles hittas
// UD-02  de 32 korrekt raddeklarerade toggles rapporteras INTE som odeklarerade
// UD-03  de 78 checkbox-kandidaterna hittas exakt
// UD-04  de 28 chip-kandidaterna hittas exakt
// UD-05  de tva taggdetalj-strukturerna rapporteras separat som UNKNOWN
// UD-06  deklarerad komponent med korrekt agare ger ingen falsk traff
// UD-07  saknad metadata blir aldrig automatiskt kontroll
// UD-08  unknown overlever hela pipen utan att tvingas till pass eller kontroll
//
// SEM-01 hog deklarationsgrad ensam gor INTE en forekomst till kontroll
// SEM-02 explicit positiv kontrollsemantik racker aven vid LAG deklarationsgrad
// SEM-03 profil|34 ar fortfarande kontroll, utan att nagon troskel anvands
// SEM-04 profil|38 ar fortfarande kontroll, utan att nagon troskel anvands
// SEM-05 de 108 tidigare UNKNOWN har inte tvingats till annan klass av metodfixen
//
// UD-01 … UD-05 och SEM-03 … SEM-05 kors mot den verkliga korpusobservationen i
// fas2/odeklarerade-komponenter.json. Ovriga kors mot syntetiska poster, dar
// poangen ar att regeln ska halla aven for konstruerade grannfall.

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { svep, arKandidat, VERDIKT, EVIDENSKRAV, ADJUDICERINGSREGEL }
  from './undeclared-components.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (!OUT) { console.error('✖ ange --out=<katalog utanfor reporoten>'); process.exit(2); }
const outAbs = resolve(OUT);
if (outAbs.startsWith(resolve('.') + '\\') || outAbs.startsWith(resolve('.') + '/')) {
  console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
mkdirSync(outAbs, { recursive: true });
const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

const rot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const K = JSON.parse(readFileSync(join(rot, 'fas2', 'odeklarerade-komponenter.json'), 'utf8'));
const MODUL = readFileSync(join(rot, 'tools', 'undeclared-components.mjs'), 'utf8');
const kand = K.D_adjudicering.kandidater;
const konv = new Map(K.C_observation.stodjandeTypkonvention.map(k => [k.komponent, k]));
const antalMed = (komp, verdikt) => kand.filter(r => r.komponent === komp &&
  (!verdikt || r.verdikt === verdikt)).length;

/* Byggstenar for syntetiska fall. */
const KRAV5 = { komponent: 'kryss', etikett: 'Synlig etikett',
  signatur: 'div|flex|TEXT+KOMPONENT', tillstandsstruktur: { typ: 'FYLLD_MED_IKON' },
  sektion: 'Installningar' };
const deklareradRad = (art, ordinal, roll, extra = {}) => ({ art, ordinal,
  ...KRAV5, ...extra, agare: { roll }, deklarerad: true });
const kandidatRad = (art, ordinal, extra = {}) => ({ art, ordinal,
  ...KRAV5, ...extra, deklarerad: false });

/* ── UD-01 · profilens tva toggles hittas ────────────────────────────*/
{ const p = kand.filter(r => r.art === 'profil' && r.komponent === 'toggle');
  prov('UD-01', 'de tva profil-toggles hittas av detektorn',
    p.length === 2 && p.some(r => r.identitet === 'profil|34') &&
    p.some(r => r.identitet === 'profil|38') &&
    p.every(r => r.verdikt === VERDIKT.INTERACTIVE_CONTROL && r.kontrolltyp === 'switch'),
    p.map(r => r.identitet + ' ' + r.verdikt).join(' · ')); }

/* ── UD-02 · de 32 raddeklarerade ar inte kandidater ─────────────────*/
{ const t = konv.get('toggle');
  prov('UD-02', 'de 32 korrekt raddeklarerade toggles rapporteras inte som odeklarerade',
    t && t.totalt === 34 && t.deklarerade === 32 && antalMed('toggle') === 2,
    'toggle i korpusen ' + (t ? t.deklarerade + ' av ' + t.totalt : '?') +
      ' deklarerade, kandidater ' + antalMed('toggle')); }

/* ── UD-03 · 78 checkbox-kandidater ──────────────────────────────────*/
{ const c = konv.get('checkbox');
  prov('UD-03', 'de 78 checkbox-kandidaterna hittas exakt',
    antalMed('checkbox') === 78 && c && c.totalt === 131 && c.deklarerade === 53,
    'checkbox totalt ' + (c ? c.totalt : '?') + ', deklarerade ' + (c ? c.deklarerade : '?') +
      ', kandidater ' + antalMed('checkbox')); }

/* ── UD-04 · 28 chip-kandidater ──────────────────────────────────────*/
{ const c = konv.get('chip');
  prov('UD-04', 'de 28 chip-kandidaterna hittas exakt',
    antalMed('chip') === 28 && c && c.totalt === 41 && c.deklarerade === 13,
    'chip totalt ' + (c ? c.totalt : '?') + ', deklarerade ' + (c ? c.deklarerade : '?') +
      ', kandidater ' + antalMed('chip')); }

/* ── UD-05 · taggdetalj separat som UNKNOWN ──────────────────────────*/
{ const t = kand.filter(r => r.art === 'taggdetalj' && !r.komponent);
  prov('UD-05', 'de tva taggdetalj-strukturerna rapporteras separat som UNKNOWN, inte som kontroller',
    t.length === 2 && t.every(r => r.verdikt === VERDIKT.UNKNOWN) &&
    t.every(r => (r.saknadeKrav || []).includes('AUTHORED_KOMPONENTTYP')),
    t.map(r => r.identitet + ' ' + r.verdikt).join(' · ') +
      ' — saknar authored komponenttyp, och formen ensam ar inte evidens'); }

/* ── UD-06 · deklarerad komponent med agare ger ingen falsk traff ────*/
{ const poster = [ deklareradRad('X', 1, 'switch', { komponent: 'toggle' }),
    { art: 'X', ordinal: 2, komponent: 'toggle', egenA11yRoll: 'switch', deklarerad: true },
    kandidatRad('X', 3, { komponent: 'toggle', harKnopp: true }) ];
  const r = svep(poster);
  prov('UD-06', 'deklarerad komponent med korrekt agardeklaration blir ingen falsk traff',
    !arKandidat(poster[0]) && !arKandidat(poster[1]) && arKandidat(poster[2]) &&
    r.kandidater.length === 1 && r.kandidater[0].ordinal === 3,
    '2 deklarerade filtreras bort, 1 odeklarerad kvar — kandidater ' + r.kandidater.length); }

/* ── UD-07 · saknad metadata blir aldrig automatiskt kontroll ────────*/
{ /* Kandidaten har mycket "mjuk" evidens — syskonkontroller och lokal
     skarmkonvention — men saknar ett av de fem kraven. */
  const poster = [ ...Array.from({ length: 6 }, (_, i) => deklareradRad('Y', 100 + i, 'checkbox')),
    ...Array.from({ length: 4 }, (_, i) => kandidatRad('Y', 200 + i,
      { sektion: null, syskonKontroller: 3, sammaTypDeklareradISkarmen: 6 })) ];
  const r = svep(poster);
  const k = r.kandidater;
  prov('UD-07', 'saknad metadata betyder aldrig automatiskt kontroll — resultatet ar kandidat',
    k.length === 4 && k.every(x => x.verdikt === VERDIKT.UNKNOWN) &&
    k.every(x => x.saknadeKrav.length === 1 && x.saknadeKrav[0] === 'INSTALLNINGSKONTEXT') &&
    k.every(x => x.prioritet > 0),
    'fyra av fem evidenskrav uppfyllda racker inte; syskonparitet och skarmkonvention hojer ' +
      'bara prioriteten till ' + k[0].prioritet); }

/* ── UD-08 · unknown overlever hela pipen ────────────────────────────*/
{ const poster = [ kandidatRad('Z', 1, { komponent: 'gizmo', sektion: null }),
    kandidatRad('Z', 2, { komponent: null, harKnopp: true, sektion: null }),
    deklareradRad('Z', 3, 'button', { komponent: 'gizmo' }) ];
  const r = svep(poster);
  const u = r.kandidater.filter(x => x.verdikt === VERDIKT.UNKNOWN);
  prov('UD-08', 'unknown overlever hela pipen utan att tvingas till pass eller kontroll',
    r.summerar && r.kandidater.length === 2 && u.length === 2 &&
    r.rakn[VERDIKT.INTERACTIVE_CONTROL] === 0 &&
    r.rakn[VERDIKT.NON_INTERACTIVE_STATE_GRAPHIC] === 0 &&
    r.rakn[VERDIKT.DECORATIVE_GRAPHIC] === 0 &&
    Object.values(r.rakn).reduce((a, b) => a + b, 0) === r.kandidater.length,
    'bada kandidaterna slutar UNKNOWN, rakningen summerar och ingen kategori har smugit ivag'); }

/* ── SEM-01 · hog frekvens ensam gor ingen kontroll ──────────────────*/
{ /* 19 av 20 forekomster ar deklarerade = 95 %, over den gamla troskeln.
     Kandidaten saknar ett enda evidenskrav och far darfor inte bli kontroll. */
  const poster = [ ...Array.from({ length: 19 }, (_, i) => deklareradRad('Q', 10 + i, 'switch')),
    kandidatRad('Q', 99, { sektion: null }) ];
  const r = svep(poster);
  const k = r.kandidater[0];
  const grad = r.konvention.find(c => c.komponent === 'kryss').grad;
  prov('SEM-01', 'en forekomst blir inte kontroll enbart for att typens deklarationsgrad overstiger 90 %',
    grad === 0.95 && k.verdikt === VERDIKT.UNKNOWN &&
    k.saknadeKrav.includes('INSTALLNINGSKONTEXT') &&
    !k.skal.some(s => /troskel/i.test(s)),
    'deklarationsgrad 95 % men ett evidenskrav saknas → ' + k.verdikt +
      '; frekvensen namns inte i skalen'); }

/* ── SEM-02 · lag frekvens hindrar inte en kontroll ──────────────────*/
{ /* 4 av 10 = 40 %, langt under den gamla troskeln. Kandidaterna uppfyller
     samtliga fem evidenskrav och ska darfor bli kontroller. */
  const poster = [ ...Array.from({ length: 4 }, (_, i) => deklareradRad('W', 10 + i, 'checkbox')),
    ...Array.from({ length: 6 }, (_, i) => kandidatRad('W', 20 + i)) ];
  const r = svep(poster);
  const grad = r.konvention.find(c => c.komponent === 'kryss').grad;
  prov('SEM-02', 'explicit positiv kontrollsemantik racker aven nar typens deklarationsgrad ar lag',
    grad === 0.4 && r.rakn[VERDIKT.INTERACTIVE_CONTROL] === 6 &&
    r.kandidater.every(k => k.kontrolltyp === 'checkbox') &&
    r.kandidater.every(k => k.uppfylldaKrav.length === 5),
    'deklarationsgrad 40 % men alla fem evidenskrav uppfyllda → ' +
      r.rakn[VERDIKT.INTERACTIVE_CONTROL] + ' kontroller'); }

/* ── SEM-03 / SEM-04 · profil utan troskel ───────────────────────────*/
for (const [id, ident, etikett] of [['SEM-03', 'profil|34', 'Sökbar för vänner'],
  ['SEM-04', 'profil|38', 'Visa mina recept publikt']]) {
  const p = kand.find(r => r.identitet === ident);
  const ingenTroskelIModulen = !/TROSKEL/.test(MODUL);
  prov(id, ident + ' klassificeras fortfarande INTERACTIVE_CONTROL utan att en troskel anvands',
    p && p.verdikt === VERDIKT.INTERACTIVE_CONTROL && p.kontrolltyp === 'switch' &&
    p.uppfylldaKrav.length === 5 &&
    p.skal.some(s => s.includes(etikett)) &&
    !p.skal.some(s => /troskel|%/.test(s.replace('$ingenFrekvensregel', ''))) &&
    ingenTroskelIModulen &&
    ADJUDICERINGSREGEL.some(x => /varken tillracklig eller nodvandig/.test(x)),
    p ? 'fem av fem evidenskrav: ' + p.uppfylldaKrav.join(', ') +
      '; ingen troskel finns kvar i modulen' : 'kandidaten saknas'); }

/* ── SEM-05 · de 108 unknown ar ororda av metodfixen ─────────────────*/
{ const j = K.D_adjudicering.jamfortMedBlockA;
  const u = kand.filter(r => r.verdikt === VERDIKT.UNKNOWN);
  prov('SEM-05', 'de 108 tidigare UNKNOWN har inte tvingats till annan klass av metodandringen',
    u.length === 108 && j && j.antalBytteKlass === 0 &&
    K.D_adjudicering.rakn[VERDIKT.INTERACTIVE_CONTROL] === 2 &&
    K.D_adjudicering.rakn[VERDIKT.NON_INTERACTIVE_STATE_GRAPHIC] === 0 &&
    K.D_adjudicering.rakn[VERDIKT.DECORATIVE_GRAPHIC] === 0 &&
    K.D_adjudicering.summerar,
    '110 = 2 / 0 / 0 / 108, och noll kandidater bytte klass av metodfixen'); }

const ANTAL = 13;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('EVIDENSKRAV FOR INTERACTIVE_CONTROL');
for (const [k, v] of Object.entries(EVIDENSKRAV)) console.log('  ' + k + ': ' + v);
console.log('');
console.log('ODEKLARERADE-KOMPONENT-PROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') +
  ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'odeklareradkomponentprov.json'),
  JSON.stringify({ resultat, evidenskrav: EVIDENSKRAV }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
