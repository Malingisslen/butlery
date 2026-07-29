/// BUT-1723: an unconfirmed conversion must NEVER be reported as a success.
///
/// `ListLifecycleOperations` keeps the source list whenever the copy cannot be
/// read back from the server (`originalKept: true`). That decision only
/// protects anybody if the UI layer branches on it — reporting the usual
/// "Listan omvandlad till personlig" would tell an owner who converted
/// specifically to cut collaborators off that they are out, while every one of
/// them still has access.
///
/// `ShoppingListOperations` had ZERO test references before this file, so the
/// outcome→message mapping was the untested half of the fix (the knowledge
/// file's "root cause ships tested, the UI branch does not" pattern).
///
/// CHANNEL-AGNOSTIC BY DESIGN. Whether the warning reaches the user as the
/// `onError` callback (a snackbar) or as a blocking dialog is a live UX
/// decision — both shapes were on disk during the same review round. What must
/// never vary is the pair asserted here: `onSuccess` is not called, and the
/// user is told the original survived. The helper below therefore collects
/// BOTH channels and the assertions read from the merged result.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping_operations.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_list_operations.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';

class _MockCollaborativeOps extends Mock
    implements CollaborativeShoppingOperations {}

UnifiedShoppingList _collaborativeList() => UnifiedShoppingList(
  id: 'collab-1',
  name: 'Familjehandling',
  ownerId: 'owner-uid',
  ownerDisplayName: 'Malin',
  type: ListType.collaborative,
  items: [UnifiedShoppingItem(id: 'i1', name: 'Mjölk', amount: 1)],
);

void main() {
  late MockUnifiedShoppingService shoppingService;
  late _MockCollaborativeOps collaborativeOps;
  late AppLocalizations l10n;
  late List<String> successes;
  late List<String> errors;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() {
    successes = [];
    errors = [];
    collaborativeOps = _MockCollaborativeOps();
    shoppingService = MockUnifiedShoppingService();
    when(() => shoppingService.collaborative).thenReturn(collaborativeOps);

    if (GetIt.instance.isRegistered<UnifiedShoppingService>()) {
      GetIt.instance.unregister<UnifiedShoppingService>();
    }
    GetIt.instance.registerSingleton<UnifiedShoppingService>(shoppingService);
  });

  tearDown(() {
    if (GetIt.instance.isRegistered<UnifiedShoppingService>()) {
      GetIt.instance.unregister<UnifiedShoppingService>();
    }
  });

  /// Drives the real menu action end to end: tap the entry point, confirm the
  /// danger dialog, let the conversion settle.
  Future<void> convertAndConfirm(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            l10n = context.l10n;
            return TextButton(
              onPressed: () =>
                  ShoppingListOperations.showConvertToPersonalDialog(
                    context,
                    _collaborativeList(),
                    successes.add,
                    errors.add,
                  ),
              child: const Text('convert'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('convert'));
    await tester.pumpAndSettle();
    // The danger dialog whose promise the outcome may contradict.
    expect(find.text(l10n.shoppingConvertToPersonalTitle), findsOneWidget);
    await tester.tap(find.text(l10n.shoppingConvertToPersonal).last);
    await tester.pumpAndSettle();
  }

  /// Every string the user could have been shown, whichever channel carried it.
  List<String> shownToUser(WidgetTester tester) => [
    ...errors,
    ...tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>(),
  ];

  testWidgets(
    'a kept original is never reported as a completed conversion',
    (tester) async {
      when(
        () => collaborativeOps.convertCollaborativeToPersonal(any()),
      ).thenAnswer(
        (_) async => (newListId: 'personal-1', originalKept: true),
      );

      await convertAndConfirm(tester);

      // The whole point: the copy DID get made, so a naive `newListId != null`
      // check reports success — and the shared list is still shared.
      expect(
        successes,
        isEmpty,
        reason:
            'every collaborator still has access; "Listan omvandlad till '
            'personlig" is a false statement about who can see the list',
      );
      // …and the user is actually told, rather than left with a silent
      // duplicate they never learn about.
      expect(
        shownToUser(tester).join('\n'),
        contains('finns kvar'),
        reason:
            'the warning must name the surviving original, through whichever '
            'channel the UX layer currently uses',
      );
    },
  );

  testWidgets(
    'a confirmed conversion still reports the plain success',
    (tester) async {
      // Recall control: the branch above must not have made every conversion
      // report a warning. Without this, hardcoding the warning passes.
      when(
        () => collaborativeOps.convertCollaborativeToPersonal(any()),
      ).thenAnswer(
        (_) async => (newListId: 'personal-1', originalKept: false),
      );

      await convertAndConfirm(tester);

      expect(successes, [l10n.shoppingConvertedToPersonal]);
      expect(errors, isEmpty);
    },
  );

  testWidgets('a conversion that never ran reports the error', (tester) async {
    when(
      () => collaborativeOps.convertCollaborativeToPersonal(any()),
    ).thenAnswer((_) async => (newListId: null, originalKept: false));

    await convertAndConfirm(tester);

    expect(successes, isEmpty);
    expect(errors, [l10n.shoppingConvertError]);
  });

  testWidgets('cancelling the danger dialog converts nothing', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            l10n = context.l10n;
            return TextButton(
              onPressed: () =>
                  ShoppingListOperations.showConvertToPersonalDialog(
                    context,
                    _collaborativeList(),
                    successes.add,
                    errors.add,
                  ),
              child: const Text('convert'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('convert'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();

    verifyNever(() => collaborativeOps.convertCollaborativeToPersonal(any()));
    expect(successes, isEmpty);
    expect(errors, isEmpty);
  });
}
