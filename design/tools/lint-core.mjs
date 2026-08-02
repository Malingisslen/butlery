import { SCREEN_FILES, ICON_SOURCE_FILES } from './screen-files.mjs';
import { parseEvidence, splitEvidenceProblems } from './report-logic.mjs';
// Butlery · spec-lint, delad logik. Importeras av tools/spec-lint.mjs.
// Ren funktion av en env ({read, exists}) så att samma kod kan köras i CI
// och i granskningsverktyg utan filsystemsantaganden.

// Beslutsunderlag räknas inte — se tools/gen-icons.mjs.
// <!--hist--> gäller ENDAST i historik- och ändringsloggsavsnitt. En markör i
// ett aktivt normativt avsnitt döljer verkliga fel och rapporteras som varning.
// Infört 2026-07-31 (Fas 0.2) efter att markören hamnat på en aktiv kravrad.
const HIST_HEADING = /^#{1,4}\s*(ändringslogg|historik|senast avgjort|sync history)/i;
function inHistorySection(text, at) {
  const before = text.slice(0, at).split('\n');
  for (let i = before.length - 1; i >= 0; i--) {
    const l = before[i];
    if (/^#{1,4}\s/.test(l)) return HIST_HEADING.test(l);
  }
  return false;
}
function histExempt(text, at, file, warn) {
  if (!lineOf(text, at).includes('<!--hist-->')) return false;
  if (inHistorySection(text, at)) return true;
  warn('T-11', file + ': <!--hist--> står utanför ett historikavsnitt — markören gäller bara historik och ändringsloggar');
  return false;
}

// Raden ett index pekar in i.
function lineOf(text, at) {
  const s = text.lastIndexOf('\n', at) + 1;
  const e = text.indexOf('\n', at);
  return text.slice(s, e === -1 ? text.length : e);
}

// DOCS = de kanoniska skärmfilerna. Delas med gen-counts så att T-11 räknar
// exakt det generatorn skriver. Två listor gav 526 mot 534 och en T-11 som
// aldrig kunde bli noll. Rättat 2026-07-31 (Fas 0.3).
export const DOCS = SCREEN_FILES;

const BACKTICK = String.fromCharCode(96);

function srgb(c) { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
function lum(hex) {
  const n = parseInt(hex.slice(1), 16);
  return 0.2126 * srgb((n >> 16) & 255) + 0.7152 * srgb((n >> 8) & 255) + 0.0722 * srgb(n & 255);
}
export function ratio(a, b) {
  const x = lum(a), y = lum(b);
  return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}
function flatten(hex, alpha, bg) {
  const ch = h => { const n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; };
  const [r1, g1, b1] = ch(hex), [r2, g2, b2] = ch(bg);
  const mix = (a, b) => Math.round(a * alpha + b * (1 - alpha));
  const h2 = n => n.toString(16).padStart(2, '0');
  return ('#' + h2(mix(r1, r2)) + h2(mix(g1, g2)) + h2(mix(b1, b2))).toUpperCase();
}
export function resolve(tok, mode, overBase) {
  const raw = typeof tok === 'string' ? tok : tok[mode];
  if (typeof raw !== 'string') return null;
  if (/^#[0-9A-Fa-f]{6}$/.test(raw)) return raw.toUpperCase();
  const m = raw.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+))?\)/);
  if (!m) return null;
  const h2 = n => Number(n).toString(16).padStart(2, '0');
  const hex = ('#' + h2(m[1]) + h2(m[2]) + h2(m[3])).toUpperCase();
  const a = m[4] === undefined ? 1 : parseFloat(m[4]);
  return overBase ? flatten(hex, a, overBase) : hex;
}

