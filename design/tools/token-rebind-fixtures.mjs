#!/usr/bin/env node
// F2-R04 · PROV FOR TOKEN_REBIND, SCOPED_OVERRIDE OCH MALIDENTITET.
//
// TR-12 ar regression for det nyupptackta scopefelet: matchning pa roll och
// undergrupp UTAN kandidatens ljusvarde lat fel instanser in i skrivmangden.

import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { rebindITagg, overrideITagg } from './token-rebind.mjs';
import { malMatchning, MALREGEL } from './decision-target.mjs';
import { arAktiv } from './theme-decisions.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (OUT) { const o = resolve(OUT);
  if (o.startsWith(resolve('.') + '\\') || o.startsWith(resolve('.') + '/')) {
    console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
  mkdirSync(o, { recursive: true }); }

const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });
const post = (eg) => ({ egenskap: eg, ankare: { egenskap: eg } });

/* ── TR-01 · enkel rebind ───────────────────────────────────────────────── */
{ const t = '<div style="padding:8px;background:var(--yta-upphojd);color:#222">';
  const r = rebindITagg(t, post('background-color'), '--yta-upphojd', '--yta-upphojd-d2');
  prov('TR-01', 'var(--gammal) byts mot var(--ny) pa exakt den ankrade egenskapen',
    r.ok && r.text.includes('background:var(--yta-upphojd-d2)') && r.text.includes('color:#222'),
    r.ok ? r.text : r.skal); }

/* ── TR-02 · icke-mal lamnas orort ──────────────────────────────────────── */
{ const t = '<div style="background:var(--yta-upphojd);border-top-color:var(--yta-upphojd)">';
  const r = rebindITagg(t, post('background-color'), '--yta-upphojd', '--ny');
  prov('TR-02', 'en annan egenskap som bar samma token lamnas helt oforandrad',
    r.ok && r.text.includes('background:var(--ny)') && r.text.includes('border-top-color:var(--yta-upphojd)'),
    r.ok ? r.text : r.skal); }

/* ── TR-03 · samma gamla token, tva olika mal ───────────────────────────── */
{ const yttre = '<div style="background:var(--yta-upphojd-b2)">';
  const inre = '<div style="background:var(--yta-upphojd-b2)">';
  const a = rebindITagg(yttre, post('background-color'), '--yta-upphojd-b2', '--yta-upphojd-d12');
  const b = rebindITagg(inre, post('background-color'), '--yta-upphojd-b2', '--yta-upphojd-d16');
  prov('TR-03', 'tva instanser med samma delade token kan bindas till tva olika beslutstokens',
    a.ok && b.ok && a.text.includes('--yta-upphojd-d12') && b.text.includes('--yta-upphojd-d16') &&
    !a.text.includes('d16') && !b.text.includes('d12'),
    a.ok && b.ok ? 'RC-YH-17 -> d12 · RC-YH-18 -> d16' : (a.skal || b.skal)); }

/* ── TR-04/TR-05 · vardena kommer ur tokendefinitionen ──────────────────── */
{ // Tokendefinitionen ar det som avgor bade ljust och morkt. Provet bevisar
  // att definitionen byggs med IDENTISKT ljusvarde och beslutets morka.
  const def = (namn, ljus, mork) => ({ namn, ljus, mork });
  const d17 = def('--yta-upphojd-d12', 'rgb(230, 234, 217)', '#24382c');
  const d18 = def('--yta-upphojd-d16', 'rgb(230, 234, 217)', '#4a5c43');
  const ljusFore = 'rgb(230, 234, 217)';
  prov('TR-04', 'ljusvardet i den nya tokenen ar identiskt med mattet fore migrationen',
    d17.ljus === ljusFore && d18.ljus === ljusFore,
    d17.ljus + ' och ' + d18.ljus + ' mot uppmatt ' + ljusFore);
  prov('TR-05', 'morkvardet foljer respektive registrerat beslut, aldrig ett delat varde',
    d17.mork === '#24382c' && d18.mork === '#4a5c43' && d17.mork !== d18.mork,
    d17.mork + ' mot ' + d18.mork); }

