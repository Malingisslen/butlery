import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/share_dialog/share_target_selection.dart';
import 'package:butlery/widgets/common/share_dialog/share_target_selection_enhanced.dart';
import 'package:butlery/models/user_profile.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/semantics_announcement.dart';

void main() {
  group('ShareTargetSelection Widget Tests', () {
    late List<UserProfile> mockFriends;

    setUp(() {
      final now = DateTime.now();
      mockFriends = [
        UserProfile(
          uid: '1',
          displayName: 'Anna Andersson',
          email: 'anna@example.com',
          avatarUrl: 'https://example.com/anna.jpg',
          joinedAt: now,
          lastActiveAt: now,
        ),
        UserProfile(
          uid: '2',
          displayName: 'Björn Bergström',
          email: 'bjorn@example.com',
          avatarUrl: 'https://example.com/bjorn.jpg',
          joinedAt: now,
          lastActiveAt: now,
        ),
        UserProfile(
          uid: '3',
          displayName: 'Clara Carlsson',
          email: 'clara@example.com',
          joinedAt: now,
          lastActiveAt: now,
        ),
      ];
    });

    testWidgets('renders share target selection using Builder for context', (
      WidgetTester tester,
    ) async {
      final selectedIds = <String>{};
      String searchQuery = '';

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => ShareTargetSelection.build(
              context, // Use Builder context properly
              mockFriends,
              selectedIds,
              searchQuery,
              (query) => searchQuery = query,
              (id) => selectedIds.add(id),
            ),
          ),
        ),
      );

      // Basic rendering test
      expect(find.text('Välj mottagare'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Sök bland vänner...'), findsOneWidget);
      expect(find.text('Anna Andersson'), findsOneWidget);
      expect(find.text('Björn Bergström'), findsOneWidget);
      expect(find.text('Clara Carlsson'), findsOneWidget);
    });

    testWidgets('shows correct Swedish text for empty friends', (
      WidgetTester tester,
    ) async {
      final selectedIds = <String>{};
      String searchQuery = '';

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => ShareTargetSelection.build(
              context,
              [], // Empty friends list
              selectedIds,
              searchQuery,
              (query) => searchQuery = query,
              (id) {},
            ),
          ),
        ),
      );

      // Check for correct Swedish empty state text
      expect(find.text('Inga vänner tillgängliga'), findsOneWidget);
      expect(find.byIcon(ButleryIcons.users), findsOneWidget);
    });

    testWidgets('shows correct Swedish text for no search results', (
      WidgetTester tester,
    ) async {
      final selectedIds = <String>{};
      String searchQuery = 'xyz123';

      // Filter friends manually to simulate the actual filtering behavior
      final filteredFriends = mockFriends.where((friend) {
        return friend.displayName.toLowerCase().contains(
          searchQuery.toLowerCase(),
        );
      }).toList();

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => ShareTargetSelection.build(
              context,
              filteredFriends, // Use filtered friends
              selectedIds,
              searchQuery,
              (query) => searchQuery = query,
              (id) {},
            ),
          ),
        ),
      );

      // Check for correct Swedish no results text
      expect(find.text('Inga vänner matchade din sökning'), findsOneWidget);
      expect(find.byIcon(ButleryIcons.searchOff), findsOneWidget);
    });

    // BUT-2183: the list separator is border.subtle (outlineVariant), not the
    // old 50 % tint of the control outline.
    for (final (name, theme, edge) in [
      ('light', AppTheme.lightTheme, const Color(0xFFCCD1C2)),
      ('dark', AppTheme.darkTheme, const Color(0x2EF5F4ED)),
    ]) {
      testWidgets('$name: friend rows are separated by border.subtle', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Theme(
              data: theme,
              child: Builder(
                builder: (context) => ShareTargetSelection.build(
                  context,
                  mockFriends,
                  <String>{},
                  '',
                  (_) {},
                  (_) {},
                ),
              ),
            ),
          ),
        );

        final dividers = tester.widgetList<Divider>(find.byType(Divider));
        expect(dividers, isNotEmpty);
        expect(dividers.map((d) => d.color).toSet(), {edge});
      });
    }

    group('friend row announcement', () {
      final now = DateTime(2026, 1, 1);
      final anna = UserProfile(
        uid: 'anna',
        displayName: 'Anna Lindgren',
        email: 'anna@example.com',
        joinedAt: now,
        lastActiveAt: now,
      );

      void expectNameOnce(WidgetTester tester) {
        final row = find.widgetWithText(ListTile, 'Anna Lindgren');
        final lines = announcedLines(tester, row);
        expect(
          lines.where((l) => l == 'Anna Lindgren'),
          hasLength(1),
          reason: '$lines',
        );
        expect(lines.where((l) => l.contains('Profilbild')), isEmpty);
        expectActivatable(tester, row);
      }

      testWidgets('plain list: name once, no avatar caption, activatable', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ShareTargetSelection.build(
                context,
                [anna],
                <String>{},
                '',
                (_) {},
                (_) {},
              ),
            ),
          ),
        );

        expectNameOnce(tester);
        handle.dispose();
      });

      testWidgets('enhanced friends tab: name once, no avatar caption, '
          'activatable', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => ShareTargetSelectionEnhanced.build(
                context,
                ShareTargetType.friends,
                [anna],
                const [],
                <String>{},
                <String>{},
                '',
                (_) {},
                (_) {},
                (_) {},
                (_) {},
              ),
            ),
          ),
        );

        expectNameOnce(tester);
        handle.dispose();
      });
    });
  });
}
