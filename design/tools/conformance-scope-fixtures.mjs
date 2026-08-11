#!/usr/bin/env node
// F2-R04 · METODPROV FOR SEMANTISKA SCOPEGRANSER.  CS-01 … CS-15
//
// Felklassen proven finns for: scope avgjordes av CSS-klassnamn. Den regeln
// foll nar .sc-cap visade sig bara bade produktrubrik och ritningsannotering.
// Proven kraver att den nya motorn avgor scope ur AUTHORED grans, att den ar
// symmetrisk at bada hallen, att en annotationsgrans inte kan gomma produkt-UI,
// och att scope aldrig lacker in i vare sig bakgrundsupplosning eller tackning.

import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { losScope, granskaIntegritet, maladBakgrund, arProdukt,
  SCOPE_ATTRIBUT, SCOPEVARDEN } from './conformance-scope.mjs';
import { tackning } from './theme-contract.mjs';

const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=')[1];
const OUT = arg('out');
if (OUT) { const o = resolve(OUT);
  if (o.startsWith(resolve('.') + '\\') || o.startsWith(resolve('.') + '/')) {
    console.error('✖ --out ligger inne i reporoten.'); process.exit(2); }
  mkdirSync(o, { recursive: true }); }

const resultat = [];
const prov = (id, vad, ok, diag) => resultat.push({ id, vad, ok: !!ok, diag });

// Nodbyggare. Kedjan gar fran elementet och uppat, precis som i sonden.
const nod = (o = {}) => ({ scope: o.scope ?? null, legacyRoot: !!o.legacyRoot,
  kontroll: !!o.kontroll, productSurface: !!o.productSurface,
  bakgrund: o.bakgrund ?? null, klass: o.klass ?? null, tagg: o.tagg ?? 'div' });

/* ── CS-01 · ramlos produkt-UI kommer in genom explicit product ─────────── */
{ const utan = losScope([nod({ klass: 'sc-cap' }), nod({ klass: 'sc-wide' }), nod()]);
  const med = losScope([nod({ klass: 'sc-cap' }), nod({ klass: 'sc-wide', scope: 'product' }), nod()]);
  prov('CS-01', 'explicit product tar in ramlos produkt-UI som legacy-regeln aldrig sag',
    utan.scope === null && utan.kalla === 'ingen' &&
    med.scope === 'product' && med.kalla === 'explicit' && med.ankare === 1,
    'utan grans: ' + utan.kalla + ' · med grans: ' + med.scope + '/' + med.kalla + ' pa niva ' + med.ankare); }

/* ── CS-02 · annotation lyfts ur produktnamnaren ───────────────────────── */
{ const kedja = [nod({ klass: 'sc-cap' }), nod({ scope: 'annotation' }), nod({ legacyRoot: true }), nod()];
  const r = losScope(kedja);
  prov('CS-02', 'text under annotation raknas inte som produkttext',
    r.scope === 'annotation' && arProdukt(kedja) === false,
    'scope ' + r.scope + ' · arProdukt ' + arProdukt(kedja)); }

/* ── CS-03 · product aterintrader inuti annotation ─────────────────────── */
{ const r = losScope([nod({ klass: 'sc-btn' }), nod({ scope: 'product' }), nod({ scope: 'annotation' }), nod()]);
  prov('CS-03', 'en produktrot inuti annotation aterintrader i produktscope',
    r.scope === 'product' && r.kalla === 'explicit' && r.ankare === 1,
    'scope ' + r.scope + ' · ankare ' + r.ankare); }

/* ── CS-04 · annotation skar ut BARA sin egen subtrad ─────────────────── */
{ const produktrot = nod({ scope: 'product' });
  const syskonA = losScope([nod({ klass: 'sc-cap' }), produktrot, nod()]);
  const syskonB = losScope([nod({ klass: 'sc-cap' }), nod({ scope: 'annotation' }), produktrot, nod()]);
  prov('CS-04', 'annotation inuti product skar ut endast annotationssubtraden',
    syskonA.scope === 'product' && syskonB.scope === 'annotation',
    'syskon utan grans: ' + syskonA.scope + ' · syskon under annotation: ' + syskonB.scope); }

/* ── CS-05 · narmaste explicita grans vinner ───────────────────────────── */
{ const full = [nod(), nod({ scope: 'product' }), nod(), nod({ scope: 'annotation' }), nod({ scope: 'product' }), nod()];
  const vid = i => losScope(full.slice(i));
  const svar = [vid(0).scope, vid(2).scope, vid(4).scope, vid(5).scope];
  prov('CS-05', 'narmaste explicita grans vinner — ingen sida vinner globalt',
    svar[0] === 'product' && svar[1] === 'annotation' && svar[2] === 'product' && svar[3] === null,
    'fran djup 0/2/4/5: ' + svar.map(x => x === null ? 'ingen' : x).join(' · ')); }

