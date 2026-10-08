// BUT-2183 5n: the chat composer's top edge leaves the old opacity steps. The
// hairline between the message list and the composer is outlineVariant, drawn
// on the page background. Runs in both modes and asserts the line and the
// fill.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/messaging/chat_view/chat_input_section.dart';

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;

    testWidgets('the composer top line is outlineVariant on the page '
        'background, $mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('sv', 'SE'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatInputSection(
                conversationId: 'conv-1',
                onSendMessage:
                    (String _, {MessageType type = MessageType.text}) async {},
                onAttachment: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = tester
          .widget<DecoratedBox>(
            find
                .ancestor(
                  of: find.byType(TextField).first,
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is DecoratedBox &&
                        w.decoration is BoxDecoration &&
                        (w.decoration as BoxDecoration).border != null,
                  ),
                )
                .first,
          )
          .decoration;
      final decoration = box as BoxDecoration;
      final top = (decoration.border! as Border).top;
      expect(top.color, cs.outlineVariant);
      expect(top.width, 1);
      expect(decoration.color, theme.scaffoldBackgroundColor);
    });
  }
}
