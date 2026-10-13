import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:butlery/widgets/social/profile_header.dart';

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    final mode = theme.brightness.name;
    final cs = theme.colorScheme;

    Future<void> pump(
      WidgetTester tester, {
      String? bio,
      ProfileStatsLayout layout = ProfileStatsLayout.stacked,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileHeader(
              displayName: 'Erik Sandell',
              subline: 'Vänner sedan mars 2026',
              bio: bio,
              statsLayout: layout,
              stats: const [ProfileStat(value: 84, label: 'recept')],
            ),
          ),
        ),
      ),
    );

    Finder band() => find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == cs.primary,
    );

    testWidgets('$mode: name, line and bio sit on the ink band, edge to edge', (
      tester,
    ) async {
      await pump(tester, bio: 'Surdegsnörd');
      for (final text in [
        'Erik Sandell',
        'Vänner sedan mars 2026',
        'Surdegsnörd',
      ]) {
        expect(
          find.ancestor(of: find.text(text), matching: band()),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        tester.getSize(band()).width,
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
      );
      final name = tester.widget<Text>(find.text('Erik Sandell'));
      expect(name.style?.color, cs.onPrimary);
      final line = tester.widget<Text>(find.text('Vänner sedan mars 2026'));
      expect(line.style?.color, AppModeColors.textSecondaryOnInk());
    });

    testWidgets('$mode: the avatar is the header size on ink', (tester) async {
      await pump(tester);
      final avatar = tester.widget<AvatarCircle>(find.byType(AvatarCircle));
      expect(avatar.size, AvatarCircleSize.header);
      expect(avatar.tone, AvatarCircleTone.onInk);
    });

    for (final layout in ProfileStatsLayout.values) {
      testWidgets('$mode: the figures sit below the band ($layout)', (
        tester,
      ) async {
        await pump(tester, layout: layout);
        final stat = find.textContaining('84');
        expect(stat, findsOneWidget);
        expect(find.ancestor(of: stat, matching: band()), findsNothing);
        expect(
          tester.getTopLeft(stat).dy,
          greaterThanOrEqualTo(tester.getRect(band()).bottom),
        );
      });
    }

    testWidgets('$mode: no bio, no bio text', (tester) async {
      await pump(tester);
      expect(find.text('Surdegsnörd'), findsNothing);
    });
  }
}
