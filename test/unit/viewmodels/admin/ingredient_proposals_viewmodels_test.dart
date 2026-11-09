library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/models/tagging/ingredient_column.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/services/tagging/ingredient_change_pr_service.dart';
import 'package:butlery/viewmodels/admin/bulk_status_proposal_viewmodel.dart';
import 'package:butlery/viewmodels/admin/ingredient_proposal_form_viewmodel.dart';
import 'package:butlery/viewmodels/admin/pending_proposals_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../test_support/ingredient_review_fixtures.dart';

IngredientData _ing(
  String id, {
  String status = 'draft',
  Set<String>? props,
  DateTime? updatedAt,
}) => IngredientData(
  id: id,
  swedish: id,
  english: id,
  group: 'protein/dairy',
  properties: props ?? {'dairy', 'animal-product'},
  status: status,
  updatedAt: updatedAt ?? DateTime.utc(2026, 10, 1),
);

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  group('IngredientProposalFormViewModel', () {
    IngredientProposalFormViewModel build(
      FakeChangeRequestRepository repo, {
      List<IngredientData>? items,
      Object? error,
    }) => IngredientProposalFormViewModel(
      ingredientId: 'milk',
      ingredientRepository: FakeIngredientRepository(
        items ?? [_ing('milk')],
        error: error,
      ),
      repository: repo,
    );

    test('loads the old value from the server read', () async {
      final vm = build(FakeChangeRequestRepository());
      await vm.load();
      expect(vm.current!.id, 'milk');
      expect(vm.valueOf(IngredientColumn.status), 'draft');
    });

    test('an edit equal to the old value is not a change', () async {
      final vm = build(FakeChangeRequestRepository());
      await vm.load();
      vm.setValue(IngredientColumn.status, 'verified');
      expect(vm.changedColumns, [IngredientColumn.status]);
      vm.setValue(IngredientColumn.status, 'draft');
      expect(vm.hasChanges, isFalse);
      vm.setValue(IngredientColumn.properties, ['dairy', 'animal-product']);
      expect(vm.hasChanges, isFalse);
    });

    test('save writes only changed columns with old and new', () async {
      final repo = FakeChangeRequestRepository();
      final vm = build(repo);
      await vm.load();
      vm.setValue(IngredientColumn.status, 'verified');
      vm.setValue(IngredientColumn.english, '  Milk ');
      expect(await vm.save(' rätta '), isTrue);
      final r = repo.created.single;
      expect(r.note, 'rätta');
      expect(r.ingredientUpdatedAt, DateTime.utc(2026, 10, 1));
      expect(r.changes.map((c) => c.column.csvName), ['english', 'status']);
      expect(r.changeFor(IngredientColumn.english)!.oldValue, 'milk');
      expect(r.changeFor(IngredientColumn.english)!.newValue, 'Milk');
    });

    test('nothing changed, invalid or too long a note: no write', () async {
      final repo = FakeChangeRequestRepository();
      final vm = build(repo);
      await vm.load();
      expect(await vm.save(''), isFalse);
      vm.setValue(IngredientColumn.status, 'deleted');
      expect(vm.validation.isValid, isFalse);
      expect(await vm.save(''), isFalse);
      vm.setValue(IngredientColumn.status, 'verified');
      expect(await vm.save('x' * 501), isFalse);
      expect(repo.created, isEmpty);
      expect(await vm.save('x' * 500), isTrue);
      expect(repo.created.single.note, hasLength(500));
    });

    test('list elements and a price are trimmed and typed on save', () async {
      final repo = FakeChangeRequestRepository();
      final vm = build(repo);
      await vm.load();
      vm.setValue(IngredientColumn.properties, [
        ' dairy ',
        'animal-product  ',
        'processed',
      ]);
      vm.setValue(IngredientColumn.avgPriceSek, 12.5);
      expect(await vm.save(''), isTrue);
      final r = repo.created.single;
      expect(r.changeFor(IngredientColumn.properties)!.newValue, [
        'dairy',
        'animal-product',
        'processed',
      ]);
      expect(r.changeFor(IngredientColumn.avgPriceSek)!.newValue, 12.5);
    });

    test('allergen change asks for confirmation', () async {
      final vm = build(FakeChangeRequestRepository());
      await vm.load();
      vm.setValue(IngredientColumn.properties, ['animal-product']);
      expect(vm.needsAllergenConfirmation, isTrue);
    });

    test('a failed write is an error state, not success', () async {
      final vm = build(FakeChangeRequestRepository(failWrites: true));
      await vm.load();
      vm.setValue(IngredientColumn.status, 'verified');
      expect(await vm.save(''), isFalse);
      expect(vm.error, isNotNull);
    });

    test('a failed or empty server read is an error', () async {
      final failing = build(
        FakeChangeRequestRepository(),
        error: StateError('x'),
      );
      await failing.load();
      expect(failing.current, isNull);
      expect(failing.error, isNotNull);
      final missing = build(
        FakeChangeRequestRepository(),
        items: [_ing('other')],
      );
      await missing.load();
      expect(missing.error, isNotNull);
    });
  });

  group('BulkStatusProposalViewModel', () {
    BulkStatusProposalViewModel build(
      List<IngredientData> rows,
      FakeChangeRequestRepository repo,
    ) => BulkStatusProposalViewModel(
      selected: rows,
      repository: repo,
      batchIdFactory: () => 'batch-1',
    );

    test(
      'one proposal per changed row in one batch with a shared id',
      () async {
        final repo = FakeChangeRequestRepository();
        final vm = build([
          _ing('a', updatedAt: DateTime.utc(2026, 9, 3)),
          _ing('b', status: 'verified'),
          _ing('c', status: 'verified'),
        ], repo);
        expect(vm.statusDistribution, {'draft': 1, 'verified': 2});
        expect(vm.rowsChangedBy('verified'), 1);
        expect(await vm.submit('verified'), isTrue);
        expect(repo.batches.single.length, 1);
        final r = repo.batches.single.single;
        expect(r.batchId, 'batch-1');
        expect(r.ingredientId, 'a');
        expect(r.changeFor(IngredientColumn.status)!.oldValue, 'draft');
        expect(r.changeFor(IngredientColumn.status)!.newValue, 'verified');
        expect(r.changes, hasLength(1));
        expect(r.ingredientUpdatedAt, DateTime.utc(2026, 9, 3));
      },
    );

    test('50 rows are allowed, 51 are refused without writing', () async {
      final ok = FakeChangeRequestRepository();
      expect(
        await build([
          for (var i = 0; i < 50; i++) _ing('i$i'),
        ], ok).submit('verified'),
        isTrue,
      );
      expect(ok.batches.single.length, 50);
      final over = FakeChangeRequestRepository();
      final vm = build([for (var i = 0; i < 51; i++) _ing('i$i')], over);
      expect(vm.exceedsLimit, isTrue);
      expect(await vm.submit('verified'), isFalse);
      expect(over.batches, isEmpty);
    });

    test('unknown status or nothing to change writes nothing', () async {
      final repo = FakeChangeRequestRepository();
      final vm = build([_ing('a', status: 'verified')], repo);
      expect(await vm.submit('deleted'), isFalse);
      expect(await vm.submit('verified'), isFalse);
      expect(repo.batches, isEmpty);
    });

    test('a failed batch is an error', () async {
      final vm = build([
        _ing('a'),
      ], FakeChangeRequestRepository(failWrites: true));
      expect(await vm.submit('verified'), isFalse);
      expect(vm.error, isNotNull);
    });
  });

  group('PendingProposalsViewModel', () {
    IngredientChangeRequest req(String id, String ingredient, DateTime? at) =>
        IngredientChangeRequest(
          id: id,
          ingredientId: ingredient,
          createdAt: at,
          changes: const [],
        );

    test('sorts newest first with unsynced first and exposes ids', () async {
      final repo = FakeChangeRequestRepository();
      final vm = PendingProposalsViewModel(repository: repo)..start();
      expect(vm.hasLoaded, isFalse);
      repo.pending.add([
        req('old', 'a', DateTime.utc(2026, 1, 1)),
        req('new', 'b', DateTime.utc(2026, 2, 1)),
        req('local', 'a', null),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(vm.proposals.map((p) => p.id), ['local', 'new', 'old']);
      expect(vm.pendingIngredientIds, {'a', 'b'});
      expect(vm.hasLoaded, isTrue);
      vm.dispose();
    });

    test(
      'word-list proposals are not ingredient ids but are counted',
      () async {
        final repo = FakeChangeRequestRepository();
        final vm = PendingProposalsViewModel(repository: repo)..start();
        repo.pending.add([
          req('i', 'a', DateTime.utc(2026, 1, 1)),
          IngredientChangeRequest.wordList(
            listKey: 'christmas.titleWords',
            oldWords: const ['a'],
            newWords: const ['b'],
          ).withIdentity(id: 'w', createdBy: 'u'),
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(vm.pendingIngredientIds, {'a'});
        expect(vm.waitingCount, 2);
        expect(vm.waitingWordListCount, 1);
        vm.dispose();
      },
    );

    test('a stream error is an error state, never an empty list', () async {
      final repo = FakeChangeRequestRepository();
      final vm = PendingProposalsViewModel(repository: repo)..start();
      repo.pending.addError(StateError('denied'));
      await Future<void>.delayed(Duration.zero);
      expect(vm.error, isNotNull);
      expect(vm.hasLoaded, isTrue);
      vm.dispose();
    });

    test('retry after a stream error resubscribes and recovers', () async {
      final repo = FakeChangeRequestRepository();
      final vm = PendingProposalsViewModel(repository: repo)..start();
      vm.start();
      expect(repo.watchCalls, 1);
      repo.pending.addError(StateError('denied'));
      await Future<void>.delayed(Duration.zero);
      expect(vm.error, isNotNull);
      vm.retry();
      expect(repo.watchCalls, 2);
      expect(vm.error, isNull);
      expect(vm.hasLoaded, isFalse);
      repo.pending.add([req('r1', 'a', DateTime.utc(2026, 1, 1))]);
      await Future<void>.delayed(Duration.zero);
      expect(vm.proposals.map((p) => p.id), ['r1']);
      expect(vm.hasLoaded, isTrue);
      expect(vm.error, isNull);
      vm.dispose();
    });

    test('withdraw calls the repository; failure sets error', () async {
      final repo = FakeChangeRequestRepository();
      final vm = PendingProposalsViewModel(repository: repo);
      expect(await vm.withdraw('r1'), isTrue);
      expect(repo.withdrawn, ['r1']);
      final bad = PendingProposalsViewModel(
        repository: FakeChangeRequestRepository(failWrites: true),
      );
      expect(await bad.withdraw('r1'), isFalse);
      expect(bad.error, isNotNull);
    });

    group('review', () {
      IngredientChangeRequest inState(
        String id,
        IngredientChangeStatus status,
      ) => IngredientChangeRequest(
        id: id,
        ingredientId: id,
        status: status,
        changes: const [],
        createdAt: DateTime.utc(2026, 1, 1),
      );

      Future<PendingProposalsViewModel> loaded(
        FakeChangeRequestRepository repo,
        _FakePrService pr,
      ) async {
        final vm = PendingProposalsViewModel(repository: repo, prService: pr)
          ..start();
        repo.pending.add([
          inState('p1', IngredientChangeStatus.pending),
          inState('p2', IngredientChangeStatus.pending),
          inState('i1', IngredientChangeStatus.inReview),
          inState('c1', IngredientChangeStatus.conflict),
        ]);
        repo.decided.add([
          inState('a1', IngredientChangeStatus.applied),
          inState('r1', IngredientChangeStatus.rejected),
        ]);
        await Future<void>.delayed(Duration.zero);
        return vm;
      }

      test('groups by status; waiting counts pending and inReview', () async {
        final vm = await loaded(
          FakeChangeRequestRepository(),
          _FakePrService(),
        );
        expect(vm.pending.map((p) => p.id), ['p1', 'p2']);
        expect(vm.inReview.map((p) => p.id), ['i1']);
        expect(vm.conflicts.map((p) => p.id), ['c1']);
        expect(vm.applied.map((p) => p.id), ['a1']);
        expect(vm.rejected.map((p) => p.id), ['r1']);
        expect(vm.waitingCount, 3);
        expect(vm.canCreateReview, isTrue);
        vm.dispose();
      });

      test('nothing waiting disables the button and the call', () async {
        final repo = FakeChangeRequestRepository();
        final pr = _FakePrService();
        final vm = PendingProposalsViewModel(repository: repo, prService: pr)
          ..start();
        repo.pending.add([inState('c1', IngredientChangeStatus.conflict)]);
        await Future<void>.delayed(Duration.zero);
        expect(vm.canCreateReview, isFalse);
        expect(await vm.createReview(), isFalse);
        expect(pr.calls, 0);
        vm.dispose();
      });

      test(
        'applied sorts by appliedAt with unsynced first; rejected newest first',
        () async {
          final repo = FakeChangeRequestRepository();
          final vm = PendingProposalsViewModel(
            repository: repo,
            prService: _FakePrService(),
          )..start();
          IngredientChangeRequest row(
            String id,
            IngredientChangeStatus status, {
            DateTime? appliedAt,
            DateTime? createdAt,
          }) => IngredientChangeRequest(
            id: id,
            ingredientId: id,
            status: status,
            changes: const [],
            appliedAt: appliedAt,
            createdAt: createdAt,
          );
          repo.decided.add([
            row(
              'a-old',
              IngredientChangeStatus.applied,
              appliedAt: DateTime.utc(2026, 1, 1),
            ),
            row(
              'a-new',
              IngredientChangeStatus.applied,
              appliedAt: DateTime.utc(2026, 2, 1),
            ),
            row('a-local', IngredientChangeStatus.applied),
            row(
              'r-old',
              IngredientChangeStatus.rejected,
              createdAt: DateTime.utc(2026, 1, 1),
            ),
            row(
              'r-new',
              IngredientChangeStatus.rejected,
              createdAt: DateTime.utc(2026, 3, 1),
            ),
          ]);
          await Future<void>.delayed(Duration.zero);
          expect(vm.applied.map((p) => p.id), ['a-local', 'a-new', 'a-old']);
          expect(vm.rejected.map((p) => p.id), ['r-new', 'r-old']);
          vm.dispose();
        },
      );

      test(
        'a later applied snapshot does not hide a rejected failure',
        () async {
          final repo = FakeChangeRequestRepository();
          final vm = PendingProposalsViewModel(
            repository: repo,
            prService: _FakePrService(),
          )..start();
          repo.pending.add([inState('p1', IngredientChangeStatus.pending)]);
          repo.decided.addError(StateError('denied'));
          await Future<void>.delayed(Duration.zero);
          expect(vm.decidedFailed, isTrue);
          repo.appliedOnly.add([inState('a1', IngredientChangeStatus.applied)]);
          await Future<void>.delayed(Duration.zero);
          expect(vm.applied, hasLength(1));
          // Both streams failed above; applied recovered, rejected has not.
          expect(vm.decidedFailed, isTrue);
          repo.decided.add([inState('r1', IngredientChangeStatus.rejected)]);
          await Future<void>.delayed(Duration.zero);
          expect(vm.decidedFailed, isFalse);
          vm.dispose();
        },
      );

      test('a new createReview clears an earlier error', () async {
        final pr = _FakePrService(
          error: const IngredientChangePrException(
            IngredientChangePrFailure.locked,
          ),
        );
        final vm = await loaded(FakeChangeRequestRepository(), pr);
        expect(await vm.createReview(), isFalse);
        expect(vm.reviewError, isNotNull);
        pr.error = null;
        expect(await vm.createReview(), isTrue);
        expect(vm.reviewError, isNull);
        expect(vm.lastReview, isNotNull);
        vm.dispose();
      });

      test('a decided-stream error keeps the open list', () async {
        final repo = FakeChangeRequestRepository();
        final vm = PendingProposalsViewModel(
          repository: repo,
          prService: _FakePrService(),
        )..start();
        repo.pending.add([inState('p1', IngredientChangeStatus.pending)]);
        repo.decided.addError(StateError('denied'));
        await Future<void>.delayed(Duration.zero);
        expect(vm.decidedFailed, isTrue);
        expect(vm.pending, hasLength(1));
        expect(vm.error, isNull);
        vm.dispose();
      });

      test(
        'createReview success keeps the summary and is busy meanwhile',
        () async {
          final pr = _FakePrService(
            result: const IngredientChangePrResult(
              prNumber: 9,
              prUrl: 'https://github.com/Malingisslen/butlery/pull/9',
              applied: 3,
              conflicts: 1,
              rejected: 0,
              reopened: 0,
              skipped: 0,
            ),
          );
          final vm = await loaded(FakeChangeRequestRepository(), pr);
          final future = vm.createReview();
          expect(vm.isCreatingReview, isTrue);
          expect(vm.canCreateReview, isFalse);
          expect(await future, isTrue);
          expect(vm.isCreatingReview, isFalse);
          expect(vm.lastReview!.prNumber, 9);
          expect(vm.reviewError, isNull);
          vm.dispose();
        },
      );

      final expected = <IngredientChangePrFailure, String>{
        IngredientChangePrFailure.notAdmin: 'behörighet',
        IngredientChangePrFailure.locked: 'skapas just nu',
        IngredientChangePrFailure.tooManyProposals: 'för många förslag',
        IngredientChangePrFailure.notConfigured: 'inte inställd',
        IngredientChangePrFailure.unavailable: 'GitHub svarar inte',
        IngredientChangePrFailure.mainMoved: 'ändrades under tiden',
        IngredientChangePrFailure.foreignCommits: 'Be Claude titta',
        IngredientChangePrFailure.rateLimited: 'för många granskningar',
        IngredientChangePrFailure.other: 'Kunde inte skapa granskningen',
      };
      for (final entry in expected.entries) {
        test(
          'createReview ${entry.key.name} gives a Swedish message',
          () async {
            final pr = _FakePrService(
              error: IngredientChangePrException(entry.key),
            );
            final vm = await loaded(FakeChangeRequestRepository(), pr);
            expect(await vm.createReview(), isFalse);
            expect(vm.reviewError, contains(entry.value));
            expect(vm.lastReview, isNull);
            expect(vm.isCreatingReview, isFalse);
            vm.dispose();
          },
        );
      }

      test('an unexpected exception reads as the generic message', () async {
        final pr = _FakePrService(unexpected: StateError('boom'));
        final vm = await loaded(FakeChangeRequestRepository(), pr);
        expect(await vm.createReview(), isFalse);
        expect(vm.reviewError, contains('Kunde inte skapa granskningen'));
        vm.dispose();
      });
    });
  });
}

class _FakePrService extends Fake implements IngredientChangePrService {
  _FakePrService({this.result, this.error, this.unexpected});

  final IngredientChangePrResult? result;
  IngredientChangePrException? error;
  final Object? unexpected;
  int calls = 0;

  @override
  Future<IngredientChangePrResult> createPr() async {
    calls++;
    await Future<void>.delayed(Duration.zero);
    if (error != null) throw error!;
    if (unexpected != null) throw unexpected!;
    return result ??
        const IngredientChangePrResult(
          prNumber: 1,
          prUrl: '',
          applied: 0,
          conflicts: 0,
          rejected: 0,
          reopened: 0,
          skipped: 0,
        );
  }
}
