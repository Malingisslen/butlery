import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  test('an ingredient row written as a range keeps the whole range', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestServiceLocator.initialize();
    final result = await TextImportStrategy().import(
      'Äggröra\n4 portioner\nIngredienser\n6-8 ägg\n2 dl mjölk\n'
      '125 g smör • 1 tsk salt\nGör så här\nVispa ihop allt och stek i smör.\n',
    );
    final rows = result.recipe!.ingredients;
    expect(rows, contains('6-8 ägg'));
    expect(rows, containsAll(['125 g smör', '1 tsk salt']));
  });
}
