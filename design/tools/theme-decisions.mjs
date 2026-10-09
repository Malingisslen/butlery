// F2-R04 · REGISTRET FOR MANSKLIGA DESIGNBESLUT.
//
// Ett beslut ar AUKTORITET, inte observation. Modulen ager tre saker:
//
//   identitet   tokennamnet tilldelas EN gang och ar darefter persistent
//   livscykel   ACTIVE eller SUPERSEDED; bara aktiva far migreras
//   uppslagning konsumenterna slar upp pa beslutsId, aldrig pa listindex
//
// Felklassen som ar belagd: namnen genererades ur listordningen. Nar ett
// beslut ersattes foll det ur den aktiva listan, numreringen forskots, och
// nasta batch fick ett namn som redan stod i ritningarna for en annan farg.
// Darfor far varken supersede, insattning eller omsortering rora ett
// befintligt namn.

// Beslutets identitet. Ett undergruppsbeslut identifieras av bade kandidaten
// och undergruppen; ett helkandidatbeslut av kandidaten ensam.
export function beslutsIdAv(b) {
  if (b.beslutsId) return b.beslutsId;
  return b.omfattning === 'SUBGROUP' && b.semantiskUndergrupp
    ? b.kandidatId + ' ‖ ' + b.semantiskUndergrupp
    : b.kandidatId;
}

// SCOPE mot POST. beslutsId ar det beslutet handlar OM — kandidaten och
// eventuell undergrupp. Ett ersatt beslut ar en tidigare revision av samma
// scope, sa lagringsidentiteten maste bara med revisionen. Annars kolliderar
// historiken med sin egen ersattare.
export const postIdAv = b => beslutsIdAv(b) + ' @r' + (b.revision || 1);

export const arAktiv = b => b.aktiv !== false && b.status !== 'SUPERSEDED';

// Tilldela namn till de beslut som saknar det. Rorer ALDRIG ett befintligt
// namn, och reserverar aven namn fran ersatta beslut sa att ett historiskt
// namn inte kan ateranvandas av ett annat beslut.
export function tilldelaTokennamn(register, reserverade = []) {
  const tagna = new Set(reserverade);
  for (const b of register.beslut) if (b.tokenNamn) tagna.add(b.tokenNamn);
  const nya = [];
  for (const b of register.beslut) {
    if (b.tokenNamn) continue;
    if (!arAktiv(b)) { b.tokenNamn = null; continue; }
    const bas = '--' + String(b.roll).replace(/[^a-z0-9]/g, '-') + '-d';
    let i = 1, n = bas + i;
    while (tagna.has(n)) n = bas + (++i);
    tagna.add(n); b.tokenNamn = n; nya.push({ beslutsId: beslutsIdAv(b), tokenNamn: n });
  }
  return nya;
}

// Uppslagning pa identitet. Konsumenterna far aldrig rakna sig fram.
export function tokenkarta(register, { baraAktiva = true } = {}) {
  const m = new Map();
  for (const b of register.beslut) {
    if (baraAktiva && !arAktiv(b)) continue;
    if (!b.tokenNamn) continue;
    m.set(beslutsIdAv(b), { namn: b.tokenNamn, ljus: b.ljusvarde, mork: b.morkvarde,
      omfattning: b.omfattning, kandidatId: b.kandidatId,
      semantiskUndergrupp: b.semantiskUndergrupp || null });
  }
  return m;
}

// Vilket beslut galler for en malad post? Helkandidatbeslut forst, darefter
// exakt undergrupp. Ett ersatt beslut galler aldrig.
export function beslutFor(register, kandidatId, undergrupp) {
  const aktiva = register.beslut.filter(arAktiv);
  const helt = aktiva.find(b => b.omfattning === 'WHOLE_CANDIDATE' && b.kandidatId === kandidatId);
  if (helt) return helt;
  if (!undergrupp) return null;
  return aktiva.find(b => b.omfattning === 'SUBGROUP' && b.kandidatId === kandidatId &&
    b.semantiskUndergrupp === undergrupp) || null;
}

// Ersatt ett beslut. Historiken raderas aldrig och namnet foljer med det
// gamla beslutet — ersattaren far ett eget.
export function ersatt(register, beslutsId, nytt, reason) {
  const gammal = register.beslut.find(b => beslutsIdAv(b) === beslutsId && arAktiv(b));
  if (!gammal) return { ok: false, skal: 'inget aktivt beslut med id ' + beslutsId };
  gammal.status = 'SUPERSEDED';
  gammal.aktiv = false;
  gammal.reason = reason;
  gammal.ersattAv = beslutsId;
  gammal.revision = gammal.revision || 1;
  const post = { ...gammal, ...nytt, status: 'ACTIVE', aktiv: true,
    revision: gammal.revision + 1, ersatter: postIdAv(gammal) };
  delete post.reason; delete post.ersattAv; delete post.tokenNamn;
  gammal.ersattAv = postIdAv(post);
  register.beslut.push(post);
  const nya = tilldelaTokennamn(register);
  return { ok: true, gammaltNamn: gammal.tokenNamn, nyttNamn: post.tokenNamn, nya };
}
