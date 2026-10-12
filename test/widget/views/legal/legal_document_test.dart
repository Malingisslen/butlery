// The shared document reader: a table of contents built from the `##`
// headings that scrolls to its section, and a foot of links that leaves out
// the document it sits on.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/widgets/legal/legal_document.dart';
import 'package:butlery/widgets/legal/legal_link_foot.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  final sv = AppLocalizationsSv();
  final filler = List.filled(40, 'Fyllnad som gör sidan lång.\n').join();
  final content =
      '# Titel\n\nVersion 3\n\n---\n\n## 1. Första\n\n$filler\n## 2. Andra\n\n$filler\nSlut.\n';

  Future<List<String?>> pump(
    WidgetTester tester, {
    LegalDocumentKind current = LegalDocumentKind.guidelines,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final opened = <String?>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: true,
        onGenerateRoute: (settings) {
          opened.add(settings.name);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SizedBox(),
          );
        },
        child: LegalDocument(content: content, current: current),
      ),
    );
    await tester.pumpAndSettle();
    return opened;
  }

  Future<void> scrollToFoot(WidgetTester tester) async {
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -6000),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the headings as numbered rows and a heading in the text', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('1 · Första'), findsNWidgets(2));
    expect(find.text('2 · Andra'), findsNWidgets(2));
  });

  for (final title in ['1 · Första', '2 · Andra']) {
    testWidgets('the contents row "$title" brings its own section to the top', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text(title).first);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text(title).last).dy, lessThan(100));
    });
  }

  final footLabels = {
    LegalDocumentKind.terms: [
      sv.legalLinkPrivacy,
      sv.legalLinkGuidelines,
      sv.legalLinkContact,
    ],
    LegalDocumentKind.privacy: [
      sv.legalLinkTerms,
      sv.legalLinkGuidelines,
      sv.legalLinkContact,
    ],
    LegalDocumentKind.guidelines: [
      sv.legalLinkTerms,
      sv.legalLinkPrivacy,
      sv.legalLinkContact,
    ],
  };
  final allLabels = {
    sv.legalLinkTerms,
    sv.legalLinkPrivacy,
    sv.legalLinkGuidelines,
    sv.legalLinkContact,
  };

  for (final entry in footLabels.entries) {
    testWidgets('on ${entry.key.name} the foot links the others, not itself', (
      tester,
    ) async {
      await pump(tester, current: entry.key);
      await scrollToFoot(tester);

      for (final label in allLabels) {
        expect(
          find.text(label),
          entry.value.contains(label) ? findsOneWidget : findsNothing,
        );
      }
    });
  }

  final opens = [
    (LegalDocumentKind.privacy, sv.legalLinkTerms, Routes.termsOfService),
    (LegalDocumentKind.terms, sv.legalLinkPrivacy, Routes.privacyPolicy),
    (
      LegalDocumentKind.terms,
      sv.legalLinkGuidelines,
      Routes.communityGuidelines,
    ),
  ];
  for (final (current, label, route) in opens) {
    testWidgets('the foot link "$label" opens $route', (tester) async {
      final opened = await pump(tester, current: current);
      await scrollToFoot(tester);

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(opened.last, route);
    });
  }
}