/* ── TR-06 · fel gammal token ───────────────────────────────────────────── */
{ const t = '<div style="background:var(--yta-upphojd)">';
  const r = rebindITagg(t, post('background-color'), '--yta-kontroll-b1', '--ny');
  prov('TR-06', 'fel forvantad gammal token ger fail closed',
    !r.ok && /ingen deklaration/.test(r.skal), r.ok ? 'skrev anda' : r.skal); }

/* ── TR-07 · ingen forekomst ────────────────────────────────────────────── */
{ const t = '<div style="background:#e6ead9">';
  const r = rebindITagg(t, post('background-color'), '--yta-upphojd', '--ny');
  prov('TR-07', '0 matchande var-forekomster ger fail closed',
    !r.ok, r.ok ? 'skrev anda' : r.skal); }

/* ── TR-08 · tvetydigt ──────────────────────────────────────────────────── */
{ const t = '<div style="background:linear-gradient(var(--x),var(--x))">';
  const r = rebindITagg(t, post('background-color'), '--x', '--ny');
  const t2 = '<div style="background:var(--x);background-color:var(--x)">';
  const r2 = rebindITagg(t2, post('background-color'), '--x', '--ny');
  prov('TR-08', 'flera forekomster av samma token ger fail closed, aldrig en gissning',
    !r.ok && !r2.ok && /tvetydig/.test(r.skal) && /tvetydig/.test(r2.skal),
    r.skal + ' · ' + r2.skal); }

/* ── TR-09 · idempotens ─────────────────────────────────────────────────── */
{ const t = '<div style="background:var(--yta-upphojd)">';
  const ett = rebindITagg(t, post('background-color'), '--yta-upphojd', '--ny');
  const tva = rebindITagg(ett.text, post('background-color'), '--yta-upphojd', '--ny');
  prov('TR-09', 'en andra korning efter lyckad migration ger 0 skrivningar',
    ett.ok && !tva.ok, ett.ok ? 'forsta ok · andra ' + tva.skal : ett.skal); }

/* ── TR-10 · ersatt beslut far aldrig vara mal ──────────────────────────── */
{ const reg = { beslut: [
    { beslutsId: 'X', kandidatId: 'X', omfattning: 'WHOLE_CANDIDATE', roll: 'yta-upphojd',
      ljusvarde: '#e6ead9', morkvarde: '#24382c', tokenNamn: '--gammal', status: 'SUPERSEDED', aktiv: false },
    { beslutsId: 'X', kandidatId: 'X', omfattning: 'WHOLE_CANDIDATE', roll: 'yta-upphojd',
      ljusvarde: '#e6ead9', morkvarde: '#4a5c43', tokenNamn: '--ny', status: 'ACTIVE', aktiv: true }] };
  const t = malMatchning(reg, { kandidatId: 'X', roll: 'yta-upphojd', undergrupp: null, ljusvarde: '#e6ead9' });
  prov('TR-10', 'ett ersatt beslut kan aldrig bli mal for en rebind',
    t.ok && t.beslut.tokenNamn === '--ny' && reg.beslut.filter(arAktiv).length === 1,
    t.ok ? 'valde ' + t.beslut.tokenNamn : t.skal); }

/* ── TR-11 · registerordning rorer inga identiteter ─────────────────────── */
{ const reg = { beslut: [
    { beslutsId: 'A', kandidatId: 'A', omfattning: 'WHOLE_CANDIDATE', roll: 'yta-upphojd', ljusvarde: '#aaa', morkvarde: '#111', tokenNamn: '--a', aktiv: true },
    { beslutsId: 'B', kandidatId: 'B', omfattning: 'WHOLE_CANDIDATE', roll: 'yta-upphojd', ljusvarde: '#bbb', morkvarde: '#222', tokenNamn: '--b', aktiv: true }] };
  const fore = malMatchning(reg, { kandidatId: 'B', roll: 'yta-upphojd', undergrupp: null, ljusvarde: '#bbb' });
  reg.beslut.reverse();
  reg.beslut.unshift({ beslutsId: 'C', kandidatId: 'C', omfattning: 'WHOLE_CANDIDATE', roll: 'yta-upphojd', ljusvarde: '#ccc', morkvarde: '#333', tokenNamn: '--c', aktiv: true });
  const efter = malMatchning(reg, { kandidatId: 'B', roll: 'yta-upphojd', undergrupp: null, ljusvarde: '#bbb' });
  prov('TR-11', 'omsortering och insattning i registret andrar ingen befintlig tokenidentitet',
    fore.ok && efter.ok && fore.beslut.tokenNamn === efter.beslut.tokenNamn,
    (fore.beslut || {}).tokenNamn + ' -> ' + (efter.beslut || {}).tokenNamn); }

