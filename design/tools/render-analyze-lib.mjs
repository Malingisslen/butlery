// F2-R06 · Domsluten i R-03-analysen, som rena funktioner.
//
// render-analyze.mjs ANVÄNDER dem, och render-negatives.mjs matar dem med fel
// som måste fällas. Ett prov mot en kopia av logiken bevisar ingenting om den
// logik som faktiskt kör.
//
// FYRA SKILDA FYNDNIVÅER. De summeras aldrig ihop och byter aldrig namn:
//
//   1  RÅ DETEKTION        en metodträff på ett element i ett körfall
//   2  ELEMENTFYND         ett element, ett fel, oavsett hur många metoder som
//                          såg det och i hur många körfall
//   3  FELINSTANS          ett användarsynligt fel i en ritning. Flera element
//                          kan beskriva samma synliga fel — en klippande box och
//                          det barn som sticker ut ur den är ETT synligt fel.
//   4  KÄLLROTORSAK        en gemensam källa bakom felinstanser i flera ritningar

export const METODER = ['r03a', 'r03b', 'r03c', 'r03d'];
export const KLASSER = ['verifierad', 'avsiktlig', 'observation', 'verktygsfel'];

/* ── Nivå 2 · findingId ──────────────────────────────────────────────────── */

/**
 * HÄRDAD KANONISK IDENTITET.
 *
 * DOM-sökvägen ensam dög inte: ett orelaterat inskjutet syskon flyttar varje
 * index efter sig och hade bytt identitet på ett fynd som inte ändrats.
 * Nyckeln härleds därför ur elementets egen stabila identitet (explicit id,
 * annars roll och namn, annars normaliserad selektor, och DOM-sökvägen bara
 * som dokumenterad reserv) och ur felets art.
 *
 * MÄTMETODEN INGÅR INTE. r03a…r03d är evidens, inte identitet — annars får
 * samma fel fyra id:n.
 */
export function findingId(d, ctx) {
  return [
    'CHK-R-03',
    d.artefakt,
    d.elementKey || ('path:' + (d.path === '' ? 'rot' : d.path)),
    d.subtype || 'okänd',
    'axis=' + (d.axis || '-'),
    'vp=' + (ctx.viewport || '-'),
    'theme=' + (ctx.theme || 'obeslutad'),
    'ts=' + (ctx.textScale || '1.0')
  ].join(' · ');
}

/** Plocka ut råa detektioner ur en mätt artefakt. */
export function detektionerAv(artefakt, ctx = {}) {
  const c = { viewport: ctx.viewport || 'prov', theme: ctx.theme || 'obeslutad',
              textScale: ctx.textScale || '1.0', fall: ctx.fall || 'prov' };
  const ut = [];
  for (const m of METODER)
    for (const t of (artefakt[m] || [])) {
      const d = { metod: m, klass: t.klass, artefakt: artefakt.id,
        path: t.path, elementKey: t.elementKey, keyBasis: t.keyBasis,
        subtype: t.subtype, detaljsubtyp: t.detaljsubtyp, axis: t.axis, tag: t.tag, cls: t.cls, why: t.why,
        intent: t.intent || null,
        ancestorPath: t.ancestorPath ?? null, ancestorKey: t.ancestorKey ?? null,
        offenderPath: t.offenderPath ?? null, offenderKey: t.offenderKey ?? null,
        ...c };
      d.findingId = findingId(d, c);
      ut.push(d);
    }
  return ut;
}

/** Nivå 1 → nivå 2. Metoderna blir evidens på fyndet, aldrig egna fynd. */
export function elementfynd(detektioner, klass) {
  const byId = new Map();
  for (const d of detektioner.filter(x => x.klass === klass)) {
    let f = byId.get(d.findingId);
    if (!f) {
      f = { findingId: d.findingId, artefakt: d.artefakt, path: d.path,
            elementKey: d.elementKey, keyBasis: d.keyBasis,
            subtype: d.subtype, axis: d.axis, detaljsubtyper: new Set(),
            element: d.tag + (d.cls ? '.' + d.cls.split(/\s+/)[0] : ''),
            evidens: { metoder: new Set(), profiler: new Set(), detektioner_st: 0 },
            ancestorPath: d.ancestorPath, ancestorKey: d.ancestorKey,
            offenderPath: d.offenderPath, offenderKey: d.offenderKey,
            why: d.why };
      byId.set(d.findingId, f);
    }
    if (d.detaljsubtyp) f.detaljsubtyper.add(d.detaljsubtyp);
    f.evidens.metoder.add(d.metod); f.evidens.profiler.add(d.fall); f.evidens.detektioner_st++;
    // Den ömsesidiga referensen kan komma från vilken metod som helst.
    if (d.ancestorPath !== null && f.ancestorPath === null) { f.ancestorPath = d.ancestorPath; f.ancestorKey = d.ancestorKey; }
    if (d.offenderPath !== null && f.offenderPath === null) { f.offenderPath = d.offenderPath; f.offenderKey = d.offenderKey; }
  }
  return [...byId.values()]
    .map(f => ({ ...f, detaljsubtyper: [...f.detaljsubtyper].sort(), evidens: { metoder: [...f.evidens.metoder].sort(),
                                  profiler: [...f.evidens.profiler].sort(),
                                  detektioner_st: f.evidens.detektioner_st } }))
    .sort((a, b) => b.evidens.metoder.length - a.evidens.metoder.length ||
                    a.findingId.localeCompare(b.findingId));
}

