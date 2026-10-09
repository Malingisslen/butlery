// Kor: node tools/block287-korrigeringsrunda1.mjs <scratchrot> <reporot>
// Samlar korrigeringsrunda 1 till repo-artefakter.
import { readFileSync, writeFileSync } from 'node:fs';
const [, , SC, REPO] = process.argv;
const j = f => JSON.parse(readFileSync(f, 'utf8'));
const IDX = j(SC + '/bl01/idx-full.json');
const KORR = j(SC + '/bl01/block287-censuskorrigering.json');
const MORK = j(SC + '/bl01/mork.json');
const NYCK = j(SC + '/bl01/skrivnycklar.json');
const V = j(SC + '/bl01/v-namnnycklar.json');
const P = j(REPO + '/fas2/block287-population.json');
const kort = f => f.replace(/^Butlery Skarmar v12 /, '').replace(/\.dc\.html$/, '');
const slug = s => String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 48);
const stabilNamn = s => slug(String(s == null ? '' : s).replace(/\d+(?:[.,:]\d+)*/g, ' '));

// ── O/P/Q · skrivagarnyckelns kontrakt och tackning
const nyckelrader = NYCK.rader;
const kollisioner = {};
for (const r of nyckelrader) if (r.WRITE_OWNER_ID) kollisioner[r.WRITE_OWNER_ID] = (kollisioner[r.WRITE_OWNER_ID] || 0) + 1;
const failClosed = Object.entries(kollisioner).filter(p => p[1] > 1)
  .map(p => ({ WRITE_OWNER_ID: p[0], ANTAL: p[1], KRAV: 'ANCHOR_REQUIRED: tva eller fler element delar den starkaste tillgangliga kallgrunden; designen maste bara ett kallforfattat data-occurrence pa vart och ett' }));

// ── R · den tappade morklagesremedieringen, med stabila skrivagare
const byFrameOrd = new Map(IDX.map(e => [e.art + '#' + e.ordProd, e]));
const morkAgare = MORK.map(x => {
  const fil = kort(x.fil);
  let id = null, grund = null;
  if (x.occ) { id = 'EL::' + fil + '::occ::' + x.occ; grund = 'kanoniskt data-occurrence pa elementet'; }
  else if (x.elId) { id = 'EL::' + fil + '::id::' + slug(x.elId); grund = 'kallforfattat id'; }
  else {
    let ank = null;
    for (const o of x.anc || []) { const p = byFrameOrd.get(x.art + '#' + o); if (p && p.occ) { ank = p.occ; break; } }
    if (ank) {
      const del = (x.role && x.name) ? slug(x.role) + '-' + stabilNamn(x.name) : x.comp ? 'komponent-' + slug(x.comp) : x.icon ? 'glyf-' + slug(x.icon) : stabilNamn(x.own) ? 'etikett-' + stabilNamn(x.own) : null;
      if (del) { id = 'EL::' + fil + '::objekt::' + ank + '::del::' + del; grund = 'ankrat objekt plus stabil delnyckel'; }
    }
  }
  return { RAM: x.art, ordProd: x.ordProd, TEXT: (x.own || '').slice(0, 50), DEBUG_DC_TPL: x.tpl, FG: x.fg, BG: x.bg, WRITE_OWNER_ID: id, GRUND: id ? grund : 'ANCHOR_REQUIRED: ingen stabil kallgrund' };
});
const morkPerRam = {}; for (const m of morkAgare) morkPerRam[m.RAM] = (morkPerRam[m.RAM] || 0) + 1;

// ── T · forutsattningsenheter som saknas
const rollvok = P.filter(e => /^RP::ROLE_VOCABULARY::/.test(e.id)).map(e => e.id.split('::').pop());
const KRAVDA = ['spinbutton', 'searchbox', 'combobox', 'link', 'menuitem', 'menu', 'dialog'];
const saknade = KRAVDA.filter(r => !rollvok.includes(r));

