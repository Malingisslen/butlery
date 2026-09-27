// P7-B4: while the ingredient dialog saves, its button keeps its name and
// colours and draws the plate line along its bottom edge (Komponentark
// v1:365, :372; produktregler.md:902), never a spinner (B-18,
// beslutslogg.md:25).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/unknown_ingredient_dialog.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

class _HangingTaggingService implements TaggingService {
  // Made when the save starts, inside the test's fake-async zone, so that
  // completing it is seen by tester.pump.
  Completer<void>? gate;

  @override
  Future<void> saveUserIngredient({
    required String userId,
    required String ingredientName,
    required Set<String> properties,
    String? group,
  }) => (gate = Completer<void>()).future;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Module implements DIModule {
  _Module(this.service);

  final _HangingTaggingService service;

  @override
  String get name => 'UnknownIngredientBusyTestModule';

  @override
  List<Type> get dependencies => const [];

  @override
  List<Type> get provides => const [TaggingService];

  @override
  Future<void> configure(GetIt container) async {
    container.registerSingleton<TaggingService>(service);
  }

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _HangingTaggingService service;

  setUp(() async {
    service = _HangingTaggingService();
    final container = DIContainer();
    await container.reset();
    container.registerModule(_Module(service));
    await container.initialize();
    ServiceLocator.initialize(container);
  });

  tearDown(() => DIContainer().reset());

  for (final dark in [false, true]) {
    testWidgets('the saving button draws the plate line and keeps its name '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('sv'),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => UnknownIngredientDialog.show(
                  ctx,
                  unknownIngredients: const ['shiitake', 'yuzu'],
                  userId: 'u',
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gluten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spara och nästa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ButtonPlateLine), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // The name stays on the button while it works.
      expect(find.text('Spara och nästa'), findsOneWidget);
      expect(
        tester
            .widget<BusyButtonSemantics>(find.byType(BusyButtonSemantics))
            .busy,
        isTrue,
      );

      service.gate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ButtonPlateLine), findsNothing);
      expect(find.text('yuzu'), findsOneWidget, reason: 'moved on');
    });
  }
}
