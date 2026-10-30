// Measures where each icon, chip, button, count and card of the lab's example screens sits against the app's Linux golden,
// and writes the offsets it finds to design/mockup-kit/designlabb-nudges.js. The lab applies them as a CSS `translate`,
// so a part that the app draws 1-3 px from where the lab's markup puts it ends up on the same pixel.
//   node design/tools/lab-golden-nudge.mjs [--check]   --check only reports, and leaves the file as it is
//   node design/tools/lab-golden-nudge.mjs --refine    measures what is left with the current file applied and adds it
//   PLAYWRIGHT_MODULE=<path to playwright/index.mjs>   when playwright is not resolvable from here
// A part is moved only when the golden has an almost exact copy of it (at most 15 % of its pixels differ) within 7 px.
// The numbers are keyed by screen and by the part's position in querySelectorAll(NUDGE_PARTS) of that screen, so
// regenerate the file after editing a screen's markup.
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { SCREENS } from './lab-screens.mjs';

const root = new URL('../../', import.meta.url).pathname;
const check = process.argv.includes('--check');
const refine = process.argv.includes('--refine');
const PARTS = 'svg.i, .b-chip, .b-btn, .b-iconbtn, .b-count, .tile, .b-avatar, .b-checkbox, .b-input, .b-band, .mr-card, .b-stepper button';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE ?? 'playwright');
const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
await page.goto('file://' + join(root, 'design/mockup-kit/designlabb.html'));
await page.addStyleTag({ content: '.phone{border-radius:0!important;box-shadow:none!important}' });
await page.waitForTimeout(1500);
if (!refine) await page.evaluate(() => document.querySelectorAll('[style*="translate"]').forEach(e => { e.style.translate = ''; }));
const figs = await page.$$('#screens figure');
const nudges = {};
if (refine) {
  const old = readFileSync(join(root, 'design/mockup-kit/designlabb-nudges.js'), 'utf8');
  Object.assign(nudges, JSON.parse(old.match(/const NUDGES = (.*);/)[1]));
}
let moved = 0;
await page.click('button[data-view="light"]');
await page.mouse.move(0, 0);
await page.waitForTimeout(300);
for (const [name, idx] of SCREENS) {
  const goldenBuf = readFileSync(join(root, `test/views/golden_linux/goldens/${name}_light.png`));
  const gw = goldenBuf.readUInt32BE(16), gh = goldenBuf.readUInt32BE(20);
  const phone = await figs[idx * 2].$('.phone');
  await phone.scrollIntoViewIfNeeded();
  const box = await phone.boundingBox();
  const lab = (await page.screenshot({ clip: { x: Math.round(box.x), y: Math.round(box.y), width: gw, height: gh } })).toString('base64');
  const parts = await figs[idx * 2].evaluate((f, sel) => {
    const ph = f.querySelector('.phone').getBoundingClientRect();
    return [...f.querySelectorAll(sel)].map((e, i) => {
      const r = e.getBoundingClientRect();
      // A chevron is a thin stroke that matches almost anywhere, so it is never moved.
      let anc = -1;
      for (let up = e.parentElement; up && up !== f; up = up.parentElement) {
        if (up.matches(sel)) { anc = [...f.querySelectorAll(sel)].indexOf(up); break; }
      }
      const thin = e.querySelector('use[href*="chevron"]') ? 1 : 0;
      return { i, anc, thin, x: Math.round(r.left - ph.left), y: Math.round(r.top - ph.top), w: Math.round(r.width), h: Math.round(r.height) };
    });
  }, PARTS);
  let found = await page.evaluate(async ([g, l, parts]) => {
    const load = b64 => new Promise(res => { const i = new Image(); i.onload = () => res(i); i.src = 'data:image/png;base64,' + b64; });
    const [gi, li] = await Promise.all([load(g), load(l)]);
    const w = gi.naturalWidth, h = gi.naturalHeight;
    const read = img => { const c = document.createElement('canvas'); c.width = w; c.height = h; const x = c.getContext('2d'); x.drawImage(img, 0, 0, w, h); return x.getImageData(0, 0, w, h).data; };
    const a = read(gi), b = read(li);
    const far = (i, j) => Math.max(Math.abs(a[i] - b[j]), Math.abs(a[i + 1] - b[j + 1]), Math.abs(a[i + 2] - b[j + 2])) > 40;
    const out = [];
    for (const p of parts) {
      if (p.thin || p.w < 7 || p.h < 7 || p.w > 200 || p.h > 200 || p.x < 0 || p.y < 0 || p.x + p.w > w || p.y + p.h > h) continue;
      let busy = 0;
      const b0 = (p.y * w + p.x) * 4;
      for (let y = 0; y < p.h; y++) for (let x = 0; x < p.w; x++) {
        const j = ((p.y + y) * w + p.x + x) * 4;
        if (Math.max(Math.abs(b[j] - b[b0]), Math.abs(b[j + 1] - b[b0 + 1]), Math.abs(b[j + 2] - b[b0 + 2])) > 40) busy++;
      }
      if (busy / (p.w * p.h) < 0.04) continue;
      const score = (dx, dy) => {
        let bad = 0;
        for (let y = 0; y < p.h; y++) for (let x = 0; x < p.w; x++) {
          if (far(((p.y + dy + y) * w + p.x + dx + x) * 4, ((p.y + y) * w + p.x + x) * 4)) bad++;
        }
        return bad / (p.w * p.h);
      };
      const here = score(0, 0);
      if (here <= 0.1) continue;
      let best = { d: here, dx: 0, dy: 0 };
      for (let dy = -7; dy <= 7; dy++) for (let dx = -7; dx <= 7; dx++) {
        if (p.y + dy < 0 || p.x + dx < 0 || p.y + dy + p.h > h || p.x + dx + p.w > w) continue;
        const d = score(dx, dy);
        if (d < best.d - 0.02) best = { d, dx, dy };
      }
      if (best.d <= 0.15 && (best.dx || best.dy)) out.push({ i: p.i, anc: p.anc, dx: best.dx, dy: best.dy });
    }
    return out;
  }, [goldenBuf.toString('base64'), lab, parts]);
  // A part inside a part that moves is carried along with it.
  found = found.filter(f => !found.some(o => o.i === f.anc));
  const have = nudges[name] ?? {};
  for (const f of found) {
    const [px, py] = have[f.i] ?? [0, 0];
    have[f.i] = [px + f.dx, py + f.dy];
  }
  if (found.length || Object.keys(have).length) nudges[name] = have;
  moved += found.length;
  console.log(`${name.padEnd(20)} ${found.length} part(s) to move`);
}
await browser.close();
if (check) process.exit(0);
const body = `'use strict';
// Written by design/tools/lab-golden-nudge.mjs; do not edit by hand. Offsets in px, by screen name and by the part's
// position in querySelectorAll(NUDGE_PARTS) of that screen: where the app's golden draws the part against the lab's markup.
const NUDGE_PARTS = '${PARTS}';
const NUDGES = ${JSON.stringify(nudges)};
`;
writeFileSync(join(root, 'design/mockup-kit/designlabb-nudges.js'), body);
console.log(`wrote design/mockup-kit/designlabb-nudges.js, ${moved} part(s)`);
