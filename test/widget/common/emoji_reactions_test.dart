/// Widget tests for EmojiReactionDisplay + EmojiReactionPicker +
/// emojiSemanticsLabel + kReactionEmojis.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/emoji_reaction_display.dart';
import 'package:butlery/widgets/common/emoji_reaction_picker.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(body: child),
    );

void main() {
  group('kReactionEmojis', () {
    test('contains the 6 expected reaction keys', () {
      expect(kReactionEmojis.keys.toSet(), {
        'thumbs_up',
        'heart',
        'fire',
        'laughing',
        'yum',
        'thinking',
      });
    });

    test('every key maps to a non-empty display emoji', () {
      for (final v in kReactionEmojis.values) {
        expect(v, isNotEmpty);
      }
    });
  });

  group('emojiSemanticsLabel', () {
    testWidgets('returns localized labels for known keys', (tester) async {
      late BuildContext capturedCtx;
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        capturedCtx = ctx;
        return const SizedBox();
      })));
      for (final k in kReactionEmojis.keys) {
        final label = emojiSemanticsLabel(capturedCtx, k);
        expect(label, isNotEmpty, reason: 'no label for $k');
      }
    });

    testWidgets('falls back to humanized key when unknown', (tester) async {
      late BuildContext capturedCtx;
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        capturedCtx = ctx;
        return const SizedBox();
      })));
      expect(emojiSemanticsLabel(capturedCtx, 'rocket_ship'), 'rocket ship');
      expect(emojiSemanticsLabel(capturedCtx, 'simple'), 'simple');
    });
  });

  group('EmojiReactionPicker', () {
    testWidgets('renders 6 emoji buttons in a row', (tester) async {
      await tester.pumpWidget(_wrap(EmojiReactionPicker(
        onReactionSelected: (_) {},
      )));
      // 6 GestureDetectors, one per emoji
      expect(
        find.descendant(
          of: find.byType(EmojiReactionPicker),
          matching: find.byType(GestureDetector),
        ),
        findsNWidgets(6),
      );
      // 6 visible emoji glyphs
      for (final e in kReactionEmojis.values) {
        expect(find.text(e), findsOneWidget);
      }
    });

    testWidgets('tap fires onReactionSelected with the right key',
        (tester) async {
      final fired = <String>[];
      await tester.pumpWidget(_wrap(EmojiReactionPicker(
        onReactionSelected: fired.add,
      )));
      // Tap the heart emoji
      await tester.tap(find.text(kReactionEmojis['heart']!));
      await tester.pump();
      expect(fired, ['heart']);
    });

    testWidgets('container uses square design (no BorderRadius.zero — it is M)',
        (tester) async {
      await tester.pumpWidget(_wrap(EmojiReactionPicker(
        onReactionSelected: (_) {},
      )));
      final container = tester.firstWidget<Container>(find.descendant(
        of: find.byType(EmojiReactionPicker),
        matching: find.byType(Container),
      ));
      final deco = container.decoration! as BoxDecoration;
      expect(deco.borderRadius, isNotNull);
      expect(deco.border, isNotNull);
      expect(deco.boxShadow, isNotEmpty);
    });
  });

  group('EmojiReactionDisplay', () {
    testWidgets('empty when no reactions have any users', (tester) async {
      await tester.pumpWidget(_wrap(EmojiReactionDisplay(
        reactions: const {'heart': [], 'fire': []},
        currentUserId: 'me',
        onReactionTap: (_) {},
      )));
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('renders one badge per active reaction', (tester) async {
      await tester.pumpWidget(_wrap(EmojiReactionDisplay(
        reactions: const {
          'heart': ['u1'],
          'fire': ['u1', 'u2'],
          'yum': [], // skipped: empty
        },
        currentUserId: 'me',
        onReactionTap: (_) {},
      )));
      expect(find.byType(Wrap), findsOneWidget);
      // 2 active badges (heart, fire) — each has its emoji
      expect(find.text(kReactionEmojis['heart']!), findsOneWidget);
      expect(find.text(kReactionEmojis['fire']!), findsOneWidget);
      expect(find.text(kReactionEmojis['yum']!), findsNothing);
      // Count labels
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('user-reacted badge uses primary color tint', (tester) async {
      await tester.pumpWidget(_wrap(EmojiReactionDisplay(
        reactions: const {
          'heart': ['me', 'other'],
        },
        currentUserId: 'me',
        onReactionTap: (_) {},
      )));
      // The count Text should be bold (w600) when the user has reacted.
      final countText = tester.widget<Text>(find.text('2'));
      expect(countText.style!.fontWeight, FontWeight.w600);
    });

    testWidgets('non-reacted badge uses normal weight', (tester) async {
      await tester.pumpWidget(_wrap(EmojiReactionDisplay(
        reactions: const {
          'heart': ['other'],
        },
        currentUserId: 'me',
        onReactionTap: (_) {},
      )));
      final countText = tester.widget<Text>(find.text('1'));
      expect(countText.style!.fontWeight, FontWeight.normal);
    });

    testWidgets('tap on a badge fires onReactionTap with the emoji key',
        (tester) async {
      final fired = <String>[];
      await tester.pumpWidget(_wrap(EmojiReactionDisplay(
        reactions: const {
          'fire': ['u1'],
        },
        currentUserId: 'me',
        onReactionTap: fired.add,
      )));
      await tester.tap(find.text(kReactionEmojis['fire']!));
      await tester.pump();
      expect(fired, ['fire']);
    });

    testWidgets('unknown emoji key falls back to the key as display',
        (tester) async {
      // Production has `kReactionEmojis[emojiKey] ?? emojiKey`
      await tester.pumpWidget(_wrap(EmojiReactionDisplay(
        reactions: const {
          'unknown_key': ['u1'],
        },
        currentUserId: 'me',
        onReactionTap: (_) {},
      )));
      expect(find.text('unknown_key'), findsOneWidget);
    });
  });
}
