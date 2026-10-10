// BUT-1325: the "Alla recept | Kokböcker" switch as Hem wires it. The switch
// and the shelf have suites of their own; this one drives the real Mina recept
// view, where the choice decides what the library body shows.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/services/tagging/cookbook_service.dart';
import 'package:butlery/viewmodels/cookbook_viewmodel.dart';
import 'package:butlery/views/cookbooks/cookbook_shelf.dart';
import 'package:butlery/views/mina_recept/library_header_row.dart';
import 'package:butlery/views/mina_recept/library_switch.dart';
import 'package:butlery/views/mina_recept/recipe_card_widget.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/cookbook_fixtures.dart';
import '../../../views/design_states/state_harness.dart';
import '../../../views/design_states/state_host.dart';
import '../../../views/design_states/state_hosts.dart'
    show registerHostFallbacks;
import '../../../views/design_states/state_runner.dart';
import '../../../views/golden_linux/golden_hosts.dart';

class _MockCookbookService extends Mock implements CookbookService {}

/// Counts how many times the view asked the shelf's view model to start.
class _SpyCookbookViewModel extends CookbookViewModel {
  _SpyCookbookViewModel(CookbookService service) : super(service: service);

  int starts = 0;

  @override
  void start() {
    starts++;
    super.start();
  }
}

final _row = StateRow(
  view: 'mina_recept',
  state: 'DEFAULT',
  drawing: '-',
  evidence: '-',
  host: '-',
  hostFile: '-',
  hostNote: null,
  block288Category: '-',
  ownerNow: null,
);

void main() {
  late _SpyCookbookViewModel cookbooks;
  late StreamController<List<PersonalTag>> tagStream;

  setUpAll(() {
    registerHostFallbacks();
    registerFallbackValue(cookbookTag());
    registerFallbackValue(const CookbookDetails());
  });

  setUp(() {
    final service = _MockCookbookService();
    tagStream = StreamController<List<PersonalTag>>.broadcast();
    when(service.watchTags).thenAnswer((_) => tagStream.stream);
    when(() => service.libraryChanges).thenAnswer((_) => const Stream.empty());
    when(() => service.libraryRecipes).thenReturn(const <Recipe>[]);
    cookbooks = _SpyCookbookViewModel(service);
  });

  tearDown(() async {
    cookbooks.dispose();
    await tagStream.close();
  });

  /// The real Mina recept host with the cookbook view model registered where
  /// the view fetches it, on first use.
  StateHost hemHost() {
    final base = minaReceptHostWith();
    return StateHost(
      build: (ctx) async {
        final home = await base.build(ctx);
        TestServiceLocator.registerMock<CookbookViewModel>(cookbooks);
        return home;
      },
      reach: base.reach,
    );
  }

  Future<void> withHemClock(
    WidgetTester tester,
    Future<void> Function() body,
  ) {
    final start = tester.binding.clock.now();
    return withClock(
      Clock(() => goldenNow.add(tester.binding.clock.now().difference(start))),
      body,
    );
  }

  Future<StateRun> pumpHem(WidgetTester tester) => pumpState(
    tester,
    _row,
    Brightness.light,
    size: const Size(400, 1600),
    host: hemHost(),
  );

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the switch sits above the library, which shows the recipes', (
    tester,
  ) async {
    await withHemClock(tester, () async {
      final run = await pumpHem(tester);

      expect(find.byType(LibrarySwitch), findsOneWidget);
      expect(find.text('Alla recept'), findsOneWidget);
      expect(find.text('Kokböcker'), findsOneWidget);
      expect(
        tester.getRect(find.byType(LibrarySwitch)).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byType(MinaReceptLibraryHeader)).top,
        ),
      );
      expect(find.byType(MinaReceptRecipeCard), findsWidgets);
      expect(find.byType(CookbookShelf), findsNothing);
      // Hem costs no cookbook reads until the shelf is asked for.
      expect(cookbooks.starts, 0);
      await finishState(tester, run);
    });
  });

  testWidgets('choosing Kokböcker shows the shelf and starts it once', (
    tester,
  ) async {
    await withHemClock(tester, () async {
      final run = await pumpHem(tester);

      await choose(tester, 'Kokböcker');
      tagStream.add([
        cookbookTag(
          id: 'soppor',
          name: 'Soppor',
          cookbook: const CookbookDetails(),
        ),
      ]);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CookbookShelf), findsOneWidget);
      expect(find.text('Soppor'), findsOneWidget);
      expect(cookbooks.starts, 1);
      expect(find.byType(MinaReceptRecipeCard), findsNothing);
      expect(find.byType(MinaReceptLibraryHeader), findsNothing);
      expect(find.byType(LibrarySwitch), findsOneWidget);
      await finishState(tester, run);
    });
  });

  testWidgets('choosing Alla recept brings the recipe list back', (
    tester,
  ) async {
    await withHemClock(tester, () async {
      final run = await pumpHem(tester);
      await choose(tester, 'Kokböcker');
      expect(find.byType(CookbookShelf), findsOneWidget);

      await choose(tester, 'Alla recept');

      expect(find.byType(CookbookShelf), findsNothing);
      expect(find.byType(MinaReceptRecipeCard), findsWidgets);
      expect(find.byType(MinaReceptLibraryHeader), findsOneWidget);
      await finishState(tester, run);
    });
  });

  testWidgets('selection mode takes the switch away', (tester) async {
    await withHemClock(tester, () async {
      final run = await pumpHem(tester);
      expect(find.byType(LibrarySwitch), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mina-recept-select-enter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LibrarySwitch), findsNothing);
      expect(find.text('Kokböcker'), findsNothing);
      expect(find.byType(MinaReceptRecipeCard), findsWidgets);
      await finishState(tester, run);
    });
  });
}
