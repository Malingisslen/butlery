#!/usr/bin/env node
// Butlery · tokens.json → assets/generated/tokens.css
// Kör: node tools/gen-css.mjs   ·   Verifieras av tools/test-generated.mjs
import { readFileSync } from 'node:fs';
// GEMENSAM header. Fas 1 (andra vändan): importen saknades, så generatorn
// kraschade på "header is not defined" i varje körning — och de incheckade
// filerna kunde därför inte vara annat än stale.
import { header } from './gen-header.mjs';
// --check renderar till minnet och jämför byte för byte utan att skriva.
import { emit } from './gen-check.mjs';

const kebab = s => String(s).replace(/([a-z0-9])([A-Z])/g, '$1-$2').replace(/[._ ]+/g, '-').toLowerCase();
const isColor = v => typeof v === 'string' && (/^#[0-9A-Fa-f]{6}$/.test(v) || /^rgba?\(/.test(v));

function buildCss(t) {
  const light = [], dark = [];
  for (const [k, v] of Object.entries(t.semantic)) {
    const name = '--butlery-' + kebab(k);
    if (isColor(v.light)) light.push(name + ': ' + v.light + ';');
    if (isColor(v.dark)) dark.push(name + ': ' + v.dark + ';');
  }
  const fr = t.semantic.focusRing;
  light.push('--butlery-focus-width: ' + fr.width + ';');
  light.push('--butlery-focus-offset: ' + fr.offset + ';');
  for (const [k, v] of Object.entries(t.palette)) if (isColor(v)) light.push('--butlery-palette-' + kebab(k) + ': ' + v + ';');
  t.avatar.pairs.forEach((p, i) => {
    light.push('--butlery-avatar-' + (i + 1) + '-fill: ' + p.fill + ';');
    light.push('--butlery-avatar-' + (i + 1) + '-on-fill: ' + p.onFill + ';');
  });
  light.push('--butlery-avatar-self-ring: ' + t.avatar.selfRing + ';');
  t.space.scale.forEach(n => light.push('--butlery-space-' + n + ': ' + n + 'px;'));
  for (const [k, v] of Object.entries(t.space.layoutMargin)) light.push('--butlery-space-layout-margin-' + kebab(k) + ': ' + v + 'px;');
  for (const [k, v] of Object.entries(t.space.radius)) light.push('--butlery-radius-' + kebab(k) + ': ' + v + 'px;');
  for (const [k, r] of Object.entries(t.typography.roles)) {
    const n = kebab(k);
    light.push('--butlery-type-' + n + '-size: ' + r.size + 'px;');
    light.push('--butlery-type-' + n + '-weight: ' + r.weight + ';');
    if (r.tracking) light.push('--butlery-type-' + n + '-tracking: ' + r.tracking + ';');
  }
  for (const [k, v] of Object.entries(t.motion.durations)) light.push('--butlery-motion-' + kebab(k) + ': ' + v + 'ms;');
  light.push('--butlery-motion-easing: ' + t.motion.easing.standard + ';');
  light.push('--butlery-touch-min: ' + t.touchTarget.min + 'px;');
  light.push('--butlery-touch-gap: ' + t.touchTarget.minGap + 'px;');
  return { light, dark };
}

function renderCss(t) {
  const { light, dark } = buildCss(t);
  const ind = a => a.map(l => '  ' + l).join('\n');
  return [
    '/*',
    ...header({ generator: 'tools/gen-css.mjs', generatorVersion: '1.3', tokenVersion: t.version,
      inputs: ['tokens.json'], comment: '*', date: t.date }).lines,
    '*/',
    '',
    ':root {', ind(light.slice().sort()), '}',
    '',
    '[data-theme="dark"] {', ind(dark.slice().sort()), '}',
    '',
    '/* Träffytegolv — varje interaktiv komponent ärver detta */',
    '.butlery-hit {',
    '  min-width: var(--butlery-touch-min);',
    '  min-height: var(--butlery-touch-min);',
    '  box-sizing: border-box;',
    '}',
    '.butlery-hit:focus-visible {',
    '  outline: var(--butlery-focus-width) solid var(--butlery-focus-ring);',
    '  outline-offset: var(--butlery-focus-offset);',
    '}',
    ''
  ].join('\n');
}

const t = JSON.parse(readFileSync('tokens.json', 'utf8'));
const out = renderCss(t);
emit({ 'assets/generated/tokens.css': out }, { label: 'gen-css' });
const n = (out.match(/--butlery-/g) || []).length;
console.log('tokens.css skriven · ' + n + ' variabelreferenser');
