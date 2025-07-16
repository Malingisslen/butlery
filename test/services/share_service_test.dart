import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:butlery/services/share_service.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

abstract class ShoppingRepository {
  List<UnifiedShoppingItem> getItems();
}

class MockShoppingRepository extends Mock implements ShoppingRepository {}

void main() {
  group('ShareService.formatShoppingList', () {
    late ShareService service;
    late MockShoppingRepository repository;

    setUp(() {
      service = ShareService();
      repository = MockShoppingRepository();
    });

    test('creates formatted shopping list text', () {
      final items = [
        UnifiedShoppingItem.basic(name: 'Ägg', amount: 12, unit: 'st'),
        UnifiedShoppingItem.basic(name: 'Mjölk', amount: 2, unit: 'L'),
      ];

      when(repository.getItems()).thenReturn(items);

      final text = service.formatShoppingList(repository.getItems());

      expect(text, contains('Ägg'));
      expect(text, contains('Mjölk'));
      expect(text, contains('🛒 INKÖPSLISTA'));
    });
  });
}
