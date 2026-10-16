import 'package:flutter/material.dart';

import 'package:butlery/theme/app_mode_colors.dart';

/// The colours a household member can take, in picker order. Each reaches
/// 4.5:1 with [onProfileColor] text.
const kProfileColors = <String>[
  '#3E6F8E',
  '#7A5C8E',
  '#B87F3F',
  '#477756',
  '#8B5A3C',
  '#C04435',
];

/// Stored colours from before the palette was measured, and the shade each
/// became: their initials reached only 4.32:1 to 4.48:1 in either text
/// colour.
const _legacyProfileColors = <String, String>{
  '#B07A3C': '#B87F3F',
  '#4A7C59': '#477756',
  '#C44536': '#C04435',
};

/// [hex] as the palette now spells it; any other value is returned as stored.
String canonicalProfileColor(String hex) =>
    _legacyProfileColors[hex.toUpperCase()] ?? hex;

/// Paper or ink, whichever reads better on [background]. The initials are a
/// colour pair chosen per background, since no single text colour reaches
/// 4.5:1 on all of them.
Color onProfileColor(ColorScheme cs, Color background) {
  final paper = cs.onPrimary;
  final ink = AppModeColors.onActionPrimary(cs.brightness);
  return _contrast(paper, background) >= _contrast(ink, background)
      ? paper
      : ink;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}
