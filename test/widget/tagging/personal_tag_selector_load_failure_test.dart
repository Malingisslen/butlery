// The selector does not load tags itself: the shared PersonalTagViewModel
// does, and it ends a failed load by setting its own error (initialize never
// throws). A selector that only read the view model's tags told the user
// they had no tags yet when the load had failed, and offered no retry.
//
// These cases use the REAL view model over a service that fails, so the
// failure arrives the way production produces it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/tagging/personal_tag_types.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/widgets/tagging/personal_tag_selector.dart';

import '../../infrastructure/mocks/production_mocks.dart';

class _Module implements DIModule {
  _Module(this.vm);

  final PersonalTagViewModel vm;

  @override
  String get name => 'PersonalTagSelectorLoadFailureTestModule';

  @override
  List<Type> get dependencies => const [];

  @override
  List<Type> get provides => const [PersonalTagViewModel];

  @override
  Future<void> configure(GetIt container) async {
    container.registerSingleton<PersonalTagViewModel>(vm);
  }

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late MockPersonalTagService service;
  late PersonalTagViewModel viewModel;

  final now = DateTime(2026, 1, 15);
  final tag = PersonalTag(
    id: 'tag-1',
    name: 'Favoriter',
    createdAt: now,
    updatedAt: now,
  );

  setUpAll(() => registerFallbackValue(tag));

  setUp(() async {
    service = MockPersonalTagService();
    when(() => service.getAllTags()).thenThrow(Exception('offline'));
    when(
      () => service.getAllGroups(),
    ).thenAnswer((_) async => <PersonalTagGroup>[]);
    when(() => service.watchTagsWithGroups()).thenAnswer(
      (_) => const Stream<PersonalTagsWithGroups>.empty(),
    );
    viewModel = PersonalTagViewModel(service: service);

    final container = DIContainer();
    await container.reset();
    container.registerModule(_Module(viewModel));
    await container.initialize();
    ServiceLocator.initialize(container);
  });

  tearDown(() => DIContainer().reset());

  Future<AppLocalizations> pumpSelector(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: PersonalTagSelector(
            selectedTagIds: const [],
            onChanged: (_) {},
            showManageButton: false,
          ),
        ),
      ),
    );
    return AppLocalizations.of(
      tester.element(find.byType(PersonalTagSelector)),
    );
  }

  /// Runs the view model's own load through its retry back-off.
  Future<void> failTheInitialLoad(WidgetTester tester) async {
    unawaited(viewModel.initialize());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 8));
    }
  }

  testWidgets(
    'a failed load shows the error and a retry, not the empty state',
    (
      tester,
    ) async {
      final l10n = await pumpSelector(tester);
      await failTheInitialLoad(tester);

      expect(viewModel.loadFailed, isTrue);
      expect(find.text(l10n.personalTagCouldNotLoad), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsOneWidget);
      expect(find.text(l10n.personalTagEmptyTitle), findsNothing);
    },
  );

  testWidgets('retry loads the tags and the error goes away', (tester) async {
    final l10n = await pumpSelector(tester);
    await failTheInitialLoad(tester);
    expect(find.text(l10n.personalTagCouldNotLoad), findsOneWidget);

    when(() => service.getAllTags()).thenAnswer((_) async => [tag]);
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.personalTagCouldNotLoad), findsNothing);
    expect(find.text('Favoriter'), findsOneWidget);
  });

  testWidgets('a failed action with no tags is not reported as a failed load', (
    tester,
  ) async {
    when(
      () => service.getAllTags(),
    ).thenAnswer((_) async => <PersonalTag>[]);
    when(() => service.getNextTagSortOrder()).thenAnswer((_) async => 0);
    when(() => service.createTag(any())).thenThrow(Exception('offline'));
    final l10n = await pumpSelector(tester);
    await viewModel.initialize();
    await viewModel.createTag(name: 'Ny');
    await tester.pump();

    expect(viewModel.hasError, isTrue);
    expect(find.text(l10n.personalTagCouldNotLoad), findsNothing);
    expect(find.text(l10n.personalTagEmptyTitle), findsOneWidget);
  });

  testWidgets('a failure after the tags loaded keeps showing the tags', (
    tester,
  ) async {
    when(() => service.getAllTags()).thenAnswer((_) async => [tag]);
    final l10n = await pumpSelector(tester);
    await viewModel.initialize();
    await tester.pump();
    expect(find.text('Favoriter'), findsOneWidget);

    when(() => service.getAllTags()).thenThrow(Exception('offline'));
    await failTheInitialLoad(tester);

    // The view model keeps its tags through a failed refresh; hiding them
    // behind the error would take away tags the user can still pick.
    expect(find.text('Favoriter'), findsOneWidget);
    expect(find.text(l10n.personalTagCouldNotLoad), findsNothing);
  });
}
