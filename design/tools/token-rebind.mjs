// F2-R04 · TOKEN_REBIND OCH SCOPED_OVERRIDE.
//
// Migratorn kunde bara ett: byta ett FARGVARDE mot var(--token). Tva av
// produktens verkliga kalltillstand faller utanfor det:
//
//   TOKEN_REBIND       kallan har redan var(--delad-token). Beslutet galler en
//                      undergrupp, sa referensen ska peka pa beslutets EGEN
//                      token — utan att den delade tokenens varde rors.
//
//   SCOPED_OVERRIDE    fargen kommer ur arv eller en klassregel som delas med
//                      manga element utanfor beslutet. En ny egen deklaration
//                      pa elementet ar da den enda scopade atgarden.
//
// Bada ar fail closed. Ingen blind strangersattning, ingen global replace.

// TOKEN_REBIND · byt EN var()-referens i EN deklaration.
export function rebindITagg(taggtext, post, gammalToken, nyToken) {
  const egenskap = (post.ankare && post.ankare.egenskap) || post.egenskap;
  const st = taggtext.match(/style="([^"]*)"/);
  if (!st) return { ok: false, skal: 'inget stilattribut i taggen' };
  const KORT = { 'background-color': ['background-color', 'background'],
    'border-top-color': ['border-top-color', 'border-top', 'border'],
    'border-right-color': ['border-right-color', 'border-right', 'border'],
    'border-bottom-color': ['border-bottom-color', 'border-bottom', 'border'],
    'border-left-color': ['border-left-color', 'border-left', 'border'],
    'color': ['color'] };
  const namn = KORT[egenskap] || [egenskap];
  const delar = st[1].split(';');
  // Vilka deklarationer i taggen bar den gamla tokenen for RATT egenskap?
  const traff = [];
  for (let i = 0; i < delar.length; i++) {
    const kv = delar[i].trim().match(/^([a-z-]+)\s*:\s*(.+)$/);
    if (!kv || !namn.includes(kv[1])) continue;
    const n = (kv[2].match(new RegExp('var\\(\\s*' + gammalToken.replace(/-/g, '\\-') + '\\b', 'g')) || []).length;
    if (n === 1) traff.push({ i, namn: kv[1] });
    else if (n > 1) return { ok: false, skal: 'tvetydigt: ' + n + ' forekomster av ' + gammalToken + ' i samma deklaration' };
  }
  if (!traff.length) return { ok: false, skal: 'ingen deklaration for ' + egenskap + ' med ' + gammalToken + ' i taggen' };
  if (traff.length > 1) return { ok: false, skal: 'tvetydigt: ' + traff.length + ' deklarationer bar ' + gammalToken };
  const t = traff[0];
  delar[t.i] = delar[t.i].replace(new RegExp('var\\(\\s*' + gammalToken.replace(/-/g, '\\-') + '\\b'), 'var(' + nyToken);
  return { ok: true, namn: t.namn,
    text: taggtext.replace(/style="[^"]*"/, 'style="' + delar.join(';') + '"') };
}

// SCOPED_OVERRIDE · lagg en EGEN deklaration pa elementet. Anvands bara nar
// den vinnande kallan ar arv eller en delad klassregel.
export function overrideITagg(taggtext, post, nyToken) {
  const egenskap = (post.ankare && post.ankare.egenskap) || post.egenskap;
  const st = taggtext.match(/style="([^"]*)"/);
  if (st) {
    const delar = st[1].split(';').filter(x => x.trim());
    // Finns egenskapen redan? Da ar det ingen override utan ett vardebyte —
    // fel operation, fail closed.
    for (const d of delar) { const kv = d.trim().match(/^([a-z-]+)\s*:/);
      if (kv && kv[1] === egenskap) return { ok: false,
        skal: 'egenskapen ' + egenskap + ' finns redan i taggen — override ar fel operation' }; }
    delar.push(egenskap + ':var(' + nyToken + ')');
    return { ok: true, namn: egenskap,
      text: taggtext.replace(/style="[^"]*"/, 'style="' + delar.join(';') + '"') };
  }
  // Ingen style alls: lagg till ett stilattribut sist i oppningstaggen.
  const m = taggtext.match(/^<([a-zA-Z][\w-]*)([\s\S]*?)(\/?)>$/);
  if (!m) return { ok: false, skal: 'gick inte att tolka oppningstaggen' };
  return { ok: true, namn: egenskap,
    text: '<' + m[1] + m[2] + (m[2].endsWith(' ') ? '' : ' ') + 'style="' + egenskap + ':var(' + nyToken + ')"' + m[3] + '>' };
}
