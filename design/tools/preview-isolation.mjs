// Butlery · GRINDEN FOR PREVIEW-ISOLERING.
//
// FELKLASSEN MODULEN FINNS FOR
// Att dolja ovriga artefakter i en fil gor helsidesrendringen billig. Men det
// ar en OPTIMERING, inte en garanti. I artefakten flertagg flyttade sig tva
// element nar grannarna doldes. Om en sadan bild fatt passera hade en dom
// kunnat vila pa en scen som inte finns.
//
// Darfor: isolering ar villkorlig och fail-closed PER ARTEFAKT. Den kanoniska
// matningen kors ALLTID utan isolering och beror aldrig av den har grinden.

export const ISOLATION_DIMENSIONS = Object.freeze([
  'geometry', 'paint', 'clipping', 'content_state' ]);

export const EVIDENSBESLUT = Object.freeze({
  KEEP_ISOLATED_EVIDENCE: 'KEEP_ISOLATED_EVIDENCE',
  DISCARD_AND_RERENDER_WITHOUT_ISOLATION: 'DISCARD_AND_RERENDER_WITHOUT_ISOLATION' });

/* Grinden. Saknad matning ar inte samma sak som noll delta: en dimension som
 * inte matts gor artefakten osaker. */
export function isolationSafe(delta) {
  if (!delta || typeof delta !== 'object')
    return { ISOLATION_SAFE: false, skal: 'ingen deltamatning', omatta: ISOLATION_DIMENSIONS };
  const omatta = ISOLATION_DIMENSIONS.filter(d => typeof delta[d] !== 'number');
  if (omatta.length)
    return { ISOLATION_SAFE: false, skal: 'omatta dimensioner', omatta };
  const brutna = ISOLATION_DIMENSIONS.filter(d => delta[d] !== 0);
  if (brutna.length)
    return { ISOLATION_SAFE: false, skal: 'delta i ' + brutna.join(', '), brutna,
      delta: Object.fromEntries(brutna.map(d => [d, delta[d]])) };
  return { ISOLATION_SAFE: true, skal: 'artefaktens egen geometri, malning, klippning och ' +
    'innehall/tillstand ar oforandrade' };
}

export function evidensbeslut(delta) {
  const g = isolationSafe(delta);
  return { ...g, BESLUT: g.ISOLATION_SAFE ? EVIDENSBESLUT.KEEP_ISOLATED_EVIDENCE
    : EVIDENSBESLUT.DISCARD_AND_RERENDER_WITHOUT_ISOLATION,
    $vidUnderkant: 'Samtliga isolerade evidensbilder for artefakten kasseras och renderas om ' +
      'utan isolering. Ingen dom far vila pa den underkanda bilden.' };
}

/* Isolerad och icke-isolerad evidens far aldrig blandas for SAMMA occurrence:
 * en jamforelse mellan tva scener som inte ar samma scen bevisar ingenting. */
export function farBlandas(bildA, bildB) {
  if (!bildA || !bildB) return { tillatet: false, skal: 'bild saknas' };
  if (!!bildA.ISOLERING_ANVAND !== !!bildB.ISOLERING_ANVAND)
    return { tillatet: false, skal: 'en bild ar isolerad och den andra inte — de visar inte ' +
      'samma scen och far inte jamforas' };
  return { tillatet: true, skal: 'bada bilderna kommer ur samma renderingslage' };
}

/* Den kanoniska matningen ar aldrig isolerad. */
export function matningAnvanderIsolering() { return false; }
