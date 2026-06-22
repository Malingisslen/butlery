/// REC-14 — behaviour tests for [PersonalTagsView], the personal-tags hub.
///
/// The view resolves its [PersonalTagViewModel] through the production
/// [ServiceLocator] (GetIt) and branches its body on four VM states:
///   loading → error → empty → tag list.
/// We register a thin fake VM (a real [ChangeNotifier] so the view's Consumer
/// rebuilds on state changes) over the GetIt bridge — the same seam the real
/// app uses — and assert the user-visible Swedish state for each branch.
///
/// [LayoutComponents.offlineIndicator] resolves [OfflineService] in initState,
/// so an online mock is registered too.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/views/personal_tags_view.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/state_widget.dart';

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
    getIt.registerFactory<PersonalTagViewModel>(() => fakeVm);

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

  Widget testApp() {
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
      home: const PersonalTagsView(),
    );
  }

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(testApp());
    await tester.pump(); // settle the post-frame statistics callback
  }

  testWidgets('renders the app-bar title', (tester) async {
    // Proves: the hub identifies itself with the localized title regardless of
    // state — a baseline that fails if the title key is swapped/removed.
    fakeVm.setState(tags: const [], isLoading: false);
    await pumpView(tester);

    expect(find.text('Personliga taggar'), findsOneWidget);
  });

  testWidgets('empty state shows the localized empty title and create CTA',
      (tester) async {
    // Proves: with no tags the user sees the empty-state guidance, not a blank
    // screen or an error — the !hasTags branch.
    fakeVm.setState(tags: const [], isLoading: false);
    await pumpView(tester);

    expect(find.text('Inga personliga taggar'), findsOneWidget);
    expect(find.text('Skapa taggar för att organisera dina recept'),
        findsOneWidget);
  });

  testWidgets('error state shows the VM error message with a retry action',
      (tester) async {
    // Proves: when the VM reports hasError the error message surfaces with a
    // retry CTA (StateWidget.error wired to viewModel.initialize).
    fakeVm.setState(tags: const [], isLoading: false, error: 'Något gick fel');
    await pumpView(tester);

    expect(find.text('Något gick fel'), findsOneWidget);
    expect(find.text('Försök igen'), findsOneWidget); // commonRetry
  });

  testWidgets('loading state (no tags yet) shows the loading widget, not empty',
      (tester) async {
    // Proves: the isLoading && !hasTags branch renders the branded loading
    // state — the empty/error copy must NOT appear while first load is pending.
    fakeVm.setState(tags: const [], isLoading: true);
    await pumpView(tester);

    expect(find.byType(StateWidget), findsOneWidget);
    expect(find.text('Inga personliga taggar'), findsNothing);
    expect(find.text('Något gick fel'), findsNothing);
  });

  testWidgets('with tags the list renders the tag and the Tags section header',
      (tester) async {
    // Proves: the happy path — a tag the user created appears under the
    // "Taggar" section header, not the empty state.
    final tag = PersonalTag.create(name: 'Vegetariskt');
    fakeVm.setState(
      tags: [tag],
      groups: const <PersonalTagGroup>[],
      isLoading: false,
      usageCounts: {'Vegetariskt': 4},
    );
    await pumpView(tester);

    expect(find.text('Taggar'), findsOneWidget); // personalTagSectionTags
    expect(find.text('Vegetariskt'), findsWidgets);
    expect(find.text('Inga personliga taggar'), findsNothing);
  });

  // Negative control: proves the empty and list branches are genuinely
  // distinguished by hasTags. A list render must NOT also surface the
  // empty-state guidance copy — otherwise the empty-state positive test above
  // would be meaningless.
  testWidgets('tag-list state does not render the empty-state guidance copy',
      (tester) async {
    final tag = PersonalTag.create(name: 'Snabbt');
    fakeVm.setState(
      tags: [tag],
      isLoading: false,
      usageCounts: {'Snabbt': 1},
    );
    await pumpView(tester);

    expect(find.text('Inga personliga taggar'), findsNothing);
    expect(
        find.text('Skapa taggar för att organisera dina recept'), findsNothing);
    expect(find.text('Snabbt'), findsWidgets);
  });
}