/* ── TR-12 · REGRESSION for scopefelet ──────────────────────────────────── */
{ const UG = 'ingen-kontroll · direkt-pa-appytan · utan-state · bar-text · utan-ikon · stor-yta · tackande';
  const reg = { beslut: [
    { beslutsId: 'CAND-yta-upphojd-#e6ead9 ‖ ' + UG, kandidatId: 'CAND-yta-upphojd-#e6ead9',
      omfattning: 'SUBGROUP', semantiskUndergrupp: UG, roll: 'yta-upphojd',
      ljusvarde: '#e6ead9', morkvarde: '#24382c', tokenNamn: '--beslutad', aktiv: true }] };
  // Samma roll, samma undergrupp — men en ANNAN ljuskandidat.
  const ratt = malMatchning(reg, { kandidatId: 'CAND-yta-upphojd-#e6ead9', roll: 'yta-upphojd', undergrupp: UG, ljusvarde: '#e6ead9' });
  const fel = malMatchning(reg, { kandidatId: 'CAND-yta-upphojd-#24382c', roll: 'yta-upphojd', undergrupp: UG, ljusvarde: '#24382c' });
  prov('TR-12', 'samma roll och samma undergrupp men annan ljuskandidat matchar ALDRIG',
    ratt.ok && ratt.beslut.tokenNamn === '--beslutad' && !fel.ok && /ingen/.test(fel.skal),
    'ratt kandidat: ' + (ratt.ok ? 'traff' : ratt.skal) + ' · fel kandidat: ' + (fel.ok ? 'TRAFF ✖' : fel.skal)); }

/* ── TR-13 · flera matchande beslut ger fail closed ─────────────────────── */
{ const reg = { beslut: [
    { beslutsId: 'A', kandidatId: 'K', omfattning: 'WHOLE_CANDIDATE', roll: 'yta-upphojd', ljusvarde: '#aaa', morkvarde: '#111', tokenNamn: '--a', aktiv: true },
    { beslutsId: 'B', kandidatId: 'K', omfattning: 'WHOLE_CANDIDATE', roll: 'yta-upphojd', ljusvarde: '#aaa', morkvarde: '#222', tokenNamn: '--b', aktiv: true }] };
  const t = malMatchning(reg, { kandidatId: 'K', roll: 'yta-upphojd', undergrupp: null, ljusvarde: '#aaa' });
  prov('TR-13', 'tva beslut som bada matchar ger fail closed, aldrig forsta traffen',
    !t.ok && /flera/i.test(t.skal), t.ok ? 'valde ' + t.beslut.tokenNamn : t.skal); }

/* ── TR-14 · SCOPED_OVERRIDE ────────────────────────────────────────────── */
{ const t = '<span class="x">';
  const r = overrideITagg(t, post('color'), '--text-innehall-d1');
  const t2 = '<span style="font-weight:600">';
  const r2 = overrideITagg(t2, post('color'), '--text-innehall-d1');
  prov('TR-14', 'arvd eller klassregelburen farg far en EGEN deklaration pa elementet',
    r.ok && r.text === '<span class="x" style="color:var(--text-innehall-d1)">' &&
    r2.ok && r2.text.includes('font-weight:600;color:var(--text-innehall-d1)'),
    r.text + ' · ' + r2.text); }

{ const t = '<span style="color:#8a5212">';
  const r = overrideITagg(t, post('color'), '--ny');
  prov('TR-15', 'override pa en egenskap som redan star i taggen ar fel operation — fail closed',
    !r.ok && /finns redan/.test(r.skal), r.ok ? 'skrev anda' : r.skal); }

const ANTAL = 15;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('REBINDPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
if (OUT) writeFileSync(join(resolve(OUT), 'rebindprov.json'), JSON.stringify({ resultat, MALREGEL }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
