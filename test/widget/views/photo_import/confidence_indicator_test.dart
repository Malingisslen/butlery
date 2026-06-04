/// BUT-1196: widget smoke test for [ConfidenceIndicator].
///
/// The BUT-1154 photo_import_view decomposition turned this badge into a pure
/// `StatelessWidget` taking a single `double confidence` — so the threshold →
/// (color, icon, percent-text) mapping is now directly widget-testable. This is
/// the one extracted sub-widget where a future threshold tweak could silently
/// regress; pinning the three buckets here makes that regression loud.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/views/photo_import/confidence_indicator.dart';

/// Captures the theme-resolved badge colors so assertions compare against the
/// real tokens (not hard-coded literals that would drift from the theme).
class _Tokens {
  late Color success;
  late Color warning;
  late Color error;
}

Future<_Tokens> _pump(WidgetTester tester, double confidence) async {
  final tokens = _Tokens();
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('sv'),
    home: Scaffold(
      body: Builder(builder: (context) {
        tokens
          ..success = context.butleryColors.success
          ..warning = context.butleryColors.warning
          ..error = Theme.of(context).colorScheme.error;
        return ConfidenceIndicator(confidence: confidence);
      }),
    ),
  ));
  return tokens;
}

Icon _icon(WidgetTester tester) => tester.widget<Icon>(find.byType(Icon));

void main() {
  group('ConfidenceIndicator — percent text', () {
    testWidgets('renders the truncated integer percentage', (tester) async {
      await _pump(tester, 0.876); // 87.6 -> toInt() truncates to 87
      expect(find.text('87%'), findsOneWidget);
    });

    testWidgets('floors rather than rounds (0.999 -> 99%)', (tester) async {
      await _pump(tester, 0.999);
      expect(find.text('99%'), findsOneWidget);
    });
  });

  group('ConfidenceIndicator — threshold buckets', () {
    testWidgets('>= 0.8 → success / check_circle', (tester) async {
      final tokens = await _pump(tester, 0.8);
      final icon = _icon(tester);
      expect(icon.icon, Icons.check_circle);
      expect(icon.color, tokens.success);
    });

    testWidgets('0.6..0.79 → warning / info', (tester) async {
      final tokens = await _pump(tester, 0.6);
      final icon = _icon(tester);
      expect(icon.icon, Icons.info);
      expect(icon.color, tokens.warning);
    });

    testWidgets('< 0.6 → error / warning', (tester) async {
      final tokens = await _pump(tester, 0.59);
      final icon = _icon(tester);
      expect(icon.icon, Icons.warning);
      expect(icon.color, tokens.error);
    });
  });
}