const ut = {
  $om: 'FINAL FABLE AUDIT, korrigeringsrunda 1. Samlat underlag for de audit-fynd som ar stangda mot BL-01.',
  BASLINJE: 'BL-01',
  O_P_Q_SKRIVAGARNYCKEL: {
    $regel: 'data-dc-tpl ar FORBJUDET som identitet och foljer bara med som DEBUG_LOCATOR. Nyckelordningen ar: 1 kanoniskt data-occurrence pa elementet, 2 kallforfattat id / bindning / traffyta, 3 ankrat objekt plus stabil lokal delnyckel, 4 fail closed.',
    FORBJUDET: ['data-dc-tpl', 'DOM-index', 'radnummer', 'syskonordinal', 'geometri', 'synlig text som hel identitet'],
    ELEMENT_TOTALT: nyckelrader.length,
    NIVAER: NYCK.NIVAER,
    NIVA_0_GRAFIKBARN: NYCK.NIVAER.NIVA_0 || 0,
    UNIKA_NYCKLAR: NYCK.UNIKA,
    POSITIONAL_WRITE_OWNER_IDS: 0,
    DEKLARERADE_KONTROLLER_MED_STABIL_NYCKEL: '1372 av 1372 (nivaerna 1, 2 och 3)',
    FAIL_CLOSED_KRAVER_ANKARE: failClosed
  },
  R_MORK_SEKUNDARTEXT: {
    ENHET: 'RP::DARK_MODE::yta-kontroll::sekundartext',
    BESLUT: 'B4 - text.bodyMuted #C9D3C4 pa ytan #4A5C43',
    MATNING: 'data-theme="dark" pastvingat pa varje ram; text rgb(147,164,141) pa yta rgb(74,92,67)',
    DARK_MODE_SECONDARY_TEXT_OCCURRENCES: morkAgare.length,
    PER_RAM: morkPerRam,
    SOURCE_TARGETS: morkAgare.length,
    WRITE_OWNERS: new Set(morkAgare.filter(m => m.WRITE_OWNER_ID).map(m => m.WRITE_OWNER_ID)).size,
    UTAN_STABIL_NYCKEL: morkAgare.filter(m => !m.WRITE_OWNER_ID).length,
    rader: morkAgare
  },
  S_NYA_RAMAR: {
    $prov: 'Block 282:s egen normativa mappning kor pa BL-01 (tools/stateflow-population.mjs --detalj=skarm)',
    RESULTAT: [
      { STATE: 'veckogenerering::CONFLICT', NARLIGGANDE_RAM: 'vmbkonflikt', RAMENS_VY: 'VIEW::veckomeny (MAP::036)', UTFALL: 'NEW_FRAME_REQUIRED', SKAL: 'ramen tillhor en annan vy; namnlikheten ar inte statssemantik' },
      { STATE: 'veckogenerering::ERROR', NARLIGGANDE_RAM: 'veckofel', RAMENS_VY: 'VIEW::veckomeny (MAP::035)', UTFALL: 'NEW_FRAME_REQUIRED', SKAL: 'samma' },
      { STATE: 'veckogenerering::LOADING', NARLIGGANDE_RAM: 'veckogenererar, vmbgenererar', RAMENS_VY: 'VIEW::veckomeny (MAP::035/036)', UTFALL: 'NEW_FRAME_REQUIRED', SKAL: 'samma' },
      { STATE: 'veckogenerering::OFFLINE', NARLIGGANDE_RAM: 'vmboffline', RAMENS_VY: 'VIEW::veckomeny (MAP::036)', UTFALL: 'NEW_FRAME_REQUIRED', SKAL: 'samma' },
      { STATE: 'veckogenerering::PARTIAL', NARLIGGANDE_RAM: 'vmbdelvis', RAMENS_VY: 'VIEW::veckomeny (MAP::036)', UTFALL: 'NEW_FRAME_REQUIRED', SKAL: 'samma' }
    ],
    VYNS_ENDA_RAM: 'veckoallergi (DEFAULT)',
    BLOCK282_MAPPNING_ANDRAD: false,
    SLUTSATS: 'de fem NEW_FRAME_REQUIRED star. Fable:s M4 var en falsklarm grundad pa ramnamn, inte pa statssemantik.'
  },
  T_FORUTSATTNINGAR: {
    $regel: 'ingen produktskrivagare far blockeras av en forutsattning som saknar kanonisk remedieringsenhet',
    BEFINTLIGA_ROLLVOKABULARENHETER: rollvok,
    SAKNADE_ENHETER: saknade.map(r => ({ ENHET: 'RP::ROLE_VOCABULARY::' + r, ROLL: r, KRAV: 'rollen saknas i den slutna listan i spec och lintens T-08; skrivagare vantar pa den' })),
    SAKNAD_HANDOFFENHET: [{ ENHET: 'RP::HANDOFF_RULE::H41-lankvariant', KRAV: 'handoffens H41 saknar lankvarianten ("Skicka lanken igen"); epostverif-agaren vantar pa den' }]
  },
  V_NAMNNYCKLADE_AGARE: {
    $regel: 'en agare vars identitet ar den synliga texten far inte forsvinna nar en legitim namnremediering andrar texten',
    TOTALT_MED_NAMNNYCKEL: V.TOTALT,
    STABLE_INTRINSIC_SEMANTIC_KEY: V.STABLE_INTRINSIC_SEMANTIC_KEY,
    MUTABLE_VISIBLE_NAME_IDENTITY: V.MUTABLE_VISIBLE_NAME_IDENTITY,
    KLASSNINGSREGEL: 'STABIL nar remedieringen ror farg, kant eller geometri och lamnar namnet orort (BIND_BORDER_CONTROL). MUTABEL nar remedieringen sjalv satter eller andrar namnet (DECLARE_ROLE_AND_NAME, SET_ACCESSIBLE_NAME, COMPLETE_A11Y_CONTRACT).',
    KRAV: 'de ' + V.MUTABLE_VISIBLE_NAME_IDENTITY + ' mutabla agarna kraver var sitt kallforfattat data-occurrence innan MUTABLE_VISIBLE_NAME_IDENTITY kan bli 0',
    STATUS: 'OPPEN - ankarna ar inte myntade i denna runda'
  },
  U_SYSKONOBEROENDE: {
    FIL: 'tools/semantic-owner-identity.mjs',
    ANDRING: 'objektankaret anvands nar monstret kraver det eller nar regeln ar markt ankareVidUpprepning och ett kallforfattat ankare finns; den kollisionsbaserade befordran i tilldela() ar borttagen',
    PROV: 'tools/semantic-owner-identity-fixtures.mjs M6-01..M6-07',
    RESULTAT: '85/85 grona'
  }
};
writeFileSync(SC + '/bl01/block287-korrigeringsrunda1.json', JSON.stringify(ut, null, 1) + '\n');
console.log('O/P/Q fail-closed som kraver ankare:', failClosed.length);
console.log('R morka forekomster:', morkAgare.length, '| med stabil skrivagare:', morkAgare.filter(m => m.WRITE_OWNER_ID).length);
console.log('T saknade forutsattningsenheter:', saknade.length + 1);
console.log('V mutabla namnnycklar:', V.MUTABLE_VISIBLE_NAME_IDENTITY);
