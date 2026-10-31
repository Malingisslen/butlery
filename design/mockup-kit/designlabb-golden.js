'use strict';
// "Golden" in the view bar puts the app's own picture of a screen beside the lab's, so a screen that
// has drifted from the app is seen at once. The pictures are the key-screen goldens of the app; a
// published copy of the lab carries them in window.LAB_GOLDENS, the repo copy reads them from the tree.
const GOLDEN_OF = ['mina_recept', 'hem', 'receptdetalj_fullt', 'recepteditor', 'matlagningslage', 'inloggning', 'mer', 'inkopslista', 'skafferi', 'veckomeny', 'veckogenerering_6s', 'vantar_pa_synk'];
const GOLDEN_DIR = '../../test/views/golden_linux/goldens/';
// Offsets measured against the goldens (design/tools/lab-golden-nudge.mjs), applied as a CSS translate.
(function nudgeToGolden() {
  document.querySelectorAll('#screens > figure').forEach((fig, i) => {
    const moves = NUDGES[GOLDEN_OF[Math.floor(i / 2)]];
    if (!moves) return;
    const parts = fig.querySelectorAll(NUDGE_PARTS);
    for (const [at, [dx, dy]] of Object.entries(moves)) if (parts[at]) parts[at].style.translate = `${dx}px ${dy}px`;
  });
})();
(function wireGolden() {
  const figs = [...document.querySelectorAll('#screens > figure')];
  figs.forEach((fig, i) => {
    const name = GOLDEN_OF[Math.floor(i / 2)];
    if (!name) return;
    const mode = fig.classList.contains('fig-dark') ? 'dark' : 'light';
    const img = document.createElement('img');
    img.className = 'golden-img';
    img.alt = `Appens golden: ${name}, ${mode === 'dark' ? 'mörkt' : 'ljust'}`;
    img.src = window.LAB_GOLDENS?.[`${name}_${mode}`] || `${GOLDEN_DIR}${name}_${mode}.png`;
    // A golden of a whole page is taller than the phone: it scrolls in a phone-high frame, along with the screen.
    const frame = document.createElement('div');
    frame.className = 'golden-frame';
    frame.append(img);
    fig.append(frame);
    const scroll = fig.querySelector('.phone .b-scroll');
    scroll?.addEventListener('scroll', () => { frame.scrollTop = scroll.scrollTop; });
  });
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.id = 'golden-toggle';
  btn.textContent = 'Golden bredvid';
  btn.onclick = () => {
    const on = document.body.classList.toggle('golden-on');
    btn.classList.toggle('on', on);
  };
  document.getElementById('viewbar').append(btn);
})();
