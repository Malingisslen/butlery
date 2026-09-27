/// P8-U01: the design rule for each kind of view state, read off a pumped
/// widget tree. Shared by the 53-state test, the accessibility matrix (U02)
/// and the Linux goldens (U04).
///
/// A rule returns the violations it found, each with a stable code. The test
/// compares the codes with the shrink-only list of known findings, so a new
/// failure is red, and so is a fixed one that is still listed.
///
/// Sources, per rule:
/// - every state: no overflow (testmatris.md:60-63, "inget horisontellt
///   scroll … ingen text klipps"); every painted text colour and fill is a
///   generated colour of its mode (tokens.json semantic, delivered as
///   lib/theme/app_colors.dart and app_colors_dark.dart), that colour at an
///   opacityLadder alpha (tokens.json:40-53) or fully transparent; at most one
///   saffron-filled button (Komponentark v1:843 "en hero per vy";
///   app_colors.dart actionPrimary, "exakt en per vy").
/// - LOADING: plate line plus text, no spinner, no shimmer, no skeleton
///   before 300 ms (produktregler.md:163, :304; beslutslogg B-18).
/// - EMPTY: a text says what is empty, without error styling
///   (produktregler.md:292; content-style-guide.md:87-97 keeps the error
///   form for errors).
/// - OFFLINE: the banner says "Ingen anslutning" (produktbeslut PQ-03 = A,
///   fas2/produktbeslut-2026-09-23.json:190-199), has no fill of its own
///   (PQ-20a = A, :214-218; Komponentark v1:752-754) and does not lock the
///   content under it (produktregler.md:162, :300).
/// - CONFLICT: the own recipe offers both versions (produktregler.md:102);
///   the shopping list takes the union and says "Listan uppdaterades av
///   namn" (produktregler.md:101; PQ-20b = A, produktbeslut :220-224).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/state/delayed_skeleton.dart';

import 'state_harness.dart';

/// One broken rule, with a stable [code] and a readable [detail].
class Violation {
  const Violation(this.code, this.detail);

  /// Stable across runs: the known-findings list is keyed on it.
  final String code;

  /// What was seen, for the failure message only.
  final String detail;

  @override
  String toString() => '$code: $detail';
}

// ── The allowed colours ──────────────────────────────────────────────────

/// tokens.json opacityLadder (onPaper 0.02, 0.04; onInk 0.18, 0.35, 0.6):
/// "Endast dessa nivåer får användas."
const opacityLadder = <double>[0.02, 0.04, 0.18, 0.35, 0.6];

final _member = RegExp(
  r'static const Color (\w+) = Color\(0x([0-9A-Fa-f]{8})\);',
);
final _alias = RegExp(r'static const Color (\w+) = (\w+);');
final _schemeSlot = RegExp(r'^\s+(\w+): Color\(0x([0-9A-Fa-f]{8})\),');
final _token = RegExp(r'·\s*(palette\.\w+|semantic\.[\w.]+)');

/// One generated colour member with the token its doc comment names.
class GeneratedColour {
  GeneratedColour(this.name, this.argb, this.token);
  final String name;
  final int argb;
  final String? token;
}

/// Parses `static const Color` members (with their `· token` doc line) and
/// the ColorScheme slots from a generated file, at test time, so the rule
/// follows the file and never a copy of it.
({List<GeneratedColour> members, Map<String, List<int>> schemes})
parseGeneratedColours(String path) {
  final lines = File(path).readAsLinesSync();
  final members = <String, GeneratedColour>{};
  final schemes = <String, List<int>>{};
  String? pendingToken;
  String? scheme;
  for (final line in lines) {
    final doc = _token.firstMatch(line);
    if (line.trimLeft().startsWith('///')) {
      if (doc != null) pendingToken = doc.group(1);
      continue;
    }
    final schemeStart = RegExp(
      r'static const ColorScheme (\w+) = ColorScheme\(',
    ).firstMatch(line);
    if (schemeStart != null) {
      scheme = schemeStart.group(1);
      schemes[scheme!] = [];
      continue;
    }
    if (scheme != null) {
      if (line.trim() == ');') {
        scheme = null;
        continue;
      }
      final slot = _schemeSlot.firstMatch(line);
      if (slot != null) {
        schemes[scheme]!.add(int.parse(slot.group(2)!, radix: 16));
      }
      continue;
    }
    final m = _member.firstMatch(line);
    if (m != null) {
      members[m.group(1)!] = GeneratedColour(
        m.group(1)!,
        int.parse(m.group(2)!, radix: 16),
        pendingToken,
      );
      pendingToken = null;
      continue;
    }
    final a = _alias.firstMatch(line);
    if (a != null && members.containsKey(a.group(2))) {
      final target = members[a.group(2)]!;
      members[a.group(1)!] = GeneratedColour(
        a.group(1)!,
        target.argb,
        target.token,
      );
    }
    if (line.trim().isNotEmpty) pendingToken = null;
  }
  return (members: members.values.toList(), schemes: schemes);
}

