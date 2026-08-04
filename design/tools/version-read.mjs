// Butlery · GEMENSAM versionsläsare för JSON, Markdown och HTML.
//
// F1-H05: T-15 bar hela strategitabellen och alla läsare inne i sin egen
// funktion, medan T-20 hade en fjärdedels egen variant som bara kunde läsa
// `"version"` ur JSON. Följden: en `active` källa i Markdown eller HTML kunde
// deklarera vilken version som helst i källauktoriteten utan att någon kontroll
// jämförde den med filens egen. `content-style-guide.md` kunde stå som 9.9.
//
// Nu finns EN tabell och EN uppsättning läsare. T-15 och T-20 anropar samma
// funktion, så en strategi som ger fel värde ger fel i båda kontrollerna
// samtidigt — de kan inte glida isär.
//
// Kontraktet: readVersion() returnerar ALLTID { value, strategy, problem }.
//   value    · den version som faktiskt kunde läsas ur filen, eller null
//   problem  · varför den inte kunde läsas — en saknad eller tvetydig
//              versionsuppgift är ett fel, inte ett tyst null

// Filer med en annan versionsbärare än ett `version`-fält. Allt som inte står
// här får en strategi ur filändelsen. Tabellen är avsiktligt explicit: en fil
// som byter versionsbärare ska synas som en ändring här.
export const VERSION_STRATEGY = {
  'Butlery Komponentark v1.dc.html': 'filename',
  'Butlery Grafisk manual v6.dc.html': 'filename',
  'Butlery Skarmar v12.dc.html': 'filename',
  'Butlery tillganglighetshandoff.dc.html': 'manual-linked',
  'Butlery ceremonier rorelsereferens.dc.html': 'manual-linked',
  'Butlery styrdokument modulart designsystem.dc.html': 'doc-header',
  'Butlery Fas 0 leverans.dc.html': 'doc-header',
  'Butlery Fas 1 leverans.dc.html': 'doc-header',
  'FONT-VERSION.txt': 'active-release',
  'assets/fonts/VALIDATION-0.626.txt': 'filename',
  'assets/generated/tokens.css': 'generated-header',
  'lib/theme/butlery_tokens.dart': 'generated-header',
  'lib/theme/app_colors.dart': 'generated-header',
  'lib/theme/app_text_styles.dart': 'generated-header',
  'butlery-tokens.schema.json': 'schema-id',
  'fas0/verify-report.schema.json': 'schema-id',
  'tools/app-theme-map.schema.json': 'schema-id',
  'source-authority.schema.json': 'schema-id',
  'legacy-api-contract.schema.json': 'schema-id',
  'assets/brand-colors.schema.json': 'schema-id',
  'source-authority.json': 'field',
  'legacy-api-contract.json': 'field',
  'tools/app-theme-map.json': 'field',
  'assets/brand-colors.json': 'field',
  'grundgranskning.md': 'dated',
  'arbetsplan.md': 'frozen',
  'luckor-etapp9.md': 'frozen',
  'migration-gap.md': 'dated',
  'korsgranskning.md': 'field',
  // Kodfiler bär ingen egen version. De namnges hellre än att falla tillbaka på
  // 'field', som skulle plocka valfritt "version"-ord ur en kommentar.
  'tools/controls.mjs': 'none'
};

const EXT_STRATEGY = [
  [/\.schema\.json$/i, 'schema-id'],
  [/\.json$/i, 'field'],
  [/\.md$/i, 'field'],
  [/\.dc\.html$/i, 'doc-header'],
  [/\.html?$/i, 'doc-header'],
  [/\.txt$/i, 'field'],
  [/\.(mjs|js|jsx|dart|css)$/i, 'none']
];

export function strategyFor(file) {
  if (Object.prototype.hasOwnProperty.call(VERSION_STRATEGY, file)) return VERSION_STRATEGY[file];
  for (const [re, s] of EXT_STRATEGY) if (re.test(file)) return s;
  return 'field';
}

// En deklarerad version kan vara skriven som "v12", "V6", "1.13" eller
// "mot manual V6". Jämförelsen sker på det versionsliknande token som står
// SIST i strängen — så "mot manual V6" och "V6" är samma version, medan
// "1.13" och "1.14" aldrig blir det.
export function normalizeVersion(v) {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  const m = [...s.matchAll(/v?(\d+(?:\.\d+)*)/gi)];
  if (!m.length) return null;
  return m[m.length - 1][1].replace(/(\.0)+$/, '') || m[m.length - 1][1];
}

export function sameVersion(a, b) {
  const na = normalizeVersion(a), nb = normalizeVersion(b);
  return na !== null && nb !== null && na === nb;
}

