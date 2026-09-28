// F2-R06 · Parningslogiken för temadimensionen, som en ren funktion.
//
// theme-pairing.mjs ANVÄNDER den mot verkliga mätningar, och render-negatives.mjs
// matar den med konstruerade fall som måste hamna i rätt fack: saknad motpart,
// dubblett och flertydighet.

/** Bassplatsen. variantId ingår ALDRIG — den skulle dölja konkurrerande varianter. */
export const nyckel = p => [p.viewportClass, p.buildTarget, p.layoutläge,
  JSON.stringify(Object.fromEntries(
    Object.entries(p.selectors || {}).filter(([k]) => k !== 'theme')))].join('§');

/**
 * @param poster artefakter med fälten: id, viewportClass, buildTarget, layoutläge,
 *               selectors, fRoller, rollantal, fSkelett, luminansklass, luminans
 * @returns { entydiga, utanMotpart, flertydiga, ljusaUtanKandidat }
 */
export function parning(poster) {
  const mörka = poster.filter(p => p.luminansklass === 'mörk');
  const ljusa = poster.filter(p => p.luminansklass === 'ljus');

  // En artefakt UTAN kontroller har ett tomt rollfingeravtryck. Det matchar varje
  // annan kontrollfri artefakt och är därför inte särskiljande. För dem krävs
  // alltid skelettmatchning; annars rapporteras falsk flertydighet i stället för
  // att det inte finns någon motpart alls.
  const kandidater = (m, strikt) => {
    if (m.rollantal === 0) strikt = true;
    return ljusa.filter(l =>
      nyckel(l) === nyckel(m) &&
      (strikt ? l.fSkelett === m.fSkelett : true) &&
      l.fRoller === m.fRoller && l.rollantal === m.rollantal);
  };

  const entydiga = [], utanMotpart = [], flertydiga = [];
  for (const m of mörka) {
    let c = kandidater(m, true);
    let grund = 'roll- och skelettfingeravtryck identiska';
    if (c.length === 0 && m.rollantal > 0) {
      c = kandidater(m, false);
      grund = 'rollfingeravtryck identiskt (' + m.rollantal + ' kontroller), skelettet skiljer';
    }
    const post = { mörk: m.id, källa: m, kandidater: c, grund };
    if (c.length === 1) entydiga.push(post);
    else if (c.length === 0) utanMotpart.push(post);
    else flertydiga.push(post);
  }

  const parade = new Set(entydiga.map(p => p.kandidater[0].id));
  const ljusaUtanKandidat = ljusa.filter(l => !parade.has(l.id));
  return { entydiga, utanMotpart, flertydiga, ljusaUtanKandidat };
}