/// The colour values a state may paint in [mode].
///
/// Light: every AppColors member, the light ColorScheme and the app's four
/// light category colours (lib/theme/app_specific_colors.dart).
/// Dark: every AppColorsDark member, the dark ColorScheme, the four dark
/// category colours, and the external brand colours (app_colors.dart:14-15,
/// "externa varumärkesidentiteter och tokeniseras inte"), which are quotes
/// with no mode. A palette primitive is NOT allowed in dark on its own:
/// tokens.json:7-39 gives the palette no mode, and every dark value comes
/// from a semantic token's "dark" field (tokens.json:52 on). A palette hex
/// passes in dark only when some dark member carries it too.
class AllowedColours {
  AllowedColours._(this.mode, this.bases);

  factory AllowedColours.forMode(Brightness mode) {
    final light = parseGeneratedColours('lib/theme/app_colors.dart');
    final specific = _specificColours();
    final bases = <int>{};
    if (mode == Brightness.light) {
      bases.addAll(light.members.map((m) => m.argb));
      bases.addAll(light.schemes['lightColorScheme'] ?? const []);
      bases.addAll(specific.light);
    } else {
      final dark = parseGeneratedColours('lib/theme/app_colors_dark.dart');
      bases.addAll(dark.members.map((m) => m.argb));
      bases.addAll(light.schemes['darkColorScheme'] ?? const []);
      bases.addAll(specific.dark);
      bases.addAll(
        light.members
            .where((m) => m.name.startsWith('brand'))
            .map((m) => m.argb),
      );
    }
    return AllowedColours._(mode, bases);
  }

  final Brightness mode;

  /// Opaque and translucent generated values, as 0xAARRGGBB.
  final Set<int> bases;

  /// Whether [colour] is allowed: a base, a base at a ladder alpha, or fully
  /// transparent.
  bool allows(Color colour) {
    final argb = colour.toARGB32();
    if ((argb >> 24) == 0) return true;
    if (bases.contains(argb)) return true;
    final rgb = argb & 0x00FFFFFF;
    final alpha = argb >> 24;
    for (final base in bases) {
      if ((base & 0x00FFFFFF) != rgb) continue;
      for (final step in opacityLadder) {
        if ((alpha - (step * 255).round()).abs() <= 1) return true;
      }
    }
    return false;
  }
}

({List<int> light, List<int> dark}) _specificColours() {
  final source = File(
    'lib/theme/app_specific_colors.dart',
  ).readAsStringSync();
  final light = <int>[];
  final dark = <int>[];
  for (final m in _member.allMatches(source)) {
    final value = int.parse(m.group(2)!, radix: 16);
    (m.group(1)!.endsWith('Dark') ? dark : light).add(value);
  }
  return (light: light, dark: dark);
}

String hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

// ── Reading the tree ─────────────────────────────────────────────────────

/// Every on-stage element, in tree order. A host whose layout failed leaves
/// viewports the on-stage walk cannot read; then every element is taken.
List<Element> onstageElements() {
  final root = WidgetsBinding.instance.rootElement!;
  try {
    return collectAllElementsFrom(root, skipOffstage: true).toList();
  } on Object {
    return collectAllElementsFrom(root, skipOffstage: false).toList();
  }
}

