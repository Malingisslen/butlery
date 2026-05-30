import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/personal_tag_crud_service.dart';
import 'package:butlery/services/tagging/personal_tag_rule_evaluator.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/widgets/tagging/personal_tag_selector.dart';

import '../../../infrastructure/builders/personal_tag_builder.dart';

class _MockTagRepo extends Mock implements FirebasePersonalTagRepository {}

class _MockGroupRepo extends Mock
    implements FirebasePersonalTagGroupRepository {}

class _MockLookup extends Mock implements IngredientLookupService {}

/// A PersonalTagService whose `tagsMutated` stream and `getAllTags` result are
/// directly controllable, so a test can swap "user scope" instances and drive
/// the BUT-1170 re-bind path. Inherits the REAL static `instanceReady` signal
/// and `onInitialize()` — the wiring under test.
class _FakePersonalTagService extends PersonalTagService {
  _FakePersonalTagService({
    required this.mutationController,
    required this.tags,
    required PersonalTagCrudService crud,
    required PersonalTagRuleEvaluator evaluator,
    required FirebasePersonalTagRepository tagRepo,
    required FirebasePersonalTagGroupRepository groupRepo,
  }) : super(
          crudService: crud,
          ruleEvaluator: evaluator,
          tagRepository: tagRepo,
          groupRepository: groupRepo,
        );

  final StreamController<void> mutationController;
  List<PersonalTag> tags;

  @override
  Stream<void> get tagsMutated => mutationController.stream;

  @override
  Future<List<PersonalTag>> getAllTags() async => tags;
}

_FakePersonalTagService _makeService({
  required StreamController<void> controller,
  required List<PersonalTag> tags,
}) {
  final tagRepo = _MockTagRepo();
  final groupRepo = _MockGroupRepo();
  return _FakePersonalTagService(
    mutationController: controller,
    tags: tags,
    crud: PersonalTagCrudService(
      tagRepository: tagRepo,
      groupRepository: groupRepo,
    ),
    evaluator: PersonalTagRuleEvaluator(lookupService: _MockLookup()),
    tagRepo: tagRepo,
    groupRepo: groupRepo,
  );
}

Widget _host(List<String> tagIds) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AutoPersonalTagDisplay(tagIds: tagIds),
      ),
    );

void main() {
  setUp(() {
    ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  testWidgets(
    'BUT-1170: re-binds to the fresh service after logout→login without unmount',
    (tester) async {
      // The placeholder chips shown while loading run an infinite skeleton
      // shimmer, so pumpAndSettle would never converge — drain async work with
      // explicit pumps instead.
      Future<void> flush() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      // --- Login #1: service instance bound to "Vego" for tag t1 ---
      final ctrl1 = StreamController<void>.broadcast();
      final svc1 = _makeService(
        controller: ctrl1,
        tags: [PersonalTagBuilder().withId('t1').withName('Vego').build()],
      );
      GetIt.instance.registerSingleton<PersonalTagService>(svc1);

      await tester.pumpWidget(_host(const ['t1']));
      await flush();

      // First instance's data renders on the mounted card.
      expect(find.text('Vego'), findsOneWidget);

      // --- Logout: the crud `tagsMutated` controller closes (DI disposes the
      // crud service), then GetIt drops the user-scoped registration. ---
      await ctrl1.close();
      GetIt.instance.unregister<PersonalTagService>();
      await flush();

      // Privacy invariant: once logged out, the card must NOT keep showing the
      // previous user's tag — `onDone` clears the shared cache.
      expect(find.text('Vego'), findsNothing);

      // --- Login #2: a FRESH instance, same tag id now renamed "Vegansk". ---
      final ctrl2 = StreamController<void>.broadcast();
      final svc2 = _makeService(
        controller: ctrl2,
        tags: [PersonalTagBuilder().withId('t1').withName('Vegansk').build()],
      );
      GetIt.instance.registerSingleton<PersonalTagService>(svc2);

      // onInitialize fires PersonalTagService.instanceReady → the widget's
      // static listener re-binds to svc2 and re-fetches, all while the card
      // stays mounted.
      await svc2.initialize();
      await flush();

      // The still-mounted card now reflects the fresh instance — proof the
      // static subscription was re-bound, not left pointing at svc1.
      expect(find.text('Vegansk'), findsOneWidget);
      expect(find.text('Vego'), findsNothing);

      // A mutation on the NEW controller must reach the widget (it would have
      // been ignored before the fix because the sub still pointed at svc1).
      svc2.tags = [
        PersonalTagBuilder().withId('t1').withName('Veganskt').build(),
      ];
      ctrl2.add(null);
      await flush();
      expect(find.text('Veganskt'), findsOneWidget);

      // Unmount so the static shared state (subscriber count → 0) resets.
      await tester.pumpWidget(const SizedBox());
      await ctrl2.close();
    },
  );
}
