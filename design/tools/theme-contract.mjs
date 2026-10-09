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

/* ── HYBRIDMODELLEN · tva giltiga former av tackning ───────────────────────
   A  explicitPair      en authored light-artefakt och en authored
                        dark-artefakt med samma data-theme-family
   B  dualThemeRender   en authored temakapabel kalla som EXPLICIT renderats
                        och verifierats i bada temana

   Bada ger samma conformancekontroller. Ingen heuristisk parning.

   Stodet maste vara FORFATTAT. Verifieraren far aldrig sluta sig till att
   morkt lage stods bara for att kallan rakar anvanda tokens.               */

export const STODVARDEN = new Set(['light', 'dark']);

export function parseStod(varde) {
  if (varde === null || varde === undefined)
    return { form: 'saknas', teman: [], varfor: 'ingen data-theme-support' };
  const delar = String(varde).trim().split(/\s+/).filter(Boolean);
  if (!delar.length) return { form: 'ogiltig', teman: [], varfor: 'data-theme-support ar tom' };
  const okanda = delar.filter(d => !STODVARDEN.has(d));
  if (okanda.length) return { form: 'ogiltig', teman: [],
    varfor: 'data-theme-support innehaller ' + okanda.join(', ') + ' som inte ar light eller dark' };
  if (new Set(delar).size !== delar.length) return { form: 'ogiltig', teman: [],
    varfor: 'data-theme-support upprepar ett varde' };
  return { form: 'giltig', teman: delar, varfor: 'authored data-theme-support' };
}

// renderade = de temainstanser som faktiskt kordes och mattes for en kalla.
// Verifieraren far bara rakna det som RENDERATS, aldrig det som deklarerats.
export function tackning(artefakter) {
  const rader = [], perFamilj = new Map();
  for (const a of artefakter) {
    const t = parseTema(a.tema), f = parseFamilj(a.familj), st = parseStod(a.stod);
    const harInstans = t.form === 'giltig';
    const harStod = st.form === 'giltig';
    let rad;
    if (harInstans && harStod)
      rad = { art: a.art, modell: 'ambiguous',
        varfor: 'artefakten deklarerar bade data-theme och data-theme-support — agarskapet gar inte att avgora' };
    else if (harStod) {
      if (f.form !== 'giltig') rad = { art: a.art, modell: 'unknown', varfor: f.varfor };
      else {
        const renderade = Array.isArray(a.renderade) ? a.renderade.filter(x => STODVARDEN.has(x)) : [];
        const saknade = st.teman.filter(x => !renderade.includes(x));
        rad = saknade.length
          ? { art: a.art, familj: f.id, modell: 'ejRenderad', stod: st.teman, renderade,
              varfor: 'deklarerat stod for ' + st.teman.join(' och ') + ' men ' +
                saknade.join(', ') + ' har inte renderats och matts' }
          : { art: a.art, familj: f.id, modell: 'dualThemeRender', stod: st.teman, renderade,
              varfor: 'temakapabel kalla renderad och matt i ' + renderade.join(' och ') };
      }
    } else if (harInstans) {
      if (t.tema === 'neutral') rad = { art: a.art, modell: 'neutral', varfor: 'deklarerad theme-neutral' };
      else if (f.form !== 'giltig') rad = { art: a.art, modell: 'unknown', varfor: f.varfor };
      else rad = { art: a.art, familj: f.id, modell: 'explicitInstans', tema: t.tema };
    } else rad = { art: a.art, modell: 'unknown', varfor: t.varfor };
    rader.push(rad);
    if (rad.familj) { if (!perFamilj.has(rad.familj)) perFamilj.set(rad.familj, []); perFamilj.get(rad.familj).push(rad); }
  }

  const familjer = [];
  for (const [id, v] of perFamilj) {
    const instanser = v.filter(x => x.modell === 'explicitInstans');
    const duala = v.filter(x => x.modell === 'dualThemeRender');
    const ejRend = v.filter(x => x.modell === 'ejRenderad');
    // Bade en explicit mork artefakt och en dual-render for samma familj:
    // vem ager det morka tillstandet? Fail closed tills det ar bestamt.
    if (duala.length && instanser.length)
      { familjer.push({ familj: id, status: 'ambiguous',
        varfor: 'bade explicit artefakt och dual render for samma familj — agarskapet ar inte bestamt',
        medlemmar: v.map(x => x.art) }); continue; }
    if (duala.length > 1)
      { familjer.push({ familj: id, status: 'ambiguous',
        varfor: duala.length + ' temakapabla kallor i samma familj', medlemmar: duala.map(x => x.art) }); continue; }
    if (duala.length === 1) {
      const d = duala[0];
      familjer.push(d.renderade.includes('light') && d.renderade.includes('dark')
        ? { familj: id, status: 'covered', modell: 'dualThemeRender', kalla: d.art, renderade: d.renderade }
        : { familj: id, status: 'coverageGap', modell: 'dualThemeRender', kalla: d.art,
            varfor: 'renderad bara i ' + d.renderade.join(', ') });
      continue; }
    if (ejRend.length) { familjer.push({ familj: id, status: 'coverageGap', modell: 'ejRenderad',
      varfor: ejRend[0].varfor, medlemmar: ejRend.map(x => x.art) }); continue; }
    const per = new Map();
    for (const x of instanser) { if (!per.has(x.tema)) per.set(x.tema, []); per.get(x.tema).push(x); }
    if ([...per.values()].some(l => l.length > 1))
      { familjer.push({ familj: id, status: 'ambiguous',
        varfor: 'flera artefakter deklarerar samma tema i familjen', medlemmar: instanser.map(x => x.art) }); continue; }
    const l = per.get('light'), d = per.get('dark');
    if (l && d) familjer.push({ familj: id, status: 'covered', modell: 'explicitPair',
      light: l[0].art, dark: d[0].art });
    else if (l) familjer.push({ familj: id, status: 'coverageGap', modell: 'lightOnly', art: l[0].art });
    else if (d) familjer.push({ familj: id, status: 'coverageGap', modell: 'darkOnly', art: d[0].art });
  }

  const rakna = f => familjer.filter(f).length;
  return {
    artefakter_st: artefakter.length,
    familjer_st: familjer.length,
    covered_st: rakna(x => x.status === 'covered'),
    covered_explicitPair_st: rakna(x => x.modell === 'explicitPair' && x.status === 'covered'),
    covered_dualThemeRender_st: rakna(x => x.modell === 'dualThemeRender' && x.status === 'covered'),
    coverageGap_st: rakna(x => x.status === 'coverageGap'),
    lightOnly_st: rakna(x => x.modell === 'lightOnly'),
    darkOnly_st: rakna(x => x.modell === 'darkOnly'),
    ambiguous_st: rakna(x => x.status === 'ambiguous'),
    unknown_artefakter_st: rader.filter(x => x.modell === 'unknown').length,
    neutral_st: rader.filter(x => x.modell === 'neutral').length,
    familjer, rader,
  };
}
