// Renders every sketch frame in design/sketch-frames.json to a PNG.
//
//   PLAYWRIGHT_DIR=<dir that holds node_modules/playwright-core> \
//     node tools/sketch_render.mjs <outDir> [keyPrefix]
//
// The frame key is "<file tag>#<order>"; order counts the .sc-item blocks in
// the file and the json id is the text of that block's .sc-id link, so a key
// whose id no longer matches is reported instead of silently drawing another frame.
import { createRequire } from 'node:module';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import path from 'node:path';

const { chromium } = createRequire(path.resolve(process.env.PLAYWRIGHT_DIR ?? '.') + '/')('playwright-core');

const [outDir, prefix = ''] = process.argv.slice(2);
if (!outDir) throw new Error('usage: sketch_render.mjs <outDir> [keyPrefix]');
mkdirSync(outDir, { recursive: true });

const frames = JSON.parse(readFileSync('design/sketch-frames.json', 'utf8')).frames;
const byFile = new Map();
for (const [key, f] of Object.entries(frames)) {
  if (!key.startsWith(prefix)) continue;
  if (!byFile.has(f.file)) byFile.set(f.file, []);
  byFile.get(f.file).push([key, f.id]);
}

const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH ?? '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
});
const report = { rendered: [], mismatched: [], failed: [] };
for (const [file, entries] of byFile) {
  const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
  await page.goto(pathToFileURL(path.resolve('design', file)).href);
  await page.waitForSelector('.sc-item');
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(800);
  const items = await page.$$('.sc-item');
  for (const [key, id] of entries) {
    const order = Number(key.split('#')[1]);
    const el = items[order - 1];
    try {
      const label = el ? await el.$eval('.sc-id', (a) => a.textContent.trim()).catch(() => null) : null;
      if (label !== id) {
        report.mismatched.push({ key, id, found: label });
        continue;
      }
      const theme = await el.getAttribute('data-theme');
      const body = await el.evaluateHandle((e) => [...e.children].find((c) => !c.classList.contains('sc-label')) ?? e);
      await body.asElement().screenshot({ path: path.join(outDir, `${key.replace('#', '_')}.png`) });
      report.rendered.push({ key, id, theme });
    } catch (e) {
      report.failed.push({ key, id, error: String(e).slice(0, 160) });
    }
  }
  await page.close();
}
await browser.close();
writeFileSync(path.join(outDir, 'report.json'), JSON.stringify(report, null, 1));
console.log(`rendered ${report.rendered.length}, mismatched ${report.mismatched.length}, failed ${report.failed.length}`);
