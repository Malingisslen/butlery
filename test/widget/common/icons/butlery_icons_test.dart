/// P7-U08: the Butlery icon family register (beslutslogg.md:9, B-02).
///
/// - design/assets/icons holds exactly one master per icons.json entry.
/// - Every ButleryIcons member maps to an icons.json entry and embeds that
///   entry's master exactly (the app-side counterpart of T-05), and every
///   icons.json entry has a member.
/// - ButleryIcon paints in the ambient IconTheme colour and size, with the
///   2.2 stroke at 14 px and below (Grafisk manual v6:322), and carries the
///   same semantics as Icon.
library;

import 'dart:convert';
import 'dart:io';

import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _masters = 'design/assets/icons';

Map<String, dynamic> _manifest() =>
    jsonDecode(File('design/icons.json').readAsStringSync())
        as Map<String, dynamic>;

List<Map<String, dynamic>> _entries() {
  final m = _manifest();
  return [
    for (final e in m['ui_family'] as List) e as Map<String, dynamic>,
    for (final e in m['nav_family'] as List) e as Map<String, dynamic>,
  ];
}

ButleryGlyphPainter _painterOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(ButleryIcon),
      matching: find.byType(CustomPaint),
    ),
  );
  return paint.painter! as ButleryGlyphPainter;
}

