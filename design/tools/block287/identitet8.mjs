// Block 287 omgang 8 — persistent agaridentitet for agare som Block 287 sjalv myntar.
//
//   OWNER::<ram>::handling::<handling>   dokumenterad navigeringshandling (bakat, foregaende steg ...)
//   OWNER::<ram>::grupp::<namn>          gruppbehallare (radiogrupp) med stabilt gruppnamn
//   OWNER::<ram>::namn::<namn>           stabilt tillgangligt namn, flyktiga tal bortstrukna
//   OWNER::<kallankare>                  kallforfattat ankare ur upptackten (occ, bind, id, hit-target,
//                                        text, glyf, komponent) — ororat
//
// Id:t laser ALDRIG klass, verdikt, status, roll, position, ordinal, syskon, geometri, farg eller
// filordning. <ram> ar ramens kallforfattade id (sc-item). Tva agare som inte gar att sarskilja
// far inget id (fail closed). Enda undantaget for tal: alternativ i en grupp dar talet ar
// alternativets varde (betyg 1–5, aldersintervall) — bevisat av att namnen annars kolliderar.
const fold = s => String(s == null ? '' : s).normalize('NFD').replace(/[̀-ͯ]/g, '');
export const slug = s => fold(s).toLowerCase().replace(/&amp;/g, '&').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 48);
export const stabilNamn = s => slug(String(s == null ? '' : s).replace(/\d+(?:[.,:]\d+)*/g, ' '));

// Dokumenterade navigeringshandlingar (korpuskonvention: 123 deklarerade bakatknappar, bara glyf).
export const HANDLINGAR = { 'Tillbaka': 'back', 'Föregående steg': 'previous-step',
  'Tillbaka till konversationer': 'back-to-conversations', 'Nästa steg': 'next-step',
  // omgang 9: bildredigering (beslut HD_SKRIVSJALV_REMOVE_IMAGE) och portionsvaljaren (handoff
  // "Portionsvaljare": − och + ar egna knappar "Färre/Fler portioner"; laga deklarerar "Minska/Öka").
  'Ta bort bilden': 'remove-image',
  'Färre portioner': 'decrement-portioner', 'Minska portioner': 'decrement-portioner',
  'Fler portioner': 'increment-portioner', 'Öka portioner': 'increment-portioner' };

/** Stabil etikett for en kontroll vars tillgangliga namn bar sitt valda varde ("Enhet, deciliter",
 *  "Status: ny. Ändra status", "Födelseår 1988"): etiketten fore forsta komma/kolon, tal bort. */
export const stabilEtikett = (namn, harVarde) => { const n = String(namn == null ? '' : namn); return harVarde ? n.split(/[,:]/)[0].trim() : n; };

/** Nyckel ur semantiska fakta. Returnerar null om ingen stabil grund finns. */
export function agarNyckel(f) {
  if (f.kallAnkare) return 'OWNER::' + f.kallAnkare;
  if (!f.art) return null;
  const handling = f.handling || HANDLINGAR[f.namn];
  if (handling) return 'OWNER::' + f.art + '::handling::' + handling;
  const n = stabilNamn(f.namn);
  if (!n) return null;
  return 'OWNER::' + f.art + '::' + (f.grupp ? 'grupp' : 'namn') + '::' + n;
}

/**
 * Tilldelar id till en mangd fakta. Kollision → inget id for nagon (OWNER_IDENTITY_UNRESOLVED),
 * utom nar alla kolliderande ar alternativ i samma grupp och skiljer sig bara pa sitt varde.
 */
export function tilldela(fakta) {
  const bas = fakta.map(f => ({ f, id: agarNyckel(f) }));
  const antal = new Map();
  for (const { id } of bas) if (id) antal.set(id, (antal.get(id) || 0) + 1);
  return bas.map(({ f, id }) => {
    if (!id) return { f, id: null, status: 'OWNER_IDENTITY_UNRESOLVED', skal: 'ingen stabil semantisk grund' };
    if (antal.get(id) === 1) return { f, id, status: 'RESOLVED' };
    const krock = bas.filter(b => b.id === id);
    const allaAlternativ = krock.every(b => b.f.alternativ && b.f.alternativ === f.alternativ);
    const fulla = new Set(krock.map(b => slug(b.f.namn)));
    if (allaAlternativ && fulla.size === krock.length)
      return { f, id: 'OWNER::' + f.art + '::namn::' + slug(f.namn), status: 'RESOLVED', undantag: 'OPTION_VALUE' };
    return { f, id: null, status: 'OWNER_IDENTITY_UNRESOLVED', skal: krock.length + ' agare delar ' + id + ' — kan inte sarskiljas' };
  });
}

/** Normaliserar ett innehallssegment i ett enhets-id (namn ur kallan): tal bort, utom bevisade varden. */
export function stabilSegment(namnSlug, tillatTal) { return tillatTal ? namnSlug : stabilNamn(String(namnSlug).replace(/-/g, ' ')); }
