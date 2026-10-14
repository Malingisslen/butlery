/// Megagenomgången, spår A: the sizes, colours and flags the shared
/// components promise, measured on the mounted widgets.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/avatar_stack.dart';
import 'package:butlery/widgets/common/emoji_reaction_display.dart';
import 'package:butlery/widgets/common/emoji_reaction_picker.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/page_rule.dart';
import 'package:butlery/widgets/common/star_rating_row.dart';
import 'package:butlery/widgets/common/tappable_wrapper.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _dark(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(body: child),
);

void main() {
  group('48 dp is measured where nothing else can supply it', () {
    for (final enabled in [true, false]) {
      testWidgets('TappableWrapper around a 14 dp glyph, enabled=$enabled', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: UnconstrainedBox(
              child: TappableWrapper(
                onTap: enabled ? () {} : null,
                semanticLabel: 'Liten',
                child: const ButleryIcon(ButleryIcons.info, size: 14),
              ),
            ),
          ),
        );
        final size = tester.getSize(find.byType(TappableWrapper));
        expect(size.width, AppDimensions.minTouchTarget);
        expect(size.height, AppDimensions.minTouchTarget);
      });
    }

    testWidgets('an emoji badge and a picker button', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: UnconstrainedBox(
            child: EmojiReactionDisplay(
              reactions: const {
                'heart': ['u1'],
              },
              currentUserId: 'u2',
              onReactionTap: (_) {},
            ),
          ),
        ),
      );
      final badge = tester.getSize(find.byType(InkWell).first);
      expect(badge.height, greaterThanOrEqualTo(48));
      expect(badge.width, greaterThanOrEqualTo(48));

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: UnconstrainedBox(
            child: EmojiReactionPicker(onReactionSelected: (_) {}),
          ),
        ),
      );
      expect(find.byType(InkWell), findsNWidgets(kReactionEmojis.length));
      for (final e in tester.widgetList<InkWell>(find.byType(InkWell))) {
        final size = tester.getSize(find.byWidget(e));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
    });
  });

  group('the page rule in dark', () {
    testWidgets('PageRule and AccentRule take the outline, not ink', (
      tester,
    ) async {
      await tester.pumpWidget(
        _dark(const Column(children: [PageRule.inline(), AccentRule.inline()])),
      );
      final cs = AppTheme.darkTheme.colorScheme;
      final colors = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.color)
          .whereType<Color>();
      expect(colors, contains(cs.outline));
      expect(colors, isNot(contains(cs.primary)));
    });
  });

  group('AvatarStack', () {
    testWidgets('every initial reaches 4.5:1 on its disc in dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        _dark(const AvatarStack(names: ['Anna', 'Bo', 'Cecilia'])),
      );
      final discs = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration is BoxDecoration)
          .toList();
      expect(discs, isNotEmpty);
      var checked = 0;
      for (final disc in discs) {
        final bg = (disc.decoration! as BoxDecoration).color;
        if (bg == null) continue;
        final text = find.descendant(
          of: find.byWidget(disc),
          matching: find.byType(Text),
        );
        if (text.evaluate().isEmpty) continue;
        final fg = tester.widget<Text>(text.first).style!.color!;
        expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
        checked++;
      }
      expect(checked, 3);
    });
  });

  group('EmojiReactionDisplay', () {
    testWidgets('only your own reaction is selected', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: EmojiReactionDisplay(
            reactions: const {
              'heart': ['me'],
              'thumbs_up': ['other'],
            },
            currentUserId: 'me',
            onReactionTap: (_) {},
          ),
        ),
      );
      final flags = tester
          .widgetList<InkWell>(find.byType(InkWell))
          .map(
            (w) => tester
                .getSemantics(find.byWidget(w))
                .getSemanticsData()
                .flagsCollection
                .isSelected,
          )
          .toList();
      expect(flags, [Tristate.isTrue, Tristate.isFalse]);
      handle.dispose();
    });
  });

  group('read-only StarRatingRow', () {
    for (final (rating, spoken) in [(3.0, '3'), (3.5, '3.5')]) {
      testWidgets('speaks $rating as one value', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          createLocalizedTestApp(child: StarRatingRow(rating: rating)),
        );
        expect(
          tester
              .getSemantics(find.byType(StarRatingRow))
              .getSemanticsData()
              .value,
          spoken,
        );
        handle.dispose();
      });
    }
  });

  group('dark rest edge on every filled button theme', () {
    test('elevated and filled carry it', () {
      final dark = AppTheme.darkTheme;
      final edges = [
        dark.elevatedButtonTheme.style!.side!.resolve({}),
        dark.filledButtonTheme.style!.side!.resolve({}),
      ];
      for (final edge in edges) {
        expect(edge, isNotNull);
        expect(edge!.width, 1.5);
      }
    });
  });
}
