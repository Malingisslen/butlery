/// A shared shopping list under "Delat med mig" must not offer to join: a seat
/// on a shared list is taken by accepting an invitation (BUT-2089), so a join
/// control here would say "Du gick med" and put nobody on the list (BUT-2382).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_shopping_viewmodel.dart';
import 'package:butlery/views/social/shared_with_me/shared_shopping_list_card.dart';

import '../../../../infrastructure/helpers/widget_test_app.dart';

class _MockCoordinator extends Mock
    implements SharedContentCoordinatorViewModel {}

class _MockShoppingViewModel extends Mock implements SharedShoppingViewModel {}

class _FakeSharedShoppingList extends Fake implements SharedShoppingList {}

void main() {
  late _MockCoordinator coordinator;
  late _MockShoppingViewModel lists;

  final shared = SharedShoppingList(
    id: 'share-1',
    sharedByUserId: 'u-anna',
    sharedByDisplayName: 'Anna',
    listName: 'Fredagsmiddag',
    itemCount: 4,
    originalOwnerId: 'u-anna',
    originalOwnerDisplayName: 'Anna',
  );

  setUpAll(() => registerFallbackValue(_FakeSharedShoppingList()));

  setUp(() {
    lists = _MockShoppingViewModel();
    when(() => lists.isShoppingListViewed(any())).thenReturn(false);
    when(() => lists.markAsViewed(any())).thenAnswer((_) async => true);
    coordinator = _MockCoordinator();
    when(() => coordinator.shoppingViewModel).thenReturn(lists);
  });

  Future<void> pumpCard(WidgetTester tester) => tester.pumpWidget(
    createLocalizedTestApp(
      wrapInScrollView: true,
      child: Builder(
        builder: (context) =>
            SharedShoppingListCard.build(context, coordinator, shared),
      ),
    ),
  );

  // "Gå med", "Gå med i lista" and the saved state "Medlem".
  final joinControls = find.textContaining(RegExp(r'Gå med|Medlem'));

  testWidgets('the row offers no way to join', (tester) async {
    await pumpCard(tester);

    expect(find.textContaining('Fredagsmiddag'), findsWidgets);
    expect(joinControls, findsNothing);
  });

  testWidgets('the preview sheet offers Stäng and no way to join', (
    tester,
  ) async {
    await pumpCard(tester);

    await tester.tap(find.textContaining('Fredagsmiddag').first);
    await tester.pumpAndSettle();

    expect(find.text('Stäng'), findsOneWidget);
    expect(joinControls, findsNothing);
  });
}