void main() {
  group('masters', () {
    test('the masters folder holds exactly the icons.json entries', () {
      final files = Directory(_masters)
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(files, {for (final e in _entries()) '${e['name']}.svg'});
    });

    test('icons.json counts 123 masters, one file each', () {
      final entries = _entries();
      expect(entries, hasLength(123));
      expect(
        (_manifest()['counts'] as Map)['total'],
        123,
      );
      for (final e in entries) {
        expect(File('$_masters/${e['name']}.svg').existsSync(), isTrue);
      }
    });
  });

  group('register', () {
    test('every member is an icons.json entry and embeds its master', () {
      final byName = {for (final e in _entries()) e['name'] as String: e};
      for (final g in ButleryIcons.values) {
        expect(byName.keys, contains(g.name), reason: '$g has no entry');
        expect(
          g.svg,
          File('$_masters/${g.name}.svg').readAsStringSync(),
          reason: '$g does not embed its master',
        );
        expect(g.meaning, byName[g.name]!['meaning'] ?? g.name);
        expect(g.fontFamily, kButleryGlyphFontFamily);
      }
    });

    test('every icons.json entry has exactly one master member', () {
      final masters = ButleryIcons.values.where((g) => !g.outlined);
      expect(
        masters.map((g) => g.name).toList()..sort(),
        (_entries().map((e) => e['name'] as String).toList()..sort()),
      );
    });

    test('code points are unique, so glyphs are distinct IconData', () {
      final codes = ButleryIcons.values.map((g) => g.codePoint).toSet();
      expect(codes, hasLength(ButleryIcons.values.length));
    });

    test('every master parses into at least one shape', () {
      for (final g in ButleryIcons.values) {
        final d = GlyphDrawing.parse(g.svg, outlined: g.outlined);
        expect(d.shapes, isNotEmpty, reason: g.name);
        expect(d.viewBox, g.name.startsWith('nav-') ? 160 : 24);
        for (final s in d.shapes) {
          final b = s.path.getBounds();
          expect(b.width + b.height, greaterThan(0), reason: g.name);
        }
      }
    });

    test('filled exceptions fill and the UI family strokes at 1.75', () {
      final filled = GlyphDrawing.parse(ButleryIcons.star.svg);
      expect(filled.shapes.single.fill, isTrue);
      expect(filled.shapes.single.stroke, isFalse);
      final outline = GlyphDrawing.of(ButleryIcons.starOutline);
      expect(outline.shapes.single.fill, isFalse);
      expect(outline.shapes.single.stroke, isTrue);
      expect(outline.shapes.single.strokeWidth, kButleryGlyphStroke);
      final back = GlyphDrawing.of(ButleryIcons.arrowLeft);
      expect(back.shapes.single.strokeWidth, 1.75);
      expect(back.shapes.single.cap, StrokeCap.round);
      expect(
        GlyphDrawing.of(ButleryIcons.check).shapes.single.strokeWidth,
        2.2,
      );
    });

    test('14 px and below compensates 1.75 to 2.2, nothing else', () {
      expect(
        compensatedStrokeWidth(1.75, renderedSize: 14, viewBox: 24),
        2.2,
      );
      expect(
        compensatedStrokeWidth(1.75, renderedSize: 15, viewBox: 24),
        1.75,
      );
      expect(compensatedStrokeWidth(2.2, renderedSize: 12, viewBox: 24), 2.2);
      expect(compensatedStrokeWidth(7, renderedSize: 12, viewBox: 160), 7);
    });
  });

  test('the nav family shows its live area, as the tab bars are drawn', () {
    expect(displayWindow(160), const Rect.fromLTWH(22, 22, 116, 116));
    expect(displayWindow(24), const Rect.fromLTWH(0, 0, 24, 24));
  });

  group('path parser', () {
    test('relative, implicit and arc commands', () {
      final p = parseSvgPath('M2 2h4v4H2z m10 0l2 2 2-2a2 2 0 0 1 2 2');
      final b = p.getBounds();
      expect(b.left, closeTo(2, 0.01));
      expect(b.top, closeTo(2, 0.01));
      expect(b.right, closeTo(18, 0.1));
    });

    test('compact numbers such as 6.1-6.05 and .9-.85', () {
      final p = parseSvgPath('M0 0l6.1-6.05l.9-.85');
      expect(p.getBounds().top, closeTo(-6.9, 0.01));
    });
  });

  group('ButleryIcon', () {
    Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(body: Center(child: child)),
        );

    testWidgets('takes colour and size from the ambient IconTheme', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          host(
            const IconTheme(
              data: IconThemeData(color: Color(0xFF123456), size: 20),
              child: ButleryIcon(ButleryIcons.plus),
            ),
            brightness: brightness,
          ),
        );
        expect(_painterOf(tester).color, const Color(0xFF123456));
        expect(tester.getSize(find.byType(ButleryIcon)), const Size(20, 20));
      }
    });

    testWidgets('follows the theme icon colour in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          host(const ButleryIcon(ButleryIcons.x), brightness: brightness),
        );
        final ctx = tester.element(find.byType(ButleryIcon));
        expect(_painterOf(tester).color, IconTheme.of(ctx).color);
      }
    });

    testWidgets('an explicit colour wins and IconTheme opacity applies', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const IconTheme(
            data: IconThemeData(opacity: 0.5),
            child: ButleryIcon(ButleryIcons.check, color: Color(0xFF000000)),
          ),
        ),
      );
      expect(_painterOf(tester).color.a, closeTo(0.5, 0.01));
    });

    testWidgets('announces its label, or stays out of semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ButleryIcon(ButleryIcons.search, semanticLabel: 'Sök'),
              ButleryIcon(ButleryIcons.trash2),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('Sök'), findsOneWidget);
      expect(find.byIcon(ButleryIcons.search), findsOneWidget);
      handle.dispose();
    });

    testWidgets('an IconButton around a glyph keeps its tooltip label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          IconButton(
            onPressed: () {},
            tooltip: 'Stäng',
            icon: const ButleryIcon(ButleryIcons.x),
          ),
        ),
      );
      expect(find.byTooltip('Stäng'), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('a Material residue icon falls back to Icon rendering', (
      tester,
    ) async {
      await tester.pumpWidget(host(const ButleryIcon(Icons.ac_unit)));
      expect(
        find.descendant(
          of: find.byType(ButleryIcon),
          matching: find.byType(RichText),
        ),
        findsOneWidget,
      );
    });

    testWidgets('keeps its size inside a larger forced box, as Icon does', (
      tester,
    ) async {
      // A forced 48 x 48 box (what InputDecoration gives a prefix icon) must
      // not stretch the painted glyph.
      await tester.pumpWidget(
        host(
          const SizedBox.square(
            dimension: 48,
            child: ButleryIcon(ButleryIcons.pencil),
          ),
        ),
      );
      final paint = find.descendant(
        of: find.byType(ButleryIcon),
        matching: find.byType(CustomPaint),
      );
      expect(tester.getSize(paint), const Size(24, 24));
    });

    testWidgets('a text field prefix and suffix glyph render at 24 px', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 320,
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: ButleryIcon(ButleryIcons.pencil),
                suffixIcon: ButleryIcon(ButleryIcons.search),
              ),
            ),
          ),
        ),
      );
      for (final glyph in [ButleryIcons.pencil, ButleryIcons.search]) {
        final paint = find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is ButleryIcon && w.icon == glyph,
          ),
          matching: find.byType(CustomPaint),
        );
        expect(tester.getSize(paint), const Size(24, 24), reason: '$glyph');
      }
    });

    testWidgets('every glyph paints without error at 12, 14, 24 and 56 px', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Wrap(
            children: [
              for (final size in [12.0, 14.0, 24.0, 56.0])
                for (final g in ButleryIcons.values) ButleryIcon(g, size: size),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byType(ButleryIcon),
        findsNWidgets(ButleryIcons.values.length * 4),
      );
    });
  });
}
