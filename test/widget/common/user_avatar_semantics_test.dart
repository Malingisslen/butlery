// BUT-1953: an avatar beside a visible name must not announce the name twice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/butlery_link.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/user_avatar.dart';
import 'package:butlery/widgets/tagging/tag_status_badge.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/semantics_announcement.dart';

void main() {
  group('UserAvatarWidgets.avatar', () {
    testWidgets('announces the name once when it stands alone', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: UserAvatarWidgets.avatar(displayName: 'Anna Lindgren'),
        ),
      );

      final node = find.bySemanticsLabel(RegExp('Anna Lindgren'));
      expect(announcedLines(tester, node), ['Profilbild för Anna Lindgren']);
      handle.dispose();
    });

    testWidgets('a tappable avatar keeps its name and tap, without initials', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: UserAvatarWidgets.avatar(
            displayName: 'Anna Lindgren',
            onTap: () {},
          ),
        ),
      );

      final node = find.bySemanticsLabel(RegExp('Anna Lindgren'));
      expect(announcedLines(tester, node), ['Profilbild för Anna Lindgren']);
      expectNothingAnnouncedTwice(tester, node);
      expectActivatable(tester, node);
      handle.dispose();
    });

    testWidgets('announceName: false leaves the visible name to speak', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: ListTile(
            leading: UserAvatarWidgets.avatar(
              displayName: 'Anna Lindgren',
              announceName: false,
            ),
            title: const Text('Anna Lindgren'),
            onTap: () {},
          ),
        ),
      );

      final node = find.bySemanticsLabel(RegExp('Anna Lindgren'));
      expect(announcedLines(tester, node), ['Anna Lindgren']);
      expectActivatable(tester, node);
      handle.dispose();
    });
  });

  group('UserDisplayWidgets.avatar', () {
    Future<void> pumpRow(WidgetTester tester, {required bool announceName}) =>
        tester.pumpWidget(
          createLocalizedTestApp(
            child: ListTile(
              leading: UserDisplayWidgets.avatar(
                displayName: 'Anna Lindgren',
                announceName: announceName,
              ),
              title: const Text('Anna Lindgren'),
            ),
          ),
        );

    testWidgets('announceName: false reaches the avatar, so the visible name '
        'is the only line', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester, announceName: false);

      final node = find.bySemanticsLabel(RegExp('Anna Lindgren'));
      expect(announcedLines(tester, node), ['Anna Lindgren']);
      handle.dispose();
    });

    testWidgets('by default the avatar announces whose picture it is', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: UserDisplayWidgets.avatar(displayName: 'Anna Lindgren'),
        ),
      );

      final avatar = find.bySemanticsLabel(RegExp('Anna Lindgren'));
      expect(announcedLines(tester, avatar), ['Profilbild för Anna Lindgren']);
      handle.dispose();
    });
  });

  group('UserAvatar', () {
    Future<void> pumpRow(WidgetTester tester, {bool? announceName}) =>
        tester.pumpWidget(
          createLocalizedTestApp(
            child: ListTile(
              leading: announceName == null
                  ? const UserAvatar(displayName: 'Anna Lindgren')
                  : UserAvatar(
                      displayName: 'Anna Lindgren',
                      announceName: announceName,
                    ),
              title: const Text('Anna Lindgren'),
            ),
          ),
        );

    testWidgets('announceName: false leaves the visible name as the only '
        'line', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester, announceName: false);

      final node = find.bySemanticsLabel(RegExp('Anna Lindgren'));
      expect(announcedLines(tester, node), ['Anna Lindgren']);
      handle.dispose();
    });

    testWidgets('announceName: true announces whose picture it is', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester, announceName: true);

      final node = find.bySemanticsLabel(RegExp('Anna Lindgren'));
      expect(
        announcedLines(tester, node),
        contains('Profilbild för Anna Lindgren'),
      );
      handle.dispose();
    });

    testWidgets('announces whose picture it is by default', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester);

      final node = find.bySemanticsLabel(RegExp('Anna Lindgren'));
      expect(
        announcedLines(tester, node),
        contains('Profilbild för Anna Lindgren'),
      );
      handle.dispose();
    });
  });

  group('SocialAvatarComponents.avatar', () {
    Future<void> pumpRow(WidgetTester tester, {bool? announceName}) =>
        tester.pumpWidget(
          createLocalizedTestApp(
            child: ListTile(
              leading: announceName == null
                  ? SocialAvatarComponents.avatar(displayName: 'Anna Lindgren')
                  : SocialAvatarComponents.avatar(
                      displayName: 'Anna Lindgren',
                      announceName: announceName,
                    ),
              title: const Text('Anna Lindgren'),
            ),
          ),
        );

    testWidgets('announceName: false leaves the visible name as the only '
        'line', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester, announceName: false);

      final node = find.bySemanticsLabel(RegExp('Anna Lindgren'));
      expect(announcedLines(tester, node), ['Anna Lindgren']);
      handle.dispose();
    });

    testWidgets('announces whose picture it is by default', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester);

      final node = find.bySemanticsLabel(RegExp('Anna Lindgren'));
      expect(
        announcedLines(tester, node),
        contains('Profilbild för Anna Lindgren'),
      );
      handle.dispose();
    });
  });

  group('ButleryLink', () {
    Future<void> pumpLink(WidgetTester tester) => tester.pumpWidget(
      createLocalizedTestApp(
        child: ButleryLink(onTap: () {}, child: const Text('Villkor')),
      ),
    );

    testWidgets('a labelled link announces its label once and can be tapped', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: ButleryLink(
            semanticLabel: 'Användarvillkor',
            onTap: () {},
            child: const Text('Villkor'),
          ),
        ),
      );

      final node = find.bySemanticsLabel('Användarvillkor');
      expect(announcedLines(tester, node), ['Användarvillkor']);
      expectActivatable(tester, node);
      expect(
        tester.getSemantics(node).getSemanticsData().flagsCollection.isLink,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('without a semanticLabel the visible text is announced and '
        'the link can be tapped', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLink(tester);

      final node = find.bySemanticsLabel('Villkor');
      expect(announcedLines(tester, node), ['Villkor']);
      expectActivatable(tester, node);
      expect(
        tester.getSemantics(node).getSemanticsData().flagsCollection.isLink,
        isTrue,
      );
      handle.dispose();
    });
  });

  group('TagStatusBadge', () {
    testWidgets('the info action names the action, not the status again', (
      tester,
    ) async {
      var infoTaps = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: TagStatusBadge(
            tone: TagStatusTone.success,
            icon: ButleryIcons.info,
            semanticLabel: 'Fri från gluten',
            label: 'Fri från gluten',
            onInfoTap: () => infoTaps++,
          ),
        ),
      );

      final node = find.bySemanticsLabel(RegExp('Fri från gluten'));
      expect(
        announcedLines(tester, node).where((l) => l.contains('gluten')),
        hasLength(1),
      );
      expectNothingAnnouncedTwice(tester, node);

      final info = find.bySemanticsLabel(RegExp('Mer information'));
      expect(announcedLines(tester, info), contains('Mer information'));
      expectActivatable(tester, info);
      tester.semantics.tap(
        find.semantics.byPredicate(
          (n) => n.label.contains('Mer information'),
        ),
      );
      expect(infoTaps, 1);
      handle.dispose();
    });
  });
}
