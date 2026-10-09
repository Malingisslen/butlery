// LC-medlemskap: lintens egna rader plus de avatarer vars bakgrund blev en
// var()-referens och darfor ar osynliga for lint-controls.
//
// En avataravvikelse ar samma verklighet oavsett om fargen star som literal
// eller som var()-referens. Mangden ar darfor en union per ram och storlek:
// flyttas en avatar mellan representationerna andras inte medlemskapet, och
// ingen raknas tva ganger.
import { createHash } from 'node:crypto';

export const storlekAv = t => (/avatar ([\d.]+) px/.exec(String(t || '')) || [, null])[1];
export const avatarNyckel = (ram, storlek) => 'LC::' + ram + '::avatar::' + storlek;

/**
 * @param lcRader  lintens rader: { fil, ram, text }
 * @param avatarVar  matfilens rader: { fil, ram, storlek, text }
 */
export function lcMedlemskap(lcRader, avatarVar) {
  const perAvatar = new Map();
  const notera = (kalla, ram, storlek, fil, text) => {
    const k = avatarNyckel(ram, storlek);
    const e = perAvatar.get(k) || { ram, storlek, fil, text, n: { lint: 0, matning: 0 } };
    e.n[kalla]++;
    if (kalla === 'lint') { e.fil = fil; e.text = text; }
    perAvatar.set(k, e);
  };
  for (const r of lcRader) { const st = storlekAv(r.text); if (st) notera('lint', r.ram, st, r.fil, r.text); }
  for (const a of avatarVar) notera('matning', a.ram, String(a.storlek), a.fil, a.text);

  const ut = lcRader.filter(r => !storlekAv(r.text))
    .map(r => ({ ID: 'LC::' + r.ram + '::' + r.text, fil: r.fil, ram: r.ram, text: r.text, KALLA: r.KALLA || 'tools/lint-controls.mjs' }));
  for (const [k, e] of [...perAvatar].sort((a, b) => (a[0] < b[0] ? -1 : 1))) {
    const n = Math.max(e.n.lint, e.n.matning);
    for (let i = 1; i <= n; i++) ut.push({
      ID: k + '#' + i, fil: e.fil, ram: e.ram, text: e.text,
      KALLA: e.n.lint >= e.n.matning ? 'tools/lint-controls.mjs' : 'fas2/matning/avatar.json · varUtanforSkala',
      REPRESENTATION: e.n.lint && e.n.matning ? 'BADA' : (e.n.lint ? 'LITERAL' : 'VAR_REFERENS')
    });
  }
  return ut;
}

export const mangdHash = x => createHash('sha256').update(JSON.stringify(x)).digest('hex').slice(0, 16);
export const medlemsHash = lista => mangdHash(lista.map(x => (typeof x === 'string' ? x : x.ID)).slice().sort());
