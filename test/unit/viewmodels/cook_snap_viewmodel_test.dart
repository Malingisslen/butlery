import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/viewmodels/cook_snap_viewmodel.dart';

import '../../test_support/base_unit_test.dart';

class _MockCookSnapService extends Mock implements CookSnapService {}

CookSnap _snap(String id) => CookSnap(
  id: id,
  recipeId: 'recipe1',
  userId: 'user2',
  userDisplayName: 'Anna',
  photoUrl: 'https://example.com/$id.jpg',
);

void main() {
  late _MockCookSnapService service;
  late StreamController<List<CookSnap>> failing;
  late StreamController<List<CookSnap>> recovered;
  late CookSnapViewModel viewModel;

  setUp(() async {
    await BaseUnitTest.setupUnit();
    service = _MockCookSnapService();
    failing = StreamController<List<CookSnap>>();
    recovered = StreamController<List<CookSnap>>();
    var calls = 0;
    when(
      () => service.watchCookSnaps(any(), limit: any(named: 'limit')),
    ).thenAnswer((_) => (calls++ == 0 ? failing : recovered).stream);
    viewModel = CookSnapViewModel(
      service: service,
      recipeId: 'recipe1',
      recipeAuthorId: 'author',
      recipeName: 'Pannkakor',
    );
  });

  tearDown(() async {
    if (!viewModel.isDisposed) viewModel.dispose();
    unawaited(failing.close());
    unawaited(recovered.close());
    BaseUnitTest.resetMocks();
  });

  test('retryLoad after a failed watch clears the error and shows the '
      'snaps from a fresh watch', () async {
    failing.addError(Exception('permission-denied'));
    await pumpEventQueue();
    expect(viewModel.hasError, isTrue, reason: 'premise: the watch failed');
    expect(viewModel.snaps, isEmpty);

    viewModel.retryLoad();

    expect(viewModel.hasError, isFalse);
    expect(failing.hasListener, isFalse, reason: 'old watch is dropped');
    expect(recovered.hasListener, isTrue, reason: 'a new watch is started');

    recovered.add([_snap('s1')]);
    await pumpEventQueue();

    expect(viewModel.snaps.map((s) => s.id), ['s1']);
    expect(viewModel.hasError, isFalse);
    expect(viewModel.isLoading, isFalse);
  });

  test('retryLoad on a disposed view model does not start a watch', () async {
    viewModel.dispose();

    viewModel.retryLoad();

    verify(
      () => service.watchCookSnaps(any(), limit: any(named: 'limit')),
    ).called(1);
  });

  group('addSnap', () {
    Future<CookSnapAddOutcome> add() => viewModel.addSnap(
      source: ImageSource.gallery,
    );

    void serviceAnswers(Future<CookSnapAddResult?> Function() answer) {
      when(
        () => service.addCookSnap(
          recipeId: any(named: 'recipeId'),
          recipeAuthorId: any(named: 'recipeAuthorId'),
          recipeName: any(named: 'recipeName'),
          source: any(named: 'source'),
          caption: any(named: 'caption'),
          visibility: any(named: 'visibility'),
        ),
      ).thenAnswer((_) => answer());
    }

    setUpAll(() {
      registerFallbackValue(ImageSource.gallery);
      registerFallbackValue(CookSnapVisibility.sameAsRecipe);
    });

    test(
      'a snap queued offline is reported as queued and is not an error',
      () async {
        // Proves: the screen can tell "kept for later" from a failure and show
        // its own message instead of the upload error.
        serviceAnswers(() async => const CookSnapAddResult.queued());

        expect(await add(), CookSnapAddOutcome.queuedOffline);
        expect(viewModel.hasError, isFalse);
        expect(viewModel.isUploading, isFalse);
      },
    );

    test('a created snap is reported as added', () async {
      serviceAnswers(() async => CookSnapAddResult.created(_snap('s1')));

      expect(await add(), CookSnapAddOutcome.added);
    });

    test('a cancelled pick is not added and is not an error', () async {
      serviceAnswers(() async => null);

      expect(await add(), CookSnapAddOutcome.notAdded);
      expect(viewModel.hasError, isFalse);
    });

    test('a failure is not added and sets the error', () async {
      serviceAnswers(() async => throw Exception('boom'));

      expect(await add(), CookSnapAddOutcome.notAdded);
      expect(viewModel.hasError, isTrue);
    });
  });
}
