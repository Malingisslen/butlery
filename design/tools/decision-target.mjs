// F2-R04 · CENTRAL MALIDENTITET.
//
// En instans far bindas till ett beslut BARA nar hela beslutets identitet
// stammer. Det tidigare felet var att matchningen kravde semantisk roll och
// undergrupp men INTE kandidatens ljusvarde, sa instanser med annan
// ljuskandidat gled in i skrivmangden.
//
// Regeln bor ligga pa ett stalle. Forgrund, yta och migrator ska inte ha var
// sin svagare variant.

import { arAktiv, beslutsIdAv } from './theme-decisions.mjs';

export const MALREGEL = [
  'beslutet maste vara ACTIVE — ett ersatt beslut ar aldrig ett mal',
  'kandidatidentiteten maste stamma',
  'semantisk roll maste stamma',
  'semantisk undergrupp maste stamma nar beslutet ar SUBGROUP',
  'instansens NUVARANDE ljusvarde maste stamma med beslutets ljuskandidat',
  'flera traffar: fail closed',
  'ingen traff: fail closed'
];

// VIKTIGT FOR ANROPARE: malMatchning provar IDENTITET, inte SCOPE. Tva olika
// forekomster kan dela hela identiteten och anda tillhora olika beslut, for
// att beslutet ar avgransat till en kallrad eller en artefaktlista. Anropa
// beslutstackning() i decision-scope-guard.mjs nar du binder en FOREKOMST
// till ett beslut — den lagger scopelagret ovanpa den har funktionen.
//
// instans: { kandidatId, roll, undergrupp, ljusvarde }
export function malMatchning(register, instans) {
  const kandidater = register.beslut.filter(b => {
    if (!arAktiv(b)) return false;
    if (b.kandidatId !== instans.kandidatId) return false;
    if (b.roll !== instans.roll) return false;
    if (b.omfattning === 'SUBGROUP' && b.semantiskUndergrupp !== instans.undergrupp) return false;
    // LJUSVARDET. Utan det matchar en undergrupp aven en annan ljuskandidat.
    if (String(b.ljusvarde).toLowerCase() !== String(instans.ljusvarde).toLowerCase()) return false;
    return true;
  });
  if (!kandidater.length) return { ok: false,
    skal: 'ingen aktiv beslutspost matchar hela identiteten (' + instans.kandidatId +
      ' · ' + instans.roll + ' · ljus ' + instans.ljusvarde + ')' };
  if (kandidater.length > 1) return { ok: false,
    skal: 'flera beslutsposter matchar samma identitet: ' + kandidater.map(beslutsIdAv).join(' | ') };
  return { ok: true, beslut: kandidater[0] };
}
