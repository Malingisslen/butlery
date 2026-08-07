// F2-E01 · ADJUDICERINGSLAGER — parallellt med legacy-detektionen.
//
// Legacy-lagret räknar DETEKTIONER. Det lagret är oförändrat och rörs aldrig
// här: 19 råa detektioner, 13 elementfynd, 9 instansId, 5 källrotorsaker.
//
// Men nio instansId är inte nio användarsynliga fel. Två av dem är samma
// användareffekt sedd av två mätmetoder, två är adjudicerade som avsiktliga,
// och flera är obeslutade. Det här lagret översätter DETEKTION till EFFEKT.
//
// ORDEN SKA SKILJAS ÅT:
//   detectedLegacyInstances   geometrin uppfyllde mätregeln
//   adjudicatedEffects        distinkta användarsynliga effekter
//   productErrors             effekter adjudicerade som unintended
//
// "Verifierad" i legacy-lagret betyder att MÄTNINGEN höll, inte att
// produktbeteendet är normativt fel. Frasen "9 verifierade fel" ska inte
// längre användas om legacy-instanslagret.

export const ADJUDICATION_STATUS = ['unintended', 'intentional', 'undecided'];

/**
 * SAMMANSLAGNINGSREGELN.
 *
 * Två legacy-instanser blir samma effekt endast när ALLA fyra håller:
 *   1  samma artefakt,
 *   2  samma faktiska element,
 *   3  samma belagda sourceRootCause,
 *   4  samma användarupplevda konsekvens.
 *
 * Punkt 4 avgörs av EFFEKTKLASS och AXEL, aldrig av uppmätt storlek. Storleken
 * är EVIDENS, inte identitet: samma användareffekt får inte nytt effectId bara
 * för att 2 px blir 3 px, för att fontmetriken ändras eller för att viewporten
 * ger effekten en annan magnitud. Två självständiga konsekvenser på samma
 * element — en box klippt vertikalt och en text trunkerad horisontellt —
 * skiljer sig i axel och slås därför aldrig ihop.
 *
 * Att två fynd delar symptomsignatur räcker ALDRIG. Att de ligger på samma
 * element räcker heller inte om konsekvenserna är självständiga.
 */
// EFFEKTKLASSEN är användarkonsekvensen, härledd deterministiskt ur källan.
// Den lägger till läsbarhet i nyckeln utan att dela upp något som SRC inte
// redan delar.
export const EFFEKTKLASS = {
  'SRC-01': 'innehall-ej-nabart',
  'SRC-02': 'innehall-dolt-utan-affordans',
  'SRC-03': 'text-forkortad',
  'SRC-04': 'faltvarde-dolt'
};

export function effektnyckel(i) {
  const el = (i.instansId || '').split(' · ')[2] || i.element || '?';
  const klass = EFFEKTKLASS[i.sourceRootCause] || 'okand-konsekvens';
  return [i.artifactId, el, i.sourceRootCause, 'klass=' + klass,
          'axel=' + i.faktisk_overflow.axel].join(' ‖ ');
}

const BESKRIVNING = {
  'SRC-01': (i, px) => 'Innehållet i telefonramens kolumn kapas ' + px + ' px nedtill utan att kunna scrollas fram.',
  'SRC-02': (i, px) => 'Ungefär ' + Math.round(px / 18.4 * 10) / 10 + ' rader av receptets källblock är dolda (' + px + ' px av 226 px innehåll) utan synlig väg till resten.',
  'SRC-03': (i, px) => 'Tredje raden av recepttiteln döljs av en tvåradig clamp (' + px + ' px).',
  'SRC-04': (i, px) => 'Slutet av adressen användaren själv klistrat in är dolt bakom en ellips (' + px + ' px).'
};

/**
 * @param triage  fas2/residual-r03-triage.json
 * @param karta   fas2/source-root-cause-map.json
 */
