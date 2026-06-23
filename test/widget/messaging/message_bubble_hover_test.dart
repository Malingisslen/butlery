/// BUT-1358: pin that MessageBubble mounts a HoverableCard ancestor whose rest
/// decoration reproduces the previous StyledCard appearance (a flat filled
/// square — no shadow) and whose hover variant only adds a subtle shadow.
///
/// Intent: BUT-1358 replaced the bubble's StyledCard with a HoverableCard so
/// the bubble gains a web/desktop hover affordance without changing its rest
/// look. This render test guards against a refactor dropping the wrapper or
/// reintroducing a rest shadow / rounded corners.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';
import 'package:butlery/widgets/messaging/message_bubble.dart';

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

Message _message() => Message.text(
  conversationId: 'c1',
  senderId: 'other',
  senderDisplayName: 'Anna',
  content: 'Hej!',
);

void main() {
  group('MessageBubble mounts HoverableCard (BUT-1358)', () {
    testWidgets('renders a HoverableCard ancestor', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MessageBubble(message: _message(), currentUserId: 'me'),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(MessageBubble),
          matching: find.byType(HoverableCard),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rest decoration is a flat filled square with no shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MessageBubble(message: _message(), currentUserId: 'me'),
        ),
      );

      final hoverable = tester.widget<HoverableCard>(
        find.descendant(
          of: find.byType(MessageBubble),
          matching: find.byType(HoverableCard),
        ),
      );

      final rest = hoverable.restDecoration as BoxDecoration;
      expect(
        rest.color,
        isNotNull,
        reason: 'Bubble keeps its solid fill at rest.',
      );
      expect(
        rest.borderRadius,
        BorderRadius.circular(AppDimensions.borderRadiusM),
      );
      expect(
        rest.boxShadow,
        isNull,
        reason: 'Rest stays flat — identical to the old StyledCard.',
      );
    });

    testWidgets('hover variant keeps fill + corners, only adds a shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MessageBubble(message: _message(), currentUserId: 'me'),
        ),
      );

      final hoverable = tester.widget<HoverableCard>(
        find.descendant(
          of: find.byType(MessageBubble),
          matching: find.byType(HoverableCard),
        ),
      );

      final rest = hoverable.restDecoration as BoxDecoration;
      final hover = hoverable.hoverDecoration as BoxDecoration;

      expect(hover.color, equals(rest.color));
      expect(hover.borderRadius, equals(rest.borderRadius));
      expect(
        hover.boxShadow,
        isNotNull,
        reason: 'Hover adds the reserved subtle elevation shadow.',
      );
    });

    testWidgets('display-only bubble (no handlers) defers the cursor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MessageBubble(message: _message(), currentUserId: 'me'),
        ),
      );

      final mouseRegion = tester.widget<MouseRegion>(
        find
            .descendant(
              of: find.byType(HoverableCard),
              matching: find.byType(MouseRegion),
            )
            .first,
      );
      expect(
        mouseRegion.cursor,
        MouseCursor.defer,
        reason:
            'A bubble with no tap/long-press/reaction handler is not '
            'interactive, so it must not imply clickability.',
      );
    });

    testWidgets('interactive bubble (with onTap) shows the click cursor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MessageBubble(
            message: _message(),
            currentUserId: 'me',
            onTap: () {},
          ),
        ),
      );

      final mouseRegion = tester.widget<MouseRegion>(
        find
            .descendant(
              of: find.byType(HoverableCard),
              matching: find.byType(MouseRegion),
            )
            .first,
      );
      expect(mouseRegion.cursor, SystemMouseCursors.click);
    });
  });
}
