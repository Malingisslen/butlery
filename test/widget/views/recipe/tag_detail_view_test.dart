/// REC-15 — behaviour tests for [TagDetailView], the single-tag detail screen.
///
/// The view resolves its [PersonalTagViewModel] through the production
/// [ServiceLocator] (GetIt) and looks the tag up by id in `build`. It branches
/// on three VM states (loading-while-missing → not-found → loaded) and carries
/// a local edit-mode toggle in its app bar. We register a thin fake VM over the
/// GetIt bridge and assert the user-visible Swedish behaviour for each branch
/// plus the edit-mode transition.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/views/tag_detail_view.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../../infrastructure/mocks/production_mocks.dart';
import 'fake_personal_tag_viewmodel.dart';

void main() {
  late FakePersonalTagViewModel fakeVm;
  late MockOfflineService offlineService;

  setUp(() {
    final getIt = GetIt.instance;

    fakeVm = FakePersonalTagViewModel();
    if (getIt.isRegistered<PersonalTagViewModel>()) {
      getIt.unregister<PersonalTagViewModel>();
    }
    // TagDetailView.build() resolves the VM once per build and calls selectTag;
    // a singleton keeps the same configured fake across rebuilds.
    getIt.registerSingleton<PersonalTagViewModel>(fakeVm);

    offlineService = MockOfflineService();
    when(() => offlineService.isOnline).thenReturn(true);
    when(() => offlineService.addListener(any())).thenReturn(null);
    when(() => offlineService.removeListener(any())).thenReturn(null);
    if (getIt.isRegistered<OfflineService>()) {
      getIt.unregister<OfflineService>();
    }
    getIt.registerSingleton<OfflineService>(offlineService);

    production.ServiceLocator.reset();
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() {
    production.ServiceLocator.reset();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersonalTagViewModel>()) {
      getIt.unregister<PersonalTagViewModel>();
    }
    if (getIt.isRegistered<OfflineService>()) {
      getIt.unregister<OfflineService>();
    }
  });

  Widget testApp(String tagId) {
    return MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: TagDetailView(tagId: tagId),
    );
  }

  Future<void> pumpView(WidgetTester tester, String tagId) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(testApp(tagId));
    await tester.pump(); // settle the post-frame loadRuleEffectiveness callback
  }

  testWidgets('loaded tag shows its name in the app bar and the recipe count',
      (tester) async {
    // Proves: the happy path — the resolved tag's name titles the screen and
    // its usage count is rendered via TagDetailHeader.
    final tag = PersonalTag.create(name: 'Vardagsmat');
    fakeVm.setState(
      tags: [tag],
      isLoading: false,
      usageCounts: {'Vardagsmat': 3},
    );
    await pumpView(tester, tag.id);

    expect(find.text('Vardagsmat'), findsWidgets);
    expect(find.text('3 recept'), findsOneWidget); // tagDetailRecipeCount(3)
  });

  testWidgets('unknown tag id shows the not-found error state', (tester) async {
    // Proves: when no tag matches the id (and we are not loading), the user
    // gets the localized "could not find the tag" state, not a blank screen.
    fakeVm.setState(tags: const [], isLoading: false);
    await pumpView(tester, 'does-not-exist');

    expect(find.text('Taggen kunde inte hittas'), findsOneWidget);
    expect(find.text('Tagg'), findsOneWidget); // tagDetailDefaultTitle
  });

  testWidgets('loading while tag not yet present shows the loading title',
      (tester) async {
    // Proves: the isLoading && tag==null branch shows the "Laddar..." app bar
    // rather than prematurely flashing the not-found error.
    fakeVm.setState(tags: const [], isLoading: true);
    await pumpView(tester, 'pending-id');

    expect(find.text('Laddar...'), findsOneWidget); // commonLoading
    expect(find.text('Taggen kunde inte hittas'), findsNothing);
  });

  testWidgets('tapping edit enters edit mode with a Save action and name field',
      (tester) async {
    // Proves: the edit IconButton flips the local edit mode — the app bar shows
    // the edit title + a Save action and the body exposes the name text field
    // seeded with the current tag name.
    final tag = PersonalTag.create(name: 'Helg');
    fakeVm.setState(
      tags: [tag],
      isLoading: false,
      usageCounts: {'Helg': 1},
    );
    await pumpView(tester, tag.id);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Redigera tagg'), findsOneWidget); // tagDetailEditTitle
    expect(find.text('Spara'), findsOneWidget); // commonSave
    expect(find.byType(TextField), findsOneWidget);
    // The name field is pre-filled with the tag's current name.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Helg',
    );
  });

  testWidgets('closing edit mode returns to the detail app bar',
      (tester) async {
    // Proves: the edit-mode close (X) restores the read view — the Save action
    // disappears and the tag name titles the screen again.
    final tag = PersonalTag.create(name: 'Helg');
    fakeVm.setState(
      tags: [tag],
      isLoading: false,
      usageCounts: {'Helg': 1},
    );
    await pumpView(tester, tag.id);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    expect(find.text('Spara'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Spara'), findsNothing);
    expect(find.text('Redigera tagg'), findsNothing);
    expect(find.text('Helg'), findsWidgets);
  });
}