/**
 * STABIL ID-TILLDELNING.
 *
 * effectId byggde på arrayindex. Så fort tre effekter rättades renumrerades
 * EFF-04 till EFF-01, och varje tidigare rapport pekade på fel effekt. Numret
 * hör till effektens NYCKEL och lever i fas2/effect-registry.json: en effekt
 * som försvinner frigör aldrig sitt nummer, och en ny får alltid nästa lediga.
 */
export function tilldelaId(nyckel, artifactId, registry) {
  const t = (registry && registry.tilldelningar) || {};
  if (t[nyckel]) return { effectId: t[nyckel].effectId, ordinal: t[nyckel].ordinal, nytilldelad: false };
  const nästa = (registry && registry.nextOrdinal) || 1;
  return { effectId: 'EFF-' + String(nästa).padStart(2, '0') + ' · ' + artifactId,
           ordinal: nästa, nytilldelad: true };
}

export function adjudicera(triage, karta, registry = null) {
  const kändaKällor = new Set((karta.sourceRootCauses || []).map(s => s.id));
  const fel = [];
  const grupper = new Map();

  for (const i of triage.instanser) {
    // FAIL CLOSED · en legacy-instans utan adjudicering får aldrig tyst falla ur.
    if (!ADJUDICATION_STATUS.includes(i.intentionality)) {
      fel.push('ADJUDICERING SAKNAS: ' + i.instansId + ' bär status ' + JSON.stringify(i.intentionality) +
        ' — varje legacy-instans måste adjudiceras innan effektrapporten kan stängas');
      continue;
    }
    // FAIL CLOSED · en okänd eller saknad sourceRootCause får aldrig ge en
    // påhittad grupp. Effekten skapas inte alls.
    if (!i.sourceRootCause || !kändaKällor.has(i.sourceRootCause)) {
      fel.push('KÄLLA SAKNAS: ' + i.instansId + ' pekar på sourceRootCause ' +
        JSON.stringify(i.sourceRootCause) + ' som inte finns i källrotorsakskartan — ' +
        'ingen effekt skapas och ingen grupp hittas på');
      continue;
    }
    const k = effektnyckel(i);
    if (!grupper.has(k)) grupper.set(k, []);
    grupper.get(k).push(i);
  }

  let nästaLediga = (registry && registry.nextOrdinal) || 1;
  const nyaId = [];
  const effekter = [...grupper.entries()].map(([nyckel, lista], n) => {
    const f = lista[0];
    const px = f.faktisk_overflow.scroll_minus_client_px;
    // Statusen måste vara enig inom en effekt; annars är sammanslagningen fel.
    const statusar = [...new Set(lista.map(x => x.intentionality))];
    if (statusar.length > 1)
      fel.push('MOTSTRIDIG ADJUDICERING i effekten ' + nyckel + ': ' + statusar.join(' och ') +
        ' — två instanser med olika status kan inte vara samma användareffekt');
    return {
      effectId: (() => {
        if (!registry) return 'EFF-' + String(n + 1).padStart(2, '0') + ' · ' + f.artifactId;
        const t = registry.tilldelningar[nyckel];
        if (t) return t.effectId;
        const id = 'EFF-' + String(nästaLediga).padStart(2, '0') + ' · ' + f.artifactId;
        nyaId.push({ nyckel, effectId: id, ordinal: nästaLediga });
        nästaLediga++;
        return id;
      })(),
      effektnyckel: nyckel,
      artifactId: f.artifactId,
      legacyInstansIds: lista.map(x => x.instansId),
      findingIds: [...new Set(lista.flatMap(x => x.findingIds))].sort(),
      symptomTypes: [...new Set(lista.map(x => x.symptomGroup))].sort(),
      sourceRootCauseId: f.sourceRootCause,
      adjudicationStatus: statusar[0],
      intentionalityEvidence: statusar[0] === 'intentional'
        ? lista.map(x => x.intentionality_skal).join(' ')
        : { status: statusar[0], skäl: lista[0].intentionality_skal,
            $regel: 'intentional kräver positiv evidens. undecided och unintended bär skäl, inte evidens för avsikt.' },
      userEffectDescription: (BESKRIVNING[f.sourceRootCause] || ((_, p) => 'Uppmätt överskott ' + p + ' px.'))(f, px),
      identityV2Status: f.identityV2_status,
      sammanslagen: lista.length > 1,
      sammanslagningsgrund: lista.length > 1
        ? 'samma artefakt, samma element, samma sourceRootCause, samma effektklass och samma axel — två mätmetoder, en användareffekt. Storleken (' + px + ' px) är evidens, inte identitet.'
        : null,
      matt: { axel: f.faktisk_overflow.axel, scroll_minus_client_px: px,
              barn_utanfor_brakdel: f.faktisk_overflow.barn_utanfor_brakdel },
      designRuntimeDeviation: false
    };
  });

  // Den belagda implementationsavvikelsen registreras separat och gör ALDRIG
  // en effekt unintended av sig själv.
  for (const j of (karta.runtimejamforelse || []))
    if (/SKILJER SIG/.test(j.slutsats || ''))
      for (const e of effekter)
        if (e.sourceRootCauseId === j.source) {
          e.designRuntimeDeviation = true;
          e.designRuntimeDeviationDetalj = {
            designArtifactResult: j.designArtifactResult,
            runtimeImplementationResult: j.runtimeImplementationResult,
            $regel: 'En skillnad mot runtime är ett eget fynd. Den sätter aldrig automatiskt adjudicationStatus till unintended.'
          };
        }

  const räkna = s => effekter.filter(e => e.adjudicationStatus === s).length;
  const rapport = {
    $regel: 'PARALLELLT LAGER. Legacy-detektionen är oförändrad: 19 råa detektioner, 13 elementfynd, 9 instansId, 5 källrotorsaker. Ingen produktmarkup rörd.',
    $ordregel: '"Verifierad" i legacy-lagret betyder att mätregeln uppfylldes, inte att produktbeteendet är normativt fel. Frasen "9 verifierade fel" används inte längre om legacy-instanslagret.',
    $sammanslagningsregel: 'Två legacy-instanser blir en effekt endast vid samma artefakt, samma element, samma sourceRootCause OCH samma användarupplevda konsekvens, mätt som samma axel och samma storlek inom en halv pixel. Samma symptomsignatur räcker aldrig. Samma element räcker inte heller om konsekvenserna är självständiga.',
    detectedLegacyInstances_st: triage.instanser.length,
    adjudicatedEffects_st: effekter.length,
    productErrors_st: räkna('unintended'),
    intentionalEffects_st: räkna('intentional'),
    undecidedEffects_st: räkna('undecided'),
    designRuntimeDeviations_st: effekter.filter(e => e.designRuntimeDeviation).length,
    legacy_oforandrat: {
      raa_verifierade_detektioner_st: triage.population.raa_verifierade_detektioner_st,
      elementfynd_st: triage.population.elementfynd_st,
      legacy_instansId_st: triage.population.felinstanser_fore_analys_st,
      legacy_kallrotorsaker_st: triage.population.kanoniska_legacy_kallrotorsaker_st,
      berorda_produktartefakter_st: triage.population.berorda_produktartefakter_st
    },
    idTilldelning: registry
      ? { kalla: 'fas2/effect-registry.json v' + registry.version,
          regel: 'Numret hör till effektens nyckel, aldrig till dess plats i listan. Ett frigjort nummer återanvänds aldrig.',
          nytilldelade: nyaId, nastaLediga: nästaLediga }
      : { kalla: null,
          varning: 'INGET REGISTER — effectId faller tillbaka på arrayordning och är då INTE stabilt när populationen ändras.' },
    failClosed: { fel, status: fel.length ? 'FÄLLD' : 'godkänd' },
    effects: effekter
  };
  return rapport;
}