/// A readable sample of a painted text: an icon glyph (Private Use Area)
/// is named as one.
String textSample(String text) {
  final t = text.trim();
  if (t.runes.isNotEmpty && t.runes.every((r) => r >= 0xE000 && r <= 0xF8FF)) {
    return 'icon U+${t.runes.first.toRadixString(16).toUpperCase()}';
  }
  return t.length > 24 ? '${t.substring(0, 24)}…' : t;
}

/// Visible text: every RenderParagraph and RenderEditable with its text.
List<({String text, List<Color> colours, RenderBox box})> paintedTexts() {
  final out = <({String text, List<Color> colours, RenderBox box})>[];
  for (final e in onstageElements()) {
    final r = e.renderObject;
    if (e is! RenderObjectElement) continue;
    if (r is RenderParagraph) {
      out.add((
        text: r.text.toPlainText(),
        colours: _spanColours(r.text),
        box: r,
      ));
    } else if (r is RenderEditable) {
      final span = r.text;
      if (span == null) continue;
      out.add((text: span.toPlainText(), colours: _spanColours(span), box: r));
    }
  }
  return out;
}

List<Color> _spanColours(InlineSpan span) {
  final colours = <Color>[];
  span.visitChildren((s) {
    final c = s.style?.color;
    if (c != null) colours.add(c);
    return true;
  });
  return colours;
}

/// Painted fills: box decorations, ColoredBox and the physical layers
/// Material paints with. Each with the widget kind it came from.
List<({String kind, Color colour, Element element})> paintedFills() {
  final out = <({String kind, Color colour, Element element})>[];
  for (final e in onstageElements()) {
    final w = e.widget;
    if (w is ColoredBox) {
      out.add((kind: 'ColoredBox', colour: w.color, element: e));
      continue;
    }
    final r = e is RenderObjectElement ? e.renderObject : null;
    if (r is RenderDecoratedBox) {
      final d = r.decoration;
      final c = d is BoxDecoration
          ? d.color
          : d is ShapeDecoration
          ? d.color
          : null;
      if (c != null) out.add((kind: 'DecoratedBox', colour: c, element: e));
    } else if (r is RenderPhysicalShape) {
      out.add((kind: 'Material', colour: r.color, element: e));
    } else if (r is RenderPhysicalModel) {
      out.add((kind: 'Material', colour: r.color, element: e));
    }
  }
  return out;
}

/// Buttons whose own surface is saffron (action.primary).
int saffronButtonCount(Brightness mode) {
  final saffron = mode == Brightness.dark
      ? const _Generated('lib/theme/app_colors_dark.dart').value(
          'actionPrimary',
        )
      : const _Generated('lib/theme/app_colors.dart').value('actionPrimary');
  var count = 0;
  for (final e in onstageElements()) {
    final w = e.widget;
    if (w is! ButtonStyleButton && w is! FloatingActionButton) continue;
    var filled = false;
    void visit(Element child) {
      if (filled) return;
      final r = child is RenderObjectElement ? child.renderObject : null;
      if (r is RenderPhysicalShape && r.color.toARGB32() == saffron) {
        filled = true;
      }
      if (r is RenderDecoratedBox) {
        final d = r.decoration;
        if (d is BoxDecoration && d.color?.toARGB32() == saffron) {
          filled = true;
        }
      }
      if (!filled) child.visitChildElements(visit);
    }

    e.visitChildElements(visit);
    if (filled) count++;
  }
  return count;
}

class _Generated {
  const _Generated(this.path);
  final String path;

  int value(String member) => parseGeneratedColours(
    path,
  ).members.firstWhere((m) => m.name == member).argb;
}

// ── The rules ────────────────────────────────────────────────────────────

