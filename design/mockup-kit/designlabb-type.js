'use strict';
// Type scale by ratio and ready-made heading + body font pairs.

const TYPE_TIERS = {
  'calendar-cell': -2, 'nav-label': -2, overline: -2, caption: -1, chip: -1, meta: -1, tab: -1, 'list-item': -1,
  body: 0, 'body-medium': 0, label: 0, stepper: 0, 'card-title': 1, 'cooking-step': 1, title: 2, 'display-compact': 3, display: 4, stat: 4,
};
const TYPE_RATIOS = [['', 'Appens egna'], ['1.125', 'Liten steg (1,125)'], ['1.2', 'Mjuk (1,2)'], ['1.25', 'Tydlig (1,25)'], ['1.333', 'Stark (1,333)'], ['1.5', 'Dramatisk (1,5)']];
const HEAD_FONTS = { 'Fraunces': 1, 'Playfair Display': 1, 'Lora': 1, 'Poppins': 1, 'DM Sans': 1, 'Nunito': 1, 'Georgia': 1, 'Inter': 1 };

function applyTypeScale(ratio) {
  state.typeRatio = ratio;
  const base = sizes.get('body') || 16;
  for (const [role, px] of sizes) {
    const tier = TYPE_TIERS[role];
    const r = (state.roles[role] ||= {});
    if (!ratio || tier == null) delete r.size;
    else r.size = Math.round(base * Math.pow(+ratio, tier) * 2) / 2;
    if (!Object.keys(r).length) delete state.roles[role];
  }
}

function wireType() {
  const ratio = document.getElementById('type-ratio');
  for (const [v, l] of TYPE_RATIOS) ratio.add(new Option(l, v));
  ratio.onchange = () => { applyTypeScale(ratio.value); syncUi(); };
  const head = document.getElementById('font-head');
  head.add(new Option('Samma som brödtext', ''));
  for (const f of Object.keys(HEAD_FONTS)) head.add(new Option(f, f));
  head.onchange = () => { state.fontHead = head.value; loadFont(); render(); };
}
