// test/core/form/form_fields_manager_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/form/form_fields_manager.dart';

void main() {
  group('FormFieldsManager', () {
    late FormFieldsManager manager;

    setUp(() {
      manager = FormFieldsManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('ska skapa controllers för alla värden', () {
      // Arrange
      final values = ['Ingrediens 1', 'Ingrediens 2', 'Ingrediens 3'];

      // Act
      final controllers = manager.getControllers(values);

      // Assert
      expect(controllers.length, equals(3));
      expect(controllers[0].text, equals('Ingrediens 1'));
      expect(controllers[1].text, equals('Ingrediens 2'));
      expect(controllers[2].text, equals('Ingrediens 3'));
    });

    test('ska ta bort rätt controller vid borttagning', () {
      // Arrange
      final values = ['Rad 1', 'Rad 2', 'Rad 3', 'Rad 4'];
      var controllers = manager.getControllers(values);

      // Verifiera initial state
      expect(controllers[1].text, equals('Rad 2'));

      // Act - Ta bort index 1 (Rad 2)
      values.removeAt(1);
      manager.removeController(1);
      controllers = manager.getControllers(values);

      // Assert
      expect(controllers.length, equals(3));
      expect(controllers[0].text, equals('Rad 1'));
      expect(
        controllers[1].text,
        equals('Rad 3'),
      ); // Detta var tidigare index 2
      expect(
        controllers[2].text,
        equals('Rad 4'),
      ); // Detta var tidigare index 3
    });

    test('ska hantera borttagning av sista raden korrekt', () {
      // Arrange
      final values = ['Rad 1', 'Rad 2', 'Rad 3'];
      var controllers = manager.getControllers(values);

      // Act - Ta bort sista index
      values.removeLast();
      manager.removeController(2);
      controllers = manager.getControllers(values);

      // Assert
      expect(controllers.length, equals(2));
      expect(controllers[0].text, equals('Rad 1'));
      expect(controllers[1].text, equals('Rad 2'));
    });

    test('ska hantera borttagning av första raden korrekt', () {
      // Arrange
      final values = ['Rad 1', 'Rad 2', 'Rad 3'];
      var controllers = manager.getControllers(values);

      // Act - Ta bort första index
      values.removeAt(0);
      manager.removeController(0);
      controllers = manager.getControllers(values);

      // Assert
      expect(controllers.length, equals(2));
      expect(controllers[0].text, equals('Rad 2'));
      expect(controllers[1].text, equals('Rad 3'));
    });

    test('ska inte ta bort om det bara finns en rad', () {
      // Arrange
      final values = ['Enda raden'];
      var controllers = manager.getControllers(values);

      // Act
      manager.removeController(0);

      // Assert - Ska fortfarande ha en controller
      controllers = manager.getControllers(values);
      expect(controllers.length, equals(1));
    });

    test('ska hantera onValueChanged callback', () {
      // Arrange
      String? lastChangedValue;
      int? lastChangedIndex;

      final managerWithCallback = FormFieldsManager(
        onValueChanged: (index, value) {
          lastChangedIndex = index;
          lastChangedValue = value;
        },
      );

      final values = ['Test'];
      final controllers = managerWithCallback.getControllers(values);

      // Act
      controllers[0].text = 'Ändrad text';

      // Assert
      expect(lastChangedIndex, equals(0));
      expect(lastChangedValue, equals('Ändrad text'));

      managerWithCallback.dispose();
    });

    test('ska städa upp oanvända controllers', () {
      // Arrange
      var values = ['Rad 1', 'Rad 2', 'Rad 3'];
      manager.getControllers(values);

      // Act - Minska antalet värden
      values = ['Rad 1'];
      final controllers = manager.getControllers(values);

      // Assert
      expect(controllers.length, equals(1));
      expect(manager.hasController(0), isTrue);
      expect(manager.hasController(1), isFalse);
      expect(manager.hasController(2), isFalse);
    });

    test('ska hantera tom lista', () {
      // Arrange
      final values = <String>[];

      // Act
      final controllers = manager.getControllers(values);

      // Assert - Ska skapa minst en controller
      expect(controllers.length, equals(1));
      expect(controllers[0].text, isEmpty);
    });
  });

  group('FormFieldsManager Integration', () {
    testWidgets('ska fungera korrekt i en widget', (tester) async {
      // Arrange
      final manager = FormFieldsManager();
      final values = ['Item 1', 'Item 2', 'Item 3'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                final controllers = manager.getControllers(values);
                return Column(
                  children:
                      controllers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final controller = entry.value;
                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: ValueKey('field_$index'),
                                controller: controller,
                              ),
                            ),
                            IconButton(
                              key: ValueKey('delete_$index'),
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                setState(() {
                                  values.removeAt(index);
                                  manager.removeController(index);
                                });
                              },
                            ),
                          ],
                        );
                      }).toList(),
                );
              },
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.byKey(const ValueKey('field_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('field_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('field_2')), findsOneWidget);

      // Act - Ta bort mittenfältet
      await tester.tap(find.byKey(const ValueKey('delete_1')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byKey(const ValueKey('field_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('field_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('field_2')), findsNothing);

      // Verifiera att rätt innehåll finns kvar
      final field0 = tester.widget<TextField>(
        find.byKey(const ValueKey('field_0')),
      );
      final field1 = tester.widget<TextField>(
        find.byKey(const ValueKey('field_1')),
      );

      expect(field0.controller!.text, equals('Item 1'));
      expect(
        field1.controller!.text,
        equals('Item 3'),
      ); // Detta var tidigare Item 3

      manager.dispose();
    });
  });
}
