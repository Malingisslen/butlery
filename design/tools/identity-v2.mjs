// F2-ID02 · IDENTITY-V2 — ett PARALLELLT identitetslager.
//
// Detta lager ersätter INGENTING. elementKey, findingId och instansId är
// oförändrade och styr fortfarande hela R-03-rapporten. identity-v2 lägger sig
// bredvid och gör tvetydigheten EXPLICIT i stället för tyst hopslagen.
//
// FYRA TILLSTÅND:
//   stable      identiteten kan bäras kanoniskt. identityKey är satt.
//   candidate   en diskriminator finns men är inte beslutad som identitetsbärande.
//               identityKey är null.
//   ambiguous   noderna går inte att särskilja stabilt. identityKey är null.
//   error       mätningen räcker inte för att avgöra. identityKey är null.
//
// identityKey sätts BARA vid stable. Ett null får aldrig strängifieras in i en
// nyckel: "null" som identitet vore värre än ingen identitet alls.

export const IDENTITY_STATUS = ['stable', 'candidate', 'ambiguous', 'error'];
export const IDENTITY_BASIS = ['explicit-element-id', 'explicit-control-id', 'data-icon',
  'role-and-name', 'unique-selector', 'semantic-candidate', 'none'];

/**
 * IDENTITETSKONTEXTEN. Unikhet prövas alltid inom den, aldrig globalt.
 * Stabil förfader ingår: samma data-icon i två skilda behållare är två
 * identiteter, inte en.
 */
export const identityContext = n =>
  [n.artefakt, n.viewport, n.theme, n.textScale, n.stabilForfader || '(ingen stabil förfader)'].join(' · ');

const attr = (n, k) => (n.dataAttr || {})[k] || null;

/**
 * Bedöm en grupp noder som DELAR legacy-elementKey inom samma kontext.
 *
 * En grupp om ett element är trivialt stabil: den normaliserade selektorn är
 * redan unik. Grupper om flera prövas mot prioritetsordningen, och varje steg
 * kräver att diskriminatorn är UNIK inom gruppen — ett återanvänt data-icon på
 * två syskon gör dem inte till samma identitet, det gör dem otydbara.
 */
export function bedomGrupp(legacyElementKey, noder, ctx) {
  const bas = { legacyElementKey, kontext: ctx };
  const ofullstandig = noder.some(n => !n.path);
  if (ofullstandig)
    return noder.map(n => ({ ...bas, nod: n, identityStatus: 'error', identityBasis: 'none',
      identityKey: null,
      identityDiagnostics: { skäl: 'mätningen saknar nodidentitet — går inte att avgöra' } }));

  const diag = n => ({
    runtimeDomPath: n.path, rect: n.rect || null,
    narmasteStabilaForfader: n.stabilForfader || null,
    tag: n.tag, roll: n.roll || null, namn: n.namn || null,
    dataAttr: n.dataAttr || {}, domBeskrivning: n.domBeskrivning || null,
    $not: 'runtimeDomPath är DIAGNOSTIK för mänsklig lokalisering, aldrig kanonisk identitet.'
  });

  if (noder.length === 1) {
    const n = noder[0];
    const explicit = attr(n, 'data-element-id') || attr(n, 'data-control-id');
    const basis = attr(n, 'data-element-id') ? 'explicit-element-id'
      : attr(n, 'data-control-id') ? 'explicit-control-id' : 'unique-selector';
    return [{ ...bas, nod: n, identityStatus: 'stable', identityBasis: basis,
      identityKey: ctx + ' ‖ ' + (explicit ? 'id:' + explicit : legacyElementKey),
      identityDiagnostics: diag(n) }];
  }

  // Flera noder under samma legacy-nyckel. Sök en diskriminator som är unik
  // för SAMTLIGA noder i gruppen — inte bara för några av dem.
  const unik = f => {
    const v = noder.map(f);
    return v.every(x => x !== null && x !== undefined && x !== '') && new Set(v).size === noder.length;
  };

  const stege = [
    { basis: 'explicit-element-id', f: n => attr(n, 'data-element-id') },
    { basis: 'explicit-control-id', f: n => attr(n, 'data-control-id') },
    { basis: 'data-icon',           f: n => attr(n, 'data-icon') },
    { basis: 'role-and-name',       f: n => (n.roll && n.namn) ? n.roll + '|' + n.namn : null }
  ];
  for (const steg of stege)
    if (unik(steg.f))
      return noder.map(n => ({ ...bas, nod: n, identityStatus: 'stable', identityBasis: steg.basis,
        identityKey: ctx + ' ‖ ' + legacyElementKey + ' ‖ ' + steg.basis + '=' + steg.f(n),
        identityDiagnostics: diag(n) }));

  // TEXT ÄR INTE AUTOMATISKT IDENTITET. Den ändras av lokalisering, redaktionella
  // ändringar, dynamiskt innehåll och formattering. En textbaserad särskiljning
  // är en KANDIDAT tills ett uttryckligt kontrakt säger att just den texten bär
  // identitet — och identityKey förblir null till dess.
  const textDisk = n => (n.domBeskrivning || '').replace(/^.*\[/, '').replace(/\]$/, '').trim() || null;
  if (unik(textDisk))
    return noder.map(n => ({ ...bas, nod: n, identityStatus: 'candidate', identityBasis: 'semantic-candidate',
      identityKey: null,
      identityDiagnostics: { ...diag(n), kandidat: textDisk(n),
        skäl: 'texten särskiljer noderna, men text är inte beslutad som identitetsbärande. ' +
              'Lokalisering, redaktion, dynamiskt innehåll och formattering kan ändra den.' } }));

  const sammaIkon = noder.map(n => attr(n, 'data-icon')).filter(Boolean);
  return noder.map(n => ({ ...bas, nod: n, identityStatus: 'ambiguous', identityBasis: 'none',
    identityKey: null,
    identityDiagnostics: { ...diag(n),
      skäl: sammaIkon.length === noder.length && new Set(sammaIkon).size < noder.length
        ? 'samtliga noder bär samma data-icon (' + sammaIkon[0] + ') — attributet särskiljer dem inte'
        : 'ingen stabil diskriminator: varken explicit id, data-attribut, roll och namn eller unik selektor',
      gruppstorlek: noder.length } }));
}

/**
 * FAIL-CLOSED. Ett verifierat fynd som landar i en tvetydig grupp får aldrig
 * slås ihop, aldrig välja första noden, aldrig få ett nth-child och aldrig ett
 * påhittat hash. Det blir blockerat, och grinden faller.
 */
export function felClosedUtfall({ verified_ambiguous_st, error_st }) {
  if (error_st > 0)
    return { status: 'error', skäl: 'identitetsmätningen är osäker för ' + error_st + ' grupper' };
  if (verified_ambiguous_st > 0)
    return { status: 'blocked',
      skäl: 'identity ambiguous: ' + verified_ambiguous_st + ' verifierade fynd landar i en tvetydig ' +
            'identitetsgrupp. Fyndet får varken slås ihop eller tilldelas ett skört index. ' +
            'Ett explicit data-element-id krävs i produktmarkupen innan de kan bäras kanoniskt.',
      fasgrind: 'faller' };
  return { status: 'ok', skäl: 'inget verifierat fynd landar i en tvetydig identitetsgrupp' };
}

/** identityKey får aldrig strängifieras in i en nyckel. */
export function identityKeyÄrSäker(k) {
  if (k === null) return true;
  return typeof k === 'string' && k.length > 0 &&
    !/(^|[‖·]\s*)(null|undefined|NaN)(\s*[‖·]|$)/.test(k);
}
