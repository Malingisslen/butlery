#!/usr/bin/env node
// F2-R04 · METODPROV FOR SEMANTISKA SCOPEGRANSER.  CS-01 … CS-15
//
// Felklassen proven finns for: scope avgjordes av CSS-klassnamn. Den regeln
// foll nar .sc-cap visade sig bara bade produktrubrik och ritningsannotering.
// Proven kraver att den nya motorn avgor scope ur AUTHORED grans, att den ar
// symmetrisk at bada hallen, att en annotationsgrans inte kan gomma produkt-UI,
// och att scope aldrig lacker in i vare sig bakgrundsupplosning eller tackning.

import { writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { losScope, granskaIntegritet, maladBakgrund, arProdukt,
  SCOPE_ATTRIBUT, SCOPEVARDEN } from './conformance-scope.mjs';
import { tackning } from './theme-contract.mjs';
import { artefaktBlock, elementIArtefakt, skrivScopeITagg, migreraFil } from './scope-migrator.mjs';
import { PAINT_PROBE } from './theme-paint-probe.mjs';

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

/* ── CS-17 · efter klassstadningen avgor rotupplosningen ensam ────────── */
{ // De fyra klassnamn som historiskt styrde populationen. Ingen av dem far
  // langre andra vare sig scope eller medlemskap — bara roten avgor.
  const KLASSER = ['sc-label', 'sc-id', 'sc-cap', 'sc-note', 'nagot-annat'];
  const iRot = KLASSER.map(k => losScope([nod({ klass: k }), nod({ legacyRoot: true }), nod()]));
  const utanRot = KLASSER.map(k => losScope([nod({ klass: k }), nod()]));
  const iAuthored = KLASSER.map(k => losScope([nod({ klass: k }), nod({ scope: 'product' }), nod()]));
  prov('CS-17', 'efter klassstadningen avgors populationen enbart av rotupplosningen',
    iRot.every(r => r.scope === 'product' && r.kalla === 'legacy-root') &&
    utanRot.every(r => r.scope === null && r.kalla === 'ingen') &&
    iAuthored.every(r => r.scope === 'product' && r.kalla === 'explicit'),
    KLASSER.length + ' klassnamn ger identiskt utfall: i legacy-rot ' + iRot[0].scope +
    ' · utan rot ' + utanRot[0].kalla + ' · under authored product ' + iAuthored[0].scope); }

/* ── CS-18 · fargsonden anvander scopemotorn, inte klasslistan ────────── */
{ // Kopplingsprov. Att sonden FAKTISKT avgor produktyta med losScope kan bara
  // visas i en riktig DOM; det harvarande provet hindrar att kopplingen tas
  // bort tyst vid en refaktorering. Den semantiska korrektheten bevisas av
  // CS-01…CS-17, och empiriskt av att 35 familjer gick fran 0 till 2070
  // malande deklarationer nar kopplingen infordes.
  const harMotor = PAINT_PROBE.includes('function losScope') && PAINT_PROBE.includes('function kedjaFor');
  const anvander = /iProdukt\s*=\s*el\s*=>[^;]*losScope\(kedjaFor\(el, it\)\)\.scope === 'product'/.test(PAINT_PROBE);
  const ingenKlasslista = !/querySelectorAll\('\.sc-phone, \.sc-card'\)/.test(PAINT_PROBE);
  prov('CS-18', 'fargsonden avgor produktyta med scopemotorn och inte langre med klasslistan',
    harMotor && anvander && ingenKlasslista,
    'motor inbaddad ' + harMotor + ' · iProdukt via losScope ' + anvander +
    ' · gammal klasslista borta ' + ingenKlasslista); }

/* ── SM · METADATAMIGRATORN ───────────────────────────────────────────── */
// Skrivaren ror kallan. Proven kraver att den bara satter ETT attribut, att
// ankaret ar samma ordning som DOM raknar, och att allt tvetydigt faller.

const FIX = `<div class="sc-item" id="prov" data-theme="light">
  <div class="sc-label"><a class="sc-id" href="#prov">etikett</a>text</div>
  <!-- <div class="lurendrejeri">kommentar med tagg</div> -->
  <div class="sc-tab"><span data-a11y-role="button">Knapp</span><br>
    <div class="sc-note"><b>Kommentar.</b> Prosa.</div></div>
</div>`;
// Forvantad ordning ur querySelectorAll('*'):
//  0 div.sc-label · 1 a.sc-id · 2 div.sc-tab · 3 span · 4 br · 5 div.sc-note · 6 b

{ const blk = artefaktBlock(FIX, 'prov');
  const el = elementIArtefakt(FIX, blk);
  const vantat = ['div', 'a', 'div', 'span', 'br', 'div', 'b'];
  prov('SM-01', 'kallankaret raknar samma element i samma ordning som querySelectorAll("*")',
    !!blk && el.length === 7 && el.every((e, i) => e.tagg === vantat[i]),
    el.length + ' element: ' + el.map(e => e.tagg).join(' ')); }

{ const el = elementIArtefakt(FIX, artefaktBlock(FIX, 'prov'));
  prov('SM-02', 'en tagg inuti en HTML-kommentar raknas aldrig som element',
    !el.some(e => e.text.includes('lurendrejeri')),
    'kommentarens div finns inte bland de ' + el.length + ' elementen'); }

{ const r = skrivScopeITagg('<div class="sc-note">', 'annotation');
  const r2 = skrivScopeITagg('<img src="x.png" />', 'product');
  prov('SM-03', 'attributet skrivs in i taggen och ror ingenting annat',
    r.ok && r.ny && r.text === '<div class="sc-note" data-conformance-scope="annotation">' &&
    r2.ok && r2.text === '<img src="x.png" data-conformance-scope="product"/>',
    r.text + ' · ' + r2.text); }

{ const r = skrivScopeITagg('<div data-conformance-scope="annotation">', 'annotation');
  prov('SM-04', 'samma varde igen ar idempotent — ingen skrivning, ingen konflikt',
    r.ok && r.ny === false && r.text === '<div data-conformance-scope="annotation">',
    'ny=' + r.ny + ' · ' + r.skal); }

{ const r = skrivScopeITagg('<div data-conformance-scope="product">', 'annotation');
  prov('SM-05', 'ett annat varde pa samma element ar en konflikt — fail closed',
    !r.ok && /finns redan/.test(r.skal), r.ok ? 'skrev anda' : r.skal); }

{ const fel = ['produkt', 'PRODUCT', '', 'product annotation', null]
    .map(v => skrivScopeITagg('<div>', v));
  prov('SM-06', 'bara product, annotation och harness accepteras',
    fel.every(r => !r.ok) && skrivScopeITagg('<div>', 'harness').ok,
    fel.length + ' ogiltiga varden avvisade'); }

{ const f = join(resolve(OUT || '.'), 'sm-prov.html');
  writeFileSync(f, FIX);
  const r = migreraFil(f, [{ art: 'prov', ordinal: 5, varde: 'annotation' },
    { art: 'prov', ordinal: 2, varde: 'product' }]);
  const efter = readFileSync(f, 'utf8');
  const utan = efter.split(' data-conformance-scope="annotation"').join('')
    .split(' data-conformance-scope="product"').join('');
  prov('SM-07', 'tva skrivningar i samma fil andrar exakt tva taggar och inget annat',
    r.skrivningar === 2 && utan === FIX &&
    /class="sc-tab" data-conformance-scope="product"/.test(efter) &&
    /class="sc-note" data-conformance-scope="annotation"/.test(efter),
    r.skrivningar + ' skrivningar · resten av filen bit-identisk: ' + (utan === FIX)); }

{ const f = join(resolve(OUT || '.'), 'sm-prov2.html');
  writeFileSync(f, FIX);
  migreraFil(f, [{ art: 'prov', ordinal: 5, varde: 'annotation' }]);
  const efter1 = readFileSync(f, 'utf8');
  const r2 = migreraFil(f, [{ art: 'prov', ordinal: 5, varde: 'annotation' }]);
  const efter2 = readFileSync(f, 'utf8');
  prov('SM-08', 'andra korningen skriver 0 och lamnar filen bit-identisk',
    r2.skrivningar === 0 && efter1 === efter2 &&
    r2.logg.every(x => x.utfall === 'OFORANDRAD'),
    'skrivningar ' + r2.skrivningar + ' · utfall ' + r2.logg.map(x => x.utfall).join(',')); }

{ const f = join(resolve(OUT || '.'), 'sm-prov3.html');
  writeFileSync(f, FIX);
  const r = migreraFil(f, [{ art: 'prov', ordinal: 99, varde: 'product' },
    { art: 'finns-inte', ordinal: 0, varde: 'product' }]);
  prov('SM-09', 'saknat ankare och saknad artefakt hoppas over utan att nagot skrivs',
    r.skrivningar === 0 && readFileSync(f, 'utf8') === FIX &&
    r.logg.filter(x => x.utfall === 'HOPPAD').length === 2,
    r.logg.map(x => x.utfall + ':' + x.skal).join(' · ')); }

const ANTAL = 27;
for (const x of resultat) console.log((x.ok ? '✔ ' : '✖ ') + x.id + '  ' + x.vad + '\n     ' + x.diag);
const ok = resultat.filter(x => x.ok).length;
console.log('');
console.log('SCOPEPROV status=' + (ok === ANTAL ? 'godkand' : 'FALLD') + ' godkanda=' + ok + ' av ' + ANTAL);
if (OUT) writeFileSync(join(resolve(OUT), 'scopeprov.json'),
  JSON.stringify({ resultat, SCOPE_ATTRIBUT, SCOPEVARDEN }, null, 1) + '\n');
process.exit(ok === ANTAL ? 0 : 1);
