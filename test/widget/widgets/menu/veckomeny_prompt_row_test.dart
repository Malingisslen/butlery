/// The week generator's prompt row: the field with the one saffron action
/// beside it (or under it when there is no room), the compact field-only
/// form on a planned week, and the offline reason said once under the row.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/menu/veckomeny_prompt_row.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _FakeOffline extends ChangeNotifier implements OfflineService {
  @override
  bool get isOnline => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _generateKey = ValueKey('test-veckomeny-generate');

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController(text: 'pasta'));
  tearDown(() => controller.dispose());

  Future<void> pump(
    WidgetTester tester, {
    bool hasMenu = false,
    bool compact = false,
    bool isGenerating = false,
    VoidCallback? onGenerate,
    VoidCallback? onClear,
  }) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: VeckomenyPromptRow(
          controller: controller,
          isGenerating: isGenerating,
          hasMenu: hasMenu,
          compact: compact,
          onClear: onClear ?? () {},
          onChanged: () {},
          onGenerate: onGenerate ?? () {},
        ),
      ),
    );
  }

  group('VeckomenyPromptRow', () {
    testWidgets('with room, the button sits beside the field and starts '
        'generation', (tester) async {
      var generated = 0;
      await pump(tester, onGenerate: () => generated++);

      expect(tester.takeException(), isNull);
      final field = tester.getRect(find.byType(StyledInput));
      final button = tester.getRect(find.byKey(_generateKey));
      expect(button.left, greaterThanOrEqualTo(field.right));
      expect(button.top, lessThan(field.bottom));
      expect(button.right, lessThanOrEqualTo(420));

      await tester.tap(find.byType(HeroButton));
      expect(generated, 1);
    });

    testWidgets('the button names a new menu only when one is on screen', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Generera meny'), findsOneWidget);
      expect(find.text('Generera ny meny'), findsNothing);

      await pump(tester, hasMenu: true);
      expect(find.text('Generera ny meny'), findsOneWidget);
      expect(find.text('Generera meny'), findsNothing);
    });

    testWidgets('with nothing typed Generera is switched off', (tester) async {
      controller.clear();
      await pump(tester);

      expect(
        tester.widget<HeroButton>(find.byType(HeroButton)).onPressed,
        isNull,
      );
    });

    testWidgets('the clear cross empties through onClear', (tester) async {
      var cleared = 0;
      await pump(tester, onClear: () => cleared++);

      await tester.tap(find.byTooltip('Rensa'));
      expect(cleared, 1);
    });

    testWidgets('compact: the field alone with the question until there is '
        'text, then the button comes', (tester) async {
      controller.clear();
      await pump(tester, compact: true);

      expect(find.byKey(_generateKey), findsNothing);
      expect(find.text('Vad vill du ha för meny?'), findsOneWidget);

      controller.text = 'pasta';
      await pump(tester, compact: true);
      expect(find.byKey(_generateKey), findsOneWidget);
    });

    testWidgets('while generating the field is off and the button stays', (
      tester,
    ) async {
      controller.clear();
      await pump(tester, compact: true, isGenerating: true);

      expect(find.byKey(_generateKey), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).enabled,
        isFalse,
      );
    });
  });

  group('VeckomenyPromptRow offline', () {
    setUp(() async {
      await GetIt.instance.reset();
      GetIt.instance.registerSingleton<OfflineService>(_FakeOffline());
      prod.ServiceLocator.initialize(DIContainer());
    });

    tearDown(() async {
      prod.ServiceLocator.reset();
      await GetIt.instance.reset();
    });

    testWidgets('Generera is off and the reason is said once, under the row', (
      tester,
    ) async {
      var generated = 0;
      await pump(tester, onGenerate: () => generated++);

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<HeroButton>(find.byType(HeroButton)).onPressed,
        isNull,
      );
      final reason = find.byKey(VeckomenyOfflineReason.reasonKey);
      expect(reason, findsOneWidget);
      expect(
        tester.getRect(reason).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(StyledInput)).bottom),
      );

      await tester.tap(find.byType(HeroButton), warnIfMissed: false);
      expect(generated, 0);
    });
  });
}