/* ── CS-06 · .sc-cap andrar ingenting pa egen hand ─────────────────────── */
{ const bygg = k => [nod({ klass: k }), nod({ klass: 'sc-body' }), nod({ legacyRoot: true }), nod()];
  const a = losScope(bygg('sc-cap')), b = losScope(bygg('nagot-helt-annat'));
  const utanRot = losScope([nod({ klass: 'sc-cap' }), nod()]);
  prov('CS-06', '.sc-cap utan explicit grans forandrar inte scope pa egen hand',
    a.scope === b.scope && a.kalla === b.kalla && a.scope === 'product' &&
    utanRot.scope === null,
    'sc-cap ' + a.scope + '/' + a.kalla + ' = annan klass ' + b.scope + '/' + b.kalla +
    ' · utan rot: ' + utanRot.kalla); }

/* ── CS-07 · samma klass, tva scopen ───────────────────────────────────── */
{ const iProdukt = losScope([nod({ klass: 'sc-cap' }), nod({ scope: 'product' }), nod()]);
  const iAnnotation = losScope([nod({ klass: 'sc-cap' }), nod({ scope: 'annotation' }), nod()]);
  prov('CS-07', 'samma .sc-cap ar produkt i en produktsubtrad och annotation i en annotationssubtrad',
    iProdukt.scope === 'product' && iAnnotation.scope === 'annotation',
    '"SA TOLKADE JAG BESKRIVNINGEN" -> ' + iProdukt.scope +
    ' · "Ratt · en spalt, bottenrad" -> ' + iAnnotation.scope); }

/* ── CS-08 · .sc-label / .sc-id avgor inte langre pa egen hand ─────────── */
{ const label = losScope([nod({ klass: 'sc-label' }), nod({ scope: 'product' }), nod()]);
  const id = losScope([nod({ klass: 'sc-id' }), nod({ scope: 'product' }), nod()]);
  const rent = losScope([nod({ klass: 'sc-label' }), nod()]);
  prov('CS-08', '.sc-label och .sc-id far inte ensamma avgora annotation i den nya motorn',
    label.scope === 'product' && id.scope === 'product' && rent.kalla === 'ingen',
    'sc-label under product -> ' + label.scope + ' · sc-id under product -> ' + id.scope +
    ' · utan grans -> ' + rent.kalla); }

/* ── CS-09 · kontroll under annotation ar fail closed ─────────────────── */
{ const r = granskaIntegritet([nod({ kontroll: true, klass: 'sc-btn' }), nod({ scope: 'annotation' }), nod()]);
  prov('CS-09', 'produktkontroll under annotation utan narmare produktgrans => fail closed',
    r.ok === false && r.kod === 'SCOPE_CONFLICT',
    (r.kod || 'slapptes igenom') + ' · ' + (r.skal || '')); }

/* ── CS-10 · nastlad produktgrans loser konflikten ────────────────────── */
{ const r = granskaIntegritet([nod({ kontroll: true, klass: 'sc-btn' }),
    nod({ scope: 'product' }), nod({ scope: 'annotation' }), nod()]);
  prov('CS-10', 'annotation med nastlad produktgrans: kontrollen tillhor produkten',
    r.ok === true && r.scope === 'product' && r.kod === null,
    'ok=' + r.ok + ' scope=' + r.scope); }

/* ── CS-11 · explicit slar legacy ─────────────────────────────────────── */
{ const r = losScope([nod({ klass: 'sc-cap' }), nod({ scope: 'annotation' }), nod({ legacyRoot: true }), nod()]);
  const p = losScope([nod(), nod({ scope: 'product' }), nod({ legacyRoot: true }), nod()]);
  prov('CS-11', 'explicit data-conformance-scope har foretrade framfor .sc-phone/.sc-card',
    r.scope === 'annotation' && r.kalla === 'explicit' && p.kalla === 'explicit',
    'annotation inuti sc-phone -> ' + r.scope + '/' + r.kalla); }

