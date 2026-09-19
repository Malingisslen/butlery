#!/usr/bin/env node
// F2 · UPPTACKTSPOPULATIONEN ur en ren utcheckning: skord → detektor → klassningsunderlag.
//
// Kor: node tools/discovery-population.mjs --ut=<fil utanfor repot> [--filordning=fallande]
//        [--historisk=<commit>] [--historisk-population=<kandidatklustring.json>]
//
//   skord     tools/discovery-harvest.mjs
//   detektor  tools/control-shape-discovery.mjs (mekanismerFor, arDeklarerad) — oforandrad
//   verdikt   registrerade verdikt i fas2/*.json, overforda till dagens forekomster ENDAST
//             via entydig 1:1-harkomst mot den historiska skorden (annars inget verdikt)
//   klass     positiv kallforfattad evidens eller registrerat verdikt; allt annat UNKNOWN
//   identitet tools/discovery-identity.mjs (forekomst, familj, agare — atskilda)
//
// Ingen kallskrivning. Ingen egen detektor. Ingen klass ur tystnad.
import { readFileSync, writeFileSync, readdirSync, mkdtempSync, rmSync, mkdirSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { mekanismerFor, arDeklarerad } from './control-shape-discovery.mjs';
import { skorda } from './discovery-harvest.mjs';
import { forekomstId, familjeId, familjesignatur, tilldelaAgare, slug } from './discovery-identity.mjs';

const mek = o => o.grafikkandidat ? [GRAFIKMEKANISM] : o.signalmekanism ? [o.signalmekanism] : mekanismerFor(o);
const ROT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const fail = m => { throw new Error('FAIL CLOSED: ' + m); };
const h = x => createHash('sha256').update(JSON.stringify(x)).digest('hex').slice(0, 16);
const prep = xs => xs.map(o => ({ ...o, ordinal: o.ordProd, foraldrakedja: o.foraldraProd }));
const traffar = xs => prep(xs).filter(o => !o.iSvg && !arDeklarerad(o) && mek(o).length > 0);

/* ── FRISTAENDE GRAFIK (omgang 6). Detektorn ser aldrig svg (iSvg). En glyf som bar
      funktion men saknar kontrollagare blev darfor osynlig. Den tas med HAR — inte
      i detektorn — och bara nar kallan sjalv signalerar funktion:
        data-graphic-role="required"  · binding · data-hit-target
        data-graphic-role="redundant" dar forsta forfadern saknar egen text
          (redundans kraver synlig text med samma information; utan text kan
          pastaendet inte provas, box-graphics.mjs)
      Aldrig: glyf inuti deklarerad kontroll (grafikbarn), glyf som ar enda innehallet
      i en kandidat (omslaget ar agarfragan), dekorativ glyf.                         */
export const GRAFIKMEKANISM = 'STANDALONE_GRAPHIC';
export function grafikkandidater(xs, kandidater) {
  const p = prep(xs), perId = new Map(p.map(o => [o.art + '|' + o.ordinal, o]));
  const omslag = new Set(kandidater.filter(k => k.egenTextLangd === 0 && k.svgAntal === 1).map(k => k.art + '|' + k.ordinal));
  return p.filter(o => {
    if (o.tagg !== 'svg' || arDeklarerad(o)) return false;
    if ((o.foraldrakedja || []).some(a => omslag.has(o.art + '|' + a))) return false;
    const binding = o.attr && Object.keys(o.attr).length > 0;
    const forfar = (o.foraldrakedja || []).length ? perId.get(o.art + '|' + o.foraldrakedja[0]) : null;
    const redundansOprovbar = o.grafikroll === 'redundant' && (!forfar || forfar.egenTextLangd === 0);
    return o.grafikroll === 'required' || binding || !!o.hitTarget || redundansOprovbar;
  }).map(o => ({ ...o, grafikkandidat: true }));
}

/* ── FUNKTIONSSIGNAL UTAN KONTROLLFORM (omgang 9). Detektorns predikat ar formbaserade:
      ett omalat element som inte ar flex, eller en flexbehallare med en malad inre form,
      traffas aldrig — oavsett vad kallan sager om funktion. Har tas sadana element med,
      men BARA nar kallan sjalv bar en positiv funktionssignal:
        FUNCTIONAL_SIGNAL  data-hit-target · binding (data-action/-bind/-binding/-action-id)
                           · interaktiv tagg (a, button, input, select, textarea)
        HANDOFF_STEPPER    komponentarket §04 / handoffen "Portionsvaljare": en synlig etikett
                           fore gruppen [− · varde · +] dar varde ar ett tal. Minus- och
                           plustecknet blir kandidater som stegknappar. Ett ensamt −/+ ar
                           ingen signal.
      Aldrig: deklarerat element eller element inuti deklarerad kontroll (grafikbarn),
      element med kallforfattad ARIA-roll (role=, redan deklarerad semantik), svg-inre,
      element som redan ar kandidat.                                                  */
export const SIGNALMEKANISM = 'FUNCTIONAL_SIGNAL', STEPPERMEKANISM = 'HANDOFF_STEPPER';
const INTERAKTIV_TAGG = /^(a|button|input|select|textarea)$/;
const MINUS = /^[−-]$/, PLUS = /^\+$/, TAL = /^\d+(?:[.,]\d+)?$/;
export function signalkandidater(xs, redan) {
  const p = prep(xs), perId = new Map(p.map(o => [o.art + '|' + o.ordinal, o]));
  const upptagna = new Set(redan.map(k => k.art + '|' + k.ordinal));
  const barn = new Map(); for (const o of p) { const f = (o.foraldrakedja || [])[0]; if (f != null) { const k = o.art + '|' + f; barn.set(k, (barn.get(k) || []).concat(o)); } }
  const egen = o => (o.egenDelar || []).join(' ').trim();
  const stegknapp = o => {
    if (!MINUS.test(egen(o)) && !PLUS.test(egen(o))) return false;
    const grupp = perId.get(o.art + '|' + (o.foraldrakedja || [])[0]); if (!grupp) return false;
    const b = (barn.get(grupp.art + '|' + grupp.ordinal) || []).sort((x, y) => x.ordinal - y.ordinal);
    if (b.length !== 3 || !MINUS.test(egen(b[0])) || !TAL.test(egen(b[1])) || !PLUS.test(egen(b[2]))) return false;
    const yttre = perId.get(grupp.art + '|' + (grupp.foraldrakedja || [])[0]); if (!yttre) return false;
    const fore = (barn.get(yttre.art + '|' + yttre.ordinal) || []).filter(x => x.ordinal < grupp.ordinal && x !== grupp);
    return fore.some(x => /\p{L}{3}/u.test(egen(x)) && !TAL.test(egen(x)));      // synlig etikett fore gruppen
  };
  const ut = [];
  for (const o of p) {
    if (o.iSvg || arDeklarerad(o) || o.rawRole || upptagna.has(o.art + '|' + o.ordinal)) continue;
    const binding = o.attr && Object.keys(o.attr).length > 0;
    if (binding || o.hitTarget || INTERAKTIV_TAGG.test(o.tagg)) ut.push({ ...o, signalmekanism: SIGNALMEKANISM });
    else if (stegknapp(o)) ut.push({ ...o, signalmekanism: STEPPERMEKANISM });
  }
  return ut;
}

/* ── registrerade verdikt ─────────────────────────────────────────────── */
const HID = /^[a-z0-9-]+\|\d+$/;
const VERDIKT = new Set(['INTERACTIVE_CONTROL', 'NON_INTERACTIVE_STATE_GRAPHIC', 'DECORATIVE_GRAPHIC', 'UNKNOWN']);
export function verdiktregister(rot) {
  const per = {};
  for (const f of readdirSync(join(rot, 'fas2')).filter(f => f.endsWith('.json')).sort()) {
    let d; try { d = JSON.parse(readFileSync(join(rot, 'fas2', f), 'utf8')); } catch { continue; }
    let datum = ''; try { datum = execFileSync('git', ['-C', rot, 'log', '-1', '--format=%cI', '--', 'fas2/' + f], { encoding: 'utf8' }).trim(); } catch {}
    const walk = o => { if (Array.isArray(o)) return o.forEach(walk); if (!o || typeof o !== 'object') return;
      const id = [o.identitet, o.id, o.identity].find(v => typeof v === 'string' && HID.test(v));
      const v = [o.verdikt, o.VERDIKT, o.nyttVerdikt, o.verdict].find(v => VERDIKT.has(v));
      if (id && v) (per[id] = per[id] || []).push({ verdikt: v, fil: f, datum });
      Object.values(o).forEach(walk); };
    walk(d);
  }
  const senaste = {};
  for (const [id, xs] of Object.entries(per)) {
    const max = xs.reduce((m, x) => x.datum > m ? x.datum : m, '');
    const v = [...new Set(xs.filter(x => x.datum === max).map(x => x.verdikt))];
    senaste[id] = { verdikt: v.length === 1 ? v[0] : 'UNKNOWN', konflikt: v.length > 1, kallor: [...new Set(xs.filter(x => x.datum === max).map(x => x.fil))] };
  }
  return senaste;
}

/* ── entydig harkomst historisk → idag. Nyckeln ar bara ett matchningsvillkor;
      tva eller fler traffar pa nagon sida ger INGEN overforing.                */
const harkomstnyckel = o => [o.art, o.anker, o.tagg, o.komponent || '-', slug(o.text), (o.ikoner || []).join('+'), mek(o).join('+')].join('|');

/* ── positiv kallforfattad evidens, i prioritetsordning ─────────────────── */
export function kallregel(o, ctx) {
  if (!ctx.iScope.has(o.art)) return ['OUT_OF_SCOPE', 'ramen saknar viewportprofil i artifacts.json'];
  if (o.hitTarget) { const agare = ctx.hitAgare.get(o.fil + '|' + o.hitTarget);
    if (agare) return ['DUPLICATE_OF_CANONICAL_OWNER', 'data-hit-target="' + o.hitTarget + '" ar traffytan for ' + agare]; }
  if (o.rawRole === 'presentation' || o.ariaHidden) return ['DECORATIVE_OR_STRUCTURAL', 'authored role=presentation / aria-hidden'];
  if (o.grafikroll === 'decorative') return ['DECORATIVE_OR_STRUCTURAL', 'authored data-graphic-role=decorative'];
  const kl = (o.klass || '').split(/\s+/);
  if (kl.includes('sc-phone') || kl.includes('sc-tab') || kl.includes('sc-card')) return ['DECORATIVE_OR_STRUCTURAL', 'ritytans ram (' + o.klass + '), inte produktinnehall'];
  if (kl.includes('sc-skeleton') || kl.includes('sc-loader')) return ['DECORATIVE_OR_STRUCTURAL', 'laddplatshallare (' + o.klass + ')'];
  if (kl.includes('av') && !o.hit && !o.roll) return ['KNOWN_COMPONENT', 'avatarkomponent (.av), ingen roll, ingen traffyta'];
  if ((o.rawRole === 'tablist' || o.rawRole === 'radiogroup') && o.barDeklareradeKontroller > 0)
    return ['KNOWN_COMPONENT', 'gruppbehallare role=' + o.rawRole + ' runt deklarerade kontroller'];
  if (o.barDeklareradeKontroller > 0 && o.textUtanforKontroller === 0 && o.ikonerUtanforKontroller === 0 && !o.hit)
    return ['DECORATIVE_OR_STRUCTURAL', 'layoutbarare: all text och alla ikoner ags av ' + o.barDeklareradeKontroller + ' deklarerade kontroller'];
  return null;
}
const FRAN_VERDIKT = { INTERACTIVE_CONTROL: 'KNOWN_CONTROL', NON_INTERACTIVE_STATE_GRAPHIC: 'KNOWN_NON_CONTROL', DECORATIVE_GRAPHIC: 'DECORATIVE_OR_STRUCTURAL' };

/* ── signaler for granskningsordning (aldrig klass) ─────────────────────── */
export function kontrollsignal(o, mek) {
  let s = 0; const skal = [];
  if (o.komponent === 'checkbox' || o.komponent === 'chip' || o.komponent === 'toggle') { s += 3; skal.push('komponent ' + o.komponent); }
  if (mek.includes('PILL_KNOB')) { s += 3; skal.push('piller med knopp'); }
  if (o.pekare === 'pointer') { s += 2; skal.push('cursor:pointer'); }
  if (mek.includes('CONTROL_SHELL') && o.svgAntal > 0) { s += 1; skal.push('flexskal med glyf'); }
  if (o.tagg === 'a') { s += 2; skal.push('<a>'); }
  if (o.w >= 44 && o.h >= 44 && o.w <= 400) { s += 1; skal.push('kontrollstorlek'); }
  return { s, skal };
}

export async function population({ rot, filordning, historisk, historiskPopulation }) {
  const objekt = await skorda(rot, { filordning });
  const tr0 = traffar(objekt);
  const tr1 = [...tr0, ...grafikkandidater(objekt, tr0)];
  const tr = [...tr1, ...signalkandidater(objekt, tr1)];
  const REG = JSON.parse(readFileSync(join(rot, 'artifacts.json'), 'utf8')).artifacts;
  const iScope = new Set(REG.filter(a => a.viewportProfile).map(a => a.sourceElementId));
  const hitAgare = new Map();
  for (const f of readdirSync(rot).filter(f => /^Butlery Skarmar.*\.dc\.html$/.test(f)))
    for (const m of readFileSync(join(rot, f), 'utf8').matchAll(/<[a-z]+[^>]*data-hit="target:([^"]+)"[^>]*>/g))
      hitAgare.set(f + '|' + m[1], ((/data-a11y-role="([^"]*)"/.exec(m[0]) || [])[1] || '?') + ' "' + ((/data-a11y-name="([^"]*)"/.exec(m[0]) || [])[1] || '') + '"');

  // historisk skord → entydig harkomst → verdikt
  let hist = null, overforda = new Map(), histAvstamning = null;
  if (historisk) {
    const kat = mkdtempSync(join(tmpdir(), 'hist-'));
    try {
      execFileSync('git', ['-C', rot, 'archive', '-o', join(kat, '_t.tar'), historisk]);
      execFileSync('tar', ['-xf', '_t.tar'], { cwd: kat });
      hist = traffar(await skorda(kat));   // HISTORICAL_SCOPE: bara detektorns scope, ingen grafikutvidgning
    } finally { rmSync(kat, { recursive: true, force: true }); }
    if (historiskPopulation) {
      const H = new Set(JSON.parse(readFileSync(historiskPopulation, 'utf8')).A_population.medlemmar);
      const T = new Set(hist.map(o => o.art + '|' + o.ordinal));
      histAvstamning = { historiska: H.size, aterfunna: [...H].filter(x => T.has(x)).length, skordade: T.size };
    }
    const V = verdiktregister(rot);
    const hNyckel = new Map(), iNyckel = new Map();
    for (const o of hist) { const k = harkomstnyckel(o); hNyckel.set(k, (hNyckel.get(k) || []).concat(o)); }
    for (const o of tr0) { const k = harkomstnyckel(o); iNyckel.set(k, (iNyckel.get(k) || []).concat(o)); }
    // (1) Oforandrad ram: hela ramens produktstruktur ar identisk historiskt och idag.
    //     Da ar ordinal→ordinal exakt harkomst (samma dokument), inte en gissning.
    const ramavtryck = xs => { const m = new Map(); for (const o of xs) m.set(o.art, (m.get(o.art) || []).concat(o));
      return new Map([...m].map(([a, os]) => [a, h(os.sort((p, q) => p.ordinal - q.ordinal).map(o => [o.ordinal, o.tagg, o.klass, o.komponent, slug(o.text), (o.ikoner || []).join('+'), mek(o).join('+')]))])); };
    const hRam = ramavtryck(hist), iRam = ramavtryck(tr0);
    const oforandrade = new Set([...hRam].filter(([a, f]) => iRam.get(a) === f).map(([a]) => a));
    for (const o of tr0) if (oforandrade.has(o.art)) {
      const v = V[o.art + '|' + o.ordinal];
      if (v) overforda.set(forekomstId(o), { ...v, historisk: o.art + '|' + o.ordinal, harkomst: 'oforandrad ram' });
    }
    // (2) Andrad ram: bara entydig 1:1 pa harkomstnyckeln.
    for (const [k, hs] of hNyckel) {
      const is = iNyckel.get(k) || [];
      if (hs.length !== 1 || is.length !== 1 || oforandrade.has(is[0].art)) continue;
      const v = V[hs[0].art + '|' + hs[0].ordinal];
      if (v) overforda.set(forekomstId(is[0]), { ...v, historisk: hs[0].art + '|' + hs[0].ordinal, harkomst: 'entydig 1:1' });
    }
    histAvstamning = { ...(histAvstamning || {}), OFORANDRADE_RAMAR: oforandrade.size, RAMAR_IDAG: iRam.size };
  }

  const poster = tr.map(o => {
    const mk = mek(o);
    let klass, grund, verdikt = overforda.get(forekomstId(o)) || null;
    const k0 = kallregel(o, { iScope, hitAgare });
    if (k0 && (k0[0] === 'OUT_OF_SCOPE' || k0[0] === 'DUPLICATE_OF_CANONICAL_OWNER')) [klass, grund] = k0;
    else if (verdikt && verdikt.verdikt !== 'UNKNOWN') { klass = FRAN_VERDIKT[verdikt.verdikt]; grund = 'registrerat verdikt ' + verdikt.historisk + ' (' + verdikt.kallor.join('+') + ')'; }
    else if (k0) [klass, grund] = k0;
    else if (verdikt) { klass = 'UNKNOWN_SEMANTICS'; grund = 'granskad, UNKNOWN (' + verdikt.historisk + ')'; }
    else { klass = 'UNKNOWN_SEMANTICS'; grund = 'ogranskad'; }
    return { forekomst: forekomstId(o), familj: familjeId(o, mk), klass, grund, granskad: !!verdikt, objekt: o, mek: mk };
  });
  const medAgare = tilldelaAgare(poster);

  // familjer (for granskning; aldrig klass)
  const fam = new Map();
  for (const p of medAgare) {
    const f = fam.get(p.familj) || { FAMILY_ID: p.familj, signatur: familjesignatur(p.objekt, p.mek), forekomster: [], ramar: new Set(), klasser: {} };
    f.forekomster.push(p); f.ramar.add(p.objekt.art); f.klasser[p.klass] = (f.klasser[p.klass] || 0) + 1; fam.set(p.familj, f);
  }
  const familjer = [...fam.values()].map(f => {
    const ks = f.forekomster.map(p => kontrollsignal(p.objekt, p.mek));
    const max = Math.max(...ks.map(k => k.s));
    const rep = f.forekomster[0];
    return { FAMILY_ID: f.FAMILY_ID, OCCURRENCE_COUNT: f.forekomster.length, FRAME_COUNT: f.ramar.size, KLASSER: f.klasser,
      UNKNOWN_COUNT: f.klasser.UNKNOWN_SEMANTICS || 0, COMMON_SOURCE_PATTERN: f.signatur,
      REPRESENTATIVE_EVIDENCE: f.forekomster.slice(0, 3).map(p => p.objekt.art + ' · ' + (p.objekt.text || '(ingen text)').slice(0, 40)),
      POTENTIAL_CONTROL_SIGNAL: [...new Set(ks.flatMap(k => k.skal))], KONTROLLSIGNAL_MAX: max,
      POTENTIAL_NON_CONTROL_SIGNAL: [!f.signatur.egenText && f.signatur.ikoner === '-' ? 'ingen text och ingen glyf' : null,
        f.signatur.malar === 'omalad' ? 'omalad' : null].filter(Boolean),
      EXEMPEL_RAMAR: [...f.ramar].sort().slice(0, 6) };
  }).sort((a, b) => b.UNKNOWN_COUNT - a.UNKNOWN_COUNT || b.KONTROLLSIGNAL_MAX - a.KONTROLLSIGNAL_MAX || b.FRAME_COUNT - a.FRAME_COUNT || (a.FAMILY_ID < b.FAMILY_ID ? -1 : 1));

  const KL = ['KNOWN_CONTROL', 'KNOWN_NON_CONTROL', 'KNOWN_COMPONENT', 'DECORATIVE_OR_STRUCTURAL', 'OUT_OF_SCOPE', 'DUPLICATE_OF_CANONICAL_OWNER', 'UNKNOWN_SEMANTICS'];
  const perKlass = Object.fromEntries(KL.map(k => [k, medAgare.filter(p => p.klass === k).length]));
  const summa = Object.values(perKlass).reduce((a, b) => a + b, 0);
  const forekomstIds = new Set(medAgare.map(p => p.forekomst));
  if (summa !== tr.length || forekomstIds.size !== tr.length) fail('implicit bortfall eller forekomstkollision');
  const agarIds = medAgare.filter(p => p.agarId).map(p => p.agarId);
  if (new Set(agarIds).size !== agarIds.length) fail('agarkollision efter tilldelning');
  const perAgarStatus = medAgare.reduce((m, p) => (m[p.klass + '|' + p.agarStatus] = (m[p.klass + '|' + p.agarStatus] || 0) + 1, m), {});
  const ut = {
    SKORD_OBJEKT: objekt.length, SKORD_FINGERAVTRYCK: h(objekt), DISCOVERY_TOTAL: tr.length, SUMMA_KLASSER: summa, IMPLICIT_DROPS: tr.length - summa,
    OCCURRENCE_COLLISIONS: 0, OWNER_COLLISIONS: 0, perKlass, perAgarStatus, UNKNOWN_GRANSKADE: medAgare.filter(p => p.klass === 'UNKNOWN_SEMANTICS' && p.granskad).length,
    DETEKTOR_SCOPE: tr0.length, GRAFIK_SCOPE: tr1.length - tr0.length, SIGNAL_SCOPE: tr.length - tr1.length,
    FAMILJER: familjer.length, UNKNOWN_FAMILJER: familjer.filter(f => f.UNKNOWN_COUNT > 0).length, HISTORISK_AVSTAMNING: histAvstamning,
    VERDIKT_OVERFORDA: overforda.size,
    FINGERAVTRYCK: { forekomster: h([...forekomstIds].sort()), klassning: h(medAgare.map(p => [p.forekomst, p.klass]).sort()),
      familjer: h(familjer.map(f => [f.FAMILY_ID, f.OCCURRENCE_COUNT])), agare: h(agarIds.sort()) },
    familjer,
    forekomster: medAgare.map(p => ({ DISCOVERY_OCCURRENCE_ID: p.forekomst, DISCOVERY_REVIEW_FAMILY_ID: p.familj,
      PERSISTENT_SEMANTIC_OWNER_ID: p.agarId, OWNER_STATUS: p.agarStatus, klass: p.klass, grund: p.grund, art: p.objekt.art, fil: p.objekt.fil,
      text: p.objekt.text, mekanismer: p.mek })).sort((a, b) => a.DISCOVERY_OCCURRENCE_ID < b.DISCOVERY_OCCURRENCE_ID ? -1 : 1) };
  return ut;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const arg = n => (process.argv.find(a => a.startsWith('--' + n + '=')) || '').split('=').slice(1).join('=');
  const UT = arg('ut'); if (!UT) { console.error('✖ ange --ut=<fil utanfor repot>'); process.exit(2); }
  if (resolve(UT).startsWith(ROT)) { console.error('✖ --ut ligger i reporoten'); process.exit(2); }
  const r = await population({ rot: ROT, filordning: arg('filordning') || 'stigande', historisk: arg('historisk') || null,
    historiskPopulation: arg('historisk-population') || null });
  mkdirSync(dirname(resolve(UT)), { recursive: true });
  writeFileSync(UT, JSON.stringify(r, null, 1));
  const { familjer, forekomster, ...kort } = r;
  console.log(JSON.stringify(kort, null, 1));
}
