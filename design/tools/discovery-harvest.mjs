#!/usr/bin/env node
// F2 · SKORD FOR UPPTACKTEN AV ODEKLARERADE KONTROLLER (discovery harvest).
//
// VARFOR MODULEN FINNS
// tools/control-shape-discovery.mjs ar detektorn. Den konsumerar skordade objekt
// enligt sitt PRIMITIVKONTRAKT, men skorden i webblasaren fanns aldrig i repot:
// den korde som ett engangsskript. Utan den gick varken 2700-ramen eller
// batch3-populationen att rakna om ur en ren utcheckning.
//
// VAD MODULEN GOR
// Samlar ENBART kontraktets falt, plus kallforfattade ankare for identitet och
// familjegranskning. Den innehaller ingen detektor: predikaten, unionen och
// deklarationsregeln importeras oforandrade fran control-shape-discovery.mjs.
//
// ORDINALBAS
// ordinal = index bland ramens PRODUKTELEMENT (conformance-scope), samma bas som
// fargsonden och semantic-units. Avstamd 2684/2684 mot fas2/kandidatklustring.json
// (d0c86f6). Segmentgeometri jamfors i hela bildpunkter.
//
// ordinal ar en MATHANDTAG, aldrig identitet. Persistent identitet byggs i
// tools/discovery-identity.mjs och far inte bero pa den.
import { spawn } from 'node:child_process';
import { readdirSync, mkdtempSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { tmpdir } from 'node:os';
import { pathToFileURL } from 'node:url';
import { SCOPE_KOD, KEDJA_KOD } from './conformance-scope.mjs';

export const SKORD = `(() => {
${SCOPE_KOD}
${KEDJA_KOD}
  const alfa = v => { const m = String(v || '').match(/rgba?\\(([^)]+)\\)/); if (!m) return 0;
    const p = m[1].split(',').map(s => s.trim()); return p.length > 3 ? +p[3] : 1; };
  const malarEl = el => { const cs = getComputedStyle(el);
    const fyll = alfa(cs.backgroundColor) > 0;
    const ram = ['Top','Right','Bottom','Left'].every(s => parseFloat(cs['border' + s + 'Width']) > 0 &&
      cs['border' + s + 'Style'] !== 'none' && alfa(cs['border' + s + 'Color']) > 0);
    const outl = cs.outlineStyle !== 'none' && parseFloat(cs.outlineWidth) > 0 && alfa(cs.outlineColor) > 0;
    return { fyll, ram, malar: fyll || ram || outl }; };
  const ut = [];
  for (const it of document.querySelectorAll('.sc-item')) {
    const alla = [...it.querySelectorAll('*')];
    const produkt = alla.filter(el => losScope(kedjaFor(el, it)).scope === 'product');
    const ordAlla = new Map(alla.map((e, i) => [e, i]));
    const ordProd = new Map(produkt.map((e, i) => [e, i]));
    const malCache = new Map(); const M = el => { if (!malCache.has(el)) malCache.set(el, malarEl(el)); return malCache.get(el); };
    for (const el of produkt) {
      const cs = getComputedStyle(el); const r = el.getBoundingClientRect();
      const iSvg = !!el.closest('svg');
      const m = M(el);
      // egen text: textnoder i subtradet vars narmaste malande forfader (upp till el) ar el sjalv
      let egen = 0; const egenDelar = [];
      const tw = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
      for (let n = tw.nextNode(); n; n = tw.nextNode()) {
        const t = n.textContent.replace(/\\s+/g, ' ').trim(); if (!t) continue;
        let p = n.parentElement, inuti = false;
        while (p && p !== el) { if (M(p).malar) { inuti = true; break; } p = p.parentElement; }
        if (!inuti) { egen += t.length;
          // Identitetsetikett: text som tillhor en deklarerad barnkontroll ar barnets, inte behallarens.
          const k = n.parentElement && n.parentElement.closest('[data-a11y-role]');
          if (!(k && k !== el && el.contains(k))) egenDelar.push(t); } }
      const under = [...el.querySelectorAll('*')];
      const inreMalande = under.filter(x => M(x).malar).length;
      const svgAntal = under.filter(x => x.tagName.toLowerCase() === 'svg' || x.hasAttribute('data-icon')).length;
      const geo = {}; for (const b of el.children) { if (!M(b).malar) continue; const q = b.getBoundingClientRect();
        const k = Math.round(q.width) + 'x' + Math.round(q.height); geo[k] = (geo[k] || 0) + 1; }
      const segmentgrupp = Math.max(0, ...Object.values(geo));
      const rad = parseFloat(cs.borderTopLeftRadius);
      const piller = r.height > 0 && r.width > r.height && rad >= r.height / 2 - 0.5;
      const harKnopp = [...el.children].some(b => { const bc = getComputedStyle(b); const q = b.getBoundingClientRect();
        return bc.position === 'absolute' && q.width > 0 && Math.abs(q.width - q.height) < 0.5 &&
          parseFloat(bc.borderTopLeftRadius) >= q.width / 2 - 0.5; });
      const anc = []; let p = el.parentElement; let forfaderRoll = null;
      while (p && p !== it) { if (ordAlla.has(p)) anc.push(p);
        if (!forfaderRoll && p.hasAttribute('data-a11y-role')) forfaderRoll = p.getAttribute('data-a11y-role');
        p = p.parentElement; }
      // Identitetsunderlag (inte detektorfalt): ankare = narmaste forfader med
      // data-a11y-name, annars narmaste forfader med id, annars ramen.
      let anker = null; for (let q = el.parentElement; q && q !== it; q = q.parentElement) {
        if (q.hasAttribute('data-a11y-name')) { anker = 'namn:' + q.getAttribute('data-a11y-name'); break; }
        if (q.id) { anker = 'id:' + q.id; break; } }
      const ikoner = under.filter(x => x.hasAttribute('data-icon')).map(x => x.getAttribute('data-icon'));
      if (el.hasAttribute('data-icon')) ikoner.unshift(el.getAttribute('data-icon'));
      const svgRoller = under.filter(x => x.tagName.toLowerCase() === 'svg').map(x => x.getAttribute('data-graphic-role') || '');
      ut.push({ art: it.id, ordAlla: ordAlla.get(el), ordProd: ordProd.get(el),
        text: (el.textContent || '').replace(/\\s+/g, ' ').trim().slice(0, 80), anker: anker || 'ram',
        egenDelar: egenDelar.map(t => t.slice(0, 80)),
        ikoner, svgRoller, klass: el.getAttribute('class') || null,
        barDeklareradeKontroller: el.querySelectorAll('[data-a11y-role]').length,
        // kallforfattade ankare och relationer (identitet och familjegranskning, aldrig detektorn)
        attrId: el.id || null, occ: el.getAttribute('data-occurrence'), partOcc: el.getAttribute('data-part-occurrence'),
        hitTarget: el.getAttribute('data-hit-target'), rawRole: el.getAttribute('role'),
        ariaHidden: !!el.closest('[aria-hidden="true"]'), nameAttr: el.getAttribute('name'),
        forfaderHit: (() => { for (let q = el.parentElement; q && q !== it; q = q.parentElement) if (q.hasAttribute('data-hit')) return q.getAttribute('data-hit'); return null; })(),
        textUtanforKontroller: (() => { let n = 0; const w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
          for (let t = w.nextNode(); t; t = w.nextNode()) { const s = t.textContent.replace(/\\s+/g, ' ').trim(); if (!s) continue;
            const k = t.parentElement && t.parentElement.closest('[data-a11y-role]'); if (!k || !el.contains(k)) n += s.length; } return n; })(),
        ikonerUtanforKontroller: under.filter(x => (x.tagName.toLowerCase() === 'svg' || x.hasAttribute('data-icon')) && !(x.closest('[data-a11y-role]') && el.contains(x.closest('[data-a11y-role]')))).length,
        attr: Object.fromEntries(['data-action', 'data-bind', 'data-binding', 'data-action-id'].filter(a => el.hasAttribute(a)).map(a => [a, el.getAttribute(a)])),
        pekare: cs.cursor,
        foraldraAlla: anc.map(a => ordAlla.get(a)), foraldraProd: anc.filter(a => ordProd.has(a)).map(a => ordProd.get(a)),
        tagg: el.tagName.toLowerCase(), roll: el.getAttribute('data-a11y-role'), forfaderRoll, iSvg,
        komponent: el.getAttribute('data-component'), grafikroll: el.getAttribute('data-graphic-role'),
        hit: el.getAttribute('data-hit'), namn: el.getAttribute('data-a11y-name'),
        harFyllning: m.fyll, helRam: m.ram, malar: m.malar, egenTextLangd: egen, inreMalande, svgAntal, segmentgrupp,
        display: cs.display, align: cs.alignItems, piller, harKnopp,
        x: Math.round(r.left), y: Math.round(r.top), w: Math.round(r.width), h: Math.round(r.height) });
    }
  }
  return ut;
})()`;

const sleep = ms => new Promise(r => setTimeout(r, ms));

/** Skordar alla skarmfiler under rot. filordning styr bara korningsordningen;
 *  utdata sorteras alltid (fil, art, ordinal) och ar darfor ordningsinvariant. */
export async function skorda(rot, { filordning = 'stigande', krom = 'C:/Program Files/Google/Chrome/Application/chrome.exe' } = {}) {
  let filer = readdirSync(rot).filter(f => /^Butlery Skarmar.*\.dc\.html$/.test(f)).sort();
  if (filordning === 'fallande') filer = filer.reverse();
  const profil = mkdtempSync(join(tmpdir(), 'skord-'));
  const port = 18600 + (process.pid % 300);
  const chrome = spawn(krom, ['--headless=new', '--remote-debugging-port=' + port, '--disable-gpu', '--no-first-run',
    '--allow-file-access-from-files', '--force-device-scale-factor=1', '--user-data-dir=' + profil, 'about:blank'], { stdio: 'ignore' });
  try {
    let ws;
    for (let i = 0; i < 80 && !ws; i++) { await sleep(250);
      try { ws = (await (await fetch('http://127.0.0.1:' + port + '/json/list')).json()).find(t => t.type === 'page').webSocketDebuggerUrl; } catch {} }
    if (!ws) throw new Error('Chrome startade aldrig sin debuggerport');
    const sock = new WebSocket(ws); await new Promise(r => sock.addEventListener('open', r));
    let id = 0; const pend = new Map();
    sock.addEventListener('message', e => { const m = JSON.parse(e.data); if (m.id && pend.has(m.id)) { pend.get(m.id)(m); pend.delete(m.id); } });
    const send = (method, params = {}) => new Promise(r => { const i = ++id; pend.set(i, r); sock.send(JSON.stringify({ id: i, method, params })); });
    await send('Page.enable'); await send('Runtime.enable');
    await send('Emulation.setDeviceMetricsOverride', { width: 1400, height: 1000, deviceScaleFactor: 1, mobile: false });
    const objekt = [];
    for (const f of filer) {
      await send('Page.navigate', { url: pathToFileURL(resolve(rot, f)).href });
      await send('Runtime.evaluate', { expression: `(async()=>{ if(document.readyState!=='complete') await new Promise(r=>addEventListener('load',r,{once:true})); await document.fonts.ready; return 1 })()`, awaitPromise: true });
      await sleep(100);
      const s = await send('Runtime.evaluate', { expression: SKORD, returnByValue: true });
      const v = s.result && s.result.result && s.result.result.value;
      if (!Array.isArray(v)) throw new Error('FAIL CLOSED: skorden misslyckades i ' + f);
      for (const o of v) objekt.push({ ...o, fil: f });
    }
    sock.close();
    return objekt.sort((a, b) => a.fil < b.fil ? -1 : a.fil > b.fil ? 1 : a.art < b.art ? -1 : a.art > b.art ? 1 : a.ordProd - b.ordProd);
  } finally { try { chrome.kill(); } catch {} await sleep(300); try { rmSync(profil, { recursive: true, force: true }); } catch {} }
}