// Läs den version som FAKTISKT står i filen.
// text får vara null när strategin inte behöver filinnehållet (filename).
export function readVersion(file, text, strategyOverride) {
  const strategy = strategyOverride || strategyFor(file);
  const t = text === null || text === undefined ? '' : String(text);
  const out = v => ({ value: v || null, strategy, problem: null });
  const bad = p => ({ value: null, strategy, problem: p });

  switch (strategy) {
    case 'none':
      return { value: null, strategy, problem: null, versionless: true };

    case 'filename': {
      const v = (file.match(/[ -]([Vv]?\d+(?:\.\d+)+)(?=\.[a-z]|$)/) || file.match(/[ -]([Vv]\d+)(?=\.|$)/) || [])[1];
      return v ? out(v) : bad('filnamnet bär ingen version');
    }

    case 'manual-linked': {
      const v = (t.match(/manual\s*\*{0,2}\s*([Vv]\d+)/i) || [])[1];
      return v ? out(v) : bad('dokumentet nämner ingen "manual V<n>"-rad');
    }

    case 'active-release': {
      const v = (t.match(/(?:active release|aktuell|version)[^\n]*?([\d.]+)/i) || [])[1];
      return v ? out(v) : bad('ingen aktiv release angiven');
    }

    case 'generated-header': {
      const head = t.split('\n').slice(0, 12).join('\n');
      const v = (head.match(/^[^\n]*\btokens\s+v?(\d+\.\d+(?:\.\d+)?)/im) || [])[1] ||
                (head.match(/tokens[- ]?version\s*[:=]\s*v?(\d+\.\d+(?:\.\d+)?)/i) || [])[1];
      return v ? out(v) : bad('headern saknar en läsbar rad "tokens <version>" bland de första 12 raderna');
    }

    case 'schema-id': {
      let j = null;
      try { j = JSON.parse(t); } catch (e) { return bad('schemafilen går inte att tolka: ' + e.message); }
      let v = (String(j.$id || '').match(/\/(\d+(?:\.\d+)*)$/) || [])[1] || null;
      if (!v && j.version) v = String(j.version);
      if (v && /^\d+$/.test(v) && j.version) v = String(j.version);
      return v ? out(v) : bad('schemafilen saknar version i $id och i version-fältet');
    }

    case 'field': {
      const j = t.match(/"version"\s*:\s*"([^"]+)"/);
      if (j) return out(j[1]);
      const md = t.match(/[Vv]ersion\s*\*{0,2}\s*:?\s*\*{0,2}\s*([Vv]?\d+(?:\.\d+)+)/);
      if (md) return out(md[1]);
      return bad('filen bär inget "version"-fält och ingen "Version N.N"-rad');
    }

    // HTML-dokument bär sin version i dokumenthuvudet: "· styrdokument · 2.5"
    // eller "Butlery · Fas 1 · korrigerad / 2026-08-02 · styrdokument 2.1".
    // Läses ANKRAT till de första 60 raderna, så en versionsliknande sträng
    // längre ned i brödtexten aldrig kan plockas upp.
    case 'doc-header': {
      const head = t.split('\n').slice(0, 60).join('\n');
      const title = (head.match(/<title>([^<]*)<\/title>/i) || [])[1] || '';
      const badge = (head.match(/class="[^"]*\b(?:ver|version|badge)\b[^"]*"[^>]*>\s*([Vv]?\d+(?:\.\d+)+)/i) || [])[1];
      const fromTitle = (title.match(/·\s*([Vv]?\d+(?:\.\d+)+)\s*$/) || title.match(/\b([Vv]?\d+\.\d+)\b/) || [])[1];
      const fromHead = (head.match(/styrdokument\s*·?\s*([Vv]?\d+\.\d+)/i) || [])[1];
      const v = badge || fromTitle || fromHead;
      return v ? out(v) : bad('dokumenthuvudet bär ingen läsbar version bland de första 60 raderna');
    }

    // Historiska underlag daterar sig i stället för att versionera.
    case 'dated': {
      const v = (t.match(/\*{0,2}Datum:?\*{0,2}\s*:?\s*(20\d\d-\d\d-\d\d)/i) || [])[1]
        || (t.match(/(?:läst|granskad|skriven)\s+(20\d\d-\d\d-\d\d)/i) || [])[1]
        || (t.match(/(20\d\d-\d\d-\d\d)/) || [])[1];
      return v ? { value: v, strategy, problem: null, dated: true } : bad('filen bär inget datum');
    }

    case 'frozen': {
      if (!/FRYST\s+(\d{4}-\d{2}-\d{2})/.test(t)) return bad('fryst underlag utan "FRYST <datum>"-markör');
      const v = (t.match(/"version"\s*:\s*"([^"]+)"/) || [])[1]
        || (t.match(/[Vv]ersion\s*\*{0,2}\s*([Vv]?\d+(?:\.\d+)+)/) || [])[1];
      return v ? out(v) : bad('fryst underlag utan versionsfält — skriv "Version N.N" i dokumenthuvudet');
    }

    default:
      return bad('okänd versionsstrategi "' + strategy + '"');
  }
}
