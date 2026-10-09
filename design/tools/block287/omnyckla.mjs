// Agarsteget i remedieringsbygget (Block 287, efter ankarcommit): varje kontrollagare harleds
// fran noll ur KALLAN — skordens element, deras kallforfattade data-occurrence och innehall —
// med den kanoniska metoden (tools/semantic-owner-identity.mjs pa den rot som byggs).
// Utfall per enhet: oforandrad, ny nyckel (IDENTITY_CORRECTION) eller fail closed. Aldrig tyst.
import { pathToFileURL } from 'node:url';

export async function laddaMetod(rot) { return import(pathToFileURL(rot + '/tools/semantic-owner-identity.mjs').href); }

const rollOrd = r => String(r || '').split(/[\s(]/)[0];
const fold = s => String(s).normalize('NFD').replace(/[̀-ͯ]/g, '');
const slugA = s => fold(s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const talfri = s => String(s).replace(/\d+(?:[.,:]\d+)*/g, '').replace(/-+/g, '-').replace(/^-|-$/g, '');

/** Kontrollfakta for alla kontroller i kallan: deklarerade (skord) + Block 287-agare (overlay). */
export function kontrollFakta({ skord, overlay, etikett, M }) {
  const obj = new Map(skord.map(o => [o.art + '|' + o.ordProd, o]));
  const barn = new Map(); for (const o of skord) { const k = o.art + '|' + (o.foraldraProd[0] ?? 'rot'); barn.set(k, (barn.get(k) || []).concat(o)); }
  const undertrad = o => { const ut = [o]; for (let i = 0; i < ut.length; i++) ut.push(...(barn.get(ut[i].art + '|' + ut[i].ordProd) || [])); return ut; };
  // kedja: kontrollens element och forfader; innehall = objektets text utanfor kontrollens undertrad
  const kedja = e => { const egna = new Set(undertrad(e).map(x => x.ordProd)); const leder = [e, ...e.foraldraProd.map(f => obj.get(e.art + '|' + f)).filter(Boolean)];
    // skordens egenDelar kan aggregera odeklarerade barns text: ett segment som exakt ar kontrollens egen text raknas aldrig som objektets innehall
    const egenText = undertrad(e).flatMap(x => x.egenDelar || []).concat(e.text ? [e.text] : []).map(t => String(t).trim().toLowerCase()).filter(Boolean);
    return leder.map((l, i) => ({ occ: l.occ, ord: l.ordProd, innehall: i === 0 ? [] : undertrad(l).filter(x => !egna.has(x.ordProd)).flatMap(x => x.egenDelar || [])
      .filter(t => !egenText.includes(String(t).trim().toLowerCase())) })); };
  const fakta = [];
  const kryss = {};
  for (const o of skord) if (o.roll === 'checkbox' && o.namn != null) kryss[o.art] = (kryss[o.art] || 0) + 1;
  for (const a of Object.values(overlay.agare)) if (rollOrd(a.roll) === 'checkbox') kryss[a.art] = (kryss[a.art] || 0) + 1;
  for (const o of skord) if (o.roll && o.namn != null)
    fakta.push({ kalla: 'deklarerad', art: o.art, ord: o.ordProd, roll: o.roll, namn: o.namn, glyf: (o.ikoner || [])[0], text: (o.egenDelar || []).join(' '), el: o });
  const occAv = {}; for (const [id, b] of Object.entries(overlay.forekomst)) if (b.agare && b.klass === 'KNOWN_CONTROL') (occAv[b.agare] = occAv[b.agare] || []).push(id);
  for (const [aid, a] of Object.entries(overlay.agare)) {
    const oc = (occAv[aid] || [a.radForekomst]).filter(Boolean)[0]; const ord = oc ? Number(oc.split('::').pop()) : (a.radOrd ?? null);
    const o = ord != null ? obj.get(a.art + '|' + ord) : null;
    fakta.push({ kalla: 'overlay', agare: aid, art: a.art, ord: o ? o.ordProd : null, roll: rollOrd(a.roll), namn: a.namn || '', glyf: o && (o.ikoner || [])[0], text: o && (o.egenDelar || []).join(' '), el: o,
      grupp: /::grupp::/.test(aid), handling: (aid.match(/::handling::(.+)$/) || [])[1] || undefined });
  }
  // MIGRATION_LOCATOR (aldrig identitet): en betygsgrupp utan eget element = narmaste ankrade
  // forfader till stjarnorna for samma person.
  for (const f of fakta) if (!f.el && f.roll === 'radiogroup' && /^Betyg för .+/.test(f.namn)) {
    const p = f.namn.replace(/^Betyg för /, '');
    const stj = fakta.find(x => x.art === f.art && x.roll === 'radio' && x.el && x.namn.endsWith('för ' + p));
    const a = stj && [stj.el, ...stj.el.foraldraProd.map(q => obj.get(f.art + '|' + q))].find(x => x && x.occ);
    if (a) { f.el = a; f.ord = a.ordProd; f.lokator = 'via stjarnorna for samma person'; } }
  for (const f of fakta) { f.iLista = f.roll === 'checkbox' && kryss[f.art] >= 3; f.ramEtikett = etikett[f.art]; f.kedja = f.el ? kedja(f.el) : []; }
  return { fakta, obj };
}

/** Omnyckling av en byggd population. metod = kanonisk modul; gammalAgare = identitet8.agarNyckel (historisk). */
export function omnyckla({ enheter, fakta, metod, gammalAgare, discovery }) {
  for (const f of fakta) f.objekt = metod.narmasteAnkare(f.kedja);
  const tilldelat = metod.tilldela(fakta);
  tilldelat.forEach((t, i) => { fakta[i].ny = t; });
  // gamla nyckelformer per kontroll (sa som bygget pa e6e2f06 myntade dem)
  const perGammal = new Map(); const lagg = (k, f) => { if (!k) return; perGammal.set(k, (perGammal.get(k) || []).concat(f)); };
  const overlayNycklar = new Set(fakta.filter(f => f.agare).map(f => f.agare));
  for (const f of fakta) {
    if (f.agare) lagg(f.agare, f);
    else { const g = gammalAgare({ art: f.art, namn: f.namn }); if (!overlayNycklar.has(g)) lagg(g, f); }   // overlayns agare ar sin egen kontroll
    const a = slugA(f.namn || '(utan-namn)');
    lagg('A2::' + f.art + '::' + f.roll + '::' + a, f);
    if (talfri(a) !== a) lagg('A2::' + f.art + '::' + f.roll + '::' + talfri(a), f);
    // A11Y_NAME for reglage (Round 7): agaren skrevs som ram::switch::<radens etikett> — radens etikett = objektets innehall
    if (f.roll === 'switch' && f.objekt && f.objekt.ankare) for (const t of f.objekt.innehall || []) lagg('SW::' + f.art + '::' + slugA(t), f);
  }
  const rader = [], nyaEnheter = [];
  for (const e of enheter) {
    const fac = e.id.split('::')[1];
    let nyckel = null, kontroller = null;
    if (e.IDENTITY_KIND !== 'LEDGER' && ['ROLE_AND_NAME', 'DARK_BORDER'].includes(fac) && /^OWNER::[^:]+::(namn|handling|grupp)::/.test(e.OWNER_ID || '')) kontroller = perGammal.get(e.OWNER_ID);
    if (fac === 'A11Y_STATE_ANNOTATION') kontroller = perGammal.get('A2::' + e.OWNER_ID);
    if (fac === 'ROLE' && e.PERSISTENT_OWNER_ID) kontroller = perGammal.get(e.PERSISTENT_OWNER_ID);
    if (fac === 'A11Y_NAME' && /^[^:]+::switch::/.test(e.OWNER_ID || '')) kontroller = perGammal.get('SW::' + e.OWNER_ID.split('::')[0] + '::' + e.OWNER_ID.split('::').slice(2).join('::'));
    if (kontroller) kontroller = [...new Set(kontroller)];
    // kallankare ur upptackten: foljer upptacktens egen identitet (samma forekomsthandtag)
    if (fac === 'ROLE_AND_NAME' && /^OWNER::[^:]+::(occ|text|hit-target|id|bind|glyf|komponent)::/.test(e.OWNER_ID || '') && discovery) {
      const ny = discovery.get(e.OWNER_ID);
      if (ny && ny !== e.OWNER_ID) { rader.push({ fac, gammal: e.id, ny: 'RP::ROLE_AND_NAME::' + ny.replace(/^OWNER::/, ''), gammalAgare: e.OWNER_ID, nyAgare: ny, regel: 'UPPTACKT_KALLANKARE', skal: 'upptacktens agare foljer kallans nya data-occurrence' });
        nyaEnheter.push({ ...e, id: 'RP::ROLE_AND_NAME::' + ny.replace(/^OWNER::/, ''), OWNER_ID: ny, WRITE_OWNER: e.WRITE_OWNER && e.WRITE_OWNER.replace(e.OWNER_ID, ny) }); continue; }
    }
    if (!kontroller || !kontroller.length) { nyaEnheter.push(e); continue; }
    const nya = [...new Set(kontroller.map(k => k.ny.id || 'OLOST'))];
    const regler = [...new Set(kontroller.map(k => k.ny.regel))];
    // Berord = agaren styrs av handoffen eller bar objektinnehall. Rena namnagare (regel NAMN) ror
    // commit 2 inte; deras enheter behaller exakt sitt id.
    const berord = regler.some(r => r === 'HANDOFF' || r === 'OBJEKT' || r === 'INNEHALLSMALL' || r === 'LAGE_UTESLUTET' || r === 'VARDE' || r === 'BINDNING');
    const rad = { fac, gammal: e.id, gammalAgare: e.OWNER_ID || e.PERSISTENT_OWNER_ID, kontroller: kontroller.map(k => k.art + '#' + k.ord + ' ' + k.roll + ' "' + k.namn + '"'), regel: regler.join('+'),
      monster: [...new Set(kontroller.map(k => k.ny.monster).filter(Boolean))].join('+') || null, ankare: [...new Set(kontroller.map(k => k.objekt && (k.objekt.ankare || k.objekt.skuld)).filter(Boolean))].join('+') || null, berord };
    if (!berord) { nyaEnheter.push(e); continue; }
    // Forklarad delning (R12): en gammal gruppnyckel (t.ex. ram::switch::reglage over 3 reglage) delas i en enhet per
    // kallbunden rad. Bara nar varje kontroll ar kallbunden (BINDNING) och ingen ar olost.
    if (nya.length > 1 && regler.length === 1 && regler[0] === 'BINDNING' && !nya.includes('OLOST')) {
      const nyIds = nya.map(x => 'RP::' + fac + '::' + x.replace(/^OWNER::/, ''));
      rader.push({ ...rad, ny: nyIds.join(' + '), nyAgare: nya.join(' + '), delning: nyIds });
      for (const x of nya) nyaEnheter.push({ ...e, id: 'RP::' + fac + '::' + x.replace(/^OWNER::/, ''), OWNER_ID: fac === 'A11Y_STATE_ANNOTATION' ? x.replace(/^OWNER::/, '') : x,
        OCCURRENCES: kontroller.filter(k => k.ny.id === x).length, IDENTITY_MIGRATION: { FROM: e.id, REASON: 'IDENTITY_CORRECTION', SPLIT: nya.length } });
      continue; }
    if (nya.length > 1) { rader.push({ ...rad, ny: null, fel: 'UNEXPLAINED_SPLIT', nya }); nyaEnheter.push(e); continue; }
    if (nya[0] === 'OLOST') { rader.push({ ...rad, ny: null, fel: 'OWNER_IDENTITY_UNRESOLVED', skal: kontroller.map(k => k.ny.skal).join('; ') }); nyaEnheter.push(e); continue; }
    nyckel = nya[0];
    if (fac === 'ROLE') { rader.push({ ...rad, ny: e.id, nyAgare: nyckel, persistentFore: e.PERSISTENT_OWNER_ID }); nyaEnheter.push({ ...e, PERSISTENT_OWNER_ID: nyckel }); continue; }
    const nyId = 'RP::' + fac + '::' + nyckel.replace(/^OWNER::/, '');
    rader.push({ ...rad, ny: nyId, nyAgare: nyckel });
    nyaEnheter.push({ ...e, id: nyId, OWNER_ID: fac === 'A11Y_STATE_ANNOTATION' ? nyckel.replace(/^OWNER::/, '') : nyckel,
      WRITE_OWNER: e.WRITE_OWNER ? (e.WRITE_OWNER.includes(e.OWNER_ID) ? e.WRITE_OWNER.replace(e.OWNER_ID, nyckel) : e.WRITE_OWNER.replace(String(e.OWNER_ID).replace(/^OWNER::/, ''), nyckel.replace(/^OWNER::/, ''))) : e.WRITE_OWNER,
      IDENTITY_MIGRATION: { FROM: e.id, REASON: 'IDENTITY_CORRECTION' } });
  }
  return { enheter: nyaEnheter, rader };
}
