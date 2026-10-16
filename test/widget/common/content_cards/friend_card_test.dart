/// Widget tests for FriendCard.
///
/// Covers public render contracts:
///   - FriendCard: each FriendCardStyle (detailed / compact / list) renders
///     the user's display name, the avatar visibility flag is honoured,
///     subtitle/trailing/metadata slots show up, and tap + long-press
///     callbacks fire on the InkWell.
///
/// Avatars are exercised via UserProfile.avatarUrl == null so the underlying
/// AvatarWidgets falls back to its initials placeholder (no network
/// fetch needed in the test harness).
library;

import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/content_cards/friend_card.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import '../../../test_support/semantics_announcement.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

UserProfile _user({
  String uid = 'u1',
  String displayName = 'Anna Andersson',
  String email = 'anna@example.com',
  bool isOnline = false,
}) {
  final now = DateTime(2026, 5, 1, 12);
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: email,
    joinedAt: now,
    lastActiveAt: now,
    isOnline: isOnline,
  );
}

void main() {
  group('FriendCard - rendering', () {
    testWidgets('detailed style renders display name', (tester) async {
      await tester.pumpWidget(_wrap(FriendCard(user: _user())));
      expect(find.text('Anna Andersson'), findsOneWidget);
    });

    // BUT-2264: another user's address is never shown, even when an older
    // public profile still carries one.
    testWidgets('never shows the address', (tester) async {
      await tester.pumpWidget(_wrap(FriendCard(user: _user())));
      expect(find.text('anna@example.com'), findsNothing);
      expect(find.text('Anna Andersson'), findsOneWidget);
    });

    testWidgets('subtitle takes precedence over metadata when supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FriendCard(user: _user(), subtitle: 'Mutual: 3'),
        ),
      );
      expect(find.text('Mutual: 3'), findsOneWidget);
    });

    testWidgets('trailing widget renders inside the card', (tester) async {
      const trailingKey = Key('trailing-marker');
      await tester.pumpWidget(
        _wrap(
          FriendCard(
            user: _user(),
            trailing: const ButleryIcon(
              ButleryIcons.chevronRight,
              key: trailingKey,
            ),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(FriendCard),
          matching: find.byKey(trailingKey),
        ),
        findsOneWidget,
      );
    });

    testWidgets('compact style still renders the display name', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendCard(user: _user(), style: FriendCardStyle.compact),
        ),
      );
      expect(find.text('Anna Andersson'), findsOneWidget);
      // Compact style does NOT show metadata even if showMetadata=true
      expect(find.text('anna@example.com'), findsNothing);
    });

    testWidgets('list style uses a ListTile internally', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FriendCard(user: _user(), style: FriendCardStyle.list),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(FriendCard),
          matching: find.byType(ListTile),
        ),
        findsOneWidget,
      );
      expect(find.text('Anna Andersson'), findsOneWidget);
    });
  });

  group('FriendCard - interaction', () {
    testWidgets('onTap fires when card is tapped (detailed)', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          FriendCard(user: _user(), onTap: () => taps++),
        ),
      );
      await tester.tap(find.byType(FriendCard));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('onLongPress fires when card is long-pressed (detailed)', (
      tester,
    ) async {
      var longs = 0;
      await tester.pumpWidget(
        _wrap(
          FriendCard(user: _user(), onLongPress: () => longs++),
        ),
      );
      await tester.longPress(find.byType(FriendCard));
      await tester.pump();
      expect(longs, 1);
    });

    testWidgets('onTap fires in list style (ListTile path)', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          FriendCard(
            user: _user(),
            style: FriendCardStyle.list,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(ListTile));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('FriendCard - semantics', () {
    testWidgets('exposes localized friend semantics label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(FriendCard(user: _user(), onTap: () {})),
      );
      // The label names the role only; the name comes from the visible text.
      final node = find.bySemanticsLabel(RegExp(r'^Vän\n'));
      expect(node, findsAtLeastNWidgets(1));
      final lines = announcedLines(tester, node.first);
      expect(lines.where((l) => l.startsWith('Vän')), ['Vän']);
      expect(lines.where((l) => l == 'Anna Andersson'), hasLength(1));
      expect(lines.where((l) => l.contains('Profilbild')), isEmpty);
      expectNothingAnnouncedTwice(tester, node.first);
      expectActivatable(tester, node.first);
      handle.dispose();
    });

    for (final style in FriendCardStyle.values) {
      testWidgets('the ${style.name} card without onTap is not a button', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(FriendCard(user: _user(), style: style)));
        final node = find.bySemanticsLabel(RegExp('Anna Andersson')).first;
        final data = tester.getSemantics(node).getSemanticsData();
        expect(data.flagsCollection.isButton, isFalse);
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        handle.dispose();
      });
    }

    for (final style in FriendCardStyle.values) {
      testWidgets('the ${style.name} card announces the name once', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(FriendCard(user: _user(), style: style, onTap: () {})),
        );
        final node = find.bySemanticsLabel(RegExp('Anna Andersson')).first;
        final lines = announcedLines(tester, node);
        expect(lines.where((l) => l.contains('Anna Andersson')), hasLength(1));
        expect(lines.where((l) => l.contains('Profilbild')), isEmpty);
        handle.dispose();
      });
    }
  });
}
