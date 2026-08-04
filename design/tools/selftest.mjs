#!/usr/bin/env node
// Butlery · mutationsprov FÖR VERIFIERAREN. Kör: node tools/selftest.mjs
//
// Fas 0.6: provet mäter DELTA. Tidigare räckte det att ett fel med rätt id
// fanns efter mutationen — och eftersom baslinjen redan har fel för A11Y-02,
// T-14 och T-15 hade en no-op passerat. Nu krävs:
//   1 att mutationen faktiskt ändrade källan,
//   2 en NY diagnostik som inte fanns i baslinjen,
//   3 att den nya diagnostiken bär rätt kontroll-id.
// skipped > 0 ger exit 1: ett prov som inte kan byggas är ett prov som inte finns.
import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { lint } from './lint-core.mjs';
import { SCREEN_FILES } from './screen-files.mjs';

const cache = new Map();
const read = p => { if (!cache.has(p)) cache.set(p, existsSync(p) ? readFileSync(p, 'utf8') : null); return cache.get(p); };
const envWith = (over = {}) => ({
  read: p => (p in over ? over[p] : read(p)),
  exists: p => (p in over ? over[p] !== null : existsSync(p)),
  list: () => {
    const SKIP = new Set(['node_modules', '.git', 'assets', 'exports', 'Butlery-lockup-family-L4-3']);
    const out = [];
    const walk = dir => {
      for (const e of readdirSync(dir)) {
        if (SKIP.has(e)) continue;
        const p = dir === '.' ? e : dir + '/' + e;
        let s2; try { s2 = statSync(p); } catch { continue; }
        if (s2.isDirectory()) walk(p); else out.push(p);
      }
    };
    walk('.');
    return out;
  }
});

const screen = SCREEN_FILES[0];
const idx = '00-spec-index.md';
const ev = 'evidensmatris.md';

// Baslinjen mäts EN gång och jämförs mot varje mutation.
const baseline = lint(envWith());
const baseSet = new Set(baseline.errors);
console.log('SELFTEST-BASELINE errors=' + baseline.errors.length + ' warnings=' + baseline.warnings.length);