/* ── Nivå 3 · felinstanser ───────────────────────────────────────────────── */

/**
 * SMAL, BEVISBUNDEN HOPSLAGNING — inte generell ancestor-collapse.
 *
 * Två elementfynd i samma ritning slås ihop till EN felinstans endast om
 * ALLA fyra villkoren håller:
 *
 *   1  det ena elementet är förfader till det andra (sökvägsprefix),
 *   2  de har ÖMSESIDIG REFERENS — förfaderns fynd pekar ut just det barnet
 *      som den utstickande, eller barnets fynd pekar ut just den förfadern
 *      som den klippande,
 *   3  samma axel, eller att den enas axel ingår i den andras,
 *   4  ingen av dem har olika subtype-familj (deklarerad klippning och
 *      textrunkering är två skilda synliga fel även på samma element).
 *
 * Villkor 2 är det som gör regeln smal. Två OBEROENDE fel på en förälder och
 * ett barn saknar den ömsesidiga referensen och slås därför aldrig ihop.
 */
const axelPassar = (a, b) => a === b || a === 'xy' || b === 'xy';
const ärFörfader = (f, b) => b.path !== f.path && (f.path === '' || b.path.startsWith(f.path + '/'));

// Andra smala regeln: SAMMA element, samma axel, och de två subtyperna
// egen-box-överskott och deklarerad-klippning. De är två beskrivningar av
// EN identisk geometrisk situation — R-03a fäller bara när axeln har
// hidden/clip och innehållet sticker ut, vilket per definition också är
// R-03c:s villkor. Textrunkering ingår aldrig: en klippt box och en trunkerad
// text är två skilda synliga fel även på samma element.
// Regeln för samma element och två metodnamnade subtyper behövs inte längre:
// subtype ÄR felklassen, så r03a och r03c ger redan samma findingId.
const sammaGeometriskaFel = () => false;

export function felinstanser(fynd) {
  const perArtefakt = new Map();
  for (const f of fynd) {
    if (!perArtefakt.has(f.artefakt)) perArtefakt.set(f.artefakt, []);
    perArtefakt.get(f.artefakt).push(f);
  }
  const instanser = [];
  for (const [artefakt, lista] of perArtefakt) {
    const kvar = new Set(lista.map(f => f.findingId));
    const byId = new Map(lista.map(f => [f.findingId, f]));
    for (const f of lista) {
      if (!kvar.has(f.findingId)) continue;
      const grupp = [f];
      const textfamilj = x => x.subtype === 'textrunkering';
      for (const g of lista) {
        if (g === f || !kvar.has(g.findingId)) continue;
        let grund = null;
        if (sammaGeometriskaFel(f, g)) {
          grund = 'samma element och axel, två beskrivningar av en identisk geometrisk situation';
        } else {
          const [ytter, inner] = ärFörfader(f, g) ? [f, g] : (ärFörfader(g, f) ? [g, f] : [null, null]);
          if (!ytter) continue;
          const ömsesidig =
            (ytter.offenderPath !== null && ytter.offenderPath === inner.path) ||
            (inner.ancestorPath !== null && inner.ancestorPath === ytter.path);
          if (!ömsesidig) continue;
          if (!axelPassar(f.axis, g.axis)) continue;
          if (textfamilj(f) !== textfamilj(g)) continue;
          grund = 'ömsesidig referens mellan förfader och barn i samma axel';
        }
        grupp.push(g); kvar.delete(g.findingId); f.__grund = grund;
      }
      kvar.delete(f.findingId);
      const yttersta = grupp.reduce((a, b) => (a.path.length <= b.path.length ? a : b));
      instanser.push({
        instansId: 'INST · ' + artefakt + ' · ' + (yttersta.elementKey || yttersta.path) + ' · ' + yttersta.subtype,
        artefakt, element: yttersta.element, axis: yttersta.axis, subtype: yttersta.subtype,
        elementfynd_st: grupp.length,
        findingIds: grupp.map(x => x.findingId).sort(),
        hopslagen: grupp.length > 1,
        hopslagningsgrund: grupp.length > 1 ? (f.__grund || 'okänd') : null,
        why: yttersta.why
      });
    }
  }
  return instanser.sort((a, b) => a.instansId.localeCompare(b.instansId));
}

