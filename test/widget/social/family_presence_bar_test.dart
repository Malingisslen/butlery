// test/widget/social/family_presence_bar_test.dart
//
// BUT-407: widget pump tests for [FamilyPresenceBar].
//
// Strategy: we inject `memberProfiles` + `onlineUserIdsStream` directly into
// the widget so we don't have to stand up ServiceLocator, PresenceService, or
// a real RTDB. The production pathway (ServiceLocator -> PresenceService ->
// RTDB) is composed inside the widget, but its inputs and outputs are the
// injected seams — that's the contract we verify here.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/social/family_presence_bar.dart';

UserProfile profile(String uid, {String? avatarUrl}) => UserProfile(
      uid: uid,
      displayName: uid.toUpperCase(),
      email: '$uid@butlery.test',
      avatarUrl: avatarUrl,
      joinedAt: DateTime(2026, 1, 1),
      lastActiveAt: DateTime(2026, 4, 20),
    );

Widget wrap(Widget child, {bool disableAnimations = false}) {
  // Pin AppTheme.lightTheme so `colorScheme.primary` resolves to the same
  // forestGreen the production theme installs — the BUT-755 migration moved
  // the online-dot from `AppColors.forestGreen` to `cs.primary`, so the bare
  // MaterialApp default theme would no longer satisfy `findOnlineDot()`.
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('sv'),
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: child,
      ),
    ),
  );
}

/// The online dot is the only widget in the tree whose `decoration` is a
/// [BoxDecoration] with the brand forestGreen as the fill — unique enough to
/// be a reliable finder across both plain Containers and DecoratedBoxes.
/// Production now resolves the colour from `colorScheme.primary`; under the
/// `AppTheme.lightTheme` installed by `wrap()` that's the same hex as
/// `AppColors.forestGreen`, so the literal comparison still holds.
Finder findOnlineDot() {
  return find.byWidgetPredicate((w) {
    BoxDecoration? decoration;
    if (w is Container) {
      final d = w.decoration;
      if (d is BoxDecoration) decoration = d;
    } else if (w is DecoratedBox) {
      final d = w.decoration;
      if (d is BoxDecoration) decoration = d;
    }
    if (decoration == null) return false;
    return decoration.color == AppColors.forestGreen;
  });
}

void main() {
  group('FamilyPresenceBar', () {
    testWidgets('no online members → renders SizedBox.shrink (hidden)',
        (tester) async {
      final members = [profile('u1'), profile('u2')];
      await tester.pumpWidget(
        wrap(
          FamilyPresenceBar(
            memberProfiles: members,
            onlineUserIdsStream: Stream.value(const <String>{}),
          ),
        ),
      );
      await tester.pump();

      // No avatar text should be rendered, and the bar takes no space.
      expect(find.text('U1'), findsNothing);
      expect(find.text('U2'), findsNothing);
      // Bar collapses — confirm by absence of the presence-title semantics.
      expect(find.bySemanticsLabel('Online just nu'), findsNothing);
    });

    testWidgets('one online member → avatar renders with green online dot',
        (tester) async {
      final members = [profile('erik'), profile('sara')];
      await tester.pumpWidget(
        wrap(
          FamilyPresenceBar(
            memberProfiles: members,
            onlineUserIdsStream: Stream.value({'erik'}),
          ),
        ),
      );
      await tester.pump();

      // Erik's initials render; Sara (offline) is absent.
      expect(find.text('ER'), findsOneWidget);
      expect(find.text('SA'), findsNothing);

      // The presence bar is visible (a11y title is attached).
      expect(find.bySemanticsLabel('Online just nu'), findsOneWidget);

      // The green online dot overlay is present.
      expect(findOnlineDot(), findsWidgets);
    });

    testWidgets('7 online members → 5 avatars + "+2" overflow chip',
        (tester) async {
      final members = List<UserProfile>.generate(
        7,
        (i) => profile('u$i'),
      );
      await tester.pumpWidget(
        wrap(
          FamilyPresenceBar(
            memberProfiles: members,
            onlineUserIdsStream: Stream.value(
              {for (var i = 0; i < 7; i++) 'u$i'},
            ),
          ),
        ),
      );
      await tester.pump();

      // First 5 render, rest collapses into an overflow chip.
      expect(find.text('U0'), findsOneWidget);
      expect(find.text('U4'), findsOneWidget);
      expect(find.text('U5'), findsNothing);
      expect(find.text('U6'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('reduce-motion: no animated widgets run / no pumpAndSettle lag',
        (tester) async {
      final members = [profile('erik')];
      await tester.pumpWidget(
        wrap(
          FamilyPresenceBar(
            memberProfiles: members,
            onlineUserIdsStream: Stream.value({'erik'}),
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      // The bar renders, the initials are on screen …
      expect(find.text('ER'), findsOneWidget);

      // … and pump-and-settle finishes immediately — i.e. there are no
      // repeating animation tickers driven by the widget. If the widget
      // ever introduces a pulse it must gate on disableAnimations.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('ER'), findsOneWidget);
    });

    testWidgets(
        'stream-driven: offline → online flip materializes an avatar live',
        (tester) async {
      final members = [profile('erik'), profile('sara')];
      final controller = StreamController<Set<String>>.broadcast();

      await tester.pumpWidget(
        wrap(
          FamilyPresenceBar(
            memberProfiles: members,
            onlineUserIdsStream: controller.stream,
          ),
        ),
      );
      // Flush the initialData frame.
      await tester.pump();

      // Initial: nobody online — bar is hidden.
      controller.add(const <String>{});
      await tester.pump();
      expect(find.text('ER'), findsNothing);
      expect(find.text('SA'), findsNothing);

      // Erik comes online — his avatar appears without any rebuild from the
      // parent; this is the live-stream contract the presence bar must honor.
      controller.add({'erik'});
      await tester.pump();
      await tester.pump();
      expect(find.text('ER'), findsOneWidget);
      expect(find.text('SA'), findsNothing);

      // Sara also comes online — both render.
      controller.add({'erik', 'sara'});
      await tester.pump();
      await tester.pump();
      expect(find.text('ER'), findsOneWidget);
      expect(find.text('SA'), findsOneWidget);

      // Erik goes offline — only Sara remains.
      controller.add({'sara'});
      await tester.pump();
      await tester.pump();
      expect(find.text('ER'), findsNothing);
      expect(find.text('SA'), findsOneWidget);

      await controller.close();
    });
  });
}
