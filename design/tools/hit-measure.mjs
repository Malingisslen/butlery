// F2-R02 · MÄTSKRIPTET FÖR TRÄFFYTOR, utbrutet så att proven kör exakt samma
// kod som en skarp körning.
//
// Skriptet DÖMER INTE. Det samlar in rådata — deklarationen som den står,
// kandidaterna som bär det utpekade target-id:t, och de renderade måtten — och
// låter tools/hit-contract.mjs avgöra. Det finns bara en parser, och den bor
// på ett ställe.
//
// Ligger MEDVETET skilt från render-measure.mjs. R-01 och R-03 ska kunna
// bevisas byteidentiska över den här metodcommiten, och det kan de inte om
// deras mätskript ändras.

export const HIT_MEASURE = `(() => {
  const AKTIVERBAR = 'a[href], button, input, select, textarea, [onclick], [tabindex]:not([tabindex="-1"]), [contenteditable="true"]';
  const rendered = el => { const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0 && getComputedStyle(el).display !== 'none'; };
  const rect = el => { const r = el.getBoundingClientRect();
    return { w: +r.width.toFixed(2), h: +r.height.toFixed(2) }; };

  // Referensen är ett explicit attributvärde. Uppslaget görs över HELA
  // dokumentet med avsikt: en target som ligger i fel artefakt ska upptäckas
  // och rapporteras som valideringsfel, inte tyst missas.
  function kandidater(id) {
    if (!id) return [];
    return [...document.querySelectorAll('[data-hit-target]')]
      .filter(e => e.getAttribute('data-hit-target') === id);
  }
  const TARGET = /^target:([A-Za-z][A-Za-z0-9_-]{0,63})$/;

  const poster = [];
  for (const c of document.querySelectorAll('[data-a11y-role], [data-hit]')) {
    const roll = c.getAttribute('data-a11y-role');
    const it = c.closest('.sc-item');
    const dataHit = c.getAttribute('data-hit');
    const m = dataHit ? String(dataHit).trim().match(TARGET) : null;
    const kand = m ? kandidater(m[1]) : [];
    poster.push({
      artifactId: it ? it.id : null,
      iRegistreradArtefakt: !!it,
      roll: roll || null,
      namn: c.getAttribute('data-a11y-name') || null,
      tag: c.tagName.toLowerCase(),
      dataHit: dataHit === null ? null : dataHit,
      sjalvAktiverbar: c.matches(AKTIVERBAR),
      egenRect: rect(c),
      renderad: rendered(c),
      // ALLA kandidater rapporteras. Att välja bland dem är ett domslut, och
      // domsluten fattas inte här.
      targetKandidater: kand.map(t => ({
        id: t.getAttribute('data-hit-target'),
        inomArtefakt: !!it && it.contains(t),
        renderad: rendered(t), ...rect(t) })),
      // Separata klickytor unioneras ALDRIG. Antalet rapporteras så att en
      // fabricerad sammanhängande bounding box kan fällas som just fabricerad.
      hitOar_st: kand.length
    });
  }
  return { viewport: { w: innerWidth, h: innerHeight, dpr: devicePixelRatio, unit: 'css-px' },
    fontsReady: document.fonts ? document.fonts.status : 'saknas', poster };
})()`;
