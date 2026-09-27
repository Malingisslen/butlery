/// P7-U04 follow-up: the FAB theme's CircleBorder is inherited by every
/// FloatingActionButton.extended that sets no shape of its own, which would
/// draw a labelled button as a 56 dp disc with the label spilling out. Both
/// labelled FABs in the app therefore set a pill (Komponentark v1:665;
/// tokens.json space.radius.pill). Checked under the real app theme in both
/// modes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/social/friend_requests/friend_request_actions.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/social_components/invitation_actions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';

void main() {
  final themes = {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  };

  Widget app(ThemeData theme, Widget Function(BuildContext) fab) {
    return MaterialApp(
      theme: theme,
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: DefaultTabController(
        length: 2,
        child: Builder(
          builder: (context) => Scaffold(
            body: const SizedBox.shrink(),
            floatingActionButton: fab(context),
          ),
        ),
      ),
    );
  }

  ShapeBorder fabShape(WidgetTester tester) {
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(FloatingActionButton),
            matching: find.byType(Material),
          )
          .first,
    );
    return material.shape!;
  }

  for (final entry in themes.entries) {
    testWidgets('accept-selected FAB is a pill (${entry.key})', (
      tester,
    ) async {
      final actions = FriendRequestActions();
      await tester.pumpWidget(
        app(
          entry.value,
          (context) => actions.buildFloatingActionButton(
            context,
            DefaultTabController.of(context),
            {'req-1'},
            () {},
            batchRunning: false,
          )!,
        ),
      );
      expect(fabShape(tester), isA<StadiumBorder>());
    });

    testWidgets('send-invitations FAB is a pill (${entry.key})', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          entry.value,
          (_) => InvitationActions.floatingActionButtons(
            onSendInvitations: () {},
            showAdd: false,
          ),
        ),
      );
      expect(fabShape(tester), isA<StadiumBorder>());
    });

    testWidgets('plain FAB stays round (${entry.key})', (tester) async {
      await tester.pumpWidget(
        app(
          entry.value,
          (_) => FloatingActionButton(
            onPressed: () {},
            child: const ButleryIcon(ButleryIcons.plus),
          ),
        ),
      );
      expect(fabShape(tester), isA<CircleBorder>());
    });
  }
}
