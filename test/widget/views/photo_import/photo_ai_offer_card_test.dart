import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/viewmodels/photo_import/photo_import_ai_offer_mixin.dart';
import 'package:butlery/views/photo_import/photo_ai_offer_card.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

Widget _card({
  PhotoAiOfferReason reason = PhotoAiOfferReason.phoneCouldNotRead,
  bool consented = false,
  bool busy = false,
  VoidCallback? onAccept,
  VoidCallback? onDecline,
}) => createLocalizedTestApp(
  wrapInScrollView: true,
  child: PhotoAiOfferCard(
    reason: reason,
    consented: consented,
    busy: busy,
    onAccept: onAccept ?? () {},
    onDecline: onDecline ?? () {},
  ),
);

void main() {
  const lines = {
    PhotoAiOfferReason.phoneCouldNotRead:
        'Telefonen kunde inte läsa hela receptet.',
    PhotoAiOfferReason.noRecipeFound:
        'Telefonen läste texten men hittade inget recept i den.',
    PhotoAiOfferReason.handwriting: 'Handskrivna recept kan bara läsas av AI.',
  };

  for (final entry in lines.entries) {
    testWidgets('shows the line for ${entry.key.name}', (tester) async {
      await tester.pumpWidget(_card(reason: entry.key));
      expect(find.text(entry.value), findsOneWidget);
    });
  }

  testWidgets('not consented shows the consent sentence', (tester) async {
    await tester.pumpWidget(_card());
    expect(find.textContaining('Ditt ja gäller AI-tolkning'), findsOneWidget);
  });

  testWidgets('consented leaves the consent sentence out', (tester) async {
    await tester.pumpWidget(_card(consented: true));
    expect(find.textContaining('Ditt ja gäller'), findsNothing);
    expect(
      find.text(
        'Vill du att AI läser fotot? Då skickas fotot till Google för att läsas.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('buttons call their own callbacks', (tester) async {
    var accepted = 0;
    var declined = 0;
    await tester.pumpWidget(
      _card(onAccept: () => accepted++, onDecline: () => declined++),
    );
    await tester.tap(find.text('Ja, skicka fotot'));
    await tester.pump();
    expect((accepted, declined), (1, 0));
    await tester.tap(find.text('Nej, jag skriver själv'));
    await tester.pump();
    expect((accepted, declined), (1, 1));
  });

  testWidgets('buttons do nothing while busy', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _card(busy: true, onAccept: () => calls++, onDecline: () => calls++),
    );
    await tester.tap(find.text('Ja, skicka fotot'), warnIfMissed: false);
    await tester.tap(find.text('Nej, jag skriver själv'), warnIfMissed: false);
    await tester.pump();
    expect(calls, 0);
  });

  testWidgets('is announced as a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_card());
    final node = tester.getSemantics(find.byType(PhotoAiOfferCard));
    expect(node.flagsCollection.isLiveRegion, isTrue);
    expect(node.label, contains('Telefonen kunde inte läsa'));
    handle.dispose();
  });
}