/* ── Nivå 4 · källrotorsaker ─────────────────────────────────────────────── */

/**
 * Gruppera FELINSTANSER (inte elementfynd) på en läges-okänslig signatur.
 * Åtta ritningar som återanvänder samma trasiga ikon är EN källrotorsak med
 * åtta felinstanser — förekomsterna finns kvar i gruppen.
 */
export function källrotorsaker(instanser) {
  const g = new Map();
  for (const i of instanser) {
    const sig = i.element + ' | ' + i.subtype + ' | ' + i.why.replace(/[0-9.]+/g, 'N');
    if (!g.has(sig)) g.set(sig, { signatur: sig, element: i.element, subtype: i.subtype,
      felinstanser_st: 0, artefakter: new Set(), instansIds: [] });
    const x = g.get(sig);
    x.felinstanser_st++; x.artefakter.add(i.artefakt); x.instansIds.push(i.instansId);
  }
  return [...g.values()].map(x => ({
    signatur: x.signatur, element: x.element, subtype: x.subtype,
    felinstanser_st: x.felinstanser_st, artefakter_st: x.artefakter.size,
    artefakter: [...x.artefakter].sort(), instansIds: x.instansIds,
    bedömning: x.artefakter.size > 1
      ? 'GEMENSAM KÄLLA — ' + x.felinstanser_st + ' felinstanser i ' + x.artefakter.size + ' ritningar'
      : 'enskild förekomst'
  })).sort((a, b) => b.felinstanser_st - a.felinstanser_st);
}

/* ── Rapportvalidering ───────────────────────────────────────────────────── */

/**
 * Fäller på fyra saker, och måste kunna fälla på alla fyra:
 *  · SUMMA      klassernas delsummor stämmer inte med metodens total
 *  · ENHET      ett artefaktantal överstiger PRODUKTPOPULATIONEN
 *  · NAMN       ett tal saknar enhetssuffix och kan läsas i fel enhet
 *  · NIVÅ       felinstanser är fler än elementfynden de bygger på
 */
export function validera(rapport) {
  const fel = [];
  const per = rapport.raa_detektioner_per_metod || {};
  const pop = rapport.populationer || {};
  const produkt = pop.registrerade_produktartefakter_st;
  const totalt = pop.totalt_exekverade_artefakter_st;
  for (const m of Object.keys(per)) {
    const v = per[m];
    const s = KLASSER.reduce((t, k) => t + (v[k + '_detektioner_st'] || 0), 0);
    if (s !== v.detektioner_st)
      fel.push('SUMMA: ' + m + ' klasser ' + s + ' ≠ detektioner ' + v.detektioner_st);
    for (const k of KLASSER) {
      const n = v[k + '_produktartefakter_st'];
      if (typeof n === 'number' && typeof produkt === 'number' && n > produkt)
        fel.push('ENHET: ' + m + '.' + k + '_produktartefakter_st = ' + n +
                 ' överstiger produktpopulationen ' + produkt);
    }
    for (const [k, val] of Object.entries(v))
      if (typeof val === 'number' && !/_st$/.test(k))
        fel.push('ENHET: ' + m + '.' + k + ' är ett tal utan enhetssuffix');
  }
  if (typeof produkt === 'number' && typeof totalt === 'number' && produkt > totalt)
    fel.push('ENHET: produktpopulationen ' + produkt + ' överstiger totalt exekverade ' + totalt);
  const n = rapport.nivåer;
  if (n && n.felinstanser_st > n.elementfynd_st)
    fel.push('NIVÅ: felinstanser ' + n.felinstanser_st + ' är fler än elementfynden ' + n.elementfynd_st);
  if (n && n.elementfynd_st > n.raa_detektioner_st)
    fel.push('NIVÅ: elementfynd ' + n.elementfynd_st + ' är fler än de råa detektionerna ' + n.raa_detektioner_st);
  return fel;
}
