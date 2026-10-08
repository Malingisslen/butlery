// P7-B4: while the tags load, the selector shows the plate line with what it
// is fetching, never a spinner (produktregler.md:163, B-18;
// beslutslogg.md:25).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/interfaces/di_module.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/tagging/personal_tag_selector.dart';

class _LoadingViewModel extends ChangeNotifier implements PersonalTagViewModel {
  @override
  bool get isLoading => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Module implements DIModule {
  _Module(this.vm);

  final _LoadingViewModel vm;

  @override
  String get name => 'PersonalTagSelectorLoadingTestModule';

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
  setUp(() async {
    final container = DIContainer();
    await container.reset();
    container.registerModule(_Module(_LoadingViewModel()));
    await container.initialize();
    ServiceLocator.initialize(container);
  });

  tearDown(() => DIContainer().reset());

  testWidgets('loading tags: plate line and "Hämtar dina taggar …"', (
    tester,
  ) async {
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
          ),
        ),
      ),
    );
    await tester.pump();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(PersonalTagSelector)),
    );
    expect(find.byType(PlateLineMessage), findsOneWidget);
    expect(find.text(l10n.loadingPersonalTags), findsOneWidget);
    expect(l10n.loadingPersonalTags, endsWith(' …'));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
