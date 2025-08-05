import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import '../golden_test_configuration.dart';

void main() {
  configureGoldenTests();
  group('Simple Golden Test', () {
    testGoldens('basic container test', (tester) async {
      await tester.pumpWidgetBuilder(
        Container(
          width: 100,
          height: 100,
          color: Colors.blue,
          child: const Center(
            child: Text(
              'Hello',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
      
      await screenMatchesGolden(tester, 'simple_container');
    });
  });
}