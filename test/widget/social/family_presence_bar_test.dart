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
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/social/family_presence_bar.dart';
import 'package:butlery/theme/app_mode_colors.dart';

import '../../test_support/semantics_announcement.dart';

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

/// The online dot. Post-BUT-902 the indicator is a filled `ButleryIcons.dot`
/// rendered in `ModeColors.success` (= forestGreen under the light theme),
/// wrapped in a Semantics(label: "Online"). The outer Container's colour
/// changed from a forestGreen fill to `surfaceContainerHighest` (ring
/// background), so the previous BoxDecoration-by-colour heuristic no longer
/// matches. We find by the Icon directly.
Finder findOnlineDot() {
  return find.byWidgetPredicate(
    (w) =>
        w is Icon &&
        w.icon == ButleryIcons.dot &&
        w.color == ModeColors.light.success,
  );
}

void main() {
  group('FamilyPresenceBar', () {
    testWidgets('no online members → renders SizedBox.shrink (hidden)', (
      tester,
    ) async {
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

    testWidgets('one online member → avatar renders with green online dot', (
      tester,
    ) async {
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

    testWidgets('7 online members → 5 avatars + "+2" overflow chip', (
      tester,
    ) async {
      final members = List<UserProfile>.generate(7, (i) => profile('u$i'));
      await tester.pumpWidget(
        wrap(
          FamilyPresenceBar(
            memberProfiles: members,
            onlineUserIdsStream: Stream.value({
              for (var i = 0; i < 7; i++) 'u$i',
            }),
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

    testWidgets(
      'reduce-motion: no animated widgets run / no pumpAndSettle lag',
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
      },
    );

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
      },
    );

    testWidgets(
      'offline: empty RTDB emission retains the last-known online avatars',
      (tester) async {
        // BUT-1360: RTDB has no read cache, so dropping offline emits an empty
        // set and the bar would vanish. While offline we keep the last-known
        // presence; once back online an empty is trusted again.
        final members = [profile('erik'), profile('sara')];
        final controller = StreamController<Set<String>>.broadcast();
        var offline = false;

        await tester.pumpWidget(
          wrap(
            FamilyPresenceBar(
              memberProfiles: members,
              onlineUserIdsStream: controller.stream,
              isOffline: () => offline,
            ),
          ),
        );
        await tester.pump();

        // Erik is online — his avatar renders.
        controller.add({'erik'});
        await tester.pump();
        await tester.pump();
        expect(find.text('ER'), findsOneWidget);

        // Device drops offline; RTDB pushes an empty set.
        offline = true;
        controller.add(const <String>{});
        await tester.pump();
        await tester.pump();
        // Bar must NOT vanish — Erik's avatar is retained.
        expect(
          find.text('ER'),
          findsOneWidget,
          reason: 'offline empty must not blank the presence bar',
        );

        // Reconnect: an empty set is now authoritative → the bar hides.
        offline = false;
        controller.add(const <String>{});
        await tester.pump();
        await tester.pump();
        expect(
          find.text('ER'),
          findsNothing,
          reason: 'online empty is trusted — bar collapses',
        );

        await controller.close();
      },
    );

    group('avatar announcement', () {
      Future<void> pumpAnna(WidgetTester tester, {String? groupId}) {
        return tester.pumpWidget(
          wrap(
            FamilyPresenceBar(
              memberProfiles: [
                UserProfile(
                  uid: 'anna',
                  displayName: 'Anna',
                  email: 'anna@butlery.test',
                  joinedAt: DateTime(2026, 1, 1),
                  lastActiveAt: DateTime(2026, 4, 20),
                ),
              ],
              onlineUserIdsStream: Stream.value({'anna'}),
              groupId: groupId,
            ),
          ),
        );
      }

      testWidgets('says the name once, no caption', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpAnna(tester, groupId: 'g1');
        await tester.pump();

        final avatar = find.bySemanticsLabel(RegExp('^Anna'));
        final lines = announcedLines(tester, avatar);
        expect(lines.where((l) => l.contains('Anna')), hasLength(1));
        expect(lines.where((l) => l.contains('Profilbild')), isEmpty);
        handle.dispose();
      });

      testWidgets('is neither a button nor tappable, a tap does nothing', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        for (final groupId in [null, 'g1']) {
          await pumpAnna(tester, groupId: groupId);
          await tester.pump();
          final data = tester
              .getSemantics(find.bySemanticsLabel(RegExp('^Anna')))
              .getSemanticsData();
          expect(data.hasAction(SemanticsAction.tap), isFalse);
          expect(data.flagsCollection.isButton, isFalse);
        }
        handle.dispose();
      });

      testWidgets('offers a long-press action only when a group is in scope', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpAnna(tester, groupId: 'g1');
        await tester.pump();
        final withGroup = tester
            .getSemantics(find.bySemanticsLabel(RegExp('^Anna')))
            .getSemanticsData();
        expect(withGroup.hasAction(SemanticsAction.longPress), isTrue);

        await pumpAnna(tester);
        await tester.pump();
        final withoutGroup = tester
            .getSemantics(find.bySemanticsLabel(RegExp('^Anna')))
            .getSemanticsData();
        expect(withoutGroup.hasAction(SemanticsAction.longPress), isFalse);
        handle.dispose();
      });
    });
  });
}
