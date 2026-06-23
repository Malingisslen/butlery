/// BUT-1358: pin that FriendCard mounts a HoverableCard ancestor whose rest
/// decoration uses design-system tokens (surface fill + outline border) and
/// whose hover variant only deepens the shadow.
///
/// Intent: BUT-1358 wrapped FriendCard in HoverableCard for a web/desktop hover
/// affordance. This render test guards against a refactor dropping the wrapper
/// or swapping the tokenised border/colour for ad-hoc values, and confirms a
/// non-tappable card defers the cursor (no implied clickability).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/content_cards/friend_card.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

UserProfile _user() {
  final now = DateTime(2026, 5, 1, 12);
  return UserProfile(
    uid: 'u1',
    displayName: 'Anna Andersson',
    email: 'anna@example.com',
    joinedAt: now,
    lastActiveAt: now,
  );
}

void main() {
  group('FriendCard mounts HoverableCard (BUT-1358)', () {
    testWidgets('renders a HoverableCard ancestor', (tester) async {
      await tester.pumpWidget(_wrap(
        FriendCard(user: _user(), onTap: () {}),
      ));

      expect(
        find.descendant(
          of: find.byType(FriendCard),
          matching: find.byType(HoverableCard),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rest decoration uses surface fill + outline design tokens',
        (tester) async {
      late ColorScheme cs;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          cs = Theme.of(context).colorScheme;
          return FriendCard(user: _user(), onTap: () {});
        }),
      ));

      final hoverable = tester.widget<HoverableCard>(
        find.descendant(
          of: find.byType(FriendCard),
          matching: find.byType(HoverableCard),
        ),
      );

      final rest = hoverable.restDecoration as BoxDecoration;
      expect(rest.color, cs.surface,
          reason: 'Friend card fill must use the surface token.');
      final border = rest.border as Border;
      expect(border.top.color, cs.outline,
          reason: 'Friend card border must use the outline token.');
      expect(border.top.width, AppDimensions.borderWidthThin);
      expect(
        rest.borderRadius,
        BorderRadius.circular(AppDimensions.borderRadiusM),
      );
    });

    testWidgets('hover variant keeps border + corners, only deepens shadow',
        (tester) async {
      await tester.pumpWidget(_wrap(
        FriendCard(user: _user(), onTap: () {}),
      ));

      final hoverable = tester.widget<HoverableCard>(
        find.descendant(
          of: find.byType(FriendCard),
          matching: find.byType(HoverableCard),
        ),
      );

      final rest = hoverable.restDecoration as BoxDecoration;
      final hover = hoverable.hoverDecoration as BoxDecoration;

      expect(hover.border, equals(rest.border));
      expect(hover.borderRadius, equals(rest.borderRadius));
      expect(hover.color, equals(rest.color));
      expect(hover.boxShadow, isNotNull,
          reason: 'Hover should add the reserved elevation shadow.');
      expect(rest.boxShadow, isNull,
          reason: 'Rest stays flat — no shadow, identical to the old card.');
    });

    testWidgets('non-tappable card defers the cursor', (tester) async {
      MouseCursor cursorOf() {
        final mouseRegion = tester.widget<MouseRegion>(
          find
              .descendant(
                of: find.byType(HoverableCard),
                matching: find.byType(MouseRegion),
              )
              .first,
        );
        return mouseRegion.cursor;
      }

      await tester.pumpWidget(_wrap(FriendCard(user: _user(), onTap: () {})));
      expect(cursorOf(), SystemMouseCursors.click,
          reason: 'A card with an onTap must show the click cursor.');

      await tester.pumpWidget(_wrap(FriendCard(user: _user())));
      expect(cursorOf(), MouseCursor.defer,
          reason: 'A card with no onTap should not imply clickability.');
    });
  });
}