/// Checks shared by every kind: overflow, host exceptions, colours and the
/// single hero action.
List<Violation> commonRule(StateCapture capture, Brightness mode) {
  final out = <Violation>[];
  if (capture.overflows.isNotEmpty) {
    out.add(Violation('OVERFLOW', capture.overflows.toSet().join(' | ')));
  }
  if (capture.exceptions.isNotEmpty) {
    out.add(Violation('EXCEPTION', capture.exceptions.toSet().join(' | ')));
  }
  final allowed = AllowedColours.forMode(mode);
  final badText = <String, String>{};
  // A text with no characters paints nothing, whatever its colour.
  for (final t in paintedTexts().where((t) => t.text.trim().isNotEmpty)) {
    for (final c in t.colours) {
      if (!allowed.allows(c)) {
        badText.putIfAbsent(hex(c), () => textSample(t.text));
      }
    }
  }
  if (badText.isNotEmpty) {
    final keys = badText.keys.toList()..sort();
    out.add(
      Violation(
        'COLOUR_TEXT',
        keys.map((k) => '$k ("${badText[k]}")').join(', '),
      ),
    );
  }
  final badFill = <String>{};
  for (final f in paintedFills()) {
    if (!allowed.allows(f.colour)) badFill.add('${f.kind} ${hex(f.colour)}');
  }
  if (badFill.isNotEmpty) {
    out.add(Violation('COLOUR_FILL', (badFill.toList()..sort()).join(', ')));
  }
  final heroes = saffronButtonCount(mode);
  if (heroes > 1) out.add(Violation('HERO_COUNT', '$heroes saffron buttons'));
  return out;
}

/// LOADING, read at [earlyCheck] (299 ms after the state began) and at the
/// end. The skeleton threshold is DelayedSkeleton.threshold (300 ms).
List<Violation> loadingRule({required List<Violation> earlyCheck}) {
  final out = <Violation>[...earlyCheck];
  if (find.byType(PlateLine).evaluate().isEmpty &&
      find.byType(ButtonPlateLine).evaluate().isEmpty) {
    out.add(const Violation('NO_PLATE_LINE', 'no PlateLine in the tree'));
  }
  final texts = paintedTexts().where((t) => t.text.trim().isNotEmpty);
  if (texts.isEmpty) {
    out.add(const Violation('NO_LOADING_TEXT', 'no text says what loads'));
  }
  out.addAll(_spinners());
  return out;
}

/// The part of the LOADING rule read before the 300 ms threshold.
List<Violation> earlySkeletonCheck() {
  final boxes = onstageElements()
      .where((e) => e.widget.runtimeType.toString() == '_SkeletonBox')
      .length;
  final shown = find
      .descendant(
        of: find.byType(DelayedSkeleton),
        matching: find.byWidgetPredicate((w) => w is! SizedBox),
      )
      .evaluate()
      .length;
  return [
    if (boxes > 0 || shown > 0)
      Violation('EARLY_SKELETON', '$boxes skeleton boxes before 300 ms'),
  ];
}

List<Violation> _spinners() {
  final out = <Violation>[];
  if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
      find.byType(RefreshProgressIndicator).evaluate().isNotEmpty) {
    out.add(const Violation('SPINNER', 'CircularProgressIndicator'));
  }
  final linear = find
      .byType(LinearProgressIndicator)
      .evaluate()
      .where(
        (e) => find
            .ancestor(
              of: find.byElementPredicate((x) => x == e),
              matching: find.byWidgetPredicate(
                (w) => w is PlateLine || w is ButtonPlateLine,
              ),
            )
            .evaluate()
            .isEmpty,
      );
  if (linear.isNotEmpty) {
    out.add(const Violation('SPINNER', 'LinearProgressIndicator'));
  }
  final shimmer = onstageElements().where(
    (e) => e.widget.runtimeType.toString().toLowerCase().contains('shimmer'),
  );
  if (shimmer.isNotEmpty) out.add(const Violation('SHIMMER', 'shimmer'));
  return out;
}

/// EMPTY: some text says what is empty, and nothing is styled as an error.
List<Violation> emptyRule(Brightness mode) {
  final out = <Violation>[];
  final texts = paintedTexts().where((t) => t.text.trim().isNotEmpty).toList();
  if (texts.isEmpty) {
    out.add(const Violation('NO_EMPTY_TEXT', 'no text on screen'));
  }
  final error = themeFor(mode).colorScheme.error.toARGB32();
  final errorText = texts.where(
    (t) => t.colours.any((c) => c.toARGB32() == error),
  );
  if (errorText.isNotEmpty) {
    out.add(
      Violation(
        'ERROR_STYLING',
        'text in colorScheme.error: '
            '${errorText.map((t) => t.text).take(2).join(' / ')}',
      ),
    );
  }
  return out;
}