export function lint(env) {
  // info() skriver upplysningar direkt till stdout och räknas ALDRIG som
  // varning — annars säger spec-lint och rapporten olika tal. (Fas 0.4)
  const info = (id, msg) => console.log('· ' + id + '  ' + msg);
  // Körbevis. En kontroll som inte registrerar sig får status "not run" i
  // rapporten — den ärver aldrig "passed" av att steget som helhet gick igenom.
  // Infört 2026-07-31 (Fas 0.3): A11Y-01 redovisades som passed utan att någon
  // kontroll fanns, och ett borttaget data-a11y-name gick igenom.
  const ranIds = new Set();
  const ran = id => { ranIds.add(id); return true; };
  const errors = [], warnings = [];
  const fail = (tag, msg) => errors.push(tag + '  ' + msg);
  const warn = (tag, msg) => warnings.push(tag + '  ' + msg);

  const tokens = JSON.parse(env.read('tokens.json'));
  const schema = JSON.parse(env.read('butlery-tokens.schema.json'));
  const icons = JSON.parse(env.read('icons.json'));
  const assets = JSON.parse(env.read('assets-manifest.json'));
  const index = env.read('00-spec-index.md');
  const docTexts = {};
  for (const d of DOCS) if (env.exists(d)) docTexts[d] = env.read(d);

  /* ── T-01 · tokens mot schema, rekursivt och typat ───────────────────────── */
  (function () {
    ran('T-01');
    const check = (node, sch, path) => {
      if (!sch) return;
      if (sch.$ref) { warn('T-01', path + ': $ref stöds inte av den här validatorn'); return; }
      if (sch.type === 'object') {
        if (typeof node !== 'object' || node === null || Array.isArray(node)) { fail('T-01', path + ' ska vara object'); return; }
        for (const r of sch.required || []) if (!(r in node)) fail('T-01', path + ' saknar "' + r + '"');
        for (const [k, v] of Object.entries(node)) {
          if (sch.properties && sch.properties[k]) { check(v, sch.properties[k], path + '.' + k); continue; }
          let matched = false;
          for (const [re, s] of Object.entries(sch.patternProperties || {})) {
            if (new RegExp(re).test(k)) { check(v, s, path + '.' + k); matched = true; }
          }
          if (!matched && sch.additionalProperties && typeof sch.additionalProperties === 'object') check(v, sch.additionalProperties, path + '.' + k);
        }
      } else if (sch.type === 'array') {
        if (!Array.isArray(node)) { fail('T-01', path + ' ska vara array'); return; }
        if (sch.minItems && node.length < sch.minItems) fail('T-01', path + ' behöver minst ' + sch.minItems + ' element');
        if (sch.items) node.forEach((n, i) => check(n, sch.items, path + '[' + i + ']'));
      } else if (sch.type === 'number') {
        if (typeof node !== 'number') { fail('T-01', path + ' ska vara number, är ' + typeof node); return; }
        if (sch.minimum !== undefined && node < sch.minimum) fail('T-01', path + ' = ' + node + ' under minimum ' + sch.minimum);
      } else if (sch.type === 'string') {
        if (typeof node !== 'string') { fail('T-01', path + ' ska vara string'); return; }
        if (sch.pattern && !new RegExp(sch.pattern).test(node)) fail('T-01', path + ' = "' + node + '" matchar inte ' + sch.pattern);
        if (sch.enum && !sch.enum.includes(node)) fail('T-01', path + ' = "' + node + '" utanför enum');
      } else if (sch.const !== undefined) {
        if (node !== sch.const) fail('T-01', path + ' ska vara ' + JSON.stringify(sch.const));
      } else if (sch.oneOf) {
        const ok = sch.oneOf.some(s => {
          const before = errors.length;
          check(node, s, path);
          const clean = errors.length === before;
          errors.length = before;
          return clean;
        });
        if (!ok) fail('T-01', path + ' matchar ingen av de tillåtna formerna');
      }
    };
    check(tokens, schema, 'tokens');
  })();

  /* ── T-02 · kontrast enligt tokens.contrastPairs, mot RÄTT bakgrund ─────── */
  (function () {
    ran('T-02');
    const exempt = new Set((tokens.contrastPolicy.exemptions || []).filter(e => e.floor === null).map(e => e.token));
    for (const pair of tokens.contrastPairs) {
      if (exempt.has(pair.fg)) continue;
      const fgTok = tokens.semantic[pair.fg], bgTok = tokens.semantic[pair.bg];
      if (!fgTok || !bgTok) { fail('T-02', 'okänd token i contrastPairs: ' + pair.fg + ' / ' + pair.bg); continue; }
      for (const mode of ['light', 'dark']) {
        const bg = resolve(bgTok, mode);
        const fg = resolve(fgTok, mode, bg);
        if (!bg || !fg) continue;
        const r = ratio(fg, bg);
        if (r < pair.floor - 0.005) fail('T-02', pair.fg + ' mot ' + pair.bg + ' (' + mode + ') = ' + r.toFixed(2) + ':1, golv ' + pair.floor);
      }
    }
    for (const p of tokens.avatar.pairs) {
      const r = ratio(p.onFill.toUpperCase(), p.fill.toUpperCase());
      if (r < 4.5) fail('T-02', 'avatarpar ' + p.fill + '/' + p.onFill + ' = ' + r.toFixed(2) + ':1');
      else if (Math.abs(r - p.contrast) > 0.06) warn('T-02', 'avatarpar ' + p.fill + ': deklarerat ' + p.contrast + ', mätt ' + r.toFixed(2));
    }
    // Vad T-02 INTE kan se: faktiska par i skärmfilen. Där mäts kontrast i
    // browsertestet, eftersom en färg bara har betydelse mot sin renderade bakgrund.
  })();

  /* ── T-03 · råfärger i spec-HTML (varning · beslut B-27) ────────────────── */
  (function () {
    ran('T-03');
    const allowed = new Set();
    const walk = v => {
      if (typeof v === 'string') { const m = v.match(/#[0-9A-Fa-f]{6}/g); if (m) m.forEach(h => allowed.add(h.toUpperCase())); }
      else if (Array.isArray(v)) v.forEach(walk);
      else if (v && typeof v === 'object') Object.values(v).forEach(walk);
    };
    walk(tokens);
    // docOnly är redan med via walk(tokens) — deklarerade dokumentfärger är inte slarv.
    for (const [doc, text] of Object.entries(docTexts)) {
      const seen = new Map();
      for (const m of text.matchAll(/#[0-9A-Fa-f]{6}\b/g)) {
        const hex = m[0].toUpperCase();
        if (!allowed.has(hex)) seen.set(hex, (seen.get(hex) || 0) + 1);
      }
      for (const [hex, n] of seen) warn('T-03', doc + ': ' + hex + ' (' + n + '×) finns inte i tokens.json');
    }
  })();

  /* ── T-04 · opacitetsnivåer ─────────────────────────────────────────────── */
  (function () {
    ran('T-04');
    const ladder = new Set();
    [...(tokens.opacityLadder.onPaper || []), ...(tokens.opacityLadder.onInk || [])].forEach(n => ladder.add(Number(n).toFixed(2)));
    const walk = v => {
      if (typeof v === 'string') { const m = v.match(/rgba\([^)]*?,\s*([\d.]+)\)/); if (m) ladder.add(parseFloat(m[1]).toFixed(2)); }
      else if (Array.isArray(v)) v.forEach(walk);
      else if (v && typeof v === 'object') Object.values(v).forEach(walk);
    };
    walk(tokens.semantic);
    (tokens.docOnly.docChromeOpacity || []).forEach(n => ladder.add(Number(n).toFixed(2)));
    for (const [doc, text] of Object.entries(docTexts)) {
      const seen = new Map();
      for (const m of text.matchAll(/rgba\([^)]*?,\s*(0?\.\d+|1)\)/g)) {
        const v = parseFloat(m[1]).toFixed(2);
        if (!ladder.has(v)) seen.set(v, (seen.get(v) || 0) + 1);
      }
      for (const [v, n] of seen) warn('T-04', doc + ': opacitet ' + v + ' (' + n + '×) utanför opacityLadder');
    }
  })();

  /* ── T-05 · ikoner ──────────────────────────────────────────────────────── */
  const usedIcons = new Map();
  (function () {
    ran('T-05');
    // Ikoner räknas ur ICON_SOURCE_FILES — skärmfilerna PLUS komponentark,
    // manual och handoff. gen-icons hade en egen lista medan T-06 bara läste
    // skärmfilerna, vilket gav 24 usage-fel direkt efter en gen-icons-körning.
    // Rättat 2026-08-01 (Fas 0.4): ett namngivet scope, delat av båda.
    for (const f of ICON_SOURCE_FILES) {
      if (!env.exists(f)) continue;
      const text = docTexts[f] || env.read(f);
      for (const m of text.matchAll(/data-icon="([a-z0-9-]+)"/g)) usedIcons.set(m[1], (usedIcons.get(m[1]) || 0) + 1);
    }
    const known = new Map([...icons.ui_family, ...icons.nav_family].map(g => [g.name, g]));
    for (const name of usedIcons.keys()) if (!known.has(name)) fail('T-05', 'data-icon="' + name + '" saknar post i icons.json');
    for (const [name, g] of known) if (!env.exists(g.master_svg)) fail('T-05', name + ': filen ' + g.master_svg + ' saknas');
  })();

  /* ── T-06a · icons.json usages · BEROENDE av gen-icons ──────────────────── */
  // Delad från T-06 i Fas 0.8: kontrollen bar två slags diagnostik med olika
  // beroenden, så ett verkligt sökvägsfel gick inte att skilja från kaskaden när
  // gen-icons föll. Nu är usages T-06a (blockeras) och sökvägarna T-06b (mäts
  // alltid). Ett deklarerat delberoende som aldrig användes är inget beroende.
  (function () {
    ran('T-06a');
    const known = new Map([...icons.ui_family, ...icons.nav_family].map(g => [g.name, g]));
    for (const [name, g] of known) {
      const actual = usedIcons.get(name) || 0;
      if (g.usages !== actual) fail('T-06a', 'icons.json ' + name + '.usages = ' + g.usages + ', faktiskt ' + actual + ' — kör node tools/gen-icons.mjs');
    }
  })();

  /* ── T-06b · assets-manifestets filreferenser · OBEROENDE ───────────────── */
  (function () {
    ran('T-06b');
    // Endast konkreta filreferenser kontrolleras. packaging.*.path beskriver
    // DESTINATIONER och globmönster, inte källfiler — de är inte filsystemssanning.
    const FILE_KEYS = new Set(['file', 'master_svg', 'wordmark', 'validation']);
    const walk = node => {
      if (Array.isArray(node)) return node.forEach(walk);
      if (!node || typeof node !== 'object') return;
      for (const [k, v] of Object.entries(node)) {
        if (typeof v === 'string' && FILE_KEYS.has(k)) {
          if (v.includes('*') || v.includes(' ')) continue;
          if (!env.exists(v)) fail('T-06b', 'assets-manifest: ' + k + ' = ' + v + ' saknas på disk');
        } else walk(v);
      }
    };
    walk(assets);
  })();

  /* ── T-07 · föråldrade versionsreferenser ──────────────────────────────── */
  (function () {
    ran('T-07');
    const stale = [/manual v[1-5]\b/gi, /0\.62[0-4]\b/g, /Skarmar v1[01]\b/gi];
    for (const [doc, text] of Object.entries(docTexts))
      for (const re of stale)
        for (const m of text.matchAll(re)) warn('T-07', doc + ': föråldrad versionsreferens "' + m[0] + '"');
  })();

  /* ── T-08 · träffytor i källan ─────────────────────────────────────────── */
  (function () {
    ran('T-08');
    // Regeln: en a11y-märkt kontroll med uttrycklig storlek under 48 måste bära
    // data-hit som säger var hitboxen finns ("wrapper 48", "row 56"…).
    // Vad T-08 INTE kan se: padding-satta höjder. De mäts i browsertestet.
    for (const [doc, text] of Object.entries(docTexts)) {
      for (const m of text.matchAll(/<[a-z]+[^>]*data-a11y-name="[^"]*"[^>]*>/g)) {
        const tag = m[0];
        const name0 = (tag.match(/data-a11y-name="([^"]*)"/) || [])[1];
        const hit = (tag.match(/data-hit="([^"]*)"/) || [])[1];
        if (hit !== undefined) {
          // VÄRDET valideras, inte bara attributets närvaro. Fas 0.11: en
          // mutation 48 → 32 passerade eftersom varje element med data-hit
          // hoppades över. Golvet är tokens.touchTarget.min (48 dp).
          const floor = (tokens.touchTarget && (tokens.touchTarget.min ?? tokens.touchTarget.minimum)) || 48;
          const nums = [...String(hit).matchAll(/(\d+(?:\.\d+)?)/g)].map(x => parseFloat(x[1]));
          if (!nums.length) fail('T-08', doc + ': "' + name0 + '" har data-hit="' + hit + '" utan mått — skriv t.ex. "wrapper 48"');
          else {
            const under = nums.filter(n => n < floor);
            if (under.length) fail('T-08', doc + ': "' + name0 + '" deklarerar data-hit="' + hit + '" — ' + under.join('/') + ' dp är under golvet ' + floor);
          }
          continue;
        }
        const dims = [...tag.matchAll(/(?:min-)?(?:width|height):\s*(\d+(?:\.\d+)?)px/g)].map(x => parseFloat(x[1]));
        const small = dims.filter(d => d < 48);
        if (small.length && !/min-height:\s*48|height:\s*48|min-width:\s*48/.test(tag)) {
          const name = (tag.match(/data-a11y-name="([^"]*)"/) || [])[1];
          fail('T-08', doc + ': "' + name + '" deklarerar ' + small.join('/') + 'px utan data-hit');
        }
      }
      const named = (text.match(/data-a11y-name=/g) || []).length;
      const roles = (text.match(/data-a11y-role=/g) || []).length;
      if (named && roles < named) fail('T-08', doc + ': ' + (named - roles) + ' av ' + named + ' a11y-märkta kontroller saknar data-a11y-role');
      // Rollvokabulären är STÄNGD. Ett värde utanför de sex är svensk prosa i ett
      // maskinattribut, och det ska fälla bygget — att bara räkna roller mot namn
      // fångar det inte.
      // Vad T-08 INTE kan se: DOM-nästling. En regex kan inte skilja ett
      // NÄSTLAT data-a11y-role från ett SYSKON — ett försök gav 89 falska
      // träffar på intilliggande kontroller. Nästling mäts därför i browsern:
      //   document.querySelectorAll('[data-a11y-role] [data-a11y-role]')
      // ska ge 0. Kravet står i produktregler.md § 8.3c och protokollet i
      // testmatris.md § 4.
      const ROLES = new Set(['button', 'tab', 'switch', 'radio', 'checkbox', 'textbox']);
      for (const m of text.matchAll(/data-a11y-role="([^"]*)"/g))
        if (!ROLES.has(m[1])) fail('T-08', doc + ': ogiltig roll "' + m[1] + '" — tillåtna är ' + [...ROLES].join(', '));
    }
  })();

  /* ── T-09 · syntax ─────────────────────────────────────────────────────── */
  (function () {
    ran('T-09');
    for (const [doc, text] of Object.entries(docTexts)) {
      const ids = [...text.matchAll(/\sid="([^"]+)"/g)].map(m => m[1]);
      for (const id of new Set(ids.filter((v, i) => ids.indexOf(v) !== i))) fail('T-09', doc + ': dubblerat id "' + id + '"');
      for (const _ of text.matchAll(/<[a-z][^>]*?\sstyle="[^"]*"[^>]*?\sstyle="/g)) fail('T-09', doc + ': element med två style-attribut');
      // Klamrar räknas ENBART i <style>-block — resten av filen innehåller JS.
      for (const m of text.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)) {
        const open = (m[1].match(/{/g) || []).length, close = (m[1].match(/}/g) || []).length;
        if (open !== close) fail('T-09', doc + ': obalanserade klamrar i <style> (' + open + ' mot ' + close + ')');
      }
    }
  })();

  /* ── T-10 · indexets påståenden mot filernas egna värden ───────────────── */
  (function () {
    ran('T-10');
    const claim = (label, version) => {
      const re = new RegExp('\\|\\s*\\*{0,2}' + label + '\\*{0,2}\\s*\\|\\s*\\*\\*([\\d.]+)\\*\\*');
      const m = index.match(re);
      if (!m) { warn('T-10', 'indexet har ingen versionsrad för ' + label); return; }
      if (m[1] !== version) fail('T-10', 'indexet säger ' + label + ' ' + m[1] + ', filen säger ' + version);
    };
    claim('Tokens', tokens.version);
    claim('Ikoner', icons.version);
    claim('Assets', assets.version);
    // Markdown-dokumenten bär sin version i prosan; läs den i stället för att gissa.
    const mdVersion = (file) => {
      if (!env.exists(file)) return null;
      const m = env.read(file).match(/Version \*\*([\d.]+)\*\*/);
      return m ? m[1] : null;
    };
    for (const [label, file] of [
      ['Produktregler', 'produktregler.md'],
      ['Content', 'content-style-guide.md'],
      ['Test- och tillståndsmatris', 'testmatris.md'],
      ['Evidensmatris', 'evidensmatris.md'],
      ['Plattformsmatris', 'plattformsmatris.md']
    ]) {
      const v = mdVersion(file);
      if (v) claim(label, v);
      else warn('T-10', file + ' saknar en läsbar "Version **x.y**"-rad');
    }

    const dl = env.read('beslutslogg.md');
    const nDecisions = (dl.match(/^\| B-\d+ \|/gm) || []).length;
    const re = new RegExp('beslutslogg\\.md' + BACKTICK + '\\s*\\((\\d+) beslut\\)');
    const mi = index.match(re);
    if (mi && Number(mi[1]) !== nDecisions) fail('T-10', 'indexet säger ' + mi[1] + ' beslut, beslutsloggen har ' + nDecisions);

    // Indexet får inte samtidigt säga "inte stängd" och "allt stängt".
    if (/alla P0 och P1 i designens ägo är därmed stängda/i.test(index) && /Specen är inte stängd/i.test(index))
      fail('T-10', 'indexet motsäger sig själv om stängningsstatus');
  })();

  /* ── T-11 · genererade siffror i prosan är färska ────────────────────────── */
  // Rättat 2026-07-31 (Fas 0): läste tidigare bara DOCS[0], vilket jämförde
  // hela specens räknare mot en enda delfil. Aggregerar nu alla aktiva
  // skärmfiler — samma regel som tools/gen-counts.mjs.
  (function () {
    ran('T-11');
    const screens = DOCS.map(d => docTexts[d] || '').join('\n');
    if (!screens) return;
    const c = re => (screens.match(re) || []).length;
    const counts = {
      frames: c(/class="sc-phone"/g),
      items: c(/class="sc-item"/g),
      controls: c(/data-a11y-name=/g),
      roles: c(/data-a11y-role=/g),
      hits: c(/data-hit=/g)
    };
    for (const file of ['Butlery tillganglighetshandoff.dc.html', 'evidensmatris.md', 'testmatris.md', '00-spec-index.md']) {
      if (!env.exists(file)) continue;
      const text = env.read(file);
      for (const m of text.matchAll(/<!--n:([a-z]+)-->([\s\S]*?)<!--\/n-->/g)) {
        const [, key, val] = m;
        if (!(key in counts)) { fail('T-11', file + ': okänd räknare "' + key + '"'); continue; }
        if (Number(val) !== counts[key]) fail('T-11', file + ': ' + key + ' säger ' + val + ', faktiskt ' + counts[key] + ' — kör node tools/gen-counts.mjs');
      }
      // En handskriven räkning utan ankare är ett fel i sig — utom i text som
      // uttryckligen är historik. En ändringslogg ska bära det tal som gällde
      // den dagen; att skriva om den till dagens värde vore att förfalska den.
      // Markören <!--hist--> på raden undantar raden. Införd 2026-07-31 (Fas 0.1).
      for (const m of text.matchAll(/(\d+) (?:märkta kontroller|ramar)\b/g)) {
        const at = m.index;
        const before = text.slice(Math.max(0, at - 40), at);
        if (before.includes('<!--/n-->')) continue;
        if (histExempt(text, at, file, warn)) continue;
        warn('T-11', file + ': ”' + m[0] + '” är handskriven — ankra den med <!--n:...--> eller märk raden <!--hist-->');
      }
    }
  })();

  /* ── T-12 · citerade skärmankare finns i skärmfilerna ───────────────────── */
  // Rättat 2026-07-31 (Fas 0): läste tidigare bara DOCS[0] och rapporterade
  // därför varje ankare i de tretton övriga delfilerna som dött.
  (function () {
    ran('T-12');
    const screens = DOCS.map(d => docTexts[d] || '').join('\n');
    if (!screens) return;
    const ids = new Set([...screens.matchAll(/\sid="([^"]+)"/g)].map(m => m[1]));
    // Endast gemena ankare räknas som skärmreferenser; #RRGGBB och prosa i
    // versaler är färgvärden respektive platshållare, inte ankare.
    // Gemena sexsiffriga strängar är hexfärger (#627061), inte ankare, och
    // orden nedan är platshållare i prosan.
    const PROSE = new Set(['ankarnamn', 'ankare', 'namn', 'id', 'vyn']);
    const isHex = n => /^[0-9a-f]{6}$/.test(n);
    const CITERS = ['evidensmatris.md', 'testmatris.md', '00-spec-index.md', 'plattformsmatris.md', 'produktregler.md'];
    for (const file of CITERS) {
      if (!env.exists(file)) continue;
      const text = env.read(file);
      const seen = new Set();
      for (const m of text.matchAll(/`#([a-z0-9åäö]+)`/g)) {
        const name = m[1];
        if (PROSE.has(name) || isHex(name) || seen.has(name)) continue;
        // Historik får citera ett ankare som sedan dess är borttaget eller omdöpt.
        if (histExempt(text, m.index, file, warn)) continue;
        seen.add(name);
        if (!ids.has(name)) fail('T-12', file + ': ankaret #' + name + ' finns inte som id i skärmfilen');
      }
    }
  })();

  /* ── T-16 · ram-id kan inte kollidera, globalt över dokumentträdet ──────── */
  // Nytt 2026-07-31 (Fas 0): id-kontrollen kördes per fil, varför två
  // kollisioner över filgränsen passerade i månader.
  (function () {
    ran('T-16');
    const seen = new Map();
    for (const d of DOCS) {
      const t = docTexts[d];
      if (!t) continue;
      for (const m of t.matchAll(/\sid="([^"]+)"/g)) {
        const id = m[1];
        if (seen.has(id) && seen.get(id) !== d) fail('T-16', 'id "' + id + '" finns i både ' + seen.get(id) + ' och ' + d);
        else if (!seen.has(id)) seen.set(id, d);
      }
    }
  })();

  /* ── T-14 · Skärmbevis, via den GEMENSAMMA evidensparsern ───────────────── */
  // Fas 0.10: T-14 hade en egen radparser trots påståendet om delad kod. Nu
  // läser den parseEvidence() — samma rader, samma statusregler och samma
  // historikregel som kravräkningen och T-18.
  (function () {
    ran('T-14');
    if (!env.exists('evidensmatris.md')) return;
    const { rows } = parseEvidence(env.read('evidensmatris.md'));
    const frames = new Set();
    for (const d of DOCS) {
      const t = docTexts[d];
      if (!t) continue;
      for (const m of t.matchAll(/class="sc-item"[^>]*\sid="([^"]+)"/g)) frames.add(m[1]);
      for (const m of t.matchAll(/\sid="([^"]+)"[^>]*class="sc-item"/g)) frames.add(m[1]);
    }
    const sheet = env.exists('Butlery Komponentark v1.dc.html') ? env.read('Butlery Komponentark v1.dc.html') : '';
    const manual = env.exists('Butlery Grafisk manual v6.dc.html') ? env.read('Butlery Grafisk manual v6.dc.html') : '';
    const sheetIds = new Set([...sheet.matchAll(/\sid="(k\d{2})"/g)].map(m => m[1]));
    const manualIds = new Set([...manual.matchAll(/\sid="(s\d{2}[a-z]?)"/g)].map(m => m[1]));
    if (sheet && !sheetIds.size) fail('T-14', 'komponentarket saknar stabila avsnitts-id (id="kNN") — komponentbevis kan inte valideras');
    if (manual && !manualIds.size) fail('T-14', 'manualen saknar stabila kapitel-id (id="sNN") — manualbevis kan inte valideras');

    let typed = 0, legacy = 0, missing = 0;
    for (const r of rows) {
      const col = r.evidence || '';
      const id = r.id;
      let evidence = 0;

      for (const m of col.matchAll(/screen:`?#([a-z0-9åäö-]+)`?/g)) {
        evidence++; typed++;
        if (!frames.has(m[1])) fail('T-14', id + ' (rad ' + r.lineNo + '): screen:#' + m[1] + ' finns inte som skärmram');
      }
      for (const m of col.matchAll(/component:`?([A-Za-z0-9_-]+)`?/g)) {
        evidence++; typed++;
        const key = /^\d{1,2}$/.test(m[1]) ? 'k' + String(m[1]).padStart(2, '0') : m[1];
        if (!sheetIds.has(key)) fail('T-14', id + ' (rad ' + r.lineNo + '): component:' + m[1] + ' finns inte som avsnitts-id (' + key + ')');
      }
      for (const m of col.matchAll(/manual:kap-(\d{1,2})/g)) {
        evidence++; typed++;
        const sid = 's' + String(m[1]).padStart(2, '0');
        if (![...manualIds].some(x => x === sid || x.startsWith(sid))) fail('T-14', id + ' (rad ' + r.lineNo + '): manual:kap-' + m[1] + ' saknar ' + sid + ' i manualen');
      }
      for (const m of col.matchAll(/file:(?:"([^"]+)"|`([^`]+)`|(\S+))/g)) {
        evidence++; typed++;
        const p = m[1] || m[2] || m[3];
        if (!env.exists(p)) fail('T-14', id + ' (rad ' + r.lineNo + '): file:' + p + ' finns inte — sökvägar med mellanslag skrivs file:"…"');
      }
      if (/scope:all-screens/.test(col)) { evidence++; typed++; }
      if (/n\/a:\s*\S/.test(col)) { evidence++; typed++; }

      const before = evidence;
      for (const m of col.matchAll(/(?<!screen:)`#([a-z0-9åäö-]+)`/g)) {
        evidence++;
        if (!frames.has(m[1])) fail('T-14', id + ' (rad ' + r.lineNo + '): ankaret #' + m[1] + ' finns inte som skärmram');
      }
      for (const m of col.matchAll(/komponentark\s*(\d{1,2})/gi)) {
        evidence++;
        const key = 'k' + String(m[1]).padStart(2, '0');
        if (!sheetIds.has(key)) fail('T-14', id + ' (rad ' + r.lineNo + '): komponentark ' + m[1] + ' motsvarar inget avsnitt (' + key + ')');
      }
      for (const m of col.matchAll(/manual\s+kap\s*(\d{1,2})/gi)) {
        evidence++;
        const sid = 's' + String(m[1]).padStart(2, '0');
        if (![...manualIds].some(x => x === sid || x.startsWith(sid))) fail('T-14', id + ' (rad ' + r.lineNo + '): manualkapitel ' + m[1] + ' saknar ' + sid);
      }
      if (/scope:all-screens|samtliga\s+(tio\s+)?skärmfiler|alla\s+ramar/i.test(col)) evidence++;
      if (/innehållsgranskning|renderad mätning|kodläsning|browserprob|dpia|generer(ad|ade) fil/i.test(col + ' ' + (r.status || ''))) evidence++;
      legacy += evidence - before;

      if (!evidence && (r.status === 'implementerad' || r.status === 'verifierad')) {
        missing++;
        fail('T-14', id + ' (rad ' + r.lineNo + ') står "' + r.status + '" utan bevis. Skriv screen:#id · component:<id> · manual:kap-NN · file:"sökväg" · scope:all-screens · n/a: motivering');
      }
    }
    info('T-14', rows.length + ' kravrader (gemensam parser) · ' + typed + ' typade · ' + legacy + ' legacy · ' + missing + ' utan bevis');
  })();

  /* ── T-15 · exakt versionstabellen, en strategi per rad och fil ─────────── */
  // Två fel kvar efter Fas 0.4: regexen tog med efterföljande ###-tabeller (36
  // "rader" i stället för 21) och rader kunde bli omätta utan att fällas.
  // Nu läses den SAMMANHÄNGANDE tabellen under "## Versioner" — från
  // huvudraden till första icke-tabellrad — och varje citerad fil måste ha en
  // strategi och ge ett värde. Rättat 2026-08-01 (Fas 0.5).
  (function () {
    ran('T-15');
    const lines = index.split('\n');
    const start = lines.findIndex(l => /^##\s+Versioner\s*$/.test(l));
    if (start < 0) { fail('T-15', '00-spec-index.md: avsnittet "## Versioner" hittades inte'); return; }
    let head = -1, rows = [];
    for (let k = start + 1; k < lines.length; k++) {
      const l = lines[k];
      if (head < 0) { if (l.startsWith('|')) head = k; else if (l.trim() && !l.startsWith('|')) continue; continue; }
      if (!l.startsWith('|')) break;              // tabellen slutar vid första icke-tabellrad
      if (/^\|\s*:?-{2,}/.test(l)) continue;      // skiljelinjen
      rows.push(l);
    }
    const STRATEGY = {
      'Butlery Komponentark v1.dc.html': 'filename',
      'Butlery Grafisk manual v6.dc.html': 'filename',
      'Butlery tillganglighetshandoff.dc.html': 'manual-linked',
      'Butlery ceremonier rorelsereferens.dc.html': 'manual-linked',
      'FONT-VERSION.txt': 'active-release',
      'assets/fonts/VALIDATION-0.626.txt': 'filename',
      'assets/generated/tokens.css': 'generated-header',
      'lib/theme/butlery_tokens.dart': 'generated-header',
      'grundgranskning.md': 'dated',
      'arbetsplan.md': 'field',
      'luckor-etapp9.md': 'field',
      'migration-gap.md': 'dated',
      'korsgranskning.md': 'field'
    };
    const norm = s => String(s).toLowerCase().replace(/^v/, '');
    let measured = 0, filesSeen = 0;
    for (const line of rows) {
      const cells = line.split('|').map(s => s.trim());
      const del = (cells[1] || '').replace(/\*\*/g, '').trim();
      if (!del || /^Del$/i.test(del)) continue;
      const claimed = ((cells[2] || '').match(/([Vv]?\d+(?:\.\d+)*)/) || [])[1];
      const files = [...(cells[3] || '').matchAll(/`([^`]+)`/g)].map(m => m[1])
        .filter(f => /\.(json|md|dc\.html|txt|css|dart)$/.test(f));
      if (!files.length) {
        // En rad utan filreferens måste säga varför (t.ex. "kap 08 i manualen").
        if (!/manual|komponentark|kap\s*\d|ceremonier/i.test(cells[3] || '')) warn('T-15', del + ': raden pekar inte på någon fil och saknar förklaring');
        continue;
      }
      for (const file of files) {
        filesSeen++;
        if (!env.exists(file)) { fail('T-15', del + ': versionstabellen pekar på ' + file + ', som inte finns'); continue; }
        const strategy = STRATEGY[file] || 'field';
        const t = env.read(file);
        let actual = null;
        switch (strategy) {
          case 'filename': actual = (file.match(/[ -]([Vv]?\d+(?:\.\d+)+)(?=\.[a-z]|$)/) || file.match(/[ -]([Vv]\d+)(?=\.|$)/) || [])[1]; break;
          case 'manual-linked': actual = (t.match(/manual\s*\*{0,2}\s*([Vv]\d+)/i) || [])[1]; break;
          case 'active-release': actual = (t.match(/(?:active release|aktuell|version)[^\n]*?([\d.]+)/i) || [])[1]; break;
          // ANKRAD till header-raden. Den gamla regexen matchade ordet
          // "tokens." i "ändra tokens.json" på rad 1 och extraherade "." —
          // vilket också gjorde självtestet falskt positivt. Fas 0.9.
          case 'generated-header': {
            const head = t.split('\n').slice(0, 12).join('\n');
            actual = (head.match(/^[^\n]*\btokens\s+v?(\d+\.\d+(?:\.\d+)?)/im) || [])[1] ||
                     (head.match(/tokens[- ]?version\s*[:=]\s*v?(\d+\.\d+(?:\.\d+)?)/i) || [])[1] || null;
            if (!actual) fail('T-15', del + ' (' + file + '): headern saknar en läsbar rad "tokens <version>" bland de första 12 raderna');
            break;
          }
          // Hela ISO-datumet jämförs. Strategin krävde tidigare bara att NÅGOT
          // datum fanns i filen, så en mutation av tabellens datum gav noll fel.
          case 'dated': actual = (t.match(/(20\d\d-\d\d-\d\d)/) || [])[1]; break;
          default: {
            const jj = t.match(/"version"\s*:\s*"([^"]+)"/);
            actual = jj ? jj[1] : (t.match(/[Vv]ersion\s*\*{0,2}\s*([Vv]?\d+(?:\.\d+)*)/) || [])[1];
          }
        }
        if (!actual) { fail('T-15', del + ' (' + file + '): strategin "' + strategy + '" gav inget värde — rätta strategin eller lägg in ett versionsfält'); continue; }
        measured++;
        if (strategy === 'dated') {
          const claimedDate = ((cells[2] || '').match(/(20\d\d-\d\d-\d\d)/) || [])[1];
          if (!claimedDate) fail('T-15', del + ': historisk rad saknar datum i versionstabellen');
          else if (claimedDate !== actual) fail('T-15', del + ': indexet säger ' + claimedDate + ' men ' + file + ' säger ' + actual);
          continue;
        }
        if (!claimed) { fail('T-15', del + ': versionstabellen saknar versionsvärde för ' + file); continue; }
        if (norm(actual) !== norm(claimed)) fail('T-15', del + ': indexet säger ' + claimed + ' men ' + file + ' säger ' + actual + ' (strategi: ' + strategy + ')');
      }
    }
    info('T-15', rows.length + ' datarader i versionstabellen · ' + filesSeen + ' filreferenser · ' + measured + ' mätta');
    if (filesSeen && measured < filesSeen) fail('T-15', (filesSeen - measured) + ' filreferenser kunde inte mätas — varje rad ska ha en strategi som ger ett värde');
  })();

  /* ── T-17 · interna #-länkar pekar på en ram i SAMMA fil ────────────────── */
  (function () {
    ran('T-17');
    for (const d of DOCS) {
      const t = docTexts[d];
      if (!t) continue;
      const ids = new Set([...t.matchAll(/\sid="([^"]+)"/g)].map(m => m[1]));
      const seen = new Set();
      for (const m of t.matchAll(/href="#([^"]+)"/g)) {
        if (seen.has(m[1])) continue;
        seen.add(m[1]);
        if (!ids.has(m[1])) fail('T-17', d + ': intern länk #' + m[1] + ' finns inte i samma fil — skriv den som filreferens');
      }
    }
  })();

  /* ── A11Y-01 · varje märkt kontroll har roll OCH namn ───────────────────── */
  (function () {
    ran('A11Y-01');
    for (const d of DOCS) {
      const t = docTexts[d];
      if (!t) continue;
      for (const m of t.matchAll(/<[a-z]+[^>]*data-a11y-role="([^"]*)"[^>]*>/g)) {
        const line = t.slice(0, m.index).split('\n').length;
        if (!/data-a11y-name="[^"]+"/.test(m[0])) fail('A11Y-01', d + ':' + line + ' roll "' + m[1] + '" utan tillgängligt namn');
        else if (!m[1].trim()) fail('A11Y-01', d + ':' + line + ' tomt rollvärde');
      }
      // Varje normativt a11y-attribut kräver ett komplett kontrakt: ett
      // element med data-a11y-state men utan roll och namn granskas annars
      // inte av någon kontroll alls. Fas 0.6.
      for (const m of t.matchAll(/<[a-z]+[^>]*data-a11y-state="([^"]*)"[^>]*>/g)) {
        const line = t.slice(0, m.index).split('\n').length;
        if (!/data-a11y-role="[^"]+"/.test(m[0])) fail('A11Y-01', d + ':' + line + ' tillstånd "' + m[1] + '" utan roll — ett halvt kontrakt granskas av ingen kontroll');
        else if (!/data-a11y-name="[^"]+"/.test(m[0])) fail('A11Y-01', d + ':' + line + ' tillstånd "' + m[1] + '" utan namn');
      }
      for (const m of t.matchAll(/<[a-z]+[^>]*data-a11y-name="([^"]*)"[^>]*>/g)) {
        if (!/data-a11y-role=/.test(m[0])) {
          const line = t.slice(0, m.index).split('\n').length;
          fail('A11Y-01', d + ':' + line + ' namn "' + m[1].slice(0, 30) + '" utan roll');
        }
      }
    }
  })();

  /* ── A11Y-02 · kontroller med inneboende tillstånd bär tillstånd ────────── */
  (function () {
    ran('A11Y-02');
    const STATEFUL = /^(checkbox|radio|switch|tab|toggle|menuitemcheckbox|menuitemradio)$/i;
    let missing = 0;
    const per = {};
    for (const d of DOCS) {
      const t = docTexts[d];
      if (!t) continue;
      for (const m of t.matchAll(/<[a-z]+[^>]*data-a11y-role="([^"]+)"[^>]*>/g)) {
        if (!STATEFUL.test(m[1])) continue;
        if (/data-a11y-state="[^"]+"/.test(m[0])) continue;
        missing++; per[m[1]] = (per[m[1]] || 0) + 1;
      }
    }
    if (missing) fail('A11Y-02', missing + ' kontroller med inneboende tillstånd saknar data-a11y-state (' +
      Object.entries(per).map(([k, v]) => k + ' ' + v).join(' · ') + ') — kontraktet i Fas 3 gör fältet obligatoriskt');
  })();

  /* ── T-19 · Markdown-tabellintegritet ──────────────────────────────────── */
  // Fas 0.10: granskade fem filer och gav falskt fel för en legitim kodcell med
  // "A || B". Nu tokeniseras raden: kodspann (`…`) och escapade pipes maskeras
  // innan pipes räknas, och ALLA aktiva md-filer granskas.
  (function () {
    ran('T-19');
    // Alla aktiva md-filer, även nästlade. Historiska underlag är frysta och
    // undantas namngivet.
    const FROZEN = /^(granskning-v12|grundgranskning|korsgranskning|luckor-etapp9|migration-gap|arbetsplan)/;
    const files = (env.list ? env.list() : []).filter(f => /\.md$/.test(f) && !FROZEN.test(f.split('/').pop()));
    const FILES = files.length ? files : ['00-spec-index.md', 'evidensmatris.md', 'testmatris.md', 'produktregler.md', 'blockerande.md'];
    // Maskerar kodspann och escapade pipes så att bara STRUKTURELLA pipes räknas.
    const mask = s => s.replace(/\\\|/g, '\u0000').replace(/`[^`]*`/g, m => m.replace(/\|/g, '\u0000'));
    for (const f of FILES) {
      if (!env.exists(f)) continue;
      const lines = env.read(f).split('\n');
      let fence = false, table = null;
      lines.forEach((line, k) => {
        if (/^\s*```/.test(line)) { fence = !fence; return; }
        if (fence) return;
        if (!line.startsWith('|')) { table = null; return; }
        const m = mask(line);
        const cells = m.split('|');
        // Två tabellrader på samma källrad: en strukturell '||' MED innehåll efter.
        if (/\|\s*\|\s*\S/.test(m) && /\|\s*\|\s*(\*\*)?[A-ZÅÄÖ][A-ZÅÄÖa-zåäö0-9]*-\d/.test(m))
          fail('T-19', f + ':' + (k + 1) + ' två tabellrader på samma källrad — den andra försvinner vid rendering');
        if (/^\|[\s:|-]+\|?\s*$/.test(m)) { if (table) table.confirmed = true; return; }
        if (!table) { table = { cols: cells.length, at: k + 1, confirmed: false }; return; }
        if (cells.length !== table.cols)
          fail('T-19', f + ':' + (k + 1) + ' ' + cells.length + ' kolumnavgränsare, tabellen på rad ' + table.at + ' har ' + table.cols);
      });
    }
  })();

  /* ── T-18a · evidensmatrisens STRUKTUR · grindande ───────────────────────── */
  // Delad i Fas 0.11: strukturella fel gör att kravrader inte ens parsas, alltså
  // försvinner ur baslinjen medan grinden ser grön ut. Struktur = grind (T-18a),
  // innehåll = baslinjefynd (T-18b).
  (function () {
    ran('T-18a');
    if (!env.exists('evidensmatris.md')) return;
    const { problems } = parseEvidence(env.read('evidensmatris.md'));
    const { structural } = splitEvidenceProblems(problems);
    for (const p of structural) fail('T-18a', 'evidensmatris.md ' + p);
  })();

  /* ── T-18b · evidensmatrisens INNEHÅLL · baslinjefynd ────────────────────── */
  (function () {
    ran('T-18b');
    if (!env.exists('evidensmatris.md')) return;
    const { problems } = parseEvidence(env.read('evidensmatris.md'));
    const { content } = splitEvidenceProblems(problems);
    for (const p of content) fail('T-18b', 'evidensmatris.md ' + p);
  })();

  return { errors, warnings, ran: [...ranIds].sort() };
}
