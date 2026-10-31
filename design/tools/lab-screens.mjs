// The n-th screen of the lab (0-based; each is drawn once light and once dark) and the golden it copies.
export const SCREENS = [
  ['mina_recept', 0], ['mina_recept_lista', 1], ['receptdetalj_fullt', 2], ['recepteditor', 3], ['matlagningslage', 4], ['inloggning', 5],
  ['mer', 6], ['inkopslista', 7], ['skafferi', 8], ['veckomeny', 9], ['veckogenerering_6s', 10], ['vantar_pa_synk', 11],
];

// A golden taller than the phone shows the whole page unscrolled; the lab's screen of it is drawn at that height, with
// its scrolling part at full length, so the two can be laid on top of each other.
export async function fitPhone(page, phone, height) {
  if (height <= 800) return;
  const vp = page.viewportSize();
  if (vp.height < height + 100) await page.setViewportSize({ width: vp.width, height: height + 100 });
  await phone.evaluate((p, h) => {
    p.style.height = `${h}px`;
    for (const s of p.querySelectorAll('.b-scroll')) s.style.overflow = 'hidden';
  }, height);
}
