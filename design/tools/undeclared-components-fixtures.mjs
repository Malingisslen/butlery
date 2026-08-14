#!/usr/bin/env node
// F2 · METODPROV FOR DEN RIKTADE ODEKLARERADE-KOMPONENT-KONTROLLEN.  UD-01 … UD-08
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
// UD-01 … UD-05 kors mot den verkliga korpusobservationen i
// fas2/odeklarerade-komponenter.json. UD-06 … UD-08 kors mot syntetiska
// poster, dar sjalva poangen ar att provet ska halla aven for konstruerade
// grannfall som inte finns i korpusen i dag.

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { svep, arKandidat, adjudicera, typkonvention, prioritet,
  VERDIKT, TROSKEL_TYPKONVENTION } from './undeclared-components.mjs';

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
const kand = K.D_adjudicering.kandidater;
const konv = new Map(K.C_observation.typkonvention.map(k => [k.komponent, k]));
const antalMed = (komp, verdikt) => kand.filter(r => r.komponent === komp &&
  (!verdikt || r.verdikt === verdikt)).length;

/* ── UD-01 · profilens tva toggles hittas ────────────────────────────*/
{ const p = kand.filter(r => r.art === 'profil' && r.komponent === 'toggle');
  prov('UD-01', 'de tva profil-toggles hittas av detektorn',
    p.length === 2 && p.some(r => r.identitet === 'profil|34') &&
    p.some(r => r.identitet === 'profil|38') &&
    p.every(r => r.verdikt === VERDIKT.INTERACTIVE_CONTROL && r.kontrolltyp === 'switch'),
    p.map(r => r.identitet + ' ' + r.verdikt).join(' · ')); }

/* ── UD-02 · de 32 raddeklarerade ar inte kandidater ─────────────────*/
{ const t = konv.get('toggle');
  const kandToggles = antalMed('toggle');
  prov('UD-02', 'de 32 korrekt raddeklarerade toggles rapporteras inte som odeklarerade',
    t && t.totalt === 34 && t.deklarerade === 32 && kandToggles === 2,
    'toggle i korpusen ' + (t ? t.deklarerade + ' av ' + t.totalt : '?') +
      ' deklarerade, kandidater ' + kandToggles); }

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
    t.every(r => r.skal.some(s => /formen ar inte evidens/.test(s))),
    t.map(r => r.identitet + ' ' + r.verdikt).join(' · ') +
      ' — avvisas pa att strukturell form ensam inte ar evidens'); }

/* ── UD-06 · deklarerad komponent med agare ger ingen falsk traff ────*/
{ const poster = [
    { art: 'X', ordinal: 1, komponent: 'toggle', agare: { roll: 'switch' }, deklarerad: true },
    { art: 'X', ordinal: 2, komponent: 'toggle', egenA11yRoll: 'switch', deklarerad: true },
    { art: 'X', ordinal: 3, komponent: 'toggle', harKnopp: true, deklarerad: false }];
  const r = svep(poster);
  prov('UD-06', 'deklarerad komponent med korrekt agardeklaration blir ingen falsk traff',
    !arKandidat(poster[0]) && !arKandidat(poster[1]) && arKandidat(poster[2]) &&
    r.kandidater.length === 1 && r.kandidater[0].ordinal === 3,
    '2 deklarerade filtreras bort, 1 odeklarerad kvar — kandidater ' + r.kandidater.length); }

/* ── UD-07 · saknad metadata blir aldrig automatiskt kontroll ────────*/
{ /* En komponenttyp som ligger UNDER troskeln, med all "mjuk" evidens pahang:
     syskonkontroller, samma typ deklarerad i skarmen och en synlig etikett.
     Ingen av dem far racka. */
  const poster = [
    ...Array.from({ length: 6 }, (_, i) => ({ art: 'Y', ordinal: 100 + i,
      komponent: 'kryss', agare: { roll: 'checkbox' }, deklarerad: true })),
    ...Array.from({ length: 4 }, (_, i) => ({ art: 'Y', ordinal: 200 + i,
      komponent: 'kryss', deklarerad: false, etikett: 'Synlig etikett',
      syskonKontroller: 3, syskonRoller: ['checkbox'], sammaTypDeklareradISkarmen: 6 }))];
  const r = svep(poster);
  const k = r.kandidater;
  const typ = typkonvention(poster).get('kryss');
  prov('UD-07', 'saknad metadata betyder aldrig automatiskt kontroll — resultatet ar kandidat',
    k.length === 4 && k.every(x => x.verdikt === VERDIKT.UNKNOWN) &&
    typ.grad === 0.6 && !typ.entydig && k.every(x => x.prioritet === 3),
    'typkonvention 6/10 = 60 % ligger under ' + (TROSKEL_TYPKONVENTION * 100) +
      ' %; syskonparitet och skarmkonvention hojer prioritet till 3 men ger inte verdikt'); }

/* ── UD-08 · unknown overlever hela pipen ────────────────────────────*/
{ const poster = [
    { art: 'Z', ordinal: 1, komponent: 'gizmo', deklarerad: false, etikett: 'Namn' },
    { art: 'Z', ordinal: 2, harKnopp: true, deklarerad: false, etikett: 'Namn' },
    { art: 'Z', ordinal: 3, komponent: 'gizmo', agare: { roll: 'button' }, deklarerad: true }];
  const r = svep(poster);
  const u = r.kandidater.filter(x => x.verdikt === VERDIKT.UNKNOWN);
  prov('UD-08', 'unknown overlever hela pipen utan att tvingas till pass eller kontroll',
    r.summerar && r.kandidater.length === 2 && u.length === 2 &&
    r.rakn[VERDIKT.INTERACTIVE_CONTROL] === 0 &&
    r.rakn[VERDIKT.NON_INTERACTIVE_STATE_GRAPHIC] === 0 &&
    r.rakn[VERDIKT.DECORATIVE_GRAPHIC] === 0 &&
    Object.values(r.rakn).reduce((a, b) => a + b, 0) === r.kandidater.length,
    'bada kandidaterna slutar UNKNOWN, rakningen summerar och ingen kategori har smugit ivag'); }

const ANTAL = 8;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('ODEKLARERADE-KOMPONENT-PROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') +
  ' godkanda=' + ok + ' av ' + ANTAL);
writeFileSync(join(outAbs, 'odeklareradkomponentprov.json'),
  JSON.stringify({ resultat }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
