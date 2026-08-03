/// BUT-1784: creating a personal list must not be announced as done when the
/// write was refused.
///
/// `ShoppingListManagementModule.createPersonalList` returns `null` for a
/// permission denial, an offline refusal and a malformed name alike, and
/// `UnifiedShoppingViewModel.createPersonalList` folds that into `false`. The
/// dialog used to discard the bool and always call `onSuccess`, so the user was
/// shown `Lista "X" skapad` and then hunted for X in a picker that never
/// showed it.
///
/// Nothing under `test/` drove this helper before this file: the sibling
/// `shopping_list_operations_convert_test.dart` covers the BUT-1723 convert
/// flow only. This is the same "the root cause ships tested, the UI branch does
/// not" hole, one dialog over.
///
/// Deliberately asserted through the CALLBACKS rather than the snackbar: the
/// view owns which channel renders them (`_showSuccessSnackBar` /
/// `_showErrorSnackBar`), and the invariant that must not vary is which of the
/// two the dialog picks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_list_operations.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

/// A real in-memory stand-in, not a mocktail `Mock`: the only thing the dialog
/// asks of the view model is the verdict, and recording the name proves the
/// create was actually ATTEMPTED — without that, "the error branch fired" is
/// also satisfied by a dialog that bailed out before reaching the service.
class _StubShoppingViewModel extends Fake implements UnifiedShoppingViewModel {
  _StubShoppingViewModel({required this.createSucceeds});

  final bool createSucceeds;
  final List<String> requestedNames = [];

  @override
  Future<bool> createPersonalList(String name) async {
    requestedNames.add(name);
    return createSucceeds;
  }
}

void main() {
  late AppLocalizations l10n;
  late List<String> successes;
  late List<String> errors;
  late _StubShoppingViewModel viewModel;

  setUp(() {
    successes = [];
    errors = [];
  });

  /// Drives the real helper end to end: tap the entry point, type a name into
  /// `DialogFactory.showTextInput`, confirm.
  Future<void> createList(
    WidgetTester tester, {
    required bool createSucceeds,
    String name = 'Veckohandling',
  }) async {
    viewModel = _StubShoppingViewModel(createSucceeds: createSucceeds);

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            l10n = context.l10n;
            return TextButton(
              onPressed: () => ShoppingListOperations.showCreateListDialog(
                context,
                viewModel,
                successes.add,
                errors.add,
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.shoppingCreateNewList), findsOneWidget);

    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text(l10n.commonCreate));
    await tester.pumpAndSettle();
  }

  testWidgets('a refused create is reported as a failure, never as a list', (
    tester,
  ) async {
    await createList(tester, createSucceeds: false);

    expect(
      viewModel.requestedNames,
      ['Veckohandling'],
      reason:
          'the create must have been attempted, or the error branch below '
          'proves nothing about the write',
    );
    expect(
      successes,
      isEmpty,
      reason:
          'there is no list to open, rename or shop from — "Lista skapad" '
          'sends the user looking for something that does not exist',
    );
    expect(errors, [l10n.shoppingCouldNotCreateOrSelectList]);
  });

  testWidgets('a successful create still reports the plain success', (
    tester,
  ) async {
    // Recall control: without it, hardcoding the error branch also passes.
    await createList(tester, createSucceeds: true);

    expect(viewModel.requestedNames, ['Veckohandling']);
    expect(successes, [l10n.shoppingListCreated('Veckohandling')]);
    expect(errors, isEmpty);
  });

  testWidgets('a cancelled dialog neither creates nor reports anything', (
    tester,
  ) async {
    viewModel = _StubShoppingViewModel(createSucceeds: true);

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            l10n = context.l10n;
            return TextButton(
              onPressed: () => ShoppingListOperations.showCreateListDialog(
                context,
                viewModel,
                successes.add,
                errors.add,
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();

    // The early return has to stay silent: an `onError` here would tell a user
    // who changed their mind that something went wrong.
    expect(viewModel.requestedNames, isEmpty);
    expect(successes, isEmpty);
    expect(errors, isEmpty);
  });
}