/* ── CS-12 · legacy-populationen ar oforandrad dar metadata saknas ────── */
{ // Fyra fall ur den verkliga korpusen, sa som dagens motor beter sig.
  const fall = [
    { namn: 'text i telefonram', kedja: [nod({ klass: 'sc-cap' }), nod({ legacyRoot: true }), nod()], vantat: 'product' },
    { namn: 'text i kort', kedja: [nod({ klass: 'sc-row' }), nod({ legacyRoot: true }), nod()], vantat: 'product' },
    { namn: 'bildtext utanfor ram', kedja: [nod({ klass: 'sc-label' }), nod()], vantat: null },
    { namn: 'ramlos bred layout', kedja: [nod({ klass: 'sc-wide' }), nod()], vantat: null }];
  const fel = fall.filter(f => losScope(f.kedja).scope !== f.vantat);
  prov('CS-12', 'legacy-populationen forblir kompatibel dar explicit metadata saknas',
    fel.length === 0, fel.length ? 'avvek: ' + fel.map(f => f.namn).join(', ')
      : fall.length + ' fall identiska med dagens utfall'); }

/* ── CS-13 · scope ror aldrig bakgrundsupplosningen ───────────────────── */
{ const bas = [nod({ klass: 'sc-cap' }), nod({ bakgrund: 'rgb(245, 244, 237)' }), nod({ bakgrund: 'rgb(255, 255, 255)' }), nod()];
  const medScope = [nod({ klass: 'sc-cap', scope: 'annotation' }),
    nod({ bakgrund: 'rgb(245, 244, 237)', scope: 'product', productSurface: true }),
    nod({ bakgrund: 'rgb(255, 255, 255)', legacyRoot: true }), nod({ scope: 'product' })];
  const a = maladBakgrund(bas), b = maladBakgrund(medScope);
  prov('CS-13', 'scopeklassificering forandrar inte den faktiska bakgrundsupplosningen',
    !!a && !!b && a.farg === b.farg && a.ankare === b.ankare &&
    a.farg === 'rgb(245, 244, 237)',
    'utan scope: ' + a.farg + ' niva ' + a.ankare + ' · med scope: ' + b.farg + ' niva ' + b.ankare); }

/* ── CS-14 · produktrot ar aldrig en implicit textbakgrund ────────────── */
{ const kedja = [nod({ klass: 'sc-cap' }),
    nod({ scope: 'product', productSurface: true, legacyRoot: true }), nod()];
  const bg = maladBakgrund(kedja);
  const r = losScope(kedja);
  prov('CS-14', 'en produktrot utan malad bakgrund ger ingen bakgrund — scope ar ingen ytdeklaration',
    bg === null && r.scope === 'product',
    'scope ' + r.scope + ' · bakgrund ' + JSON.stringify(bg)); }

/* ── CS-15 · scope ger ingen tackningskredit ──────────────────────────── */
{ const utan = [{ art: 'bredlandskap', tema: null, familj: 'bred-landskap', stod: null, renderade: [] },
    { art: 'vmbnormal', tema: null, familj: 'vmb-normal', stod: null, renderade: [] }];
  const med = utan.map(a => ({ ...a, conformanceScope: 'product', annotationer: 2 }));
  const A = JSON.stringify(tackning(utan)), B = JSON.stringify(tackning(med));
  const rader = tackning(med).rader || tackning(med);
  prov('CS-15', 'scopebeslut ger 0 coverage credit och andrar ingen theme-coverage-klass',
    A === B && !/conformanceScope/.test(A) && !/tackt|dualThemeRender|explicitInstans/.test(JSON.stringify(rader)),
    'identiskt utfall med och utan scopefalt · modeller: ' +
    [...new Set((tackning(med).rader || []).map(r => r.modell))].join(', ')); }

/* ── FAIL CLOSED · okant scopevarde ───────────────────────────────────── */
{ const nara = losScope([nod({ scope: 'produkt' }), nod()]);
  const langtBort = losScope([nod({ scope: 'product' }), nod({ scope: 'PRODUCT' }), nod()]);
  const g = granskaIntegritet([nod({ scope: 'annotaion' }), nod()]);
  prov('CS-16', 'ett okant scopevarde faller closed aven nar en narmare giltig grans finns',
    nara.kalla === 'ogiltig' && langtBort.kalla === 'ogiltig' && g.kod === 'SCOPE_INVALID',
    'narmast: ' + nara.kalla + ' · langre upp: ' + langtBort.kalla + ' · integritet: ' + g.kod); }

const ANTAL = 16;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('SCOPEPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
if (OUT) writeFileSync(join(resolve(OUT), 'scopeprov.json'),
  JSON.stringify({ resultat, SCOPE_ATTRIBUT, SCOPEVARDEN }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
