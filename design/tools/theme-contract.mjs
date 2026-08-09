// F2-R04 · KONTRAKT FOR TEMADIMENSIONEN.
//
// Rena funktioner. Ingen DOM, ingen browser, ingen luminans.
//
// R-04 stallar tva SKILDA fragor som aldrig blandas ihop:
//
//   A  COVERAGE      finns en verifierbar mork representation av det ljusa
//                    tillstand som ska ha mork lage?
//   B  CONFORMANCE   nar en mork representation finns — haller text, grafik,
//                    layout, traffytor och tillstandssprak i det temat?
//
// Ett SAKNAT morkt tillstand ar inte ett kontrastfel. Det ar en lucka i
// tackningen och redovisas som sadan.
//
// IDENTITETEN AR AUTHORED. Tva ritningar far paras bara nar de deklarerar
// samma tema-familj och olika tema. Otillatna parningsgrunder, alla for att
// de parar ihop saker som RAKAR likna varandra:
//   rubriktext · luminans · filnamn som enda evidens · DOM-position ·
//   geometri · "mest lika artefakt"
//
// Namn som slutar pa "morkt" far anvandas som SOKSIGNAL nar migrationen
// planeras, men aldrig som slutlig normativ identitet.

export const TEMAN = new Set(['light', 'dark', 'neutral']);
export const FAMILJNYCKEL = /^[a-z][a-z0-9]*(-[a-z0-9]+){1,}$/;
export const MAXLANGD = 64;

export function parseTema(varde) {
  if (varde === null || varde === undefined)
    return { form: 'saknas', tema: null, varfor: 'ingen data-theme pa artefakten' };
  const s = String(varde).trim();
  if (!TEMAN.has(s))
    return { form: 'ogiltig', tema: null,
      varfor: 'data-theme "' + s + '" ar inte light, dark eller neutral' };
  return { form: 'giltig', tema: s, varfor: 'authored data-theme' };
}

export function parseFamilj(varde) {
  if (varde === null || varde === undefined)
    return { form: 'saknas', id: null, varfor: 'ingen data-theme-family pa artefakten' };
  const s = String(varde);
  if (!s.trim()) return { form: 'ogiltig', id: null, varfor: 'data-theme-family ar tom' };
  if (s.length > MAXLANGD) return { form: 'ogiltig', id: null,
    varfor: 'data-theme-family ar langre an ' + MAXLANGD + ' tecken' };
  if (!FAMILJNYCKEL.test(s)) return { form: 'ogiltig', id: null,
    varfor: 'data-theme-family "' + s + '" foljer inte formen gemener och bindestreck med minst tva led' };
  return { form: 'giltig', id: s, varfor: 'authored data-theme-family' };
}

// En familj ar samma skarm + samma tillstand + samma variant. Bara temat
// skiljer. Tva artefakter i samma familj MED SAMMA tema ar en tvetydighet,
// inte ett par: da gar det inte att saga vilken som representerar temat.
export function parbilda(artefakter) {
  const okanda = [], neutrala = [], familjer = new Map();
  for (const a of artefakter) {
    const t = parseTema(a.tema), f = parseFamilj(a.familj);
    if (t.form !== 'giltig') { okanda.push({ ...a, varfor: t.varfor }); continue; }
    if (t.tema === 'neutral') {
      // Neutral kraver ingen familj: artefakten har inget temaberoende alls.
      neutrala.push({ ...a, varfor: 'deklarerad theme-neutral' }); continue; }
    if (f.form !== 'giltig') { okanda.push({ ...a, varfor: f.varfor }); continue; }
    if (!familjer.has(f.id)) familjer.set(f.id, []);
    familjer.get(f.id).push({ ...a, tema: t.tema, familj: f.id });
  }

  const par = [], enbartLight = [], enbartDark = [], tvetydiga = [];
  for (const [id, v] of familjer) {
    const per = new Map();
    for (const a of v) { if (!per.has(a.tema)) per.set(a.tema, []); per.get(a.tema).push(a); }
    const dubbletter = [...per.entries()].filter(([, lista]) => lista.length > 1);
    if (dubbletter.length) {
      tvetydiga.push({ familj: id,
        varfor: dubbletter.map(([t, lista]) => lista.length + ' artefakter deklarerar ' + t).join(', ') +
          ' — vilken som representerar temat gar inte att avgora',
        artefakter: v.map(a => a.art) });
      continue; }
    const light = per.get('light') ? per.get('light')[0] : null;
    const dark = per.get('dark') ? per.get('dark')[0] : null;
    if (light && dark) par.push({ familj: id, light: light.art, dark: dark.art });
    else if (light) enbartLight.push({ familj: id, art: light.art,
      varfor: 'ingen mork representation finns i sviten — coveragelucka, inte ett kontrastfel' });
    else if (dark) enbartDark.push({ familj: id, art: dark.art,
      varfor: 'ingen ljus representation finns i sviten' });
  }

  return {
    artefakter_st: artefakter.length,
    deklarerade_st: artefakter.length - okanda.length,
    unknown_st: okanda.length,
    neutral_st: neutrala.length,
    familjer_st: familjer.size,
    par_st: par.length,
    enbartLight_st: enbartLight.length,
    enbartDark_st: enbartDark.length,
    tvetydiga_st: tvetydiga.length,
    par, enbartLight, enbartDark, tvetydiga, unknown: okanda, neutrala,
    // Varje artefakt hamnar i exakt en hink.
    invariant_ok: artefakter.length === okanda.length + neutrala.length +
      [...familjer.values()].reduce((n, v) => n + v.length, 0),
  };
}
