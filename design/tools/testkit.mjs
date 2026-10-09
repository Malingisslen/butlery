// Butlery · DOMSLUTEN i provsviterna, som körbar kod i stället för mönster.
//
// F1-U05: M-33 byggde på regexsökning i källtext. Den fångade direktformen
// `foo().status` men inte `const r = runProc(...); r.status`, och den kunde
// dessutom passera enbart därför att den sökta frasen stod i en kommentar. Ett
// källtextsprov kan inte skilja en rättad kodväg från en välformulerad ursäkt.
//
// Domsluten ligger nu här, som rena funktioner. selftest och metatest ANVÄNDER
// dem — de är alltså den verkliga kodvägen — och M-33 matar dem med de sex
// felklasserna och kräver att var och en underkänns.

/**
 * F1-U04/H05 · Läs exitkoden ur ett processresultat.
 *
 * `runProc()` returnerar `{code, timedOut, out}`. Fältet `status` finns inte,
 * och `undefined !== 0` är alltid sant — M-24 stod grön i fem vändor på just
 * den formen. Här är ett resultat utan `code` ett KASTAT FEL, inte ett tyst
 * undefined, så felet upptäcks av att provet fallerar och inte av att någon
 * läser koden.
 */
export function procCode(result, where = 'processresultat') {
  if (result === null || typeof result !== 'object')
    throw new Error(where + ': förväntade ett processresultat, fick ' + JSON.stringify(result));
  if (!('code' in result))
    throw new Error(where + ': resultatet saknar fältet "code" (fälten är ' +
      Object.keys(result).join(', ') + ') — läs inte "status" ur ett runProc-resultat');
  const c = result.code;
  if (c !== null && c !== 'TIMEOUT' && !Number.isInteger(c))
    throw new Error(where + ': "code" är ' + JSON.stringify(c) + ', varken heltal, null eller TIMEOUT');
  return c;
}

export const procFailed = (result, where) => procCode(result, where) !== 0;
export const procPassed = (result, where) => procCode(result, where) === 0;

/**
 * F1-U05 · Domslutet för ett mutationsprov, som kod.
 *
 * Ett prov godkänns bara om ALLA fem villkoren håller. Fyra av dem gick
 * tidigare att kringgå: en mutation som inte ändrade något, en kontroll som
 * redan var röd, en ny diagnostik ur fel kontroll, och ett utfall som vilade på
 * ett allmänt exitvärde.
 *
 * @param mutated      källan efter mutationen (eller null om den inte byggdes)
 * @param original     källan före
 * @param baseline     diagnostikrader före mutationen (Set eller array)
 * @param after        diagnostikrader efter
 * @param controlId    kontrollen provet påstår sig pröva
 */
export function judgeMutation({ mutated, original, baseline, after, controlId }) {
  const base = baseline instanceof Set ? baseline : new Set(baseline || []);
  const rows = after || [];

  if (mutated === null || mutated === undefined)
    return { ok: false, reason: 'provet kunde inte byggas — mönstret finns inte i källan, provet mäter alltså ingenting' };
  if (mutated === original)
    return { ok: false, reason: 'mutationen ändrade ingenting i källan' };

  const fresh = rows.filter(r => !base.has(r));
  if (!fresh.length)
    return { ok: false, reason: 'ingen NY diagnostik — baslinjen ' + base.size + ' → ' + rows.length };

  const mine = fresh.filter(r => new RegExp('(^|\\s)' + controlId.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '(\\s|:)').test(r));
  if (!mine.length)
    return {
      ok: false,
      reason: controlId + ' gav INGEN ny diagnostik (nya rader kom ur ' +
        [...new Set(fresh.map(r => (r.match(/\b([A-ZÅÄÖ]{1,5}-\d+[a-z]?)\b/) || [])[1]).filter(Boolean))].join(', ') + ')'
    };

  return { ok: true, reason: null, fresh: mine.length };
}

/**
 * F1-U04 · Domslutet för symlänksproven.
 *
 * `every(c => c[2] || c[3])` lät `EJ KÖRT` räknas som godkänt, vilket stred mot
 * den redovisade policyn — ett prov som inte kunde köras är inte ett prov som
 * lyckades. Ett ej körbart symlänksprov gör nu hela metatestet icke godkänt.
 *
 * @param cases  [{label, created, fell, error}]
 */
export function judgeSymlinkCases(cases) {
  const notRun = cases.filter(c => !c.created);
  const didNotFall = cases.filter(c => c.created && !c.fell);
  return {
    ok: notRun.length === 0 && didNotFall.length === 0,
    notRun: notRun.length,
    didNotFall: didNotFall.length,
    detail: cases.map(c =>
      c.label + '=' + (c.created ? (c.fell ? 'fällde' : 'FÖLL INTE') : 'EJ KÖRT (' + (c.error || 'okänt') + ')')).join(', '),
    reason: notRun.length
      ? notRun.length + ' symlänksprov kunde inte köras — de räknas som ICKE GODKÄNDA, aldrig som godkända'
      : (didNotFall.length ? didNotFall.length + ' symlänksprov fällde inte' : null)
  };
}

/**
 * Kör ett symlänksfall. `mk` injiceras så att M-35 kan simulera att
 * rättigheten saknas utan att röra filsystemet.
 */
export function runSymlinkCase({ label, target, link, run, diag, mk }) {
  try { mk(target, link); }
  catch (e) { return { label, created: false, fell: false, error: e.code || e.message }; }
  let fell = false, code = null;
  try {
    const r = run();
    code = procCode(r, 'symlänksprov ' + label);
    fell = code !== 0 && diag.test(r.out || '');
  } finally { /* uppstädning sköts av anroparen */ }
  return { label, created: true, fell, code, error: null };
}
