/// The one question under the store chip: what it says, and that Ja and Nej
/// reach the view model.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/shopping_store.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/shopping/store_order_learner.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/order_suggestion_banner.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockViewModel extends Mock implements UnifiedShoppingViewModel {}

void main() {
  late _MockViewModel viewModel;

  setUp(() {
    viewModel = _MockViewModel();
    when(() => viewModel.activeStore).thenReturn(
      const ShoppingStore(id: 's1', name: 'ICA Maxi'),
    );
    when(() => viewModel.acceptOrderSuggestion()).thenAnswer((_) async {});
    when(() => viewModel.dismissOrderSuggestion()).thenAnswer((_) async {});
  });

  Widget host() => createLocalizedTestApp(
    child: OrderSuggestionBanner(viewModel: viewModel),
  );

  testWidgets('shows nothing without a suggestion', (tester) async {
    when(() => viewModel.orderSuggestion).thenReturn(null);
    await tester.pumpWidget(host());

    expect(
      find.byKey(const ValueKey('unifiedShopping.orderSuggestion')),
      findsNothing,
    );
  });

  testWidgets('names both categories and the store', (tester) async {
    when(() => viewModel.orderSuggestion).thenReturn(
      const StoreOrderSuggestion(
        first: ShoppingCategory.meat,
        second: ShoppingCategory.dairy,
      ),
    );
    await tester.pumpWidget(host());

    expect(
      find.text(
        'Du tar oftast ${ShoppingCategory.displayName(ShoppingCategory.meat)} '
        'före ${ShoppingCategory.displayName(ShoppingCategory.dairy)} '
        'i ICA Maxi. Flytta?',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Ja and Nej reach the view model', (tester) async {
    when(() => viewModel.orderSuggestion).thenReturn(
      const StoreOrderSuggestion(
        first: ShoppingCategory.meat,
        second: ShoppingCategory.dairy,
      ),
    );
    await tester.pumpWidget(host());

    await tester.tap(
      find.byKey(const ValueKey('unifiedShopping.orderSuggestion.yes')),
    );
    verify(() => viewModel.acceptOrderSuggestion()).called(1);
    verifyNever(() => viewModel.dismissOrderSuggestion());

    await tester.tap(
      find.byKey(const ValueKey('unifiedShopping.orderSuggestion.no')),
    );
    verify(() => viewModel.dismissOrderSuggestion()).called(1);
  });
}