/// The PQ-03 banner title: "Ingen anslutning", with " · N ändringar
/// väntar" only when something waits.
bool isOfflineTitle(String text) =>
    text == sv.indicatorOfflineMode ||
    text.startsWith('${sv.indicatorOfflineMode} · ');

/// OFFLINE: the PQ-03 banner, without a fill of its own, over content that
/// can still be read and used.
List<Violation> offlineRule(WidgetTester tester, Brightness mode) {
  final out = <Violation>[];
  final texts = paintedTexts();
  final banner = texts.where((t) => isOfflineTitle(t.text)).toList();
  if (banner.isEmpty) {
    out.add(
      Violation('NO_OFFLINE_BANNER', 'no "${sv.indicatorOfflineMode}" title'),
    );
  } else {
    final page = themeFor(mode).colorScheme.surface.toARGB32();
    final fill = _nearestFill(banner.first.box);
    if (fill != null &&
        (fill.toARGB32() >> 24) != 0 &&
        fill.toARGB32() != page) {
      out.add(Violation('BANNER_FILL', 'banner fill ${hex(fill)}'));
    }
  }
  final others = texts.where(
    (t) => t.text.trim().isNotEmpty && !isOfflineTitle(t.text),
  );
  if (others.isEmpty) {
    out.add(const Violation('NO_CONTENT', 'nothing to read under the banner'));
  }
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  final screenArea = screen.width * screen.height;
  for (final e in onstageElements()) {
    final w = e.widget;
    final blocks =
        (w is AbsorbPointer && w.absorbing) ||
        (w is IgnorePointer && w.ignoring);
    if (!blocks) continue;
    final r = e.renderObject;
    if (r is RenderBox && r.hasSize) {
      final area = r.size.width * r.size.height;
      if (area >= screenArea / 2) {
        out.add(
          Violation('CONTENT_LOCKED', '${w.runtimeType} over ${r.size}'),
        );
        break;
      }
    }
  }
  return out;
}

Color? _nearestFill(RenderObject start) {
  RenderObject? node = start.parent;
  var depth = 0;
  while (node != null && depth < 30) {
    if (node is RenderDecoratedBox) {
      final d = node.decoration;
      final c = d is BoxDecoration
          ? d.color
          : d is ShapeDecoration
          ? d.color
          : null;
      if (c != null) return c;
    }
    if (node is RenderPhysicalShape) return node.color;
    if (node is RenderPhysicalModel) return node.color;
    node = node.parent;
    depth++;
  }
  return null;
}

/// CONFLICT on the own recipe: both versions are on offer (the banner's
/// title, and after its action the two labelled columns).
List<Violation> recipeConflictRule() {
  final texts = paintedTexts().map((t) => t.text).toList();
  final both =
      texts.any((t) => t.contains(sv.conflictDiffLocalLabel)) &&
      texts.any((t) => t.contains(sv.conflictDiffRemoteLabel));
  return [
    if (!both)
      Violation(
        'NO_BOTH_VERSIONS',
        'no "${sv.conflictDiffLocalLabel}" and '
            '"${sv.conflictDiffRemoteLabel}" side by side',
      ),
  ];
}

/// CONFLICT on the shopping list: both members' rows stay (union) and a
/// notice says "Listan uppdaterades av namn" (produktregler.md:101).
List<Violation> shoppingConflictRule({
  required String localItem,
  required String remoteItem,
}) {
  final texts = paintedTexts().map((t) => t.text).toList();
  final out = <Violation>[];
  if (!texts.any((t) => t.contains(localItem)) ||
      !texts.any((t) => t.contains(remoteItem))) {
    out.add(const Violation('NO_UNION', 'a row from one side is missing'));
  }
  if (!texts.any((t) => t.startsWith('Listan uppdaterades av'))) {
    out.add(
      const Violation(
        'NO_UPDATED_BY_NOTICE',
        'no "Listan uppdaterades av namn" (produktregler.md:101)',
      ),
    );
  }
  return out;
}
