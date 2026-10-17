import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_personal_tag_handler.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet_header.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../views/recipe/fake_personal_tag_viewmodel.dart';
import '../../infrastructure/factories/recipe_factory.dart';

void main() {
  late AppLocalizations l10n;
  late FakePersonalTagViewModel tagVm;

  setUpAll(() => registerFallbackValue(RecipeFactory.build()));

  setUp(() {
    final getIt = GetIt.instance;
    final now = DateTime(2026, 10, 17);
    tagVm = FakePersonalTagViewModel()
      ..setState(
        tags: [
          PersonalTag(id: 't1', name: 'Vardag', createdAt: now, updatedAt: now),
        ],
      );
    final tagService = MockPersonalTagService();
    when(
      () => tagService.suggestTagsForRecipe(any()),
    ).thenAnswer((_) async => []);
    if (getIt.isRegistered<PersonalTagViewModel>()) {
      getIt.unregister<PersonalTagViewModel>();
    }
    if (getIt.isRegistered<PersonalTagService>()) {
      getIt.unregister<PersonalTagService>();
    }
    getIt.registerFactory<PersonalTagViewModel>(() => tagVm);
    getIt.registerSingleton<PersonalTagService>(tagService);
    production.ServiceLocator.reset();
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() {
    production.ServiceLocator.reset();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersonalTagViewModel>()) {
      getIt.unregister<PersonalTagViewModel>();
    }
    if (getIt.isRegistered<PersonalTagService>()) {
      getIt.unregister<PersonalTagService>();
    }
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ChangeNotifierProvider<RecipeDetailViewModel>.value(
          value: MockRecipeDetailViewModel(),
          child: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return Center(
                child: ElevatedButton(
                  onPressed: () =>
                      RecipePersonalTagHandler.showQuickTagSelector(context),
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the sheet opens with the shared header: tag, title, Avbryt '
      'and Spara', (tester) async {
    await open(tester);

    expect(find.byType(ButlerySheetHeader), findsOneWidget);
    expect(find.text(l10n.taggingPersonalTags), findsOneWidget);
    expect(find.text(l10n.commonCancel), findsOneWidget);
    expect(find.text(l10n.commonSave), findsOneWidget);
    expect(find.text('Vardag'), findsOneWidget);
  });

  testWidgets('Avbryt closes the sheet', (tester) async {
    await open(tester);
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();

    expect(find.byType(ButlerySheetHeader), findsNothing);
  });
}
