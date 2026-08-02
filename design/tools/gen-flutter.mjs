#!/usr/bin/env node
// Butlery · tokens.json → lib/theme/butlery_tokens.dart
// Kör: node tools/gen-flutter.mjs   ·   Verifieras av tools/test-generated.mjs + dart analyze
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const camel = s => String(s).replace(/[-_. ]+(.)/g, (m, c) => c.toUpperCase()).replace(/^(.)/, (m, c) => c.toLowerCase());
const isColor = v => typeof v === 'string' && (/^#[0-9A-Fa-f]{6}$/.test(v) || /^rgba?\(/.test(v));
const hx = n => Number(n).toString(16).padStart(2, '0').toUpperCase();

function argb(v) {
  if (v.startsWith('#')) return 'Color(0xFF' + v.slice(1).toUpperCase() + ')';
  const m = v.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)/);
  if (!m) throw new Error('Okänt färgformat i tokens.json: ' + v);
  const a = Math.round((m[4] === undefined ? 1 : parseFloat(m[4])) * 255);
  return 'Color(0x' + hx(a) + hx(m[1]) + hx(m[2]) + hx(m[3]) + ')';
}

function renderDart(t) {
  const L = [];
  L.push('// GENERERAD FIL — ändra tokens.json, inte den här.');
  L.push('// tokens ' + t.version + ' · ' + t.date + ' · generator tools/gen-flutter.mjs');
  L.push('// ignore_for_file: unused_field');
  L.push("import 'package:flutter/material.dart';");
  L.push('');

  L.push('class ButleryColors {');
  L.push('  const ButleryColors._();');
  for (const [k, v] of Object.entries(t.semantic)) {
    const n = camel(k);
    if (isColor(v.light)) L.push('  static const ' + n + ' = ' + argb(v.light) + ';');
    if (isColor(v.dark)) L.push('  static const ' + n + 'Dark = ' + argb(v.dark) + ';');
  }
  t.avatar.pairs.forEach((p, i) => {
    L.push('  static const avatar' + (i + 1) + 'Fill = ' + argb(p.fill) + ';');
    L.push('  static const avatar' + (i + 1) + 'OnFill = ' + argb(p.onFill) + ';');
  });
  L.push('  static const avatarSelfRing = ' + argb(t.avatar.selfRing) + ';');
  L.push('  static const avatarFills = <Color>[' + t.avatar.pairs.map(p => argb(p.fill)).join(', ') + '];');
  L.push('  static const avatarOnFills = <Color>[' + t.avatar.pairs.map(p => argb(p.onFill)).join(', ') + '];');
  L.push('}');
  L.push('');

  L.push('class ButlerySpace {');
  L.push('  const ButlerySpace._();');
  t.space.scale.forEach(n => L.push('  static const double s' + n + ' = ' + n + ';'));
  for (const [k, v] of Object.entries(t.space.layoutMargin)) L.push('  static const double layoutMargin' + String(k).replace(/[^0-9]/g, '') + ' = ' + v + ';');
  L.push('}');
  L.push('');

  L.push('class ButleryRadius {');
  L.push('  const ButleryRadius._();');
  for (const [k, v] of Object.entries(t.space.radius)) L.push('  static const double ' + camel(k) + ' = ' + v + ';');
  L.push('}');
  L.push('');

  L.push('class ButleryTouch {');
  L.push('  const ButleryTouch._();');
  L.push('  static const double min = ' + t.touchTarget.min + ';');
  L.push('  static const double minGap = ' + t.touchTarget.minGap + ';');
  L.push('  /// Varje interaktiv widget wrappas i denna — hitboxen ska finnas i koden.');
  L.push('  static Widget hit({');
  L.push('    required Widget child,');
  L.push('    required String semanticLabel,');
  L.push('    VoidCallback? onTap,');
  L.push('    bool? toggled,');
  L.push('  }) {');
  L.push('    return Semantics(');
  L.push('      label: semanticLabel,');
  L.push('      button: true,');
  L.push('      toggled: toggled,');
  L.push('      child: InkWell(');
  L.push('        onTap: onTap,');
  L.push('        child: ConstrainedBox(');
  L.push('          constraints: const BoxConstraints(minWidth: min, minHeight: min),');
  L.push('          child: Center(child: child),');
  L.push('        ),');
  L.push('      ),');
  L.push('    );');
  L.push('  }');
  L.push('}');
  L.push('');

  L.push('class ButleryControls {');
  L.push('  const ButleryControls._();');
  const c = t.controls;
  L.push('  static const double checkboxSize = ' + c.checkbox.size + ';');
  L.push('  static const double checkboxRadius = ' + c.checkbox.radius + ';');
  L.push('  static const double checkboxBorder = ' + c.checkbox.border + ';');
  L.push('  static const double checkStroke = ' + c.checkbox.checkStroke + ';');
  L.push('  static const double radioSize = ' + c.radio.size + ';');
  L.push('  static const double toggleWidth = ' + c.toggle.width + ';');
  L.push('  static const double toggleHeight = ' + c.toggle.height + ';');
  L.push('  static const double toggleKnob = ' + c.toggle.knob + ';');
  L.push('  static const double chipPaddingY = ' + c.chip.paddingY + ';');
  L.push('  static const double chipPaddingX = ' + c.chip.paddingX + ';');
  L.push('  static const double chipCompactPaddingY = ' + c.chipCompactInField.paddingY + ';');
  L.push('  static const double chipCompactPaddingX = ' + c.chipCompactInField.paddingX + ';');
  L.push('  static const double statusPillPaddingY = ' + c.statusPill.paddingY + ';');
  L.push('  static const double statusPillPaddingX = ' + c.statusPill.paddingX + ';');
  L.push('  static const double badgePaddingY = ' + c.badge.paddingY + ';');
  L.push('  static const double badgePaddingX = ' + c.badge.paddingX + ';');
  L.push('  static const double buttonMinHeight = ' + c.button.minHeight + ';');
  L.push('  static const double buttonMinWidth = ' + c.button.minWidth + ';');
  L.push('  static const double stepperVisual = ' + c.stepper.visual + ';');
  L.push('  static const List<double> avatarScale = <double>[' + c.avatarScale.map(v=>v.toFixed(1)).join(', ') + '];');
  L.push('  static const double avatarStackRing = ' + c.avatarStackRing.width + ';');
  L.push('  static const double lineHairline = ' + c.lines.hairline + ';');
  L.push('  static const double lineOutlinedEdge = ' + c.lines.outlinedEdge + ';');
  L.push('  static const double lineCellAccent = ' + c.lines.cellAccent + ';');
  L.push('  static const double lineCellUnderline = ' + c.lines.cellUnderline + ';');
  L.push('}');
  L.push('');

  L.push('class ButleryMotion {');
  L.push('  const ButleryMotion._();');
  for (const [k, v] of Object.entries(t.motion.durations)) L.push('  static const ' + camel(k) + ' = Duration(milliseconds: ' + v + ');');
  L.push('  static const Curve standard = Cubic(0.33, 0, 0.2, 1);');
  L.push('}');
  L.push('');

  const fw = w => 'FontWeight.w' + w;
  L.push('class ButleryType {');
  L.push('  const ButleryType._();');
  L.push("  static const String family = 'ButlerySans';");
  for (const [k, r] of Object.entries(t.typography.roles)) {
    const n = camel(k);
    const ls = r.tracking ? ', letterSpacing: ' + parseFloat(r.tracking) : '';
    L.push('  static const TextStyle ' + n + ' = TextStyle(fontFamily: family, fontSize: ' + r.size + ', fontWeight: ' + fw(r.weight) + ls + ');');
  }
  L.push('}');
  L.push('');

  const cs = (mode) => {
    const g = (k) => {
      const v = t.semantic[k];
      const raw = mode === 'dark' ? v.dark : v.light;
      return argb(raw);
    };
    return [
      '    colorScheme: ColorScheme(',
      '      brightness: Brightness.' + mode + ',',
      '      primary: ' + g('action.primary') + ',',
      '      onPrimary: ' + g('text.onActionPrimary') + ',',
      '      secondary: ' + g('surface.ink') + ',',
      '      onSecondary: ' + argb(t.palette.paper) + ',',
      '      error: ' + g('text.danger') + ',',
      '      onError: ' + argb(mode === 'dark' ? t.palette.inkDeep : t.palette.paper) + ',',
      '      surface: ' + g('surface.base') + ',',
      '      onSurface: ' + g('text.primary') + ',',
      '    ),'
    ];
  };
  const theme = (mode) => [
    '  static ThemeData get ' + mode + ' => ThemeData(',
    '    useMaterial3: true,',
    '    scaffoldBackgroundColor: ' + argb(mode === 'dark' ? t.semantic['surface.base'].dark : t.semantic['surface.base'].light) + ',',
    ...cs(mode),
    '    fontFamily: ButleryType.family,',
    '    textTheme: const TextTheme(',
    '      displayLarge: ButleryType.display,',
    '      titleLarge: ButleryType.title,',
    '      bodyLarge: ButleryType.body,',
    '      labelLarge: ButleryType.label,',
    '    ),',
    '  );'
  ];
  L.push('class ButleryTheme {');
  L.push('  const ButleryTheme._();');
  L.push(...theme('light'));
  L.push(...theme('dark'));
  L.push('}');
  L.push('');
  return L.join('\n');
}

const t = JSON.parse(readFileSync('tokens.json', 'utf8'));
mkdirSync('lib/theme', { recursive: true });
const out = renderDart(t);
writeFileSync('lib/theme/butlery_tokens.dart', out);
console.log('butlery_tokens.dart skriven · ' + out.split('\n').length + ' rader');
