// Draws every example screen of designlabb.html, light and dark, next to the app's Linux golden of the same screen
// and reports how far apart they are. The goldens are test/views/golden_linux/goldens/*.png, 360 x 800.
//   node design/tools/lab-golden-compare.mjs [outDir] [screen,screen]   writes <screen>-<mode>.png (golden | lab | difference)
//   PLAYWRIGHT_MODULE=<path to playwright/index.mjs>   when playwright is not resolvable from here
// "strict" counts every pixel that differs by more than 24/255, with no tolerance for text edges.
// "diff" is the share of pixels that differ by more than 24/255 in some channel AND have no pixel of that colour within
// 2 px in the other picture, so the lab and the app drawing text edges differently does not count, but a part that sits
// 3 px off or has another size or colour does. Read the images, not only the number.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('../../', import.meta.url).pathname;
const out = process.argv[2] ?? '/tmp/lab-golden';
const only = process.argv[3]?.split(',');
mkdirSync(out, { recursive: true });
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE ?? 'playwright');

import { SCREENS } from './lab-screens.mjs';

const goldenDir = join(root, 'test/views/golden_linux/goldens');
const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
await page.goto('file://' + join(root, 'design/mockup-kit/designlabb.html'));
await page.addStyleTag({ content: '.phone{border-radius:0!important;box-shadow:none!important}' });
await page.waitForTimeout(1500);
const figs = await page.$$('#screens figure');

const results = [];
for (const mode of ['light', 'dark']) {
  await page.click(`button[data-view="${mode}"]`);
  await page.mouse.move(0, 0);
  await page.waitForTimeout(400);
  for (const [name, idx] of SCREENS) {
    if (only && !only.includes(name)) continue;
    const phone = await figs[idx * 2 + (mode === 'dark' ? 1 : 0)].$('.phone');
    const goldenBuf = readFileSync(join(goldenDir, `${name}_${mode}.png`));
    const gw = goldenBuf.readUInt32BE(16), gh = goldenBuf.readUInt32BE(20);
    await phone.scrollIntoViewIfNeeded();
    const box = await phone.boundingBox();
    const lab = (await page.screenshot({ clip: { x: Math.round(box.x), y: Math.round(box.y), width: gw, height: gh } })).toString('base64');
    const golden = goldenBuf.toString('base64');
    const r = await page.evaluate(async ([g, l]) => {
      const load = b64 => new Promise(res => { const i = new Image(); i.onload = () => res(i); i.src = 'data:image/png;base64,' + b64; });
      const [gi, li] = await Promise.all([load(g), load(l)]);
      const w = gi.naturalWidth, h = gi.naturalHeight;
      const read = img => { const c = document.createElement('canvas'); c.width = w; c.height = h; const x = c.getContext('2d'); x.drawImage(img, 0, 0, w, h); return x.getImageData(0, 0, w, h); };
      if (li.naturalWidth !== w || li.naturalHeight !== h) return { diff: 1, png: '', size: `lab ${li.naturalWidth}x${li.naturalHeight} golden ${w}x${h}` };
      const a = read(gi), b = read(li);
      const c = document.createElement('canvas'); c.width = w * 3 + 20; c.height = h; const x = c.getContext('2d');
      x.fillStyle = '#888'; x.fillRect(0, 0, c.width, h);
      x.drawImage(gi, 0, 0, w, h); x.drawImage(li, w + 10, 0, w, h);
      const d = x.createImageData(w, h); let bad = 0, strict = 0;
      const far = (p, q, i) => Math.max(Math.abs(p[i] - q[i]), Math.abs(p[i + 1] - q[i + 1]), Math.abs(p[i + 2] - q[i + 2])) > 24;
      // A pixel counts as different when no pixel within 2 px of it in the other picture has its colour.
      const near = (p, q, px, py) => {
        for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) {
          const nx = px + dx, ny = py + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          const j = (ny * w + nx) * 4, i = (py * w + px) * 4;
          if (Math.max(Math.abs(p[i] - q[j]), Math.abs(p[i + 1] - q[j + 1]), Math.abs(p[i + 2] - q[j + 2])) <= 24) return true;
        }
        return false;
      };
      for (let py = 0; py < h; py++) for (let px = 0; px < w; px++) {
        const i = (py * w + px) * 4;
        const on = far(a.data, b.data, i) && !(near(a.data, b.data, px, py) && near(b.data, a.data, px, py));
        if (on) bad++;
        if (far(a.data, b.data, i)) strict++;
        d.data[i] = on ? 224 : 255; d.data[i + 1] = on ? 69 : 255; d.data[i + 2] = on ? 123 : 255; d.data[i + 3] = 255;
      }
      x.putImageData(d, w * 2 + 20, 0);
      return { diff: bad / (w * h), strict: strict / (w * h), size: '', png: c.toDataURL('image/png').split(',')[1] };
    }, [golden, lab]);
    if (r.png) writeFileSync(join(out, `${name}-${mode}.png`), Buffer.from(r.png, 'base64'));
    results.push({ name, mode, diff: +(r.diff * 100).toFixed(2), strict: +((r.strict ?? 1) * 100).toFixed(2), size: r.size });
  }
}
await browser.close();
for (const r of results) console.log(`${r.name.padEnd(20)} ${r.mode.padEnd(6)} ${String(r.diff).padStart(6)} %  strict ${String(r.strict).padStart(6)} %${r.size ? '  ' + r.size : ''}`);