const cases = [
  ['A11Y-01 · borttaget tillgängligt namn', 'A11Y-01', () => {
    const t = read(screen);
    const m = t.match(/<[a-z]+[^>]*data-a11y-role="[^"]*"[^>]*data-a11y-name="[^"]*"[^>]*>/) ||
              t.match(/<[a-z]+[^>]*data-a11y-name="[^"]*"[^>]*data-a11y-role="[^"]*"[^>]*>/);
    if (!m) return null;
    return { [screen]: t.replace(m[0], m[0].replace(/\sdata-a11y-name="[^"]*"/, '')) };
  }],
  ['A11Y-01 · state utan roll och namn', 'A11Y-01', () => {
    const t = read(screen);
    const m = t.match(/<span[^>]*style="[^"]*"[^>]*>/);
    if (!m) return null;
    return { [screen]: t.replace(m[0], m[0].slice(0, -1) + ' data-a11y-state="disabled">') };
  }],
  ['A11Y-02 · borttaget tillstånd på en MÄRKT stateful kontroll', 'A11Y-02', () => {
    for (const f of SCREEN_FILES) {
      const t = read(f);
      if (!t) continue;
      const m = t.match(/<[a-z]+[^>]*data-a11y-role="(?:checkbox|radio|switch|tab)"[^>]*data-a11y-state="[^"]*"[^>]*>/) ||
                t.match(/<[a-z]+[^>]*data-a11y-state="[^"]*"[^>]*data-a11y-role="(?:checkbox|radio|switch|tab)"[^>]*>/);
      if (m) return { [f]: t.replace(m[0], m[0].replace(/\sdata-a11y-state="[^"]*"/, '')) };
    }
    return null;
  }],
  ['T-15 field · tokensversion i indexet', 'T-15', () => {
    const t = read(idx);
    // F1-H03: Del-cellen bär numera en auth:-markör. Mönstret hoppar över den
    // i stället för att sluta matcha — ett prov som tyst slutar mäta är värre
    // än inget prov alls.
    const m = t.match(/(\| Tokens[^|]*\| )\*\*[\d.]+\*\*/);
    if (!m) return null;
    return { [idx]: t.replace(m[0], m[1] + '**9.99**') };
  }],
  ['T-15 filename · komponentarkets version', 'T-15', () => {
    const t = read(idx);
    const m = t.match(/(\| Komponentark[^|]*\| )\*\*V1\*\*/);
    if (!m) return null;
    return { [idx]: t.replace(m[0], m[1] + '**V999**') };
  }],
  ['T-15 dated · grundgranskningens datum', 'T-15', () => {
    const t = read(idx);
    const m = t.match(/\| Grundgranskning \| ([\d-]+)/);
    if (!m) return null;
    return { [idx]: t.replace(m[0], '| Grundgranskning | 2099-12-31') };
  }],
  ['T-14 · borttaget skärmbevis på bevisad rad', 'T-14', () => {
    const lines = read(ev).split('\n');
    const i = lines.findIndex(l => /^\|/.test(l) && /`#[a-z0-9]+`/.test(l) && /(implementerad|verifierad)/.test(l) && !l.includes('<!--hist-->'));
    if (i < 0) return null;
    const cells = lines[i].split('|');
    cells[4] = ' — ';
    lines[i] = cells.join('|');
    return { [ev]: lines.join('\n') };
  }],
  ['T-14 · screen-bevis som pekar på en ram som inte finns', 'T-14', () => {
    // Muterar en VERKLIG kravrads Skärmbevis-cell, inte första bästa `#id` i
    // filen — det gamla provet träffade grammatikexemplet #ram-id i prosan.
    const lines = read(ev).split('\n');
    const i = lines.findIndex(l => {
      if (!l.startsWith('|') || l.includes('<!--hist-->')) return false;
      const c = l.split('|').map(s => s.trim());
      return /^[A-ZÅÄÖ]{1,3}-\d+[a-z]?$/.test(c[1] || '') && /`#[a-z0-9åäö-]+`/.test(c[4] || '');
    });
    if (i < 0) return null;
    const cells = lines[i].split('|');
    cells[4] = cells[4].replace(/`#[a-z0-9åäö-]+`/, '`#ramensomaldrigfunnits`');
    lines[i] = cells.join('|');
    return { [ev]: lines.join('\n') };
  }],
  ['T-14 · component-bevis mot avsnitt som inte finns', 'T-14', () => {
    const lines = read(ev).split('\n');
    const i = lines.findIndex(l => {
      if (!l.startsWith('|') || l.includes('<!--hist-->')) return false;
      const c = l.split('|').map(s => s.trim());
      return /^[A-ZÅÄÖ]{1,3}-\d+[a-z]?$/.test(c[1] || '') && (c[4] || '').length > 1;
    });
    if (i < 0) return null;
    const cells = lines[i].split('|');
    cells[4] = ' component:k99 ';
    lines[i] = cells.join('|');
    return { [ev]: lines.join('\n') };
  }],
  ['T-14 · manual-bevis mot kapitel som inte finns', 'T-14', () => {
    const lines = read(ev).split('\n');
    const i = lines.findIndex(l => {
      if (!l.startsWith('|') || l.includes('<!--hist-->')) return false;
      const c = l.split('|').map(s => s.trim());
      return /^[A-ZÅÄÖ]{1,3}-\d+[a-z]?$/.test(c[1] || '') && (c[4] || '').length > 1;
    });
    if (i < 0) return null;
    const cells = lines[i].split('|');
    cells[4] = ' manual:kap-99 ';
    lines[i] = cells.join('|');
    return { [ev]: lines.join('\n') };
  }],
  ['T-15 manual-linked · handoffens manualversion', 'T-15', () => {
    const t = read(idx);
    const m = t.match(/(\| Tillgänglighetshandoff[^|]*\| )([^|]*)\|/);
    if (!m) return null;
    return { [idx]: t.replace(m[0], m[1] + 'mot manual V99 |') };
  }],
  ['T-15 active-release · fontversionen', 'T-15', () => {
    const t = read(idx);
    const m = t.match(/\| Typsnitt \| ([^|]*)\|/);
    if (!m) return null;
    return { [idx]: t.replace(m[0], '| Typsnitt | Butlery Sans **9.999** |') };
  }],
  ['T-15 generated-header · versionen i headerraden', 'T-15', () => {
    // Muterar HEADER-RADEN, inte första förekomsten av ordet "tokens" — den
    // gamla mutationen skrev om "ändra tokens.json" till "ändra tokens 0.001json"
    // och rörde aldrig versionen, vilket gjorde provet falskt positivt.
    const p = 'assets/generated/tokens.css';
    const t = read(p);
    if (!t) return null;
    const lines = t.split('\n');
    const i = lines.findIndex(l => /\btokens\s+\d+\.\d+/.test(l));
    if (i < 0) return null;
    const before = lines[i];
    lines[i] = before.replace(/\btokens\s+\d+\.\d+(\.\d+)?/, 'tokens 0.001');
    if (lines[i] === before) return null;          // mutationen måste ändra just den raden
    return { [p]: lines.join('\n') };
  }],
  ['T-16 · dubblett-id över filgräns', 'T-16', () => {
    const a = read(SCREEN_FILES[0]), b = read(SCREEN_FILES[1]);
    const id = (a.match(/class="sc-item"[^>]*id="([^"]+)"/) || [])[1];
    if (!id || !b) return null;
    return { [SCREEN_FILES[1]]: b.replace(/class="sc-item"([^>]*)id="[^"]+"/, 'class="sc-item"$1id="' + id + '"') };
  }],
  ['T-17 · intern länk till en ram i en annan fil', 'T-17', () => {
    const t = read(screen);
    if (!/href="#[^"]+"/.test(t)) return null;
    return { [screen]: t.replace(/href="#[^"]+"/, 'href="#finns-inte-i-denna-fil"') };
  }],
  ['T-12 · citerat ankare utan ram', 'T-12', () => {
    const t = read(idx);
    return { [idx]: t.replace(/^## /m, 'Se `#ettankaresomintefinns`.\n\n## ') };
  }],
  ['T-02 · kontrastpar under golvet', 'T-02', () => {
    const p = 'tokens.json';
    const t = read(p);
    if (!t) return null;
    const j = JSON.parse(t);
    // Sänk en deklarerad kontrastyta till nästan samma ton som sin bakgrund.
    const key = Object.keys(j.semantic || {}).find(k => j.semantic[k] && typeof j.semantic[k].light === 'string' && /^#/.test(j.semantic[k].light));
    if (!key) return null;
    j.semantic[key] = { ...j.semantic[key], light: '#FEFEFE' };
    return { [p]: JSON.stringify(j, null, 2) };
  }],

  ['T-08 · deklarerad träffyta under golvet', 'T-08', () => {
    for (const f of SCREEN_FILES) {
      const t = read(f);
      if (!t || !/data-hit="48"/.test(t)) continue;
      return { [f]: t.replace('data-hit="48"', 'data-hit="32"') };
    }
    return null;
  }],
  ['T-10 · versionsrad i indexet motsäger filens egen version', 'T-10', () => {
    // T-10 jämför indexets versionsrader mot filernas värden. Fas 0.12: det
    // gamla provet skrev fri prosa om antalet beslut, vilket kontrollen inte
    // läser — den läser tabellraden "| Tokens | **N** |".
    const p = '00-spec-index.md';
    const t = read(p);
    const mm = t.match(/\|\s*\*{0,2}Tokens\*{0,2}[^|]*\|\s*\*\*([\d.]+)\*\*/);
    if (!mm) return null;
    return { [p]: t.replace(mm[0], mm[0].replace(mm[1], '9.99')) };
  }],

  ['T-18a · kravrad med fel kolumnantal', 'T-18a', () => {
    const lines = read(ev).split('\n');
    const i = lines.findIndex(l => {
      if (!l.startsWith('|') || l.includes('<!--hist-->')) return false;
      const c = l.split('|').map(s => s.trim());
      return /^[A-ZÅÄÖ]{1,3}-\d+[a-z]?$/.test(c[1] || '') && c.length > 6;
    });
    if (i < 0) return null;
    const cells = lines[i].split('|');
    cells.splice(3, 1);                       // ta bort en kolumn
    lines[i] = cells.join('|');
    return { [ev]: lines.join('\n') };
  }],
  ['T-18b · okänd status i statuskolumnen', 'T-18b', () => {
    const lines = read(ev).split('\n');
    const i = lines.findIndex(l => {
      if (!l.startsWith('|') || l.includes('<!--hist-->')) return false;
      const c = l.split('|').map(s => s.trim());
      return /^[A-ZÅÄÖ]{1,3}-\d+[a-z]?$/.test(c[1] || '') && /verifierad|implementerad|beslutad/.test(c[c.length - 2] || '');
    });
    if (i < 0) return null;
    const cells = lines[i].split('|');
    cells[cells.length - 2] = ' implementeradx ';
    lines[i] = cells.join('|');
    return { [ev]: lines.join('\n') };
  }],
  ['T-19 · två tabellrader på samma källrad', 'T-19', () => {
    const p = 'testmatris.md';
    const t = read(p);
    const lines = t.split('\n');
    const i = lines.findIndex(l => l.startsWith('|') && l.split('|').length > 3);
    if (i < 0) return null;
    lines[i] = lines[i].trimEnd() + '| K-99 | inbäddad rad som försvinner |';
    return { [p]: lines.join('\n') };
  }],
  // Fas 1 · BESTÄNDIGA schemaprov. Varje rad är en mutation som måste fällas av
  // T-01; listan är verktygskedjans egen, inte en engångskörning.
  ...[
    ['negativt mått', t => { t.controls.checkbox.size = -4; }],
    ['okänd toppnyckel', t => { t.pahittadNyckel = 1; }],
    ['chip.paddingY som text', t => { t.controls.chip.paddingY = 'fel'; }],
    ['button.iconSize som tal', t => { t.controls.button.iconSize = -8; }],
    ['button.iconSize med negativ post', t => { t.controls.button.iconSize = [16, -8]; }],
    ['lines.hairline negativ', t => { t.controls.lines.hairline = -1; }],
    ['labelWeight som ord', t => { t.controls.calendarPresenceRow.labelWeight = 'bold'; }],
    ['felstavat fältnamn', t => { t.controls.chip.fontSzie = 12; }],
    ['checkbox utan checkStroke', t => { delete t.controls.checkbox.checkStroke; }],
    ['maxFaces = 0', t => { t.controls.calendarPresenceRow.maxFaces = 0; }],
    ['maxFaces som decimal', t => { t.controls.calendarPresenceRow.maxFaces = 3.5; }],
    ['toggle.knob som sträng', t => { t.controls.toggle.knob = '12'; }],
    ['okänd komponent i controls', t => { t.controls.pahitt = { size: 1 }; }],
    ['statusPill.radius som boolean', t => { t.controls.statusPill.radius = true; }],
    ['tom avatarskala', t => { t.controls.avatarScale = []; }],
    ['emptyStateGlyph utan fullscreen', t => { delete t.emptyStateGlyph.fullscreen; }],
    ['okänt fält i glyfen', t => { t.emptyStateGlyph.pahitt = 1; }]
  ].map(([label, mut]) => ['T-01 · ' + label, 'T-01', () => {
    const t = JSON.parse(read('tokens.json'));
    mut(t);
    return { 'tokens.json': JSON.stringify(t, null, 2) };
  }]),
  // Fas 1 (andra vändan): T-01 validerar tre källor, inte en. De två nya
  // grenarna måste kunna fällas — annars mäter de ingenting.
  ['T-01 · app-theme-map med felaktig boldWeight', 'T-01', () => {
    const p = 'tools/app-theme-map.json';
    const m = JSON.parse(read(p) || 'null');
    if (!m) return null;
    m.boldWeight = '700';
    return { [p]: JSON.stringify(m, null, 2) };
  }],
  ['T-01 · app-theme-map med okänd toppnyckel', 'T-01', () => {
    const p = 'tools/app-theme-map.json';
    const m = JSON.parse(read(p) || 'null');
    if (!m) return null;
    m.pahitt = 1;
    return { [p]: JSON.stringify(m, null, 2) };
  }],
  // Fas 1 (fjärde vändan): dessa två källmutationer passerade HELA kedjan.
  ['T-01 · rå färg i scheme.darkOverrides', 'T-01', () => {
    const p = 'tools/app-theme-map.json';
    const m = JSON.parse(read(p) || 'null');
    if (!m || !m.scheme?.darkOverrides) return null;
    m.scheme.darkOverrides[Object.keys(m.scheme.darkOverrides)[0]] = ['raw', 'rgba(1,2,3,0.4)'];
    return { [p]: JSON.stringify(m, null, 2) };
  }],
  ['T-01 · typeSemantic.color mot en AppColors-medlem som inte finns', 'T-01', () => {
    const p = 'tools/app-theme-map.json';
    const m = JSON.parse(read(p) || 'null');
    if (!m || !m.typeSemantic) return null;
    const key = Object.keys(m.typeSemantic).find(k => m.typeSemantic[k].color);
    if (!key) return null;
    m.typeSemantic[key].color = 'AppColors.doesNotExist';
    return { [p]: JSON.stringify(m, null, 2) };
  }],
  ['T-20 · två aktiva auktoriteter för samma domän', 'T-20', () => {
    const p = 'source-authority.json';
    const a = JSON.parse(read(p) || 'null');
    if (!a) return null;
    const first = a.authorities.find(x => x.file && x.authorityState === 'active');
    if (!first) return null;
    a.authorities.push({ ...first, file: 'tokens.json' });
    return { [p]: JSON.stringify(a, null, 2) };
  }],
  // F1-H01 · registrets egen version mot självposten.
  ['T-20 · filversionen och självposten säger olika (F1-H01)', 'T-20', () => {
    const p = 'source-authority.json';
    const a = JSON.parse(read(p) || 'null');
    if (!a) return null;
    const self = a.authorities.find(x => x.domainId === 'source-authority');
    if (!self) return null;
    self.version = '1.0';               // filen säger något annat
    return { [p]: JSON.stringify(a, null, 2) };
  }],
  // F1-H04 · HELA domänen stryks. Den obligatoriska mängden bor i
  // tools/authority-contract.mjs, inte i den fil som muteras — annars hade
  // strykningen tagit med sig sitt eget krav och provet blivit vakuöst.
  ['T-20 · hela domänen Designvärden struken ur registret (F1-H04)', 'T-20', () => {
    const p = 'source-authority.json';
    const a = JSON.parse(read(p) || 'null');
    if (!a) return null;
    const before = a.authorities.length;
    a.authorities = a.authorities.filter(x => x.domainId !== 'design-values');
    if (a.authorities.length === before) return null;
    return { [p]: JSON.stringify(a, null, 2) };
  }],
  // F1-H04 · en domän som INTE finns i den kanoniska mängden.
  ['T-20 · okänd domän tillagd i registret (F1-H04)', 'T-20', () => {
    const p = 'source-authority.json';
    const a = JSON.parse(read(p) || 'null');
    if (!a) return null;
    a.authorities.push({
      domainId: 'hittepa-domain', domain: 'Påhittad domän', sourceId: null,
      file: 'tokens.json', version: '1.13', authorityState: 'active',
      changePolicy: 'maintained', owner: 'DS', note: ''
    });
    return { [p]: JSON.stringify(a, null, 2) };
  }],
  // F1-H05 · en Markdown-källa deklareras med en version filen inte bär.
  // Den gamla kontrollen läste bara JSON och hade sagt ingenting.
  ['T-20 · content-style-guide.md deklarerad som 9.9 (F1-H05)', 'T-20', () => {
    const p = 'source-authority.json';
    const a = JSON.parse(read(p) || 'null');
    if (!a) return null;
    const row = a.authorities.find(x => x.file === 'content-style-guide.md');
    if (!row) return null;
    row.version = '9.9';                // filen ändras INTE
    return { [p]: JSON.stringify(a, null, 2) };
  }],
  // F1-H06 · mängdlikhet mot tools/gen-targets.mjs, båda riktningarna.
  ['T-20 · borttagen rad ur generatedArtifacts (F1-H06)', 'T-20', () => {
    const p = 'source-authority.json';
    const a = JSON.parse(read(p) || 'null');
    if (!a || !a.generatedArtifacts.length) return null;
    a.generatedArtifacts = a.generatedArtifacts.filter(g => g.file !== 'assets/generated/tokens.css');
    return { [p]: JSON.stringify(a, null, 2) };
  }],
  ['T-20 · extra rad i generatedArtifacts (F1-H06)', 'T-20', () => {
    const p = 'source-authority.json';
    const a = JSON.parse(read(p) || 'null');
    if (!a) return null;
    a.generatedArtifacts.push({ file: 'tokens.json', generator: 'tools/gen-css.mjs' });
    return { [p]: JSON.stringify(a, null, 2) };
  }],
  // F1-H07 · KONSEKVENT omdöpning. Alla inkommande referenser döps om samtidigt,
  // så intern konsistens är perfekt. Bara en kontroll mot manifestets faktiska
  // zip:/-poster kan fälla det — och det är precis vad som saknades.
  ['T-20 · extern auktoritet konsekvent omdöpt till en fil som inte finns (F1-H07)', 'T-20', () => {
    const p = 'source-authority.json';
    const a = JSON.parse(read(p) || 'null');
    if (!a) return null;
    const OLD = 'Butlery styrdokument modulart designsystem.dc.html';
    const NEW = 'Butlery styrdokument modulart designsystem v9.dc.html';
    let touched = 0;
    for (const row of [...a.authorities, ...a.superseded]) {
      if (row.file === OLD) { row.file = NEW; touched++; }
      if (row.supersededBy === OLD) { row.supersededBy = NEW; touched++; }
    }
    if (!touched) return null;
    return { [p]: JSON.stringify(a, null, 2) };
  }],
  ['T-20 · blocked och not run ihopslagna i statusordboken', 'T-20', () => {
    const p = 'source-authority.json';
    const a = JSON.parse(read(p) || 'null');
    if (!a) return null;
    a.controlStatusVocabulary = a.controlStatusVocabulary.filter(c => c.status !== 'not run');
    return { [p]: JSON.stringify(a, null, 2) };
  }],
  ['T-20 · deklarerad version som inte stämmer med filen', 'T-20', () => {
    const p = 'source-authority.json';
    const a = JSON.parse(read(p) || 'null');
    if (!a) return null;
    const row = a.authorities.find(x => x.file === 'icons.json');
    if (!row) return null;
    row.version = '1.6';
    return { [p]: JSON.stringify(a, null, 2) };
  }],
  // F1-H02 · en domän kan inte vara både active och planned.
  ['T-20 · samma domän både active och planned (F1-H02)', 'T-20', () => {
    const p = 'source-authority.json';
    const a = JSON.parse(read(p) || 'null');
    if (!a) return null;
    const row = a.authorities.find(x => x.domainId === 'decisions');
    if (!row) return null;
    a.authorities.push({ ...row, file: null, version: null, authorityState: 'planned' });
    return { [p]: JSON.stringify(a, null, 2) };
  }],
  // F1-H02 · historical får aldrig räknas som aktuell auktoritet.
  ['T-20 · historisk post satt som aktuell (F1-H02)', 'T-20', () => {
    const p = 'source-authority.json';
    const a = JSON.parse(read(p) || 'null');
    if (!a || !a.superseded.length) return null;
    a.superseded[0] = { ...a.superseded[0], authorityState: 'active' };
    return { [p]: JSON.stringify(a, null, 2) };
  }],
  ['T-20 · supersededBy som pekar i en cykel', 'T-20', () => {
    const p = 'source-authority.json';
    const a = JSON.parse(read(p) || 'null');
    if (!a) return null;
    a.superseded = a.superseded.map(s2 => s2.file === 'grundgranskning.md' ? { ...s2, supersededBy: 'luckor-etapp9.md' } : s2);
    const b = a.superseded.find(s2 => s2.file === 'luckor-etapp9.md');
    if (b) b.supersededBy = 'grundgranskning.md';
    return { [p]: JSON.stringify(a, null, 2) };
  }],
  ['T-01 · tomt legacy-API-kontrakt', 'T-01', () => {
    const p = 'legacy-api-contract.json';
    const c = JSON.parse(read(p) || 'null');
    if (!c) return null;
    c.appColors.members = [];
    return { [p]: JSON.stringify(c, null, 2) };
  }],
  ['T-01 · varumärkesfärg utan giltig hex', 'T-01', () => {
    const p = 'assets/brand-colors.json';
    const b = JSON.parse(read(p) || 'null');
    if (!b) return null;
    b.brands[Object.keys(b.brands)[0]].color = 'red';
    return { [p]: JSON.stringify(b, null, 2) };
  }],
  // minProperties/maxProperties var deklarerade i schemana men INTE
  // implementerade i walkSchema — ett tömt rollobjekt och en tömd
  // varumärkeslista gav noll problem. Fas 1 (tredje vändan).
  ['T-01 · tom typography.roles (minProperties)', 'T-01', () => {
    const t = JSON.parse(read('tokens.json'));
    t.typography.roles = {};
    return { 'tokens.json': JSON.stringify(t, null, 2) };
  }],
  ['T-01 · tom brands (minProperties)', 'T-01', () => {
    const p = 'assets/brand-colors.json';
    const b = JSON.parse(read(p) || 'null');
    if (!b) return null;
    b.brands = {};
    return { [p]: JSON.stringify(b, null, 2) };
  }],
  // Registret får inte motsäga leveransen: fjorton mastrar fanns på disk medan
  // icons.json sa "att rita". Fas 1 (tredje vändan).
  ['T-05 · status "att rita" på en ikon som finns på disk', 'T-05', () => {
    const p = 'icons.json';
    const i = JSON.parse(read(p) || 'null');
    if (!i || !i.ui_family?.length) return null;
    i.ui_family[0].status = 'att rita';
    return { [p]: JSON.stringify(i, null, 2) };
  }],
  ['T-05 · icke-kanonisk ikonstatus', 'T-05', () => {
    const p = 'icons.json';
    const i = JSON.parse(read(p) || 'null');
    if (!i || !i.ui_family?.length) return null;
    i.ui_family[1].status = 'levererad 2026-07-26';
    return { [p]: JSON.stringify(i, null, 2) };
  }],
  ['T-10 · genererad kodfil med fel tokenversion i headern', 'T-10', () => {
    const p = 'lib/theme/app_colors.dart';
    const t = read(p);
    if (!t) return null;
    const lines = t.split('\n');
    const i = lines.findIndex(l => /\btokens\s+\d+\.\d+/.test(l));
    if (i < 0) return null;
    lines[i] = lines[i].replace(/\btokens\s+\d+\.\d+(\.\d+)?/, 'tokens 0.001');
    return { [p]: lines.join('\n') };
  }],
  // Fas 1 · SVG-KONTRAKTET. T-05 kontrollerade tidigare bara namn och filnärvaro.
  ['T-05 · fel stroke-width i en ikonmaster', 'T-05', () => {
    const p = 'assets/icons/bell.svg';
    const t = read(p);
    if (!t) return null;
    return { [p]: t.replace('stroke-width="1.75"', 'stroke-width="3"') };
  }],
  ['T-05 · title matchar inte ikonens id', 'T-05', () => {
    const p = 'assets/icons/bell.svg';
    const t = read(p);
    if (!t) return null;
    return { [p]: t.replace('<title>bell</title>', '<title>klocka</title>') };
  }],
  ['T-05 · saknad title', 'T-05', () => {
    const p = 'assets/icons/tag.svg';
    const t = read(p);
    if (!t) return null;
    return { [p]: t.replace(/\s*<title>[^<]*<\/title>/, '') };
  }],
  ['T-05 · fel viewBox', 'T-05', () => {
    const p = 'assets/icons/minus.svg';
    const t = read(p);
    if (!t) return null;
    return { [p]: t.replace('viewBox="0 0 24 24"', 'viewBox="0 0 32 32"') };
  }],
  ['T-05 · fyllning i en strecksymbol', 'T-05', () => {
    const p = 'assets/icons/block.svg';
    const t = read(p);
    if (!t) return null;
    return { [p]: t.replace('fill="none"', 'fill="currentColor"') };
  }],
  ['T-05 · inline style i mastern', 'T-05', () => {
    const p = 'assets/icons/stop.svg';
    const t = read(p);
    if (!t) return null;
    return { [p]: t.replace('<title>stop</title>', '<title>stop</title>\n  <g style="opacity:.5"></g>') };
  }],
  ['T-05 · undantag utan motivering', 'T-05', () => {
    const ic = JSON.parse(read('icons.json'));
    ic.contract.exceptions.bell = { 'stroke-width': '3' };
    return { 'icons.json': JSON.stringify(ic, null, 2) };
  }],
  ['T-05 · undantag för en ikon som inte finns', 'T-05', () => {
    const ic = JSON.parse(read('icons.json'));
    ic.contract.exceptions['finns-inte'] = { variant: 'filled', reason: 'x' };
    return { 'icons.json': JSON.stringify(ic, null, 2) };
  }],
  ['T-05 · okänt ikonnamn', 'T-05', () => {
    const t = read(screen);
    if (!/data-icon="[a-z-]+"/.test(t)) return null;
    return { [screen]: t.replace(/data-icon="[a-z-]+"/, 'data-icon="en-glyf-som-inte-finns"') };
  }]
];

// POSITIVA regressionsprov: en mutation som är GILTIG får inte skapa någon ny
// diagnostik för kontrollen. Utan dem bevisar självtestet bara att fel fälls —
// inte att rätt accepteras. Fas 0.8.
const positives = [
  ['T-19 + · A || B inne i en kodcell fälls inte', 'T-19', () => {
    const p = 'testmatris.md';
    const t = read(p);
    const lines = t.split('\n');
    const i = lines.findIndex(l => l.startsWith('|') && l.split('|').length > 3 && !/^\|[\s:|-]+\|?\s*$/.test(l));
    if (i < 0) return null;
    const cells = lines[i].split('|');
    cells[2] = ' `A || B` ';
    lines[i] = cells.join('|');
    return { [p]: lines.join('\n') };
  }],
  ['T-14 + · giltigt screen-bevis accepteras', 'T-14', () => {
    const lines = read(ev).split('\n');
    const frames = [];
    for (const f of SCREEN_FILES) {
      const t = read(f);
      if (!t) continue;
      for (const m of t.matchAll(/class="sc-item"[^>]*\sid="([^"]+)"/g)) frames.push(m[1]);
      if (frames.length) break;
    }
    const i = lines.findIndex(l => {
      if (!l.startsWith('|') || l.includes('<!--hist-->')) return false;
      const c = l.split('|').map(s => s.trim());
      return /^[A-ZÅÄÖ]{1,3}-\d+[a-z]?$/.test(c[1] || '') && /`#[a-z0-9åäö-]+`/.test(c[4] || '');
    });
    if (i < 0 || !frames.length) return null;
    const cells = lines[i].split('|');
    cells[4] = ' screen:`#' + frames[0] + '` ';
    lines[i] = cells.join('|');
    return { [ev]: lines.join('\n') };
  }],
  ['T-14 + · giltigt component-bevis accepteras', 'T-14', () => {
    const sheet = read('Butlery Komponentark v1.dc.html');
    const kid = (sheet && (sheet.match(/\sid="(k\d{2})"/) || [])[1]);
    const lines = read(ev).split('\n');
    const i = lines.findIndex(l => {
      if (!l.startsWith('|') || l.includes('<!--hist-->')) return false;
      const c = l.split('|').map(s => s.trim());
      return /^[A-ZÅÄÖ]{1,3}-\d+[a-z]?$/.test(c[1] || '') && (c[4] || '').length > 1;
    });
    if (i < 0 || !kid) return null;
    const cells = lines[i].split('|');
    cells[4] = ' component:' + kid + ' ';
    lines[i] = cells.join('|');
    return { [ev]: lines.join('\n') };
  }],
  ['T-14 + · giltigt manual-bevis accepteras', 'T-14', () => {
    const man = read('Butlery Grafisk manual v6.dc.html');
    const sid = (man && (man.match(/\sid="s(\d{2})"/) || [])[1]);
    const lines = read(ev).split('\n');
    const i = lines.findIndex(l => {
      if (!l.startsWith('|') || l.includes('<!--hist-->')) return false;
      const c = l.split('|').map(s => s.trim());
      return /^[A-ZÅÄÖ]{1,3}-\d+[a-z]?$/.test(c[1] || '') && (c[4] || '').length > 1;
    });
    if (i < 0 || !sid) return null;
    const cells = lines[i].split('|');
    cells[4] = ' manual:kap-' + sid + ' ';
    lines[i] = cells.join('|');
    return { [ev]: lines.join('\n') };
  }]
];

// TOM-MÄNGD-prov: tas alla kNN respektive sNN bort ska T-14 ge det HÅRDA felet.
// En validering mot en tom mängd godkänner allt, vilket är sämre än ingen.
const emptySetCases = [
  ['T-14 · komponentarket utan kNN ger hårt fel', 'T-14', () => {
    const p = 'Butlery Komponentark v1.dc.html';
    const t = read(p);
    if (!t || !/\sid="k\d{2}"/.test(t)) return null;
    return { [p]: t.replace(/\sid="k(\d{2})"/g, ' data-was-id="k$1"') };
  }],
  ['T-14 · manualen utan sNN ger hårt fel', 'T-14', () => {
    const p = 'Butlery Grafisk manual v6.dc.html';
    const t = read(p);
    if (!t || !/\sid="s\d{2}/.test(t)) return null;
    return { [p]: t.replace(/\sid="s(\d{2}[a-z]?)"/g, ' data-was-id="s$1"') };
  }]
];

// FIXTURPROV: innan någon mutation prövas måste parsern kunna läsa det RÄTTA
// värdet ur den omuterade filen. Ett prov som passerar på en trasig parser är
// värdelöst — det var precis vad generated-header gjorde. Fas 0.9.
let fixtureFail = 0;
{
  const tj = read('tokens.json');
  const want = tj ? (JSON.parse(tj).version || null) : null;
  for (const p of ['assets/generated/tokens.css', 'lib/theme/butlery_tokens.dart']) {
    const t = read(p);
    if (!t) { console.error('✖ FIXTUR ' + p + ' finns inte'); fixtureFail++; continue; }
    const head = t.split('\n').slice(0, 12).join('\n');
    const got = (head.match(/^[^\n]*\btokens\s+v?(\d+\.\d+(?:\.\d+)?)/im) || [])[1] || null;
    if (!got) { console.error('✖ FIXTUR ' + p + ': headern har ingen läsbar "tokens <version>"-rad'); fixtureFail++; }
    else if (!/^\d+\.\d+/.test(got)) { console.error('✖ FIXTUR ' + p + ': parsern läste "' + got + '", inte ett versionsnummer'); fixtureFail++; }
    else console.log('· FIXTUR ' + p + ' → tokens ' + got + (want && got !== want ? '  (tokens.json säger ' + want + ' — verklig drift, GEN-01/Fas 1)' : ''));
  }
}

// TÄCKNING = kontroll-id vars NEGATIVA prov faktiskt körde och gav ny
// diagnostik. Fas 0.11: uncovered=0 var falskt — fällda och hoppade prov
// räknades som täckning, och positiva prov räknades som negativ täckning.
const provenNegative = new Set();
let pass = 0, fail = 0, skip = 0;
for (const [name, id, build] of [...cases, ...emptySetCases]) {
  const over = build();
  if (!over) { console.error('✖ HOPPAS ÖVER  ' + name + ' — mönstret finns inte i källan, provet mäter alltså ingenting'); skip++; continue; }
  const [file] = Object.keys(over);
  if (over[file] === read(file)) { console.error('✖ ' + name + ' — mutationen ändrade inte källan'); fail++; continue; }
  const after = lint(envWith(over));
  const fresh = after.errors.filter(e => !baseSet.has(e));
  const hit = fresh.filter(e => e.startsWith(id));
  if (hit.length) { console.log('✔ ' + name + ' → ' + id + ' · nya diagnostiker: ' + fresh.length + ' (' + hit.length + ' med rätt id)'); pass++; provenNegative.add(id); }
  else {
    console.error('✖ ' + name + ' → ' + id + ' gav INGEN ny diagnostik (baslinje ' + baseline.errors.length + ' → ' + after.errors.length + ', nya ' + fresh.length + ')');
    fail++;
  }
}
// VARNINGSPROV: T-07 och T-11 är beslutade varningskontroller. Ett prov mot dem
// ska kräva en ny VARNING, inte ett nytt fel — den gamla listan väntade fel och
// föll därför alltid. Fas 0.11.
const warningCases = [
  ['T-07 · föråldrad versionsreferens i en SKÄRMFIL (varning)', 'T-07', () => {
    // T-07 läser skärmfilerna (docTexts) och söker "manual v1–v5", "0.620–0.624"
    // och "Skarmar v10/v11". Fas 0.12: det gamla provet skrev i indexet, som
    // kontrollen inte läser, och kunde därför aldrig fälla.
    const f = SCREEN_FILES[0];
    const t = read(f);
    if (!t) return null;
    return { [f]: t.replace('</helmet>', '</helmet>\n<!-- ritad mot manual v3 med typsnitt 0.622 -->') };
  }],
  ['T-11 · handskriven kontrolltotal i prosan (varning)', 'T-11', () => {
    const p = '00-spec-index.md';
    const t = read(p);
    if (!t) return null;
    return { [p]: t + '\n\nSpecen innehåller 4711 märkta kontroller i 999 ramar.\n' };
  }]
];
const baseWarn = new Set(baseline.warnings);
for (const [name, id, build] of warningCases) {
  const over = build();
  if (!over) { console.error('✖ HOPPAS ÖVER  ' + name + ' — fixturen kunde inte byggas'); skip++; continue; }
  const [file] = Object.keys(over);
  if (over[file] === read(file)) { console.error('✖ ' + name + ' — mutationen ändrade inte källan'); fail++; continue; }
  const after = lint(envWith(over));
  const freshW = after.warnings.filter(w => !baseWarn.has(w)).filter(w => w.startsWith(id));
  const freshE = after.errors.filter(e => !baseSet.has(e)).filter(e => e.startsWith(id));
  if (freshW.length) { console.log('✔ ' + name + ' → ' + id + ' · nya varningar: ' + freshW.length); pass++; provenNegative.add(id); }
  else if (freshE.length) { console.error('✖ ' + name + ' → ' + id + ' gav FEL, inte varning — kontrollens beslutade allvarlighetsgrad är varning'); fail++; }
  else { console.error('✖ ' + name + ' → ' + id + ' gav ingen ny varning'); fail++; }
}

// Positiva prov: INGEN ny diagnostik får uppstå.
for (const [name, id, build] of positives) {
  const over = build();
  if (!over) { console.error('✖ HOPPAS ÖVER  ' + name + ' — fixturen kunde inte byggas'); skip++; continue; }
  const [file] = Object.keys(over);
  if (over[file] === read(file)) { console.error('✖ ' + name + ' — mutationen ändrade inte källan'); fail++; continue; }
  const after = lint(envWith(over));
  const fresh = after.errors.filter(e => !baseSet.has(e)).filter(e => e.startsWith(id));
  if (!fresh.length) { console.log('✔ ' + name + ' → inga nya ' + id + '-fel, giltigt bevis accepteras'); pass++; }
  else { console.error('✖ ' + name + ' → giltigt bevis gav ' + fresh.length + ' nya ' + id + '-fel: ' + fresh[0]); fail++; }
}

console.log('\nSELFTEST-SUMMARY pass=' + pass + ' fail=' + (fail + fixtureFail) + ' skipped=' + skip + ' fixture_fail=' + fixtureFail + ' baseline_errors=' + baseline.errors.length);
if (skip) console.error('✖ ' + skip + ' prov kunde inte byggas — ett prov som inte kan byggas är ett prov som inte finns');
// ── Täckningsmatris: varje runtimekontroll måste ha minst ett negativt prov ──
// Regeln "en kontroll som inte kan fällas mäter ingenting" gäller alla, inte
// bara de åtta som råkade ha prov. Undantag kräver uttryckligt skäl. Fas 0.9.
const COVERED = provenNegative;   // endast bevisat fällande prov
// UNDANTAG med skäl som håller: varje rad säger vilken ANNAN mätning som prövar
// samma kodväg, eller varför kontrollen inte kan muteras här. Fas 0.10 —
// tidigare undantogs T-04, T-06a/b och T-09 med skäl som inte prövade samma
// logik, och T-13 (renderad, statisk) stod i runtime-listan medan T-19 saknades.
const EXEMPT = {
  'T-03': 'råfärgslint rapporterar bara varningar; ST-01 kräver fällande diagnostik och kan därför inte pröva den. Varningsräkningen prövas av M-01 (◐ räknas aldrig som fel)',
  'T-04': 'opacitetslint delar kodväg med T-03 (samma stilattributsläsning) och har ingen egen fällande gren utanför den',
  'T-06a': 'kaskadberoende: mutationen skulle döljas av blocked-omklassningen. Kodvägen prövas av metatest M-06 (T-06a blocked, T-06b självständig)',
  'T-06b': 'samma som T-06a — provas av M-06',
  'T-09': 'id-format: samma reguljära uttryck och samma insamling som T-16, vars dubblett-id-prov går genom exakt den koden',
  // Fas 0.12: T-12 och T-18b hade BÅDE fällande prov och undantag, så
  // kategorierna överlappade och summan blev 24 av 22. Undantagen är borta.
};
// Endast kontroller som FAKTISKT körs i lint-core. T-13 är renderad och statisk.
const RUNTIME = ['T-01', 'T-02', 'T-03', 'T-04', 'T-05', 'T-06a', 'T-06b', 'T-07', 'T-08', 'T-09',
  'T-10', 'T-11', 'T-12', 'T-14', 'T-15', 'T-16', 'T-17', 'T-18a', 'T-18b', 'T-19', 'T-20', 'A11Y-01', 'A11Y-02'];
let uncovered = 0;
for (const id of RUNTIME) {
  if (COVERED.has(id)) continue;
  // Ett prov som finns men inte fällde räknas INTE som täckning.
  const declared = [...cases, ...emptySetCases, ...warningCases].some(c => c[1] === id);
  if (EXEMPT[id]) { console.log('· UNDANTAG ' + id + ' — ' + EXEMPT[id]); continue; }
  console.error('✖ TÄCKNING ' + id + (declared
    ? ' har ett negativt prov som INTE fällde — täckningen är därmed obevisad'
    : ' har inget negativt mutationsprov och inget motiverat undantag'));
  uncovered++;
}
// DISJUNKTA kategorier: proven + exempt + uncovered === runtime.
const provenIds = [...COVERED].filter(i => RUNTIME.includes(i));
const exemptIds = Object.keys(EXEMPT).filter(i => RUNTIME.includes(i) && !COVERED.has(i));
console.log('SELFTEST-COVERAGE runtime=' + RUNTIME.length +
  ' proven_negative=' + provenIds.length +
  ' exempt=' + exemptIds.length +
  ' uncovered=' + uncovered +
  ' sum=' + (provenIds.length + exemptIds.length + uncovered));
if (provenIds.length + exemptIds.length + uncovered !== RUNTIME.length) {
  console.error('✖ TÄCKNING kategorierna överlappar: ' + provenIds.length + ' + ' + exemptIds.length + ' + ' + uncovered + ' ≠ ' + RUNTIME.length);
  uncovered++;
}

process.exit(fail || skip || fixtureFail || uncovered ? 1 : 0);
