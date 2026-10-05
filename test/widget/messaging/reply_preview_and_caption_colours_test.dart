// BUT-2209. The preview sits on the bubble: inkRaised under an outgoing
// one, the page colour under an incoming one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/messaging/components/system_message_widget.dart';
import 'package:butlery/widgets/messaging/fullscreen_image_viewer.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    final mode = theme.brightness.name;
    final cs = theme.colorScheme;

    for (final outgoing in [false, true]) {
      final side = outgoing ? 'an outgoing' : 'an incoming';
      testWidgets('$side reply preview takes its bubble\'s colours ($mode)', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Theme(
              data: theme,
              child: ReplyPreviewWidget(
                senderName: 'Erik',
                content: 'Ska vi ta pannkakor?',
                isFromCurrentUser: outgoing,
              ),
            ),
          ),
        );
        final box = tester.widget<Container>(
          find
              .ancestor(of: find.text('Erik'), matching: find.byType(Container))
              .first,
        );
        expect(
          (box.decoration! as BoxDecoration).color,
          outgoing ? AppModeColors.surfaceRaisedOnInk() : cs.surface,
        );
        Color? colour(String text) =>
            tester.widget<Text>(find.text(text)).style?.color;
        expect(
          colour('Erik'),
          outgoing ? AppModeColors.textSecondaryOnInk() : cs.onSurface,
        );
        expect(
          colour('Ska vi ta pannkakor?'),
          outgoing ? AppModeColors.textSecondaryOnInk() : cs.onSurfaceVariant,
        );
      });
    }

    testWidgets('the photo caption is paper on the dark caption band ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: Theme(
            data: theme,
            child: const FullscreenImageViewer(
              imageUrl: 'https://example.invalid/photo.jpg',
              caption: 'Söndagsmiddag',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('Söndagsmiddag')).style?.color,
        cs.onPrimary,
      );
      final band = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Söndagsmiddag'),
              matching: find.byType(Container),
            )
            .first,
      );
      // overlay.inkStrong, the same in both modes.
      expect(band.color, const Color(0x9917251D));
    });
  }
}
