'use strict';
// Draws the example screens as the lab shows them right now, so a hand-over to Claude carries pictures
// of what is to be built and not only numbers. The page is drawn into an SVG image, so the lab's own
// stylesheets, fonts and icon sprite are what end up in the picture.

async function labCss() {
  const out = [];
  for (const sheet of [...document.styleSheets, ...(document.adoptedStyleSheets || [])]) {
    if (sheet.disabled) continue;
    try { for (const rule of sheet.cssRules) out.push(rule.cssText); } catch {
      // A linked sheet the page may not read rule by rule is read as text instead.
      if (sheet.href) out.push(await fetch(sheet.href).then(r => r.text()).catch(() => ''));
    }
  }
  // The picture is not scrolled, so no scrollbar takes width from the content.
  out.push('*{scrollbar-width:none}');
  return out.join('\n');
}

function shotOf(phone, css, sprite) {
  const w = Math.round(phone.offsetWidth), h = Math.round(phone.offsetHeight);
  const copy = phone.cloneNode(true);
  // The phone is shown flat, as the app's golden pictures are.
  copy.style.borderRadius = '0';
  copy.style.boxShadow = 'none';
  const xhtml = 'http://www.w3.org/1999/xhtml';
  const body = new XMLSerializer().serializeToString(copy);
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><foreignObject width="100%" height="100%">`
    + `<div xmlns="${xhtml}" style="${document.documentElement.getAttribute('style') || ''}"><style><![CDATA[${css.replace(/]]>/g, ']]\\>')}]]></style>${sprite}${body}</div></foreignObject></svg>`;
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      const c = document.createElement('canvas');
      c.width = w; c.height = h;
      const x = c.getContext('2d');
      x.fillStyle = '#fff'; x.fillRect(0, 0, w, h);
      x.drawImage(img, 0, 0);
      resolve(c.toDataURL('image/jpeg', 0.72));
    };
    img.onerror = () => { const bad = new DOMParser().parseFromString(svg, 'image/svg+xml').querySelector('parsererror'); reject(new Error('screen not drawn' + (bad ? ': ' + bad.textContent.slice(0, 160) : ''))); };
    img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
  });
}

// One picture for every screen that is showing: { 'screen3-light': dataUrl, ... }
async function labShots() {
  const css = await labCss();
  const sym = document.querySelector('svg symbol')?.closest('svg');
  let sprite = '';
  if (sym) {
    const flat = sym.cloneNode(true);
    flat.setAttribute('style', 'position:absolute;width:0;height:0');
    sprite = new XMLSerializer().serializeToString(flat);
  }
  const shots = {};
  const figs = [...document.querySelectorAll('#screens > figure')];
  for (const [i, fig] of figs.entries()) {
    const phone = fig.querySelector('.phone');
    if (!phone || !phone.offsetWidth) continue;
    const dark = fig.classList.contains('fig-dark');
    try { shots[`screen${Math.floor(i / 2) + 1}-${dark ? 'dark' : 'light'}`] = await shotOf(phone, css, sprite); } catch (e) { console.warn(e); }
  }
  return shots;
}
